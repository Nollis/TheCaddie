import Foundation

public struct ShotContext: Equatable, Sendable {
    public let shotNumber: Int
    public let remainingDistanceM: ShotDistance
    public let lie: ShotLieState
    public let wind: WindContext?
    public let progressM: Double?

    public init(
        shotNumber: Int,
        remainingDistanceM: ShotDistance,
        lie: ShotLieState,
        wind: WindContext?,
        progressM: Double? = nil
    ) {
        self.shotNumber = max(1, shotNumber)
        self.remainingDistanceM = remainingDistanceM
        self.lie = lie
        self.wind = wind
        self.progressM = progressM
    }

    public var isReadyForRecommendation: Bool {
        remainingDistanceM.value != nil && lie.value != nil
    }
}

public enum ShotDistance: Equatable, Sendable {
    case known(Double)
    case missing

    public var value: Double? {
        guard case let .known(value) = self else { return nil }
        return value
    }
}

public enum ShotLieState: Equatable, Sendable {
    case known(ShotLie)
    case missing

    public var value: ShotLie? {
        guard case let .known(value) = self else { return nil }
        return value
    }
}

public enum ShotLie: String, Equatable, Hashable, Sendable {
    case tee
    case fairway
    case rough
    case bunker
    case recovery
    case green
}

public enum NextShotLieResolver {
    public static func resolve(
        isLiveDistanceEnabled: Bool,
        hasFreshFix: Bool,
        fixMatchesSelectedHole: Bool,
        inferredLie: ShotLie?
    ) -> ShotLie? {
        guard isLiveDistanceEnabled,
              hasFreshFix,
              fixMatchesSelectedHole,
              let inferredLie,
              inferredLie != .tee else {
            return nil
        }

        return inferredLie
    }
}

public enum RecordedShotPositionGate {
    public static func allowsRecording(
        lastRecordedCoordinate: GeoCoordinate?,
        currentCoordinate: GeoCoordinate?,
        lastHorizontalAccuracyM: Double? = nil,
        currentHorizontalAccuracyM: Double? = nil,
        minimumMovementM: Double = 3
    ) -> Bool {
        guard let lastRecordedCoordinate else {
            return true
        }
        guard let currentCoordinate else {
            return false
        }

        let combinedAccuracyM = max(0, lastHorizontalAccuracyM ?? 0)
            + max(0, currentHorizontalAccuracyM ?? 0)
        let requiredMovementM = max(minimumMovementM, combinedAccuracyM)

        return lastRecordedCoordinate.distance(to: currentCoordinate) >= requiredMovementM
    }
}

public struct WindContext: Equatable, Sendable {
    public let direction: WindDirection
    public let speedMps: Double

    public init(direction: WindDirection, speedMps: Double) {
        self.direction = direction
        self.speedMps = speedMps
    }
}

public enum WindDirection: String, Equatable, Sendable {
    case helping
    case hurting
    case cross
}
