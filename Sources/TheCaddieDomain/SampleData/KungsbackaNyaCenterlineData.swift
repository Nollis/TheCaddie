import Foundation

// Generated from ../TrueCaddie/shared/sample-bundles/kungsbacka-nya.v1.json
public enum KungsbackaNyaCenterlineData {
    public static func coordinates(for holeNumber: Int) -> [GeoCoordinate] {
        centerlines[holeNumber] ?? []
    }

    private static let centerlines: [Int: [GeoCoordinate]] = [
        1: [
            GeoCoordinate(latitude: 57.4930597923082, longitude: 11.986443400383),
            GeoCoordinate(latitude: 57.4923981727638, longitude: 11.9902682304382),
            GeoCoordinate(latitude: 57.4909343509684, longitude: 11.9925682246685),
        ],
        2: [
            GeoCoordinate(latitude: 57.489394067438, longitude: 11.9961100816727),
            GeoCoordinate(latitude: 57.488194662689, longitude: 11.9971776008606),
        ],
        3: [
            GeoCoordinate(latitude: 57.4874613924878, longitude: 11.9961293016947),
            GeoCoordinate(latitude: 57.486607662846, longitude: 11.9926926871446),
            GeoCoordinate(latitude: 57.4868629185635, longitude: 11.991810059364),
        ],
        4: [
            GeoCoordinate(latitude: 57.4857277749446, longitude: 11.9922493005783),
            GeoCoordinate(latitude: 57.4860147641512, longitude: 11.9887831756769),
            GeoCoordinate(latitude: 57.4862801189988, longitude: 11.9869025614696),
        ],
        5: [
            GeoCoordinate(latitude: 57.486531437961, longitude: 11.9860493714993),
            GeoCoordinate(latitude: 57.4876216725327, longitude: 11.9828193294085),
            GeoCoordinate(latitude: 57.4877673230995, longitude: 11.981354542879),
        ],
        6: [
            GeoCoordinate(latitude: 57.4881288513433, longitude: 11.981689783243),
            GeoCoordinate(latitude: 57.488149040285, longitude: 11.9850325012207),
            GeoCoordinate(latitude: 57.4880423271807, longitude: 11.9869587223346),
        ],
        7: [
            GeoCoordinate(latitude: 57.4876870386188, longitude: 11.9866424735266),
            GeoCoordinate(latitude: 57.4874451377544, longitude: 11.9917268279855),
            GeoCoordinate(latitude: 57.4876124425861, longitude: 11.9951074432781),
        ],
        8: [
            GeoCoordinate(latitude: 57.4896980438358, longitude: 11.9940774635504),
            GeoCoordinate(latitude: 57.4906556503253, longitude: 11.9927305834894),
        ],
        9: [
            GeoCoordinate(latitude: 57.491443899475, longitude: 11.9903368773735),
            GeoCoordinate(latitude: 57.4922369661869, longitude: 11.9879070555745),
            GeoCoordinate(latitude: 57.492643586439, longitude: 11.985895613688),
        ],
    ]
}

