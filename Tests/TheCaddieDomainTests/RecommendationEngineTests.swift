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
    #expect(packet.shotIntent == .approach)
    #expect(packet.recommendedClub == "8 Iron")
    #expect(packet.clubCarryDistanceM == 150)
    #expect(packet.distanceBasisM == 150)
    #expect(abs((packet.expectedDispersionM ?? 0) - 25.056) < 0.001)
    #expect(packet.target == "middle-right of the green")
    #expect(packet.primaryReason == "8 Iron covers the 150m playing number with 4m/s hurting wind.")
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
    #expect(packet.shotIntent == .advance)
    #expect(packet.recommendedClub == "3 Hybrid")
    #expect(packet.distanceBasisM == 190)
    #expect(packet.target == "stock fairway corridor")
    #expect(packet.primaryReason == "3 Hybrid advances the ball about 190m and leaves roughly 110m in.")
    #expect(packet.riskNote == nil)
}

@Test func bunkerLieSwitchesToRecoveryIntentWithPlayableRecoveryClub() {
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 3,
            remainingDistanceM: .known(72),
            lie: .known(.bunker),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .recovery)
    #expect(packet.recommendedClub == "PW")
    #expect(packet.target == "safe recovery window")
    #expect(packet.primaryReason == "PW is the safest recovery club from this lie.")
    #expect(packet.confidence == .low)
}

@Test func playerCanOverrideClubPlayabilityAndDispersionForLearnedProfile() {
    let player = PlayerContext(
        handicapIndex: 21.8,
        clubs: [
            PlayerClub(
                name: "Driver",
                carryDistanceM: 220,
                typicalDispersionM: 42,
                playableLies: [.tee, .fairway]
            ),
            PlayerClub(name: "3 Hybrid", carryDistanceM: 190)
        ],
        strategyPreference: .normal,
        skillProfile: PlayerSkillProfile(
            handicapIndex: 21.8,
            dispersionMultiplier: 1.0,
            conservativeBiasM: 10
        )
    )
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(260),
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
    #expect(packet.recommendedClub == "Driver")
    #expect(abs((packet.expectedDispersionM ?? 0) - 45.36) < 0.001)
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
    #expect(helpingPacket.recommendedClub == "9 Iron")
    #expect(hurtingPacket.distanceBasisM == 150)
    #expect(hurtingPacket.recommendedClub == "8 Iron")
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
