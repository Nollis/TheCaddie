import Foundation

public enum KungsbackaNyaCourse {
    public static let course = Course(
        id: "kungsbacka-nya",
        name: "Kungsbacka Nya",
        holes: [
            hole(
                1,
                par: 5,
                teeLengthM: 460,
                teeCoordinate: GeoCoordinate(latitude: 57.49302015313067, longitude: 11.986226141452791),
                greenCoordinate: GeoCoordinate(latitude: 57.491023724, longitude: 11.992440149),
                fairway: FairwayContext(landingWidthM: 56),
                hazards: [
                    hazard("h1-bunker-left-417", .bunker, "left 417m", "Bunker left near the green-side approach.", coordinate: GeoCoordinate(latitude: 57.491195459, longitude: 11.992199543)),
                    hazard("h1-bunker-left-240", .bunker, "left 240m", "Left bunker can catch the layup line.", coordinate: GeoCoordinate(latitude: 57.492519014, longitude: 11.99041754)),
                    hazard("h1-water-right-188", .water, "right 188m", "Water right is the expensive miss from the tee."),
                    hazard("h1-water-right-0", .water, "right", "Water sits right of the opening corridor.")
                ]
            ),
            hole(
                2,
                par: 3,
                teeLengthM: 140,
                teeCoordinate: GeoCoordinate(latitude: 57.489451730135336, longitude: 11.995965242385864),
                greenCoordinate: GeoCoordinate(latitude: 57.488330174334116, longitude: 11.997032761573793),
                hazards: [
                    hazard("h2-water-left-93", .water, "left 93m", "Water guards the left side short of the green.")
                ]
            ),
            hole(
                3,
                par: 4,
                teeLengthM: 280,
                teeCoordinate: GeoCoordinate(latitude: 57.487514749927804, longitude: 11.996338556913237),
                greenCoordinate: GeoCoordinate(latitude: 57.48686546862034, longitude: 11.991813182830812),
                fairway: FairwayContext(landingWidthM: 23.5, drivingZoneEndM: 146),
                hazards: [
                    hazard("h3-water-right-185", .water, "right 185m", "Water right shapes the tee shot."),
                    hazard("h3-water-left-196", .water, "left 196m", "Water left punishes an over-correction."),
                    hazard("h3-trees-right-56", .trees, "right 56m", "Trees pinch the right side early."),
                    hazard("h3-trees-left-278", .trees, "left 278m", "Trees left protect the green end.")
                ]
            ),
            hole(
                4,
                par: 4,
                teeLengthM: 375,
                teeCoordinate: GeoCoordinate(latitude: 57.48572200629426, longitude: 11.992922673140438),
                greenCoordinate: GeoCoordinate(latitude: 57.486323299, longitude: 11.986988782),
                fairway: FairwayContext(landingWidthM: 34, drivingZoneEndM: 255),
                hazards: [
                    hazard("h4-water-left-281", .water, "left 281m", "Water left is the main positional hazard.")
                ]
            ),
            hole(
                5,
                par: 4,
                teeLengthM: 350,
                teeCoordinate: GeoCoordinate(latitude: 57.486380187746235, longitude: 11.986569349981549),
                greenCoordinate: GeoCoordinate(latitude: 57.487737089, longitude: 11.981447571),
                fairway: FairwayContext(landingWidthM: 30, drivingZoneEndM: 185),
                hazards: [
                    hazard("h5-water-left-104", .water, "left 104m", "Water left appears early in the hole."),
                    hazard("h5-bunker-right-303", .bunker, "right 303m", "Right bunker can catch the stronger tee shot.", coordinate: GeoCoordinate(latitude: 57.487886525, longitude: 11.981634358)),
                    hazard("h5-trees-right-228", .trees, "right 228m", "Trees right narrow the stock corridor."),
                    hazard("h5-trees-right-151", .trees, "right 151m", "Right trees punish a pushed layup.")
                ]
            ),
            hole(
                6,
                par: 4,
                teeLengthM: 330,
                teeCoordinate: GeoCoordinate(latitude: 57.48812186614907, longitude: 11.98154756644462),
                greenCoordinate: GeoCoordinate(latitude: 57.488013097, longitude: 11.98698928),
                fairway: FairwayContext(landingWidthM: 42, drivingZoneEndM: 245),
                hazards: [
                    hazard("h6-bunker-right-299", .bunker, "right 299m", "Right bunker shapes the approach side.", coordinate: GeoCoordinate(latitude: 57.487987809, longitude: 11.986673002)),
                    hazard("h6-bunker-right-312", .bunker, "right 312m", "Second right bunker protects the green side.", coordinate: GeoCoordinate(latitude: 57.487926418, longitude: 11.986875358))
                ]
            ),
            hole(
                7,
                par: 5,
                teeLengthM: 525,
                teeCoordinate: GeoCoordinate(latitude: 57.48772893916422, longitude: 11.986469900276397),
                greenCoordinate: GeoCoordinate(latitude: 57.487641398, longitude: 11.995076269),
                fairway: FairwayContext(landingWidthM: 46, drivingZoneEndM: 255),
                hazards: [
                    hazard("h7-trees-right-401", .trees, "right 401m", "Trees right affect the second-shot corridor."),
                    hazard("h7-bunker-left-481", .bunker, "left 481m", "Left bunker guards the layup/approach finish.", coordinate: GeoCoordinate(latitude: 57.487644342, longitude: 11.994656033)),
                    hazard("h7-bunker-right-497", .bunker, "right 497m", "Right bunker narrows the green approach.", coordinate: GeoCoordinate(latitude: 57.487435349, longitude: 11.994949831)),
                    hazard("h7-bunker-left-500", .bunker, "left 500m", "Left bunker protects the green side.", coordinate: GeoCoordinate(latitude: 57.487728233, longitude: 11.994941354))
                ]
            ),
            hole(
                8,
                par: 3,
                teeLengthM: 130,
                teeCoordinate: GeoCoordinate(latitude: 57.48966856061047, longitude: 11.994125031611265),
                greenCoordinate: GeoCoordinate(latitude: 57.490652474, longitude: 11.992686825),
                hazards: [
                    hazard("h8-bunker-right-115", .bunker, "right 115m", "Right bunker is the miss to avoid.", coordinate: GeoCoordinate(latitude: 57.490577362, longitude: 11.993050247))
                ]
            ),
            hole(
                9,
                par: 4,
                teeLengthM: 400,
                teeCoordinate: GeoCoordinate(latitude: 57.49119783213578, longitude: 11.990969516650097),
                greenCoordinate: GeoCoordinate(latitude: 57.492651506, longitude: 11.985931091),
                fairway: FairwayContext(landingWidthM: 30, drivingZoneEndM: 215),
                hazards: [
                    hazard("h9-water-right-106", .water, "right 106m", "Water right affects the tee corridor."),
                    hazard("h9-water-left-298", .water, "left 298m", "Water left is the expensive miss deeper in the hole.")
                ]
            )
        ]
    )

    public static let openingRoundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(460),
                lie: .known(.tee),
                wind: nil
            )
        ]
    )

    private static func hole(
        _ number: Int,
        par: Int,
        teeLengthM: Double,
        teeCoordinate: GeoCoordinate? = nil,
        greenCoordinate: GeoCoordinate? = nil,
        fairway: FairwayContext? = nil,
        hazards: [Hazard]
    ) -> CourseHole {
        CourseHole(
            number: number,
            par: par,
            teeLengthM: teeLengthM,
            defaultTeeCoordinate: teeCoordinate,
            green: GreenContext(
                frontDistanceM: max(1, teeLengthM - 9),
                centerDistanceM: teeLengthM,
                backDistanceM: teeLengthM + 9,
                centerCoordinate: greenCoordinate
            ),
            hazards: hazards,
            fairway: fairway
        )
    }

    private static func hazard(
        _ id: String,
        _ kind: HazardKind,
        _ position: String,
        _ note: String,
        coordinate: GeoCoordinate? = nil
    ) -> Hazard {
        Hazard(id: id, kind: kind, position: position, note: note, coordinate: coordinate)
    }
}
