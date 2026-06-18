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
        note: "Water right is the expensive miss from the tee.",
        progressM: 187.83,
        side: .right,
        lateralOffsetM: 33.04
    )))
    #expect(hole1.fairway == FairwayContext(landingWidthM: 56, drivingZoneEndM: nil))
    #expect(hole3.fairway == FairwayContext(landingWidthM: 23.5, drivingZoneEndM: 146))
    #expect(KungsbackaNyaCourse.course.hole(number: 5)?.fairway == FairwayContext(landingWidthM: 30, drivingZoneEndM: 185))
    #expect(hole1.hazards.contains { $0.kind == .bunker && $0.position == "left 240m" })
    #expect(hole1.surfaces.contains { $0.kind == .tee })
    #expect(hole1.surfaces.contains { $0.kind == .fairway })
    #expect(hole1.surfaces.contains { $0.kind == .green })
    #expect(hole1.surfaces.contains { $0.kind == .water })
    #expect(hole8.hazards == [
        Hazard(
            id: "h8-bunker-right-115",
            kind: .bunker,
            position: "right 115m",
            note: "Right bunker is the miss to avoid.",
            coordinate: GeoCoordinate(
                latitude: 57.490577362,
                longitude: 11.993050247
            ),
            progressM: 114.72,
            side: .right,
            lateralOffsetM: 13.08
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
    #expect(hole1.centerlineCoordinates == [
        GeoCoordinate(latitude: 57.49305979230822, longitude: 11.986443400382997),
        GeoCoordinate(latitude: 57.49239817276384, longitude: 11.990268230438234),
        GeoCoordinate(latitude: 57.49093435096836, longitude: 11.992568224668505)
    ])
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

@Test func holeLieInferenceRecognizesMappedTeeGreenAndBunkerLies() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))

    #expect(HoleLieInference.inferLie(
        fix: GeoCoordinate(
            latitude: 57.49302015313067,
            longitude: 11.986226141452791
        ),
        on: hole1
    ) == .tee)

    #expect(HoleLieInference.inferLie(
        fix: GeoCoordinate(
            latitude: 57.491023724,
            longitude: 11.992440149
        ),
        on: hole1
    ) == .green)

    #expect(HoleLieInference.inferLie(
        fix: GeoCoordinate(
            latitude: 57.492519014,
            longitude: 11.99041754
        ),
        on: hole1
    ) == .bunker)

    let waterEdge = try #require(hole1.surfaces.first(where: { $0.kind == .water })?.ring.first)
    #expect(HoleLieInference.inferLie(
        fix: waterEdge,
        on: hole1
    ) == .recovery)
}

@Test func holeLieInferenceUsesMappedSurfacesAndFallsBackToRough() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))

    #expect(HoleLieInference.inferLie(
        fix: GeoCoordinate(
            latitude: 57.492021938565336,
            longitude: 11.989333145226395
        ),
        on: hole1
    ) == .fairway)

    #expect(HoleLieInference.inferLie(
        fix: GeoCoordinate(
            latitude: 57.492021938565336,
            longitude: 11.990333145226394
        ),
        on: hole1
    ) == .rough)
}

@Test func holeProgressInferenceUsesMappedCenterline() throws {
    let hole1 = try #require(KungsbackaNyaCourse.course.hole(number: 1))

    let teeSample = try #require(HoleProgressInference.sample(
        fix: GeoCoordinate(
            latitude: 57.49302015313067,
            longitude: 11.986226141452791
        ),
        on: hole1
    ))
    #expect(teeSample.progressM < 25)
    #expect(teeSample.distanceFromCenterlineM < 25)
    #expect(abs(teeSample.centerlineLengthM - 465) < 12)

    let greenSample = try #require(HoleProgressInference.sample(
        fix: GeoCoordinate(
            latitude: 57.491023724,
            longitude: 11.992440149
        ),
        on: hole1
    ))
    #expect(greenSample.progressM > 430)
    #expect(greenSample.remainingCenterlineM < 20)
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
