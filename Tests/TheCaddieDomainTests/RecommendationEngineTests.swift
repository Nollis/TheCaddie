import Testing
import TheCaddieDomain

private func teePacket(
    landingWidthM: Double,
    drivingZoneEndM: Double? = nil,
    hazards: [Hazard] = [],
    player: PlayerContext = SampleRound.player,
    teeLengthM: Double = 380
) -> CaddieRecommendationPacket {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: teeLengthM,
        green: GreenContext(
            frontDistanceM: teeLengthM - 20,
            centerDistanceM: teeLengthM - 8,
            backDistanceM: teeLengthM + 4
        ),
        hazards: hazards,
        fairway: FairwayContext(landingWidthM: landingWidthM, drivingZoneEndM: drivingZoneEndM)
    )
    let course = Course(id: "tee-test", name: "Tee Test", holes: [hole])
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(teeLengthM),
                lie: .known(.tee),
                wind: nil
            )
        ]
    )
    return CaddieRecommendationEngine.build(course: course, player: player, roundState: roundState)
}

@Test func tightFairwayClubsDownFromDriverForHighHandicap() {
    // SampleRound.player is a 21.8 handicap (dispersion multiplier 1.45).
    let packet = teePacket(landingWidthM: 30)

    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.recommendedClub != "Driver")
}

@Test func wideOpenFairwayKeepsDriverForHighHandicap() {
    let packet = teePacket(landingWidthM: 50)

    #expect(packet.recommendedClub == "Driver")
}

@Test func tightFairwayKeepsDriverForScratchPlayer() {
    let scratch = PlayerContext(
        handicapIndex: 2.0,
        clubs: SampleRound.player.clubs,
        strategyPreference: .normal
    )
    let packet = teePacket(landingWidthM: 30, player: scratch)

    #expect(packet.recommendedClub == "Driver")
}

@Test func waterAtDriverLandingZoneClubsDown() {
    let water = Hazard(
        id: "tee-water-right",
        kind: .water,
        position: "right 220m",
        note: "Water down the right at the driver landing zone."
    )
    let packet = teePacket(landingWidthM: 56, hazards: [water])

    #expect(packet.recommendedClub == "3 Hybrid")

    let noHazard = teePacket(landingWidthM: 56)
    #expect(noHazard.recommendedClub == "Driver")
}

@Test func drivingZoneEndCapDropsDriver() {
    let packet = teePacket(landingWidthM: 56, drivingZoneEndM: 180)

    #expect(packet.recommendedClub == "3 Hybrid")
}

@Test func extremelyTightFairwayFallsBackToLowestRiskClub() {
    let packet = teePacket(landingWidthM: 12)

    // No club fits a 6m half-width; fallback picks the lowest-spread club,
    // tie-broken by longest carry (PW over 50W).
    #expect(packet.recommendedClub == "PW")
    #expect(packet.recommendedClub != "Driver")
}

@Test func teeShotWithoutFairwayDataUsesLegacyLongestClub() {
    // SampleRound hole 1 has no fairway data; a tee shot should still return Driver.
    let teeRound = RoundState(
        courseId: SampleRound.course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(356),
                lie: .known(.tee),
                wind: nil
            )
        ]
    )
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: teeRound
    )

    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "Driver")
}

@Test func clubbedDownTeeShotExplainsWhyInRiskNote() {
    let packet = teePacket(landingWidthM: 30)

    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.riskNote == "Driver brings the trouble into range here — 5 Iron keeps the tee shot in play.")
}

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
    #expect(packet.recommendedClub == "7 Iron")
    #expect(packet.clubCarryDistanceM == 150)
    #expect(packet.distanceBasisM == 150)
    #expect(abs((packet.expectedDispersionM ?? 0) - 25.056) < 0.001)
    #expect(packet.target == "middle-right of the green")
    #expect(packet.primaryReason == "7 Iron covers the 150m playing number with 4m/s hurting wind.")
    #expect(packet.riskNote == "Avoid long left water; that is the expensive miss.")
    #expect(packet.confidence == .medium)
    #expect(packet.debugInfo?.mode == .approach)
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
    #expect(packet.recommendedClub == "7 Iron")
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

@Test func explicitProgressOverrideKeepsAheadHazardsRelevantOnDoglegs() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 400,
        green: GreenContext(
            frontDistanceM: 390,
            centerDistanceM: 400,
            backDistanceM: 410
        ),
        hazards: [
            Hazard(
                id: "dogleg-water-right",
                kind: .water,
                position: "right 250m",
                note: "Water right is still in play."
            )
        ],
        fairway: FairwayContext(landingWidthM: 36, drivingZoneEndM: nil)
    )
    let course = Course(id: "dogleg-test", name: "Dogleg Test", holes: [hole])

    let heuristicPacket = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: RoundState(
            courseId: course.id,
            selectedHoleNumber: 1,
            shotContexts: [
                1: ShotContext(
                    shotNumber: 2,
                    remainingDistanceM: .known(120),
                    lie: .known(.fairway),
                    wind: nil
                )
            ]
        )
    )

    let progressPacket = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: RoundState(
            courseId: course.id,
            selectedHoleNumber: 1,
            shotContexts: [
                1: ShotContext(
                    shotNumber: 2,
                    remainingDistanceM: .known(120),
                    lie: .known(.fairway),
                    wind: nil,
                    progressM: 220
                )
            ]
        )
    )

    #expect(heuristicPacket.shotIntent == .approach)
    #expect(progressPacket.shotIntent == .approach)
    #expect(heuristicPacket.recommendedClub == progressPacket.recommendedClub)
    #expect(heuristicPacket.riskNote == nil)
    #expect(progressPacket.riskNote == "Avoid right water; that is the expensive miss.")
}

@Test func mappedHazardProgressOverridesMisleadingPositionText() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 400,
        green: GreenContext(
            frontDistanceM: 390,
            centerDistanceM: 400,
            backDistanceM: 410
        ),
        hazards: [
            Hazard(
                id: "mapped-water-right",
                kind: .water,
                position: "right 90m",
                note: "Water right is still in play.",
                progressM: 250
            )
        ],
        fairway: FairwayContext(landingWidthM: 36, drivingZoneEndM: nil)
    )
    let course = Course(id: "mapped-progress-test", name: "Mapped Progress Test", holes: [hole])
    let packet = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: RoundState(
            courseId: course.id,
            selectedHoleNumber: 1,
            shotContexts: [
                1: ShotContext(
                    shotNumber: 2,
                    remainingDistanceM: .known(120),
                    lie: .known(.fairway),
                    wind: nil,
                    progressM: 220
                )
            ]
        )
    )

    #expect(packet.shotIntent == .approach)
    #expect(packet.riskNote == "Avoid right water; that is the expensive miss.")
}

@Test func mappedHazardSideOverridesMisleadingPositionText() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 360,
        green: GreenContext(
            frontDistanceM: 350,
            centerDistanceM: 360,
            backDistanceM: 370
        ),
        hazards: [
            Hazard(
                id: "mapped-water-left",
                kind: .water,
                position: "right 180m",
                note: "Water left shapes the tee shot.",
                progressM: 180,
                side: .left
            )
        ],
        fairway: FairwayContext(landingWidthM: 36, drivingZoneEndM: nil)
    )
    let course = Course(id: "mapped-side-test", name: "Mapped Side Test", holes: [hole])
    let packet = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: RoundState(
            courseId: course.id,
            selectedHoleNumber: 1,
            shotContexts: [
                1: ShotContext(
                    shotNumber: 1,
                    remainingDistanceM: .known(360),
                    lie: .known(.tee),
                    wind: nil
                )
            ]
        )
    )

    #expect(packet.shotIntent == .teePosition)
    #expect(packet.target == "right-center fairway")
}

@Test func laterallyDistantHazardStopsBiasingTargeting() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 360,
        green: GreenContext(
            frontDistanceM: 350,
            centerDistanceM: 360,
            backDistanceM: 370
        ),
        hazards: [
            Hazard(
                id: "far-water-left",
                kind: .water,
                position: "left 150m",
                note: "Far-left water is outside the normal corridor.",
                progressM: 150,
                side: .left,
                lateralOffsetM: 40
            )
        ],
        fairway: FairwayContext(landingWidthM: 36, drivingZoneEndM: nil)
    )
    let course = Course(id: "lateral-distance-test", name: "Lateral Distance Test", holes: [hole])
    let packet = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: RoundState(
            courseId: course.id,
            selectedHoleNumber: 1,
            shotContexts: [
                1: ShotContext(
                    shotNumber: 2,
                    remainingDistanceM: .known(142),
                    lie: .known(.fairway),
                    wind: nil,
                    progressM: 180
                )
            ]
        )
    )

    #expect(packet.shotIntent == .approach)
    #expect(packet.target == "middle of the green")
    #expect(packet.riskNote == nil)
    #expect(packet.debugInfo?.hazardEvaluations.count == 1)
    #expect(packet.debugInfo?.hazardEvaluations.first?.label == "water left around 150m")
    #expect(packet.debugInfo?.hazardEvaluations.first?.isRelevant == false)
}

@Test func bunkerLieSwitchesToRecoveryIntentWithMostLoftedReachingWedge() {
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

    // PW (105m) and 50W (85m) both reach 72m; loft beats distance from sand,
    // so the more lofted 50W is the recovery club, not the longer PW.
    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .recovery)
    #expect(packet.recommendedClub == "50W")
    #expect(packet.target == "safe recovery window")
    #expect(packet.primaryReason == "50W is the safest recovery club from this lie.")
    #expect(packet.confidence == .low)
}

@Test func longBunkerShotCanUseAnIronInsteadOfDefaultingToPW() {
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 3,
            remainingDistanceM: .known(125.2),
            lie: .known(.bunker),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.shotIntent == .recovery)
    #expect(packet.recommendedClub != "PW")
    #expect(packet.recommendedClub == "9 Iron")
}

@Test func longBunkerShotTakesLongestWedgeWhenLoftCannotReach() {
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 3,
            remainingDistanceM: .known(95),
            lie: .known(.bunker),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    // Only PW (105m) reaches 95m; 50W (85m) cannot, so the longer wedge wins.
    #expect(packet.shotIntent == .recovery)
    #expect(packet.recommendedClub == "PW")
}

@Test func wedgeAbbreviationsRemainBunkerPlayableByDefault() {
    #expect(PlayerClub(name: "SW", carryDistanceM: 70).isPlayable(from: .bunker))
    #expect(PlayerClub(name: "GW", carryDistanceM: 95).isPlayable(from: .bunker))
    #expect(PlayerClub(name: "LW", carryDistanceM: 55).isPlayable(from: .bunker))
    #expect(PlayerClub(name: "7 Iron", carryDistanceM: 135).isPlayable(from: .bunker))
    #expect(!PlayerClub(name: "Driver", carryDistanceM: 220).isPlayable(from: .bunker))
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
    #expect(helpingPacket.recommendedClub == "8 Iron")
    #expect(hurtingPacket.distanceBasisM == 150)
    #expect(hurtingPacket.recommendedClub == "7 Iron")
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

@Test func nearZeroDistanceDoesNotInventWedgeRecommendation() {
    let roundState = SampleRound.roundState.updateShotContext(
        ShotContext(
            shotNumber: 3,
            remainingDistanceM: .known(1),
            lie: .known(.fairway),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .unavailable)
    #expect(packet.recommendedClub == nil)
    #expect(packet.shotIntent == nil)
    #expect(packet.distanceBasisM == 1)
    #expect(packet.primaryReason == "At the green. Finish the hole from here.")
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
