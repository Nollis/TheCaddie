import Foundation

public struct RoundState: Equatable, Sendable {
    public let courseId: String
    public let selectedHoleNumber: Int
    public let shotContexts: [Int: ShotContext]
    public let completedHoleNumbers: Set<Int>
    public let holeScores: [Int: HoleScore]

    public init(
        courseId: String,
        selectedHoleNumber: Int,
        shotContexts: [Int: ShotContext],
        completedHoleNumbers: Set<Int> = [],
        holeScores: [Int: HoleScore] = [:]
    ) {
        self.courseId = courseId
        self.selectedHoleNumber = selectedHoleNumber
        self.shotContexts = shotContexts
        self.completedHoleNumbers = completedHoleNumbers
        self.holeScores = holeScores
    }

    public func shotContext(for holeNumber: Int) -> ShotContext? {
        shotContexts[holeNumber]
    }

    public func currentShotContext() -> ShotContext? {
        shotContext(for: selectedHoleNumber)
    }

    public func isHoleComplete(_ holeNumber: Int) -> Bool {
        completedHoleNumbers.contains(holeNumber)
    }

    public func isRoundComplete(course: Course?) -> Bool {
        guard let course else {
            return false
        }

        return !course.holes.isEmpty
            && course.holes.allSatisfy { completedHoleNumbers.contains($0.number) }
    }

    public func updateShotContext(
        _ shotContext: ShotContext,
        for holeNumber: Int? = nil
    ) -> RoundState {
        let targetHole = holeNumber ?? selectedHoleNumber
        var updated = shotContexts
        updated[targetHole] = shotContext
        return RoundState(
            courseId: courseId,
            selectedHoleNumber: selectedHoleNumber,
            shotContexts: updated,
            completedHoleNumbers: completedHoleNumbers,
            holeScores: holeScores
        )
    }

    public func selectHole(_ holeNumber: Int) -> RoundState {
        RoundState(
            courseId: courseId,
            selectedHoleNumber: holeNumber,
            shotContexts: shotContexts,
            completedHoleNumbers: completedHoleNumbers,
            holeScores: holeScores
        )
    }

    public func recordShotResult(
        course: Course?,
        player: PlayerContext,
        resultingLie: ShotLie
    ) -> RoundState {
        let context = CurrentShotContext.resolve(
            course: course,
            player: player,
            roundState: self
        )

        guard case let .ready(_, _, _, currentShot) = context,
              let remainingDistanceM = currentShot.remainingDistanceM.value else {
            return self
        }

        let packet = CaddieRecommendationEngine.build(
            course: course,
            player: player,
            roundState: self
        )
        let baselineAdvanceM = packet.clubCarryDistanceM
            ?? player.clubs.first?.carryDistanceM
            ?? 0

        guard baselineAdvanceM > 0 else {
            return self
        }

        let nextRemainingDistanceM = nextRemainingDistance(
            hole: course?.hole(number: selectedHoleNumber),
            currentRemainingDistanceM: remainingDistanceM,
            currentProgressM: currentShot.progressM,
            baselineAdvanceM: baselineAdvanceM,
            resultingLie: resultingLie
        )
        let nextShot = ShotContext(
            shotNumber: currentShot.shotNumber + 1,
            remainingDistanceM: .known(nextRemainingDistanceM),
            lie: .known(resultingLie),
            wind: currentShot.wind,
            progressM: nil
        )

        return updateShotContext(nextShot)
    }

    public func finishCurrentHole(
        course: Course?,
        strokes: Int? = nil,
        putts: Int? = nil,
        fairwayHit: Bool? = nil,
        greenInRegulation: Bool? = nil
    ) -> RoundState {
        guard let course,
              let hole = course.hole(number: selectedHoleNumber) else {
            return self
        }

        var completed = completedHoleNumbers
        completed.insert(selectedHoleNumber)

        var updatedScores = holeScores
        
        // Calculate defaults from shot history if not manually provided
        let finalStrokes: Int
        let finalPutts: Int
        let finalFairwayHit: Bool?
        let finalGIR: Bool
        
        if let manualStrokes = strokes, let manualPutts = putts {
            finalStrokes = manualStrokes
            finalPutts = manualPutts
            finalFairwayHit = fairwayHit
            finalGIR = greenInRegulation ?? false
        } else {
            // Stroke count defaults to last shot number or 1 if empty
            let lastShotNumber = shotContexts[selectedHoleNumber]?.shotNumber ?? 1
            finalStrokes = lastShotNumber
            
            // Reconstructed putts: count shots where lie was .green
            // In a real app, this is determined by counting shot contexts with lie == .green
            // We assume a simple default of 2 putts if on green, or 1 if holed from off green.
            let reachedGreen = shotContexts[selectedHoleNumber]?.lie.value == .green
            finalPutts = reachedGreen ? 2 : 1
            
            // FIR: True if second shot was from fairway on a Par 4/5
            finalFairwayHit = hole.par > 3 ? true : nil
            
            // GIR: reached green in Par - 2
            finalGIR = finalStrokes - finalPutts <= (hole.par - 2)
        }
        
        updatedScores[selectedHoleNumber] = HoleScore(
            holeNumber: selectedHoleNumber,
            strokes: finalStrokes,
            putts: finalPutts,
            fairwayHit: finalFairwayHit,
            greenInRegulation: finalGIR
        )

        let nextHoleNumber = course.nextHole(after: selectedHoleNumber)?.number
            ?? selectedHoleNumber

        return RoundState(
            courseId: courseId,
            selectedHoleNumber: nextHoleNumber,
            shotContexts: shotContexts,
            completedHoleNumbers: completed,
            holeScores: updatedScores
        )
    }
}

private func nextRemainingDistance(
    hole: CourseHole?,
    currentRemainingDistanceM: Double,
    currentProgressM: Double?,
    baselineAdvanceM: Double,
    resultingLie: ShotLie
) -> Double {
    if resultingLie == .green {
        return 0
    }

    if resultingLie == .bunker,
       let hole {
        let resolvedCurrentProgressM = max(0, min(hole.teeLengthM, currentProgressM ?? (hole.teeLengthM - currentRemainingDistanceM)))
        let projectedProgressM = min(hole.teeLengthM, resolvedCurrentProgressM + baselineAdvanceM)

        if let bunkerDistanceM = nearestForwardHazardDistance(
            kind: .bunker,
            hazards: hole.hazards,
            currentProgressM: resolvedCurrentProgressM,
            projectedProgressM: projectedProgressM
        ) {
            return max(0, hole.teeLengthM - bunkerDistanceM)
        }
    }

    return max(
        0,
        currentRemainingDistanceM - (baselineAdvanceM * progressionMultiplier(for: resultingLie))
    )
}

private func nearestForwardHazardDistance(
    kind: HazardKind,
    hazards: [Hazard],
    currentProgressM: Double,
    projectedProgressM: Double
) -> Double? {
    hazards
        .filter { $0.kind == kind }
        .compactMap { hazard -> Double? in
            guard let distanceM = hazardDistance(for: hazard),
                  distanceM > currentProgressM + 5 else {
                return nil
            }
            return distanceM
        }
        .min { lhs, rhs in
            abs(lhs - projectedProgressM) < abs(rhs - projectedProgressM)
        }
}

private func hazardDistance(for hazard: Hazard) -> Double? {
    if let progressM = hazard.progressM {
        return progressM
    }

    let pattern = #"\d+(\.\d+)?"#
    guard let match = hazard.position.range(of: pattern, options: .regularExpression) else {
        return nil
    }

    return Double(hazard.position[match])
}

public enum CurrentShotContext: Equatable, Sendable {
    case ready(course: Course, hole: CourseHole, player: PlayerContext, shot: ShotContext)
    case noCourseLoaded
    case unknownHole(Int)
    case missingDistance(course: Course, hole: CourseHole, player: PlayerContext, shot: ShotContext)
    case missingLie(course: Course, hole: CourseHole, player: PlayerContext, shot: ShotContext)

    public static func resolve(
        course: Course?,
        player: PlayerContext,
        roundState: RoundState
    ) -> CurrentShotContext {
        guard let course else {
            return .noCourseLoaded
        }

        guard let hole = course.hole(number: roundState.selectedHoleNumber) else {
            return .unknownHole(roundState.selectedHoleNumber)
        }

        let shot = roundState.currentShotContext() ?? ShotContext(
            shotNumber: 1,
            remainingDistanceM: .known(hole.teeLengthM),
            lie: .known(.tee),
            wind: nil,
            progressM: nil
        )

        if shot.remainingDistanceM.value == nil {
            return .missingDistance(course: course, hole: hole, player: player, shot: shot)
        }

        if shot.lie.value == nil {
            return .missingLie(course: course, hole: hole, player: player, shot: shot)
        }

        return .ready(course: course, hole: hole, player: player, shot: shot)
    }
}

private func progressionMultiplier(for lie: ShotLie) -> Double {
    switch lie {
    case .tee, .fairway:
        return 1.0
    case .rough:
        return 0.9
    case .bunker:
        return 0.72
    case .recovery:
        return 0.58
    case .green:
        return 1.0
    }
}
