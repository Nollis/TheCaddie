import Foundation

public struct GeoCoordinate: Codable, Equatable, Sendable {
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
    public let centerlineCoordinates: [GeoCoordinate]
    public let green: GreenContext
    public let hazards: [Hazard]
    public let fairway: FairwayContext?
    public let surfaces: [HoleSurface]

    public var id: Int { number }

    public init(
        number: Int,
        par: Int,
        teeLengthM: Double,
        defaultTeeCoordinate: GeoCoordinate? = nil,
        centerlineCoordinates: [GeoCoordinate] = [],
        green: GreenContext,
        hazards: [Hazard],
        fairway: FairwayContext? = nil,
        surfaces: [HoleSurface] = []
    ) {
        self.number = number
        self.par = par
        self.teeLengthM = teeLengthM
        self.defaultTeeCoordinate = defaultTeeCoordinate
        self.centerlineCoordinates = centerlineCoordinates
        self.green = green
        self.hazards = hazards
        self.fairway = fairway
        self.surfaces = surfaces
    }
}

public struct HoleProgressSample: Equatable, Sendable {
    public let progressM: Double
    public let remainingCenterlineM: Double
    public let distanceFromCenterlineM: Double
    public let centerlineLengthM: Double

    public init(
        progressM: Double,
        remainingCenterlineM: Double,
        distanceFromCenterlineM: Double,
        centerlineLengthM: Double
    ) {
        self.progressM = progressM
        self.remainingCenterlineM = remainingCenterlineM
        self.distanceFromCenterlineM = distanceFromCenterlineM
        self.centerlineLengthM = centerlineLengthM
    }
}

public struct HoleSurface: Equatable, Sendable {
    public let kind: HoleSurfaceKind
    public let ring: [GeoCoordinate]

    public init(kind: HoleSurfaceKind, ring: [GeoCoordinate]) {
        self.kind = kind
        self.ring = ring
    }
}

public enum HoleSurfaceKind: String, Equatable, Hashable, Sendable {
    case tee
    case fairway
    case green
    case bunker
    case water
    case woods
    case rough
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
    public let coordinate: GeoCoordinate?
    public let progressM: Double?
    public let side: HazardSide?
    public let lateralOffsetM: Double?

    public init(
        id: String,
        kind: HazardKind,
        position: String,
        note: String,
        coordinate: GeoCoordinate? = nil,
        progressM: Double? = nil,
        side: HazardSide? = nil,
        lateralOffsetM: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.note = note
        self.coordinate = coordinate
        self.progressM = progressM
        self.side = side
        self.lateralOffsetM = lateralOffsetM
    }
}

public enum HazardSide: String, Equatable, Hashable, Sendable {
    case left
    case right
    case center
}

public enum HazardKind: String, Equatable, Sendable {
    case bunker
    case water
    case trees
    case outOfBounds
}

public enum HoleCaptureArea: String, Equatable, Sendable {
    case tee
    case green
    case corridor
}

public struct HoleCaptureDiagnostic: Equatable, Sendable {
    public let teeDistanceM: Double
    public let greenDistanceM: Double
    public let corridorDistanceM: Double
    public let matchedArea: HoleCaptureArea?

    public var matchesHole: Bool {
        matchedArea != nil
    }

    public var summary: String {
        if let matchedArea {
            let distanceM: Double
            switch matchedArea {
            case .tee:
                distanceM = teeDistanceM
            case .green:
                distanceM = greenDistanceM
            case .corridor:
                distanceM = corridorDistanceM
            }
            return "matched \(matchedArea.rawValue) at \(Int(distanceM.rounded()))m"
        }

        return "outside capture: tee \(Int(teeDistanceM.rounded()))m > 55m, green \(Int(greenDistanceM.rounded()))m > 45m, centerline \(Int(corridorDistanceM.rounded()))m > 40m"
    }
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

    public static func fixMatchesHole(
        fix: GeoCoordinate,
        hole: CourseHole
    ) -> Bool {
        captureDiagnostic(fix: fix, hole: hole)?.matchesHole == true
    }

    public static func captureDiagnostic(
        fix: GeoCoordinate,
        hole: CourseHole
    ) -> HoleCaptureDiagnostic? {
        guard let candidate = candidate(for: fix, hole: hole) else {
            return nil
        }

        let matchedArea: HoleCaptureArea?
        if candidate.teeDistanceM <= teeCaptureRadiusM {
            matchedArea = .tee
        } else if candidate.greenDistanceM <= greenCaptureRadiusM {
            matchedArea = .green
        } else if candidate.corridorDistanceM <= corridorCaptureRadiusM {
            matchedArea = .corridor
        } else {
            matchedArea = nil
        }

        return HoleCaptureDiagnostic(
            teeDistanceM: candidate.teeDistanceM,
            greenDistanceM: candidate.greenDistanceM,
            corridorDistanceM: candidate.corridorDistanceM,
            matchedArea: matchedArea
        )
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
        let corridorDistanceM = HoleProgressInference.sample(
            fix: fix,
            on: hole
        )?.distanceFromCenterlineM
            ?? GeoSegmentMath.project(
                fix,
                ontoSegmentFrom: tee,
                to: green
            ).corridorDistanceM
        let minimumRelevantDistanceM = min(teeDistanceM, greenDistanceM, corridorDistanceM)

        let score: Double
        if teeDistanceM <= teeCaptureRadiusM {
            score = teeDistanceM
        } else if greenDistanceM <= greenCaptureRadiusM {
            score = greenDistanceM
        } else {
            score = corridorDistanceM
        }

        return HoleDetectionCandidate(
            holeNumber: hole.number,
            score: score,
            teeDistanceM: teeDistanceM,
            greenDistanceM: greenDistanceM,
            corridorDistanceM: corridorDistanceM,
            minimumRelevantDistanceM: minimumRelevantDistanceM
        )
    }

}

public enum HoleLieInference {
    private static let teeCaptureRadiusM = 22.0
    private static let greenCaptureRadiusM = 18.0
    private static let bunkerCaptureRadiusM = 18.0
    private static let minimumFairwayCaptureRadiusM = 18.0

    public static func inferLie(
        fix: GeoCoordinate,
        on hole: CourseHole
    ) -> ShotLie? {
        let containingSurfaceKinds = Set(hole.surfaces.compactMap { surface in
            GeoPolygonMath.contains(fix, in: surface.ring) ? surface.kind : nil
        })
        if containingSurfaceKinds.contains(.tee) {
            return .tee
        }
        if containingSurfaceKinds.contains(.bunker) {
            return .bunker
        }
        if containingSurfaceKinds.contains(.water) || containingSurfaceKinds.contains(.woods) {
            return .recovery
        }
        if containingSurfaceKinds.contains(.green) {
            return .green
        }
        if containingSurfaceKinds.contains(.fairway) {
            return .fairway
        }
        if containingSurfaceKinds.contains(.rough) {
            return .rough
        }

        if let tee = hole.defaultTeeCoordinate,
           tee.distance(to: fix) <= teeCaptureRadiusM {
            return .tee
        }

        if let green = hole.green.centerCoordinate,
           green.distance(to: fix) <= greenCaptureRadiusM {
            return .green
        }

        let nearestBunkerDistance = hole.hazards
            .filter { $0.kind == .bunker }
            .compactMap(\.coordinate)
            .map { $0.distance(to: fix) }
            .min()
        if let nearestBunkerDistance,
           nearestBunkerDistance <= bunkerCaptureRadiusM {
            return .bunker
        }

        guard let tee = hole.defaultTeeCoordinate,
              let green = hole.green.centerCoordinate else {
            return nil
        }

        let fairwayCaptureRadiusM = max(
            minimumFairwayCaptureRadiusM,
            (hole.fairway?.landingWidthM ?? 36) / 2
        )
        let projection = GeoSegmentMath.project(fix, ontoSegmentFrom: tee, to: green)
        return projection.corridorDistanceM <= fairwayCaptureRadiusM ? .fairway : .rough
    }
}

public enum HoleProgressInference {
    public static func coordinate(
        atProgress progressM: Double,
        on hole: CourseHole
    ) -> GeoCoordinate? {
        let centerline = resolvedCenterline(for: hole)
        guard centerline.count >= 2 else {
            return centerline.first
        }

        let targetProgressM = max(0, progressM)
        var traversedM = 0.0

        for segmentIndex in 0..<(centerline.count - 1) {
            let start = centerline[segmentIndex]
            let end = centerline[segmentIndex + 1]
            let segmentLengthM = start.distance(to: end)
            let nextProgressM = traversedM + segmentLengthM

            if targetProgressM <= nextProgressM {
                guard segmentLengthM > 0 else {
                    return end
                }

                let fraction = min(1, max(0, (targetProgressM - traversedM) / segmentLengthM))
                return GeoCoordinate(
                    latitude: start.latitude + ((end.latitude - start.latitude) * fraction),
                    longitude: start.longitude + ((end.longitude - start.longitude) * fraction)
                )
            }

            traversedM = nextProgressM
        }

        return centerline.last
    }

    public static func landingCoordinate(
        fromProgressM progressM: Double,
        carryDistanceM: Double,
        on hole: CourseHole
    ) -> GeoCoordinate? {
        guard carryDistanceM > 0,
              let start = coordinate(atProgress: progressM, on: hole),
              let sample = sample(fix: start, on: hole) else {
            return coordinate(atProgress: progressM, on: hole)
        }

        if carryDistanceM >= sample.remainingCenterlineM,
           let green = hole.green.centerCoordinate {
            return green
        }

        return coordinate(atProgress: progressM + carryDistanceM, on: hole)
    }

    public static func sample(
        fix: GeoCoordinate,
        on hole: CourseHole
    ) -> HoleProgressSample? {
        let centerline = resolvedCenterline(for: hole)
        guard centerline.count >= 2 else {
            return nil
        }

        let origin = centerline[0]
        let projectedCenterline = centerline.map { GeoSegmentMath.projectedPoint(for: $0, origin: origin) }
        let projectedFix = GeoSegmentMath.projectedPoint(for: fix, origin: origin)

        var cumulativeDistanceM = 0.0
        var bestAlongM = 0.0
        var bestDistanceM = Double.infinity
        var totalLengthM = 0.0

        for segmentIndex in 0..<(projectedCenterline.count - 1) {
            let start = projectedCenterline[segmentIndex]
            let end = projectedCenterline[segmentIndex + 1]
            let segmentX = end.x - start.x
            let segmentY = end.y - start.y
            let segmentLengthSquared = max(0.0001, (segmentX * segmentX) + (segmentY * segmentY))
            let segmentLengthM = sqrt(segmentLengthSquared)
            totalLengthM += segmentLengthM

            let relativeX = projectedFix.x - start.x
            let relativeY = projectedFix.y - start.y
            let rawT = ((relativeX * segmentX) + (relativeY * segmentY)) / segmentLengthSquared
            let clampedT = min(1, max(0, rawT))
            let closestPoint = (
                x: start.x + (segmentX * clampedT),
                y: start.y + (segmentY * clampedT)
            )
            let distanceM = hypot(projectedFix.x - closestPoint.x, projectedFix.y - closestPoint.y)
            if distanceM < bestDistanceM {
                bestDistanceM = distanceM
                bestAlongM = cumulativeDistanceM + (segmentLengthM * clampedT)
            }

            cumulativeDistanceM += segmentLengthM
        }

        return HoleProgressSample(
            progressM: bestAlongM,
            remainingCenterlineM: max(0, totalLengthM - bestAlongM),
            distanceFromCenterlineM: bestDistanceM,
            centerlineLengthM: totalLengthM
        )
    }

    private static func resolvedCenterline(for hole: CourseHole) -> [GeoCoordinate] {
        if hole.centerlineCoordinates.count >= 2 {
            return hole.centerlineCoordinates
        }
        if let tee = hole.defaultTeeCoordinate,
           let green = hole.green.centerCoordinate {
            return [tee, green]
        }
        return hole.centerlineCoordinates
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

private enum GeoSegmentMath {
    static func project(
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

    static func projectedPoint(
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

private enum GeoPolygonMath {
    static func contains(
        _ coordinate: GeoCoordinate,
        in ring: [GeoCoordinate]
    ) -> Bool {
        guard ring.count >= 3 else {
            return false
        }

        let referenceLatitudeRadians = ring[0].latitude * .pi / 180
        let cosReference = cos(referenceLatitudeRadians)

        func project(_ coordinate: GeoCoordinate) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - ring[0].longitude) * cosReference,
                y: coordinate.latitude - ring[0].latitude
            )
        }

        let target = project(coordinate)
        let projectedRing = ring.map(project)

        var inside = false
        var previousIndex = projectedRing.count - 1

        for currentIndex in projectedRing.indices {
            let current = projectedRing[currentIndex]
            let previous = projectedRing[previousIndex]

            if current.x == target.x && current.y == target.y {
                return true
            }

            let intersects = ((current.y > target.y) != (previous.y > target.y))
                && (target.x < (previous.x - current.x) * (target.y - current.y) / (previous.y - current.y) + current.x)
            if intersects {
                inside.toggle()
            }

            previousIndex = currentIndex
        }

        return inside
    }
}
