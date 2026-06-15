import Foundation

public struct PlayerContext: Equatable, Sendable {
    public let handicapIndex: Double?
    public let clubs: [PlayerClub]
    public let strategyPreference: StrategyPreference

    public init(
        handicapIndex: Double?,
        clubs: [PlayerClub],
        strategyPreference: StrategyPreference
    ) {
        self.handicapIndex = handicapIndex
        self.clubs = clubs.sorted { lhs, rhs in
            lhs.carryDistanceM > rhs.carryDistanceM
        }
        self.strategyPreference = strategyPreference
    }
}

public struct PlayerClub: Equatable, Sendable, Identifiable {
    public let name: String
    public let carryDistanceM: Double

    public var id: String { name }

    public init(name: String, carryDistanceM: Double) {
        self.name = name
        self.carryDistanceM = carryDistanceM
    }
}

public enum StrategyPreference: String, Equatable, Sendable {
    case safe
    case normal
    case aggressive
}
