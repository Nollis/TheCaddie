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
    #expect(viewState.title == "5 Iron to middle-right of the green")
    #expect(viewState.holeLabel == "Hole 1 · Par 4")
    #expect(viewState.distanceLabel == "142 m")
    #expect(viewState.primaryActionLabel == nil)
    #expect(viewState.quickUpdateLabels == ["Fairway", "Rough", "Bunker"])
    #expect(viewState.subtitle.contains("5 Iron covers the 150m playing number"))
    #expect(viewState.subtitle.contains("Avoid long left water"))
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
    #expect(viewState.distanceLabel == "--")
    #expect(viewState.primaryActionLabel == "Load sample")
    #expect(viewState.quickUpdateLabels.isEmpty)
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
    #expect(viewState.distanceLabel == "--")
    #expect(viewState.primaryActionLabel == "Add distance")
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
    #expect(viewState.quickUpdateLabels.isEmpty)
}
