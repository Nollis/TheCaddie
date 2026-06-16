import Foundation

public struct GeoCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public func distance(to other: GeoCoordinate) -> Double {
        let earthRadiusM = 6_371_000.0
        let latitude1 = latitude * .pi / 180
        let latitude2 = other.latitude * .pi / 180
        let latitudeDelta = (other.latitude - latitude) * .pi / 180
        let longitudeDelta = (other.longitude - longitude) * .pi / 180

        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }
}

public struct Course: Equatable, Sendable {
    public let id: String
    public let name: String
    public let holes: [CourseHole]

    public init(id: String, name: String, holes: [CourseHole]) {
        self.id = id
        self.name = name
        self.holes = holes.sorted { lhs, rhs in
            lhs.number < rhs.number
        }
    }

    public func hole(number: Int) -> CourseHole? {
        holes.first { $0.number == number }
    }

    public func nextHole(after holeNumber: Int) -> CourseHole? {
        holes.first { $0.number > holeNumber }
    }
}

public struct CourseHole: Equatable, Sendable, Identifiable {
    public let number: Int
    public let par: Int
    public let teeLengthM: Double
    public let green: GreenContext
    public let hazards: [Hazard]
    public let fairway: FairwayContext?

    public var id: Int { number }

    public init(
        number: Int,
        par: Int,
        teeLengthM: Double,
        green: GreenContext,
        hazards: [Hazard],
        fairway: FairwayContext? = nil
    ) {
        self.number = number
        self.par = par
        self.teeLengthM = teeLengthM
        self.green = green
        self.hazards = hazards
        self.fairway = fairway
    }
}

public struct GreenContext: Equatable, Sendable {
    public let frontDistanceM: Double
    public let centerDistanceM: Double
    public let backDistanceM: Double
    public let centerCoordinate: GeoCoordinate?

    public init(
        frontDistanceM: Double,
        centerDistanceM: Double,
        backDistanceM: Double,
        centerCoordinate: GeoCoordinate? = nil
    ) {
        self.frontDistanceM = frontDistanceM
        self.centerDistanceM = centerDistanceM
        self.backDistanceM = backDistanceM
        self.centerCoordinate = centerCoordinate
    }

    public func distanceToCenter(from coordinate: GeoCoordinate) -> Double? {
        centerCoordinate?.distance(to: coordinate)
    }
}

public struct FairwayContext: Equatable, Sendable {
    public let landingWidthM: Double
    public let drivingZoneEndM: Double?

    public init(landingWidthM: Double, drivingZoneEndM: Double? = nil) {
        self.landingWidthM = landingWidthM
        self.drivingZoneEndM = drivingZoneEndM
    }
}

public struct Hazard: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: HazardKind
    public let position: String
    public let note: String

    public init(id: String, kind: HazardKind, position: String, note: String) {
        self.id = id
        self.kind = kind
        self.position = position
        self.note = note
    }
}

public enum HazardKind: String, Equatable, Sendable {
    case bunker
    case water
    case trees
    case outOfBounds
}
