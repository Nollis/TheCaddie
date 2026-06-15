import Foundation

public enum CaddieRecommendationEngine {
    public static func build(
        course: Course?,
        player: PlayerContext,
        roundState: RoundState
    ) -> CaddieRecommendationPacket {
        let context = CurrentShotContext.resolve(
            course: course,
            player: player,
            roundState: roundState
        )

        switch context {
        case .noCourseLoaded:
            return statusPacket(
                status: .noCourseLoaded,
                reason: "Load a course before asking for a shot.",
                strategyPreference: player.strategyPreference
            )

        case let .unknownHole(holeNumber):
            return statusPacket(
                status: .unknownHole,
                holeNumber: holeNumber,
                reason: "Hole \(holeNumber) is not available in this course.",
                strategyPreference: player.strategyPreference
            )

        case let .missingDistance(course, hole, player, shot):
            return contextPacket(
                status: .missingDistance,
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                reason: "Add a distance before choosing a club.",
                confidence: .low
            )

        case let .missingLie(course, hole, player, shot):
            return contextPacket(
                status: .missingLie,
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                reason: "Choose the lie before trusting the recommendation.",
                confidence: .low
            )

        case let .ready(course, hole, player, shot):
            return readyPacket(course: course, hole: hole, player: player, shot: shot)
        }
    }

    private static func readyPacket(
        course: Course,
        hole: CourseHole,
        player: PlayerContext,
        shot: ShotContext
    ) -> CaddieRecommendationPacket {
        guard let remainingDistance = shot.remainingDistanceM.value,
              let lie = shot.lie.value else {
            return contextPacket(
                status: .unavailable,
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                reason: "Shot context is incomplete.",
                confidence: .low
            )
        }

        let distanceBasis = adjustedDistance(
            remainingDistance,
            wind: shot.wind,
            strategy: player.strategyPreference
        )
        let approachHazards = relevantHazards(
            for: hole.hazards,
            fromTeeProgressM: currentProgressM(
                holeLengthM: hole.teeLengthM,
                remainingDistanceM: remainingDistance
            )
        )

        if shouldRecommendAdvancement(
            distanceBasisM: distanceBasis,
            lie: lie,
            clubs: player.clubs
        ) {
            return advancementPacket(
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                remainingDistanceM: remainingDistance,
                lie: lie
            )
        }

        guard let club = selectClub(
            from: player.clubs,
            distanceBasisM: distanceBasis,
            strategy: player.strategyPreference
        ) else {
            return contextPacket(
                status: .unavailable,
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                reason: "No club in the current bag covers this shot.",
                confidence: .low
            )
        }

        let target = targetLabel(
            for: player.strategyPreference,
            hazards: approachHazards
        )
        let riskNote = riskNote(for: approachHazards, strategy: player.strategyPreference)
        let windPhrase = windPhrase(for: shot.wind)
        let primaryReason = "\(club.name) covers the \(formatMeters(distanceBasis))m playing number\(windPhrase)."

        return CaddieRecommendationPacket(
            status: .ready,
            courseId: course.id,
            holeNumber: hole.number,
            par: hole.par,
            shotNumber: shot.shotNumber,
            remainingDistanceM: remainingDistance,
            lie: lie,
            strategyPreference: player.strategyPreference,
            target: target,
            recommendedClub: club.name,
            clubCarryDistanceM: club.carryDistanceM,
            distanceBasisM: distanceBasis,
            primaryReason: primaryReason,
            riskNote: riskNote,
            confidence: confidence(for: club, distanceBasisM: distanceBasis, lie: lie)
        )
    }

    private static func advancementPacket(
        course: Course,
        hole: CourseHole,
        player: PlayerContext,
        shot: ShotContext,
        remainingDistanceM: Double,
        lie: ShotLie
    ) -> CaddieRecommendationPacket {
        guard let club = advancementClub(
            from: player.clubs,
            strategy: player.strategyPreference
        ) else {
            return contextPacket(
                status: .unavailable,
                course: course,
                hole: hole,
                player: player,
                shot: shot,
                reason: "No club in the current bag covers this shot.",
                confidence: .low
            )
        }

        let progressM = currentProgressM(
            holeLengthM: hole.teeLengthM,
            remainingDistanceM: remainingDistanceM
        )
        let landingHazards = advancementHazards(
            from: hole.hazards,
            currentProgressM: progressM,
            projectedLandingM: progressM + club.carryDistanceM
        )
        let leaveDistance = max(0, remainingDistanceM - club.carryDistanceM)
        let target = advancementTargetLabel(
            for: player.strategyPreference,
            hazards: landingHazards,
            leaveDistanceM: leaveDistance
        )
        let primaryReason = "\(club.name) advances the ball about \(formatMeters(club.carryDistanceM))m and leaves roughly \(formatMeters(leaveDistance))m in."

        return CaddieRecommendationPacket(
            status: .ready,
            courseId: course.id,
            holeNumber: hole.number,
            par: hole.par,
            shotNumber: shot.shotNumber,
            remainingDistanceM: remainingDistanceM,
            lie: lie,
            strategyPreference: player.strategyPreference,
            target: target,
            recommendedClub: club.name,
            clubCarryDistanceM: club.carryDistanceM,
            distanceBasisM: club.carryDistanceM,
            primaryReason: primaryReason,
            riskNote: advancementRiskNote(for: landingHazards, strategy: player.strategyPreference),
            confidence: .medium
        )
    }

    private static func shouldRecommendAdvancement(
        distanceBasisM: Double,
        lie: ShotLie,
        clubs: [PlayerClub]
    ) -> Bool {
        guard lie != .bunker, lie != .recovery else {
            return false
        }

        return !hasCoveringClub(
            in: clubs,
            distanceBasisM: distanceBasisM
        )
    }

    private static func adjustedDistance(
        _ remainingDistance: Double,
        wind: WindContext?,
        strategy: StrategyPreference
    ) -> Double {
        let windAdjustment: Double
        switch wind?.direction {
        case .helping:
            windAdjustment = -(wind?.speedMps ?? 0) * 1.5
        case .hurting:
            windAdjustment = (wind?.speedMps ?? 0) * 2.0
        case .cross:
            windAdjustment = (wind?.speedMps ?? 0) * 0.5
        case nil:
            windAdjustment = 0
        }

        let strategyBias: Double
        switch strategy {
        case .safe:
            strategyBias = 4
        case .normal:
            strategyBias = 0
        case .aggressive:
            strategyBias = -3
        }

        return max(1, remainingDistance + windAdjustment + strategyBias)
    }

    private static func selectClub(
        from clubs: [PlayerClub],
        distanceBasisM: Double,
        strategy: StrategyPreference
    ) -> PlayerClub? {
        let sortedAscending = clubs.sorted { lhs, rhs in
            lhs.carryDistanceM < rhs.carryDistanceM
        }

        switch strategy {
        case .safe:
            return sortedAscending.first { $0.carryDistanceM >= distanceBasisM }
        case .normal:
            let shortToleranceM = 1.0
            return sortedAscending.first { $0.carryDistanceM + shortToleranceM >= distanceBasisM }
                ?? sortedAscending.last
        case .aggressive:
            return sortedAscending.last { $0.carryDistanceM <= distanceBasisM }
                ?? sortedAscending.first
        }
    }

    private static func hasCoveringClub(
        in clubs: [PlayerClub],
        distanceBasisM: Double
    ) -> Bool {
        clubs.contains { $0.carryDistanceM + 1.0 >= distanceBasisM }
    }

    private static func advancementClub(
        from clubs: [PlayerClub],
        strategy: StrategyPreference
    ) -> PlayerClub? {
        let sortedDescending = clubs.sorted { lhs, rhs in
            lhs.carryDistanceM > rhs.carryDistanceM
        }

        switch strategy {
        case .safe:
            return sortedDescending.dropFirst().first ?? sortedDescending.first
        case .normal, .aggressive:
            return sortedDescending.first
        }
    }

    private static func targetLabel(
        for strategy: StrategyPreference,
        hazards: [Hazard]
    ) -> String {
        switch strategy {
        case .safe:
            return "center of the green"
        case .normal:
            if hazards.contains(where: { $0.kind == .water && $0.position.contains("left") }) {
                return "middle-right of the green"
            }
            return "middle of the green"
        case .aggressive:
            return "flag-side window"
        }
    }

    private static func advancementTargetLabel(
        for strategy: StrategyPreference,
        hazards: [Hazard],
        leaveDistanceM: Double
    ) -> String {
        if leaveDistanceM <= 60 {
            return "front approach window"
        }

        switch strategy {
        case .safe:
            return "safe fairway window"
        case .normal:
            if hazards.contains(where: { $0.kind == .water && $0.position.contains("right") }) {
                return "left-center fairway"
            }
            if hazards.contains(where: { $0.kind == .water && $0.position.contains("left") }) {
                return "right-center fairway"
            }
            return "stock fairway corridor"
        case .aggressive:
            return "strong fairway line"
        }
    }

    private static func riskNote(
        for hazards: [Hazard],
        strategy: StrategyPreference
    ) -> String? {
        guard !hazards.isEmpty else {
            return nil
        }

        if let water = hazards.first(where: { $0.kind == .water }) {
            return "Avoid \(hazardReference(for: water)); that is the expensive miss."
        }

        if let bunker = hazards.first(where: { $0.kind == .bunker }) {
            return strategy == .aggressive
                ? "The \(hazardReference(for: bunker)) is the main miss to manage."
                : "Favor away from \(hazardReference(for: bunker))."
        }

        return hazards.first?.note
    }

    private static func advancementRiskNote(
        for hazards: [Hazard],
        strategy: StrategyPreference
    ) -> String? {
        let water = nearestHazard(of: .water, in: hazards)
        let bunker = nearestHazard(of: .bunker, in: hazards)

        switch (water, bunker) {
        case let (water?, bunker?):
            return "\(hazardLeadIn(for: water, verb: "comes into play")) and \(hazardLeadIn(for: bunker, verb: bunkerVerb(for: strategy), capitalizeKind: false))."
        case let (water?, nil):
            return "\(hazardLeadIn(for: water, verb: "comes into play"))."
        case let (nil, bunker?):
            return "\(hazardLeadIn(for: bunker, verb: bunkerVerb(for: strategy)))."
        case (nil, nil):
            return hazards.first?.note
        }
    }

    private static func confidence(
        for club: PlayerClub,
        distanceBasisM: Double,
        lie: ShotLie
    ) -> RecommendationConfidence {
        let delta = abs(club.carryDistanceM - distanceBasisM)
        if lie == .bunker || lie == .recovery {
            return .low
        }
        if delta <= 6 {
            return .high
        }
        if delta <= 14 {
            return .medium
        }
        return .low
    }

    private static func windPhrase(for wind: WindContext?) -> String {
        guard let wind else {
            return ""
        }

        return " with \(formatMeters(wind.speedMps))m/s \(wind.direction.rawValue) wind"
    }

    private static func statusPacket(
        status: RecommendationStatus,
        holeNumber: Int? = nil,
        reason: String,
        strategyPreference: StrategyPreference
    ) -> CaddieRecommendationPacket {
        CaddieRecommendationPacket(
            status: status,
            courseId: nil,
            holeNumber: holeNumber,
            par: nil,
            shotNumber: nil,
            remainingDistanceM: nil,
            lie: nil,
            strategyPreference: strategyPreference,
            target: nil,
            recommendedClub: nil,
            clubCarryDistanceM: nil,
            distanceBasisM: nil,
            primaryReason: reason,
            riskNote: nil,
            confidence: .low
        )
    }

    private static func contextPacket(
        status: RecommendationStatus,
        course: Course,
        hole: CourseHole,
        player: PlayerContext,
        shot: ShotContext,
        reason: String,
        confidence: RecommendationConfidence
    ) -> CaddieRecommendationPacket {
        CaddieRecommendationPacket(
            status: status,
            courseId: course.id,
            holeNumber: hole.number,
            par: hole.par,
            shotNumber: shot.shotNumber,
            remainingDistanceM: shot.remainingDistanceM.value,
            lie: shot.lie.value,
            strategyPreference: player.strategyPreference,
            target: nil,
            recommendedClub: nil,
            clubCarryDistanceM: nil,
            distanceBasisM: shot.remainingDistanceM.value,
            primaryReason: reason,
            riskNote: nil,
            confidence: confidence
        )
    }

    private static func relevantHazards(
        for hazards: [Hazard],
        fromTeeProgressM: Double
    ) -> [Hazard] {
        hazards.filter { hazard in
            guard let hazardDistanceM = hazardDistance(for: hazard) else {
                return true
            }

            return hazardDistanceM >= fromTeeProgressM + 25
        }
    }

    private static func advancementHazards(
        from hazards: [Hazard],
        currentProgressM: Double,
        projectedLandingM: Double
    ) -> [Hazard] {
        hazards.filter { hazard in
            guard let hazardDistanceM = hazardDistance(for: hazard) else {
                return currentProgressM <= 25
            }

            return hazardDistanceM >= currentProgressM + 40
                && hazardDistanceM <= projectedLandingM + 35
        }
        .sorted { lhs, rhs in
            let lhsDistance = abs((hazardDistance(for: lhs) ?? projectedLandingM) - projectedLandingM)
            let rhsDistance = abs((hazardDistance(for: rhs) ?? projectedLandingM) - projectedLandingM)
            return lhsDistance < rhsDistance
        }
    }

    private static func currentProgressM(
        holeLengthM: Double,
        remainingDistanceM: Double
    ) -> Double {
        max(0, holeLengthM - remainingDistanceM)
    }

    private static func nearestHazard(
        of kind: HazardKind,
        in hazards: [Hazard]
    ) -> Hazard? {
        hazards.first { $0.kind == kind }
    }

    private static func bunkerVerb(for strategy: StrategyPreference) -> String {
        strategy == .aggressive
            ? "waits if you really chase it"
            : "starts to matter"
    }

    private static func hazardLeadIn(
        for hazard: Hazard,
        verb: String,
        capitalizeKind: Bool = true
    ) -> String {
        let side = hazardSide(for: hazard.position)
        let kindLabel = capitalizeKind
            ? hazard.kind.rawValue.capitalized
            : hazard.kind.rawValue
        if let distanceM = hazardDistance(for: hazard) {
            return "\(kindLabel) \(side) \(verb) around \(formatMeters(distanceM))m"
        }

        return "\(kindLabel) \(side) \(verb)"
    }

    private static func hazardReference(for hazard: Hazard) -> String {
        let side = hazardSide(for: hazard.position)
        if let distanceM = hazardDistance(for: hazard) {
            return "\(hazard.kind.rawValue) \(side) around \(formatMeters(distanceM))m"
        }

        return "\(hazard.position) \(hazard.kind.rawValue)"
    }

    private static func hazardSide(for position: String) -> String {
        let lowered = position.lowercased()
        if lowered.contains("long left") {
            return "long left"
        }
        if lowered.contains("long right") {
            return "long right"
        }
        if lowered.contains("short left") {
            return "short left"
        }
        if lowered.contains("short right") {
            return "short right"
        }
        if lowered.contains("left") {
            return "left"
        }
        if lowered.contains("right") {
            return "right"
        }
        return position
    }

    private static func hazardDistance(for hazard: Hazard) -> Double? {
        let pattern = #"\d+(\.\d+)?"#
        guard let match = hazard.position.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        return Double(hazard.position[match])
    }
}

private func formatMeters(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
}
