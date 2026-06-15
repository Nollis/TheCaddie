import Testing
import TheCaddieDomain

@Test func recommendationEngineReturnsReadyPacketForSampleShot() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.isReady)
    #expect(packet.courseId == "sample-links")
    #expect(packet.holeNumber == 1)
    #expect(packet.par == 4)
    #expect(packet.shotNumber == 2)
    #expect(packet.remainingDistanceM == 142)
    #expect(packet.lie == .fairway)
    #expect(packet.strategyPreference == .normal)
    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.clubCarryDistanceM == 160)
    #expect(packet.distanceBasisM == 150)
    #expect(packet.target == "middle-right of the green")
    #expect(packet.primaryReason == "5 Iron covers the 150m playing number with 4m/s hurting wind.")
    #expect(packet.riskNote == "Avoid long left water; that is the expensive miss.")
    #expect(packet.confidence == .medium)
}

@Test func safeStrategyChoosesCoveringClubBetweenTwoDistances() {
    let player = PlayerContext(
        handicapIndex: SampleRound.player.handicapIndex,
        clubs: SampleRound.player.clubs,
        strategyPreference: .safe
    )
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(142),
            lie: .known(.fairway),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.distanceBasisM == 146)
    #expect(packet.recommendedClub == "6 Iron")
    #expect(packet.target == "center of the green")
}

@Test func longShotBeyondReachRecommendsAdvancingInsteadOfCoveringGreenDistance() {
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(300),
            lie: .known(.fairway),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.recommendedClub == "Driver")
    #expect(packet.distanceBasisM == 220)
    #expect(packet.target == "stock fairway corridor")
    #expect(packet.primaryReason == "Driver advances the ball about 220m and leaves roughly 80m in.")
    #expect(packet.riskNote == nil)
}

@Test func helpingAndHurtingWindChangeDistanceBasisDeterministically() {
    let helpingRound = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(142),
            lie: .known(.fairway),
            wind: WindContext(direction: .helping, speedMps: 4)
        )
    )
    let hurtingRound = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(142),
            lie: .known(.fairway),
            wind: WindContext(direction: .hurting, speedMps: 4)
        )
    )

    let helpingPacket = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: helpingRound
    )
    let hurtingPacket = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: hurtingRound
    )

    #expect(helpingPacket.distanceBasisM == 136)
    #expect(helpingPacket.recommendedClub == "7 Iron")
    #expect(hurtingPacket.distanceBasisM == 150)
    #expect(hurtingPacket.recommendedClub == "5 Iron")
}

@Test func missingDistanceReturnsMissingContextPacketWithoutInventedClub() {
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.missingDistanceRoundState
    )

    #expect(packet.status == .missingDistance)
    #expect(!packet.isReady)
    #expect(packet.recommendedClub == nil)
    #expect(packet.target == nil)
    #expect(packet.primaryReason == "Add a distance before choosing a club.")
}

@Test func noSuitableClubReturnsUnavailablePacket() {
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

    #expect(packet.status == .unavailable)
    #expect(packet.recommendedClub == nil)
    #expect(packet.primaryReason == "No club in the current bag covers this shot.")
}

@Test func unknownHoleAndNoCourseReturnExplicitPackets() {
    let unknownHolePacket = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: SampleRound.roundState.selectHole(99)
    )
    let noCoursePacket = CaddieRecommendationEngine.build(
        course: nil,
        player: SampleRound.player,
        roundState: SampleRound.roundState
    )

    #expect(unknownHolePacket.status == .unknownHole)
    #expect(unknownHolePacket.holeNumber == 99)
    #expect(noCoursePacket.status == .noCourseLoaded)
    #expect(noCoursePacket.recommendedClub == nil)
}
