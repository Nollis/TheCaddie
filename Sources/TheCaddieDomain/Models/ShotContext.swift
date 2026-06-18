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
