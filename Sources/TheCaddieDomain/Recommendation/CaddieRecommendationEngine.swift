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
            hazards: hole.hazards
        )
        let riskNote = riskNote(for: hole.hazards, strategy: player.strategyPreference)
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
            let coveringClub = sortedAscending.first { $0.carryDistanceM >= distanceBasisM }
            let shorterClub = sortedAscending.last { $0.carryDistanceM < distanceBasisM }

            guard let coveringClub, let shorterClub else {
                return coveringClub ?? shorterClub
            }

            let coverDelta = abs(coveringClub.carryDistanceM - distanceBasisM)
            let shortDelta = abs(distanceBasisM - shorterClub.carryDistanceM)
            return coverDelta <= shortDelta ? coveringClub : shorterClub
        case .aggressive:
            return sortedAscending.last { $0.carryDistanceM <= distanceBasisM }
                ?? sortedAscending.first
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

    private static func riskNote(
        for hazards: [Hazard],
        strategy: StrategyPreference
    ) -> String? {
        guard !hazards.isEmpty else {
            return nil
        }

        if let water = hazards.first(where: { $0.kind == .water }) {
            return "Avoid \(water.position) \(water.kind.rawValue); that is the expensive miss."
        }

        if let bunker = hazards.first(where: { $0.kind == .bunker }) {
            return strategy == .aggressive
                ? "The \(bunker.position) bunker is the main miss to manage."
                : "Favor away from the \(bunker.position) bunker."
        }

        return hazards.first?.note
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
}

private func formatMeters(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
}
