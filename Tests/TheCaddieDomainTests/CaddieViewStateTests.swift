import Testing
import TheCaddieDomain

@Test func readyViewStateShowsRecommendationAndQuickUpdates() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    let viewState = CaddieViewState.make(from: packet)

    #expect(viewState.kind == .ready)
    #expect(viewState.title == "8 Iron to middle-right of the green")
    #expect(viewState.holeLabel == "Hole 1 · Par 4")
    #expect(viewState.shotLabel == "Shot 2")
    #expect(viewState.distanceLabel == "142 m")
    #expect(viewState.primaryActionLabel == nil)
    #expect(viewState.quickActions == [
        .init(kind: .fairway, label: "Fairway"),
        .init(kind: .rough, label: "Rough"),
        .init(kind: .bunker, label: "Bunker"),
        .init(kind: .green, label: "Green")
    ])
    #expect(viewState.subtitle == "8 Iron covers the 150m playing number with 4m/s hurting wind.")
    #expect(viewState.noteText == "Avoid long left water; that is the expensive miss.")
}

@Test func noCourseViewStateInvitesLoadingSampleContext() {
    let packet = CaddieRecommendationEngine.build(
        course: nil,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    let viewState = CaddieViewState.make(from: packet)

    #expect(viewState.kind == .noCourseLoaded)
    #expect(viewState.title == "Choose a course")
    #expect(viewState.holeLabel == "No course")
    #expect(viewState.shotLabel == "No shot")
    #expect(viewState.distanceLabel == "--")
    #expect(viewState.primaryActionLabel == "Load sample")
    #expect(viewState.quickActions.isEmpty)
}

@Test func missingDistanceViewStateDoesNotShowFakeClub() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingDistanceRoundState
    )

    let viewState = CaddieViewState.make(from: packet)

    #expect(viewState.kind == .missingContext)
    #expect(viewState.title == "Distance needed")
    #expect(viewState.shotLabel == "Shot 2")
    #expect(viewState.distanceLabel == "--")
    #expect(viewState.primaryActionLabel == "Add distance")
    #expect(viewState.quickActions.count == 4)
}

@Test func missingLieViewStatePromptsForLieWithoutChangingDistance() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingLieRoundState
    )

    let viewState = CaddieViewState.make(from: packet)

    #expect(viewState.kind == .missingContext)
    #expect(viewState.title == "Lie needed")
    #expect(viewState.shotLabel == "Shot 2")
    #expect(viewState.distanceLabel == "142 m")
    #expect(viewState.primaryActionLabel == "Mark lie")
}

@Test func unavailableViewStateShowsFallbackWithoutQuickUpdates() {
    let player = PlayerContext(
        handicapIndex: nil,
        clubs: [],
        strategyPreference: .safe
    )
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: player,
        roundState: SampleRound.roundState
    )

    let viewState = CaddieViewState.make(from: packet)

    #expect(viewState.kind == .unavailable)
    #expect(viewState.title == "No recommendation")
    #expect(viewState.subtitle == "No club in the current bag covers this shot.")
    #expect(viewState.quickActions.isEmpty)
}

@Test func onGreenViewStateSwitchesToHoleOutAction() {
    let roundState = KungsbackaNyaCourse.openingRoundState
        .selectHole(8)
        .recordShotResult(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            resultingLie: .green
        )
    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    let viewState = CaddieViewState.make(
        from: packet,
        roundState: roundState,
        course: KungsbackaNyaCourse.course
    )

    #expect(viewState.kind == .onGreen)
    #expect(viewState.title == "Putt it out")
    #expect(viewState.distanceLabel == "On green")
    #expect(viewState.quickActions == [
        .init(kind: .holed, label: "Holed")
    ])
}

@Test func roundCompleteViewStateTakesPriorityOverPacket() {
    let roundState = RoundState(
        courseId: SampleRound.course.id,
        selectedHoleNumber: 2,
        shotContexts: [
            2: ShotContext(
                shotNumber: 3,
                remainingDistanceM: .known(0),
                lie: .known(.green),
                wind: nil
            )
        ],
        completedHoleNumbers: [1, 2]
    )
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    let viewState = CaddieViewState.make(
        from: packet,
        roundState: roundState,
        course: SampleRound.course
    )

    #expect(viewState.kind == .roundComplete)
    #expect(viewState.title == "Round complete")
    #expect(viewState.quickActions.isEmpty)
}

@Test func completedHoleViewStateOffersNextHoleAction() {
    let roundState = RoundState(
        courseId: KungsbackaNyaCourse.course.id,
        selectedHoleNumber: 8,
        shotContexts: [
            8: ShotContext(
                shotNumber: 3,
                remainingDistanceM: .known(0),
                lie: .known(.green),
                wind: nil
            )
        ],
        completedHoleNumbers: [8]
    )
    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    let viewState = CaddieViewState.make(
        from: packet,
        roundState: roundState,
        course: KungsbackaNyaCourse.course
    )

    #expect(viewState.kind == .holeComplete)
    #expect(viewState.title == "Hole finished")
    #expect(viewState.primaryActionLabel == "Next hole")
}
