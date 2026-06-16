import Foundation

public enum SampleRound {
    public static let course = Course(
        id: "sample-links",
        name: "Sample Links",
        holes: [
            CourseHole(
                number: 1,
                par: 4,
                teeLengthM: 356,
                green: GreenContext(
                    frontDistanceM: 131,
                    centerDistanceM: 142,
                    backDistanceM: 154
                ),
                hazards: [
                    Hazard(
                        id: "h1-bunker-short-right",
                        kind: .bunker,
                        position: "short right",
                        note: "Bunker guards the short-right miss."
                    ),
                    Hazard(
                        id: "h1-water-long-left",
                        kind: .water,
                        position: "long left",
                        note: "Long-left miss is expensive."
                    )
                ]
            ),
            CourseHole(
                number: 2,
                par: 3,
                teeLengthM: 148,
                green: GreenContext(
                    frontDistanceM: 136,
                    centerDistanceM: 148,
                    backDistanceM: 160
                ),
                hazards: [
                    Hazard(
                        id: "h2-trees-right",
                        kind: .trees,
                        position: "right",
                        note: "Trees pinch the right side."
                    )
                ]
            )
        ]
    )

    public static let player = PlayerContext(
        handicapIndex: 21.8,
        clubs: [
            PlayerClub(name: "Driver", carryDistanceM: 220),
            PlayerClub(name: "3 Hybrid", carryDistanceM: 190),
            PlayerClub(name: "5 Iron", carryDistanceM: 170),
            PlayerClub(name: "6 Iron", carryDistanceM: 160),
            PlayerClub(name: "7 Iron", carryDistanceM: 150),
            PlayerClub(name: "8 Iron", carryDistanceM: 140),
            PlayerClub(name: "9 Iron", carryDistanceM: 130),
            PlayerClub(name: "PW", carryDistanceM: 110),
            PlayerClub(name: "50W", carryDistanceM: 90)
        ],
        strategyPreference: .normal
    )

    public static let readyShot = ShotContext(
        shotNumber: 2,
        remainingDistanceM: .known(142),
        lie: .known(.fairway),
        wind: WindContext(direction: .hurting, speedMps: 4)
    )

    public static let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [1: readyShot]
    )

    public static let missingDistanceRoundState = roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .missing,
            lie: .known(.fairway),
            wind: readyShot.wind
        )
    )

    public static let missingLieRoundState = roundState.updateShotContext(
        ShotContext(
            shotNumber: 2,
            remainingDistanceM: .known(142),
            lie: .missing,
            wind: readyShot.wind
        )
    )
}
