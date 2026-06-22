import Testing
import TheCaddieDomain

@Test func courseHoleCarriesOptionalFairwayContext() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 380,
        green: GreenContext(frontDistanceM: 360, centerDistanceM: 372, backDistanceM: 384),
        hazards: [],
        fairway: FairwayContext(landingWidthM: 30, drivingZoneEndM: 250)
    )

    #expect(hole.fairway?.landingWidthM == 30)
    #expect(hole.fairway?.drivingZoneEndM == 250)

    let holeWithoutFairway = CourseHole(
        number: 2,
        par: 3,
        teeLengthM: 150,
        green: GreenContext(frontDistanceM: 140, centerDistanceM: 150, backDistanceM: 160),
        hazards: []
    )
    #expect(holeWithoutFairway.fairway == nil)
}

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
    #expect(player.skillProfile.dispersionMultiplier == 1.45)
    #expect(player.clubs.first?.name == "Driver")
    #expect(player.clubs.first?.isPlayable(from: .fairway) == false)
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

@Test func roundStateCanRecordShotResultAndAdvanceTheHoleState() throws {
    let updatedRound = KungsbackaNyaCourse.openingRoundState.recordShotResult(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        resultingLie: .fairway
    )

    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedShot.shotNumber == 2)
    #expect(updatedShot.remainingDistanceM.value == 240)
    #expect(updatedShot.lie.value == .fairway)
    #expect(updatedShot.progressM == 220)
}

@Test func roundStateCanRecordShotResultForSelectedHoleWithoutStoredShot() throws {
    let updatedRound = KungsbackaNyaCourse.openingRoundState
        .selectHole(8)
        .recordShotResult(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            resultingLie: .bunker
        )

    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedRound.selectedHoleNumber == 8)
    #expect(updatedShot.shotNumber == 2)
    #expect(updatedShot.remainingDistanceM.value == 15)
    #expect(updatedShot.lie.value == .bunker)
}

@Test func bunkerShotResultSnapsToRealForwardBunkerInsteadOfSyntheticDistance() throws {
    let afterTee = KungsbackaNyaCourse.openingRoundState.recordShotResult(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        resultingLie: .fairway
    )
    let bunkerRound = afterTee.recordShotResult(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        resultingLie: .bunker
    )

    let updatedShot = try #require(bunkerRound.currentShotContext())
    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: bunkerRound
    )

    #expect(updatedShot.shotNumber == 3)
    #expect(updatedShot.remainingDistanceM.value == 43)
    #expect(updatedShot.lie.value == .bunker)
    #expect(updatedShot.progressM == 417.12)
    #expect(packet.recommendedClub == "50W")
}

@Test func bunkerShotResultFallsBackToProjectedProgressWhenNoBunkerIsNearLanding() throws {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 300,
        green: GreenContext(
            frontDistanceM: 291,
            centerDistanceM: 300,
            backDistanceM: 309
        ),
        hazards: [
            Hazard(
                id: "far-bunker-left",
                kind: .bunker,
                position: "left 180m",
                note: "This bunker is too far from the projected landing to snap to.",
                progressM: 180
            )
        ]
    )
    let course = Course(id: "round-state-bunker-fallback", name: "Round State Bunker Fallback", holes: [hole])
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 2,
                remainingDistanceM: .known(150),
                lie: .known(.fairway),
                wind: nil,
                progressM: 150
            )
        ]
    )

    let updatedRound = roundState.recordShotResult(
        course: course,
        player: SampleRound.player,
        resultingLie: .bunker
    )
    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedShot.shotNumber == 3)
    #expect(updatedShot.remainingDistanceM.value == 42)
    #expect(updatedShot.progressM == 258)
    #expect(updatedShot.lie.value == .bunker)
}

@Test func explicitProgressDrivesNextShotDistanceMoreThanStaleRemainingDistance() throws {
    let course = KungsbackaNyaCourse.course
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 2,
                remainingDistanceM: .known(260),
                lie: .known(.fairway),
                wind: nil,
                progressM: 260
            )
        ]
    )

    let updatedRound = roundState.recordShotResult(
        course: course,
        player: SampleRound.player,
        resultingLie: .fairway
    )
    let updatedShot = try #require(updatedRound.currentShotContext())
    let packet = CaddieRecommendationEngine.build(
        course: course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.recommendedClub == "3 Hybrid")
    #expect(updatedShot.shotNumber == 3)
    #expect(updatedShot.remainingDistanceM.value == 10)
    #expect(updatedShot.progressM == 450)
}

@Test func roughShotResultUsesBoundedPenaltyInsteadOfFlatMultiplier() throws {
    let course = KungsbackaNyaCourse.course
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 2,
                remainingDistanceM: .known(200),
                lie: .known(.fairway),
                wind: nil,
                progressM: 260
            )
        ]
    )

    let updatedRound = roundState.recordShotResult(
        course: course,
        player: SampleRound.player,
        resultingLie: .rough
    )
    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedShot.shotNumber == 3)
    #expect(updatedShot.remainingDistanceM.value == 28)
    #expect(updatedShot.progressM == 432)
    #expect(updatedShot.lie.value == .rough)
}

@Test func recoveryShotResultUsesBoundedPenaltyInsteadOfOverlyShortAdvance() throws {
    let course = KungsbackaNyaCourse.course
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 2,
                remainingDistanceM: .known(200),
                lie: .known(.fairway),
                wind: nil,
                progressM: 260
            )
        ]
    )

    let updatedRound = roundState.recordShotResult(
        course: course,
        player: SampleRound.player,
        resultingLie: .recovery
    )
    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedShot.shotNumber == 3)
    #expect(updatedShot.remainingDistanceM.value == 44)
    #expect(updatedShot.progressM == 415.8)
    #expect(updatedShot.lie.value == .recovery)
}

@Test func greenShotResultAdvancesToGreenState() throws {
    let updatedRound = KungsbackaNyaCourse.openingRoundState
        .selectHole(8)
        .recordShotResult(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            resultingLie: .green
        )

    let updatedShot = try #require(updatedRound.currentShotContext())

    #expect(updatedShot.shotNumber == 2)
    #expect(updatedShot.remainingDistanceM.value == 0)
    #expect(updatedShot.lie.value == .green)
}

@Test func finishCurrentHoleMarksItCompleteAndMovesToNextHole() {
    let finishedRound = KungsbackaNyaCourse.openingRoundState
        .selectHole(8)
        .recordShotResult(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            resultingLie: .green
        )
        .finishCurrentHole(course: KungsbackaNyaCourse.course)

    #expect(finishedRound.isHoleComplete(8))
    #expect(finishedRound.selectedHoleNumber == 9)

    let nextShot = CurrentShotContext.resolve(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: finishedRound
    )

    guard case let .ready(_, hole, _, shot) = nextShot else {
        Issue.record("Expected next hole tee shot after finishing the hole")
        return
    }

    #expect(hole.number == 9)
    #expect(shot.shotNumber == 1)
    #expect(shot.remainingDistanceM.value == 400)
    #expect(shot.lie.value == .tee)
}

@Test func finishFinalHoleMarksRoundComplete() {
    let nearingFinish = RoundState(
        courseId: KungsbackaNyaCourse.course.id,
        selectedHoleNumber: 9,
        shotContexts: [
            9: ShotContext(
                shotNumber: 2,
                remainingDistanceM: .known(0),
                lie: .known(.green),
                wind: nil
            )
        ],
        completedHoleNumbers: Set(1...8)
    )

    let finishedRound = nearingFinish.finishCurrentHole(course: KungsbackaNyaCourse.course)

    #expect(finishedRound.isHoleComplete(9))
    #expect(finishedRound.selectedHoleNumber == 9)
    #expect(finishedRound.isRoundComplete(course: KungsbackaNyaCourse.course))
}

@Test func progressedShotUsesForwardHazardsInsteadOfRepeatingPassedTeeWater() {
    let updatedRound = KungsbackaNyaCourse.openingRoundState.recordShotResult(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        resultingLie: .fairway
    )

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: updatedRound
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .layup)
    #expect(packet.target == "front approach window")
    #expect(packet.recommendedClub == "3 Hybrid")
    #expect(packet.primaryReason == "3 Hybrid advances the ball about 190m and leaves roughly 50m in.")
    #expect(packet.riskNote == "Bunker left is near the landing zone.")
}

@Test func roundStateTracksHoleScoresAndStats() {
    let holeScore = HoleScore(
        holeNumber: 1,
        strokes: 4,
        putts: 2,
        fairwayHit: true,
        greenInRegulation: true
    )
    
    let roundState = RoundState(
        courseId: "sample",
        selectedHoleNumber: 1,
        shotContexts: [:],
        completedHoleNumbers: [1],
        holeScores: [1: holeScore]
    )
    
    #expect(roundState.holeScores[1]?.strokes == 4)
    #expect(roundState.holeScores[1]?.putts == 2)
    #expect(roundState.holeScores[1]?.fairwayHit == true)
    #expect(roundState.holeScores[1]?.greenInRegulation == true)
}

@Test func playerProfileSnapshotRoundTripsClubDistancesHandicapAndStrategy() throws {
    let player = PlayerContext(
        handicapIndex: 13.4,
        clubs: [
            PlayerClub(name: "Driver", carryDistanceM: 232),
            PlayerClub(name: "7 Iron", carryDistanceM: 146),
            PlayerClub(name: "50W", carryDistanceM: 92)
        ],
        strategyPreference: .aggressive
    )

    let snapshot = PlayerProfileSnapshot(player: player)
    let encoded = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(PlayerProfileSnapshot.self, from: encoded)

    #expect(decoded.handicapIndex == 13.4)
    #expect(decoded.strategyPreferenceRawValue == StrategyPreference.aggressive.rawValue)
    #expect(decoded.clubCarryDistancesM["Driver"] == 232)
    #expect(decoded.clubCarryDistancesM["7 Iron"] == 146)
    #expect(decoded.clubCarryDistancesM["50W"] == 92)
}

@Test func playerProfileSnapshotAppliesSavedDistancesOntoLatestBaseBag() {
    let basePlayer = PlayerContext(
        handicapIndex: 21.8,
        clubs: [
            PlayerClub(name: "Driver", carryDistanceM: 220),
            PlayerClub(name: "5 Iron", carryDistanceM: 170),
            PlayerClub(name: "7 Iron", carryDistanceM: 150),
            PlayerClub(name: "PW", carryDistanceM: 110)
        ],
        strategyPreference: .normal
    )
    let savedSnapshot = PlayerProfileSnapshot(
        handicapIndex: 18.2,
        strategyPreferenceRawValue: StrategyPreference.safe.rawValue,
        clubCarryDistancesM: [
            "Driver": 228,
            "7 Iron": 144
        ]
    )

    let resolved = savedSnapshot.resolvePlayer(base: basePlayer)

    #expect(resolved.handicapIndex == 18.2)
    #expect(resolved.strategyPreference == .safe)
    #expect(resolved.clubs.first(where: { $0.name == "Driver" })?.carryDistanceM == 228)
    #expect(resolved.clubs.first(where: { $0.name == "7 Iron" })?.carryDistanceM == 144)
    #expect(resolved.clubs.first(where: { $0.name == "5 Iron" })?.carryDistanceM == 170)
    #expect(resolved.clubs.first(where: { $0.name == "PW" })?.carryDistanceM == 110)
}
