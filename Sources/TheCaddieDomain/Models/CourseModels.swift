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
    public let defaultTeeCoordinate: GeoCoordinate?
    public let green: GreenContext
    public let hazards: [Hazard]
    public let fairway: FairwayContext?

    public var id: Int { number }

    public init(
        number: Int,
        par: Int,
        teeLengthM: Double,
        defaultTeeCoordinate: GeoCoordinate? = nil,
        green: GreenContext,
        hazards: [Hazard],
        fairway: FairwayContext? = nil
    ) {
        self.number = number
        self.par = par
        self.teeLengthM = teeLengthM
        self.defaultTeeCoordinate = defaultTeeCoordinate
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

public enum HoleDetector {
    public static let missesRequiredToSwitch = 5
    public static let holeSwitchOuterRadiusM = 80.0
    private static let teeCaptureRadiusM = 55.0
    private static let greenCaptureRadiusM = 45.0
    private static let corridorCaptureRadiusM = 40.0

    public static func activeHole(
        fix: GeoCoordinate,
        course: Course,
        current: Int?,
        consecutiveMisses: Int = 0
    ) -> Int? {
        let bestGuess = bestGuessHole(fix: fix, course: course)

        guard let current else {
            return bestGuess
        }
        if bestGuess == current {
            return current
        }
        return consecutiveMisses >= missesRequiredToSwitch ? bestGuess : current
    }

    public static func fixIsBeyondSwitchRadius(
        fix: GeoCoordinate,
        hole: CourseHole
    ) -> Bool {
        guard let candidate = candidate(for: fix, hole: hole) else {
            return true
        }

        return candidate.minimumRelevantDistanceM > holeSwitchOuterRadiusM
            && candidate.corridorDistanceM > holeSwitchOuterRadiusM
    }

    private static func bestGuessHole(
        fix: GeoCoordinate,
        course: Course
    ) -> Int? {
        course.holes
            .compactMap { candidate(for: fix, hole: $0) }
            .filter { candidate in
                candidate.teeDistanceM <= teeCaptureRadiusM
                    || candidate.greenDistanceM <= greenCaptureRadiusM
                    || candidate.corridorDistanceM <= corridorCaptureRadiusM
            }
            .min { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }
                if lhs.corridorDistanceM != rhs.corridorDistanceM {
                    return lhs.corridorDistanceM < rhs.corridorDistanceM
                }
                return lhs.greenDistanceM > rhs.greenDistanceM
            }?
            .holeNumber
    }

    private static func candidate(
        for fix: GeoCoordinate,
        hole: CourseHole
    ) -> HoleDetectionCandidate? {
        guard let tee = hole.defaultTeeCoordinate,
              let green = hole.green.centerCoordinate else {
            return nil
        }

        let teeDistanceM = tee.distance(to: fix)
        let greenDistanceM = green.distance(to: fix)
        let projection = project(fix, ontoSegmentFrom: tee, to: green)
        let minimumRelevantDistanceM = min(teeDistanceM, greenDistanceM, projection.corridorDistanceM)

        let score: Double
        if teeDistanceM <= teeCaptureRadiusM {
            score = teeDistanceM
        } else if greenDistanceM <= greenCaptureRadiusM {
            score = greenDistanceM
        } else {
            score = projection.corridorDistanceM + (projection.overshootDistanceM * 1.5)
        }

        return HoleDetectionCandidate(
            holeNumber: hole.number,
            score: score,
            teeDistanceM: teeDistanceM,
            greenDistanceM: greenDistanceM,
            corridorDistanceM: projection.corridorDistanceM,
            minimumRelevantDistanceM: minimumRelevantDistanceM
        )
    }

    private static func project(
        _ fix: GeoCoordinate,
        ontoSegmentFrom tee: GeoCoordinate,
        to green: GeoCoordinate
    ) -> SegmentProjection {
        let teePoint = projectedPoint(for: tee, origin: tee)
        let greenPoint = projectedPoint(for: green, origin: tee)
        let fixPoint = projectedPoint(for: fix, origin: tee)

        let segment = (
            x: greenPoint.x - teePoint.x,
            y: greenPoint.y - teePoint.y
        )
        let lengthSquared = max(0.0001, (segment.x * segment.x) + (segment.y * segment.y))
        let relative = (
            x: fixPoint.x - teePoint.x,
            y: fixPoint.y - teePoint.y
        )
        let rawT = ((relative.x * segment.x) + (relative.y * segment.y)) / lengthSquared
        let clampedT = min(1, max(0, rawT))
        let closest = (
            x: teePoint.x + (segment.x * clampedT),
            y: teePoint.y + (segment.y * clampedT)
        )
        let corridorDistanceM = hypot(fixPoint.x - closest.x, fixPoint.y - closest.y)

        let overshootDistanceM: Double
        if rawT < 0 {
            overshootDistanceM = abs(rawT) * sqrt(lengthSquared)
        } else if rawT > 1 {
            overshootDistanceM = (rawT - 1) * sqrt(lengthSquared)
        } else {
            overshootDistanceM = 0
        }

        return SegmentProjection(
            corridorDistanceM: corridorDistanceM,
            overshootDistanceM: overshootDistanceM
        )
    }

    private static func projectedPoint(
        for coordinate: GeoCoordinate,
        origin: GeoCoordinate
    ) -> (x: Double, y: Double) {
        let latitudeRadians = origin.latitude * .pi / 180
        let metersPerDegreeLatitude = 111_132.0
        let metersPerDegreeLongitude = 111_320.0 * cos(latitudeRadians)

        return (
            x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
            y: (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
        )
    }
}

private struct HoleDetectionCandidate {
    let holeNumber: Int
    let score: Double
    let teeDistanceM: Double
    let greenDistanceM: Double
    let corridorDistanceM: Double
    let minimumRelevantDistanceM: Double
}

private struct SegmentProjection {
    let corridorDistanceM: Double
    let overshootDistanceM: Double
}
