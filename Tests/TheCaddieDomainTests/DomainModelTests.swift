import Testing
import TheCaddieDomain

@Test func sampleRoundExposesCompleteCurrentShotContext() throws {
    let context = CurrentShotContext.resolve(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    guard case let .ready(course, hole, player, shot) = context else {
        Issue.record("Expected ready sample context")
        return
    }

    #expect(course.name == "Sample Links")
    #expect(hole.number == 1)
    #expect(hole.par == 4)
    #expect(hole.green.centerDistanceM == 142)
    #expect(hole.hazards.map(\.position) == ["short right", "long left"])
    #expect(player.handicapIndex == 21.8)
    #expect(player.strategyPreference == .normal)
    #expect(player.clubs.first?.name == "Driver")
    #expect(shot.shotNumber == 2)
    #expect(shot.remainingDistanceM.value == 142)
    #expect(shot.lie.value == .fairway)
    #expect(shot.wind == WindContext(direction: .hurting, speedMps: 4))
    #expect(shot.isReadyForRecommendation)
}

@Test func missingDistanceIsExplicitCurrentShotState() {
    let context = CurrentShotContext.resolve(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingDistanceRoundState
    )

    guard case let .missingDistance(_, hole, _, shot) = context else {
        Issue.record("Expected missing distance state")
        return
    }

    #expect(hole.number == 1)
    #expect(shot.remainingDistanceM.value == nil)
    #expect(shot.lie.value == .fairway)
    #expect(!shot.isReadyForRecommendation)
}

@Test func missingLieIsExplicitCurrentShotState() {
    let context = CurrentShotContext.resolve(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingLieRoundState
    )

    guard case let .missingLie(_, hole, _, shot) = context else {
        Issue.record("Expected missing lie state")
        return
    }

    #expect(hole.number == 1)
    #expect(shot.remainingDistanceM.value == 142)
    #expect(shot.lie.value == nil)
    #expect(!shot.isReadyForRecommendation)
}

@Test func unknownHoleDoesNotCrashCurrentShotResolution() {
    let roundState = SampleRound.roundState.selectHole(99)
    let context = CurrentShotContext.resolve(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(context == .unknownHole(99))
}

@Test func noCourseLoadedIsExplicitCurrentShotState() {
    let context = CurrentShotContext.resolve(
        course: nil,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    #expect(context == .noCourseLoaded)
}

@Test func roundStateCanUpdateShotContextImmutably() {
    let updatedShot = ShotContext(
        shotNumber: 3,
        remainingDistanceM: .known(82),
        lie: .known(.rough),
        wind: nil
    )

    let updatedRound = SampleRound.roundState.updateShotContext(updatedShot)

    #expect(SampleRound.roundState.currentShotContext() == SampleRound.readyShot)
    #expect(updatedRound.currentShotContext() == updatedShot)
}
