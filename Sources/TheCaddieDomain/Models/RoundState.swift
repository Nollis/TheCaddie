import Foundation

public struct RoundState: Equatable, Sendable {
    public let courseId: String
    public let selectedHoleNumber: Int
    public let shotContexts: [Int: ShotContext]

    public init(
        courseId: String,
        selectedHoleNumber: Int,
        shotContexts: [Int: ShotContext]
    ) {
        self.courseId = courseId
        self.selectedHoleNumber = selectedHoleNumber
        self.shotContexts = shotContexts
    }

    public func shotContext(for holeNumber: Int) -> ShotContext? {
        shotContexts[holeNumber]
    }

    public func currentShotContext() -> ShotContext? {
        shotContext(for: selectedHoleNumber)
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
            shotContexts: updated
        )
    }

    public func selectHole(_ holeNumber: Int) -> RoundState {
        RoundState(
            courseId: courseId,
            selectedHoleNumber: holeNumber,
            shotContexts: shotContexts
        )
    }

    public func recordShotResult(
        course: Course?,
        player: PlayerContext,
        resultingLie: ShotLie
    ) -> RoundState {
        guard let currentShot = currentShotContext(),
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

        let nextRemainingDistanceM = max(
            0,
            remainingDistanceM - (baselineAdvanceM * progressionMultiplier(for: resultingLie))
        )
        let nextShot = ShotContext(
            shotNumber: currentShot.shotNumber + 1,
            remainingDistanceM: .known(nextRemainingDistanceM),
            lie: .known(resultingLie),
            wind: currentShot.wind
        )

        return updateShotContext(nextShot)
    }
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
            wind: nil
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
    }
}
