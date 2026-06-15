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
    #expect(packet.recommendedClub == "Driver")
    #expect(packet.clubCarryDistanceM == 220)
    #expect(packet.distanceBasisM == 220)
    #expect(packet.target == "left-center fairway")
    #expect(packet.primaryReason == "Driver advances the ball about 220m and leaves roughly 240m in.")
    #expect(packet.riskNote == "Water right comes into play around 188m and bunker left starts to matter around 240m.")
}
