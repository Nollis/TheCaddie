import Foundation

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

    public init(frontDistanceM: Double, centerDistanceM: Double, backDistanceM: Double) {
        self.frontDistanceM = frontDistanceM
        self.centerDistanceM = centerDistanceM
        self.backDistanceM = backDistanceM
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
