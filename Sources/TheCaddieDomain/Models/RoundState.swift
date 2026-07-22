import Foundation

public enum GreenCompletionScoring {
    public static let supportedPutts = 0...10

    public static func totalStrokes(
        nextShotNumber: Int,
        putts: Int
    ) -> Int? {
        guard nextShotNumber >= 1,
              supportedPutts.contains(putts) else {
            return nil
        }

        let totalStrokes = nextShotNumber + putts - 1
        return totalStrokes >= 1 ? totalStrokes : nil
    }

    public static func isGreenInRegulation(
        par: Int,
        totalStrokes: Int,
        putts: Int
    ) -> Bool {
        putts > 0 && (totalStrokes - putts) <= (par - 2)
    }
}

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

        let nextShotProjection = nextShotProjection(
            hole: course?.hole(number: selectedHoleNumber),
            currentRemainingDistanceM: remainingDistanceM,
            currentProgressM: currentShot.progressM,
            baselineAdvanceM: baselineAdvanceM,
            resultingLie: resultingLie
        )
        let nextShot = ShotContext(
            shotNumber: currentShot.shotNumber + 1,
            remainingDistanceM: .known(nextShotProjection.remainingDistanceM),
            lie: .known(resultingLie),
            wind: currentShot.wind,
            progressM: nextShotProjection.progressM
        )

        return updateShotContext(nextShot)
    }

    public func recordPenaltyDrop(
        course: Course?,
        player: PlayerContext
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

        let nextShotProjection = nextShotProjection(
            hole: course?.hole(number: selectedHoleNumber),
            currentRemainingDistanceM: remainingDistanceM,
            currentProgressM: currentShot.progressM,
            baselineAdvanceM: baselineAdvanceM,
            resultingLie: .recovery,
            snapHazardKind: .water
        )
        let nextShot = ShotContext(
            shotNumber: currentShot.shotNumber + 2,
            remainingDistanceM: .known(nextShotProjection.remainingDistanceM),
            lie: .known(.recovery),
            wind: currentShot.wind,
            progressM: nextShotProjection.progressM
        )

        return updateShotContext(nextShot)
    }

    public func recordStrokeAndDistancePenalty() -> RoundState {
        guard let currentShot = currentShotContext() else {
            return self
        }

        let replayShot = ShotContext(
            shotNumber: currentShot.shotNumber + 2,
            remainingDistanceM: currentShot.remainingDistanceM,
            lie: currentShot.lie,
            wind: currentShot.wind,
            progressM: currentShot.progressM
        )
        return updateShotContext(replayShot)
    }

    public func finishCurrentHoleFromGreen(
        course: Course?,
        putts: Int,
        recordGreenArrivalIfNeeded: Bool
    ) -> RoundState {
        guard let course,
              let hole = course.hole(number: selectedHoleNumber) else {
            return self
        }

        let startedOnGreen = currentShotContext()?.lie.value == .green
        guard putts > 0 || !startedOnGreen else {
            return self
        }

        var scoringState = self
        if scoringState.currentShotContext()?.lie.value != .green,
           recordGreenArrivalIfNeeded {
            guard let currentShot = scoringState.currentShotContext() else {
                return self
            }
            scoringState = scoringState.updateShotContext(
                ShotContext(
                    shotNumber: currentShot.shotNumber + 1,
                    remainingDistanceM: .known(0),
                    lie: .known(.green),
                    wind: currentShot.wind,
                    progressM: hole.teeLengthM
                )
            )
        }

        guard scoringState.currentShotContext()?.lie.value == .green,
              let nextShotNumber = scoringState.currentShotContext()?.shotNumber,
              let finalStrokes = GreenCompletionScoring.totalStrokes(
                nextShotNumber: nextShotNumber,
                putts: putts
              ) else {
            return self
        }

        return scoringState.finishCurrentHole(
            course: course,
            strokes: finalStrokes,
            putts: putts,
            fairwayHit: hole.par > 3 ? true : nil,
            greenInRegulation: GreenCompletionScoring.isGreenInRegulation(
                par: hole.par,
                totalStrokes: finalStrokes,
                putts: putts
            )
        )
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

public enum ScoringUndoScope {
    public static func canUndo(
        lastActionHoleNumber: Int?,
        selectedHoleNumber: Int
    ) -> Bool {
        lastActionHoleNumber == selectedHoleNumber
    }
}

private func nextShotProjection(
    hole: CourseHole?,
    currentRemainingDistanceM: Double,
    currentProgressM: Double?,
    baselineAdvanceM: Double,
    resultingLie: ShotLie,
    snapHazardKind: HazardKind? = nil
) -> ShotProjection {
    if resultingLie == .green {
        return ShotProjection(
            remainingDistanceM: 0,
            progressM: hole.map(\.teeLengthM)
        )
    }

    let projectedAdvanceM = projectedAdvanceM(
        baselineAdvanceM: baselineAdvanceM,
        resultingLie: resultingLie
    )

    guard let hole else {
        return ShotProjection(
            remainingDistanceM: max(0, currentRemainingDistanceM - projectedAdvanceM).rounded(),
            progressM: nil
        )
    }

    let resolvedCurrentProgressM = resolvedProgressM(
        holeLengthM: hole.teeLengthM,
        currentRemainingDistanceM: currentRemainingDistanceM,
        currentProgressM: currentProgressM
    )
    let projectedProgressM = min(
        hole.teeLengthM,
        resolvedCurrentProgressM + projectedAdvanceM
    )

    let hazardSnapKind = snapHazardKind ?? (resultingLie == .bunker ? .bunker : nil)
    if let hazardSnapKind {
        if let hazardDistanceM = nearestForwardHazardDistance(
            kind: hazardSnapKind,
            hazards: hole.hazards,
            currentProgressM: resolvedCurrentProgressM,
            projectedProgressM: projectedProgressM,
            minimumSnapDistanceM: projectedProgressM - 35,
            maximumSnapDistanceM: projectedProgressM + 60
        ) {
            let snappedProgressM = min(hole.teeLengthM, hazardDistanceM)
            return ShotProjection(
                remainingDistanceM: max(0, hole.teeLengthM - snappedProgressM).rounded(),
                progressM: snappedProgressM
            )
        }
    }

    return ShotProjection(
        remainingDistanceM: max(0, hole.teeLengthM - projectedProgressM).rounded(),
        progressM: projectedProgressM
    )
}

private func resolvedProgressM(
    holeLengthM: Double,
    currentRemainingDistanceM: Double,
    currentProgressM: Double?
) -> Double {
    max(
        0,
        min(
            holeLengthM,
            currentProgressM ?? (holeLengthM - currentRemainingDistanceM)
        )
    )
}

private func nearestForwardHazardDistance(
    kind: HazardKind,
    hazards: [Hazard],
    currentProgressM: Double,
    projectedProgressM: Double,
    minimumSnapDistanceM: Double? = nil,
    maximumSnapDistanceM: Double? = nil
) -> Double? {
    hazards
        .filter { $0.kind == kind }
        .compactMap { hazard -> Double? in
            guard let distanceM = hazardDistance(for: hazard),
                  distanceM > currentProgressM + 5 else {
                return nil
            }
            if let minimumSnapDistanceM,
               distanceM < minimumSnapDistanceM {
                return nil
            }
            if let maximumSnapDistanceM,
               distanceM > maximumSnapDistanceM {
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

private func projectedAdvanceM(
    baselineAdvanceM: Double,
    resultingLie: ShotLie
) -> Double {
    max(
        1,
        baselineAdvanceM - liePenaltyM(
            baselineAdvanceM: baselineAdvanceM,
            resultingLie: resultingLie
        )
    )
}

private func liePenaltyM(
    baselineAdvanceM: Double,
    resultingLie: ShotLie
) -> Double {
    switch resultingLie {
    case .tee, .fairway, .green:
        return 0
    case .rough:
        return min(18, max(8, baselineAdvanceM * 0.12))
    case .bunker:
        return min(50, max(20, baselineAdvanceM * 0.28))
    case .recovery:
        return min(42, max(14, baselineAdvanceM * 0.18))
    }
}

private struct ShotProjection {
    let remainingDistanceM: Double
    let progressM: Double?
}
