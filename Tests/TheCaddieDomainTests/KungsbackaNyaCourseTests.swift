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
    let hole8 = try #require(KungsbackaNyaCourse.course.hole(number: 8))

    #expect(hole1.hazards.contains(Hazard(
        id: "h1-water-right-188",
        kind: .water,
        position: "right 188m",
        note: "Water right is the expensive miss from the tee."
    )))
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
    #expect(packet.riskNote == "Water right is near the landing zone and bunker left is the long miss.")
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

@Test func kungsbackaHoleTwoUsesPlayerNineIronDistance() {
    let roundState = KungsbackaNyaCourse.openingRoundState.selectHole(2)

    let packet = CaddieRecommendationEngine.build(
        course: KungsbackaNyaCourse.course,
        player: SampleRound.player,
        roundState: roundState
    )

    #expect(packet.status == .ready)
    #expect(packet.shotIntent == .approach)
    #expect(packet.recommendedClub == "9 Iron")
    #expect(packet.target == "middle-right of the green")
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
    #expect(packet.recommendedClub == "8 Iron")
    #expect(packet.primaryReason == "8 Iron advances the ball about 150m and leaves roughly 130m in.")
}
