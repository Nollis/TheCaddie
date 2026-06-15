import Testing
import TheCaddieDomain

@Test func spokenFallbackUsesGroundedPacketFields() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    let text = CaddieResponseText.spokenFallback(for: packet)

    #expect(text.contains("I'd take 8 Iron here."))
    #expect(text.contains("Aim middle-right of the green."))
    #expect(text.contains("8 Iron covers the 150m playing number"))
    #expect(text.contains("Avoid long left water"))
    #expect(!text.localizedCaseInsensitiveContains("openai"))
    #expect(!text.localizedCaseInsensitiveContains("model"))
    #expect(!text.localizedCaseInsensitiveContains("connect"))
}

@Test func displayHeadlineUsesClubAndTargetForReadyPacket() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    #expect(CaddieResponseText.displayHeadline(for: packet) == "8 Iron to middle-right of the green")
}

@Test func spokenFallbackHasDeterministicMissingContextCopy() {
    let missingDistance = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingDistanceRoundState
    )
    let missingLie = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingLieRoundState
    )

    #expect(CaddieResponseText.spokenFallback(for: missingDistance) == "I need the distance before I can choose a club.")
    #expect(CaddieResponseText.spokenFallback(for: missingLie) == "Mark the lie first, then I can give you a better play.")
}
