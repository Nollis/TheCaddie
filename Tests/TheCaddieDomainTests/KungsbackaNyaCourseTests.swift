import Testing
import TheCaddieDomain

@Test func kungsbackaNyaCourseIncludesNineRealHoles() throws {
    let course = KungsbackaNyaCourse.course

    #expect(course.id == "kungsbacka-nya")
    #expect(course.name == "Kungsbacka Nya")
    #expect(course.holes.map(\.number) == Array(1...9))
    #expect(course.holes.map(\.par) == [5, 3, 4, 4, 4, 4, 5, 3, 4])
    #expect(course.hole(number: 1)?.teeLengthM == 460)
    #expect(course.hole(number: 7)?.teeLengthM == 525)
    #expect(course.hole(number: 9)?.teeLengthM == 400)
}

@Test func kungsbackaNyaCourseCarriesHazardContextFromTrueCaddieBundle() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))
    let hole3 = try #require(KungsbackaNyaCourse.course.hole(number: 3))
    let hole8 = try #require(KungsbackaNyaCourse.course.hole(number: 8))

    #expect(hole1.hazards.contains(Hazard(
        id: "h1-water-right-188",
        kind: .water,
        position: "right 188m",
        note: "Water right is the expensive miss from the tee."
    )))
    #expect(hole1.fairway == FairwayContext(landingWidthM: 56, drivingZoneEndM: nil))
    #expect(hole3.fairway == FairwayContext(landingWidthM: 23.5, drivingZoneEndM: 146))
    #expect(KungsbackaNyaCourse.course.hole(number: 5)?.fairway == FairwayContext(landingWidthM: 30, drivingZoneEndM: 185))
    #expect(hole1.hazards.contains { $0.kind == .bunker && $0.position == "left 240m" })
    #expect(hole8.hazards == [
        Hazard(
            id: "h8-bunker-right-115",
            kind: .bunker,
            position: "right 115m",
            note: "Right bunker is the miss to avoid."
        )
    ])
}

@Test func kungsbackaNyaCourseCarriesGreenCenterCoordinatesFromBundle() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))
    let hole8 = try #require(KungsbackaNyaCourse.course.hole(number: 8))

    #expect(hole1.defaultTeeCoordinate == GeoCoordinate(
        latitude: 57.49302015313067,
        longitude: 11.986226141452791
    ))
    #expect(hole1.green.centerCoordinate == GeoCoordinate(
        latitude: 57.491023724,
        longitude: 11.992440149
    ))
    #expect(hole8.green.centerCoordinate == GeoCoordinate(
        latitude: 57.490652474,
        longitude: 11.992686825
    ))
}

@Test func kungsbackaHoleOneGreenCoordinateReturnsExpectedGpsDistance() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))
    let whiteTee = GeoCoordinate(
        latitude: 57.49302015313067,
        longitude: 11.986226141452791
    )

    let distance = try #require(hole1.green.distanceToCenter(from: whiteTee))
    #expect(abs(distance - 432.6) < 1.0)
}

@Test func holeDetectorFindsHoleAtKnownTees() {
    let holeOneTee = GeoCoordinate(
        latitude: 57.49302015313067,
        longitude: 11.986226141452791
    )
    let holeEightTee = GeoCoordinate(
        latitude: 57.48966856061047,
        longitude: 11.994125031611265
    )

    #expect(HoleDetector.activeHole(
        fix: holeOneTee,
        course: KungsbackaNyaCourse.course,
        current: nil
    ) == 1)
    #expect(HoleDetector.activeHole(
        fix: holeEightTee,
        course: KungsbackaNyaCourse.course,
        current: nil
    ) == 8)
}

@Test func holeDetectorUsesHysteresisBeforeSwitchingHoles() {
    let holeTwoTee = GeoCoordinate(
        latitude: 57.489451730135336,
        longitude: 11.995965242385864
    )

    #expect(HoleDetector.activeHole(
        fix: holeTwoTee,
        course: KungsbackaNyaCourse.course,
        current: 1,
        consecutiveMisses: 4
    ) == 1)
    #expect(HoleDetector.activeHole(
        fix: holeTwoTee,
        course: KungsbackaNyaCourse.course,
        current: 1,
        consecutiveMisses: 5
    ) == 2)
}

@Test func kungsbackaOpeningRoundBuildsARecommendationFromRealCourse() {
    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: KungsbackaNyaCourse.openingRoundState
    )

    #expect(packet.status == .ready)
    #expect(packet.courseId == "kungsbacka-nya")
    #expect(packet.holeNumber == 1)
    #expect(packet.par == 5)
    #expect(packet.remainingDistanceM == 460)
    #expect(packet.lie == .tee)
    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "Driver")
    #expect(packet.clubCarryDistanceM == 220)
    #expect(packet.distanceBasisM == 220)
    #expect(packet.target == "left-center fairway")
    #expect(packet.primaryReason == "Driver advances the ball about 220m and leaves roughly 240m in.")
    #expect(packet.riskNote == "Water right is near the landing zone.")
}

@Test func kungsbackaHoleOneNearGreenDoesNotRepeatPassedTeeWater() {
    let roundState = KungsbackaNyaCourse.openingRoundState.updateShotContext(
        ShotContext(
            shotNumber: 3,
            remainingDistanceM: .known(72),
            lie: .known(.fairway),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.recommendedClub == "50W")
    #expect(packet.riskNote == nil)
}

@Test func kungsbackaHoleOneSecondShotDoesNotWarnAboutDistantBunkerPastLandingWindow() {
    let roundState = KungsbackaNyaCourse.openingRoundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(262),
            lie: .known(.fairway),
            wind: nil
        )
    )

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.recommendedClub == "3 Hybrid")
    #expect(packet.riskNote == nil)
}

@Test func kungsbackaHoleTwoUsesPlayerEightIronDistance() {
    let roundState = KungsbackaNyaCourse.openingRoundState.selectHole(2)

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .approach)
    #expect(packet.recommendedClub == "8 Iron")
    #expect(packet.target == "middle-right of the green")
}

@Test func kungsbackaHoleEightUsesNineIronForOneThirtyMeterParThree() {
    let roundState = KungsbackaNyaCourse.openingRoundState.selectHole(8)

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.holeNumber == 8)
    #expect(packet.par == 3)
    #expect(packet.remainingDistanceM == 130)
    #expect(packet.shotIntent == .approach)
    #expect(packet.recommendedClub == "9 Iron")
    #expect(packet.primaryReason == "9 Iron covers the 130m playing number.")
}

@Test func kungsbackaHoleThreeAvoidsDriverThroughPairedWater() {
    let roundState = KungsbackaNyaCourse.openingRoundState.selectHole(3)

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "7 Iron")
    #expect(packet.primaryReason == "7 Iron advances the ball about 150m and leaves roughly 130m in.")
}

@Test func kungsbackaHoleFiveClubsDownToFiveIronFromTheTee() {
    let roundState = KungsbackaNyaCourse.openingRoundState.selectHole(5)

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.target == "right-center fairway")
    #expect(packet.primaryReason == "5 Iron advances the ball about 170m and leaves roughly 180m in.")
}
