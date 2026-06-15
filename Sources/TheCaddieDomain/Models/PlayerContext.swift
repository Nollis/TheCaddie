import Foundation

public struct PlayerContext: Equatable, Sendable {
    public let handicapIndex: Double?
    public let clubs: [PlayerClub]
    public let strategyPreference: StrategyPreference
    public let skillProfile: PlayerSkillProfile

    public init(
        handicapIndex: Double?,
        clubs: [PlayerClub],
        strategyPreference: StrategyPreference,
        skillProfile: PlayerSkillProfile? = nil
    ) {
        self.handicapIndex = handicapIndex
        self.clubs = clubs.sorted { lhs, rhs in
            lhs.carryDistanceM > rhs.carryDistanceM
        }
        self.strategyPreference = strategyPreference
        self.skillProfile = skillProfile ?? PlayerSkillProfile.inferred(
            handicapIndex: handicapIndex
        )
    }
}

public struct PlayerClub: Equatable, Sendable, Identifiable {
    public let name: String
    public let carryDistanceM: Double
    public let typicalDispersionM: Double?
    public let playableLies: Set<ShotLie>

    public var id: String { name }

    public init(
        name: String,
        carryDistanceM: Double,
        typicalDispersionM: Double? = nil,
        playableLies: Set<ShotLie>? = nil
    ) {
        self.name = name
        self.carryDistanceM = carryDistanceM
        self.typicalDispersionM = typicalDispersionM
        self.playableLies = playableLies ?? Self.defaultPlayableLies(for: name)
    }

    public func isPlayable(from lie: ShotLie) -> Bool {
        playableLies.contains(lie)
    }

    private static func defaultPlayableLies(for clubName: String) -> Set<ShotLie> {
        let normalized = clubName.lowercased()
        if normalized.contains("driver") {
            return [.tee]
        }
        if normalized == "pw"
            || normalized.contains("wedge")
            || isLoftedWedgeName(normalized) {
            return [.tee, .fairway, .rough, .bunker, .recovery]
        }
        return [.tee, .fairway, .rough]
    }

    private static func isLoftedWedgeName(_ normalized: String) -> Bool {
        guard normalized.hasSuffix("w") else {
            return false
        }

        let loftText = normalized.dropLast()
        guard let loft = Double(loftText) else {
            return false
        }

        return loft >= 40
    }
}

public enum StrategyPreference: String, Equatable, Sendable {
    case safe
    case normal
    case aggressive
}

public struct PlayerSkillProfile: Equatable, Sendable {
    public let handicapIndex: Double?
    public let dispersionMultiplier: Double
    public let conservativeBiasM: Double

    public init(
        handicapIndex: Double?,
        dispersionMultiplier: Double,
        conservativeBiasM: Double
    ) {
        self.handicapIndex = handicapIndex
        self.dispersionMultiplier = dispersionMultiplier
        self.conservativeBiasM = conservativeBiasM
    }

    public static func inferred(handicapIndex: Double?) -> PlayerSkillProfile {
        guard let handicapIndex else {
            return PlayerSkillProfile(
                handicapIndex: nil,
                dispersionMultiplier: 1.2,
                conservativeBiasM: 6
            )
        }

        if handicapIndex >= 20 {
            return PlayerSkillProfile(
                handicapIndex: handicapIndex,
                dispersionMultiplier: 1.45,
                conservativeBiasM: 10
            )
        }

        if handicapIndex >= 10 {
            return PlayerSkillProfile(
                handicapIndex: handicapIndex,
                dispersionMultiplier: 1.2,
                conservativeBiasM: 6
            )
        }

        return PlayerSkillProfile(
            handicapIndex: handicapIndex,
            dispersionMultiplier: 1.0,
            conservativeBiasM: 3
        )
    }
}
