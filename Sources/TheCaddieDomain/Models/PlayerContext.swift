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
            if lhs.bagSortIndex != rhs.bagSortIndex {
                return lhs.bagSortIndex < rhs.bagSortIndex
            }
            return lhs.carryDistanceM > rhs.carryDistanceM
        }
        self.strategyPreference = strategyPreference
        self.skillProfile = skillProfile ?? PlayerSkillProfile.inferred(
            handicapIndex: handicapIndex
        )
    }
}

public struct PlayerProfileSnapshot: Codable, Equatable, Sendable {
    public let handicapIndex: Double?
    public let strategyPreferenceRawValue: String
    public let clubCarryDistancesM: [String: Double]

    public init(player: PlayerContext) {
        self.handicapIndex = player.handicapIndex
        self.strategyPreferenceRawValue = player.strategyPreference.rawValue
        self.clubCarryDistancesM = Dictionary(
            uniqueKeysWithValues: player.clubs.map { ($0.name, $0.carryDistanceM) }
        )
    }

    public func resolvePlayer(base: PlayerContext) -> PlayerContext {
        let strategyPreference = StrategyPreference(rawValue: strategyPreferenceRawValue)
            ?? base.strategyPreference
        let updatedClubs = base.clubs.map { club in
            PlayerClub(
                name: club.name,
                carryDistanceM: clubCarryDistancesM[club.name] ?? club.carryDistanceM,
                typicalDispersionM: club.typicalDispersionM,
                playableLies: club.playableLies
            )
        }

        return PlayerContext(
            handicapIndex: handicapIndex ?? base.handicapIndex,
            clubs: updatedClubs,
            strategyPreference: strategyPreference
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

    public var bagSortIndex: Int {
        Self.bagSortIndex(for: name)
    }

    private static func defaultPlayableLies(for clubName: String) -> Set<ShotLie> {
        let normalized = clubName.lowercased()
        if normalized.contains("driver") {
            return [.tee]
        }
        if isWedgeName(normalized) {
            return [.tee, .fairway, .rough, .bunker, .recovery]
        }

        if normalized.contains("wood")
            || normalized.contains("hybrid")
            || normalized.contains("iron") {
            return [.tee, .fairway, .rough, .bunker]
        }

        return [.tee, .fairway, .rough, .bunker]
    }

    private static func isWedgeName(_ normalized: String) -> Bool {
        if normalized == "pw"
            || normalized == "gw"
            || normalized == "aw"
            || normalized == "sw"
            || normalized == "lw"
            || normalized == "uw"
            || normalized.contains("wedge") {
            return true
        }

        return isLoftedWedgeName(normalized)
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

    private static func bagSortIndex(for clubName: String) -> Int {
        let normalized = clubName.lowercased()

        if normalized.contains("driver") {
            return 0
        }

        if let woodNumber = leadingNumber(in: normalized), normalized.contains("wood") {
            return 10 + woodNumber
        }

        if let hybridNumber = leadingNumber(in: normalized), normalized.contains("hybrid") {
            return 30 + hybridNumber
        }

        if let ironNumber = leadingNumber(in: normalized), normalized.contains("iron") {
            return 40 + ironNumber
        }

        if normalized == "pw" {
            return 90
        }
        if normalized == "gw" || normalized == "aw" || normalized == "uw" {
            return 91
        }
        if normalized == "sw" {
            return 92
        }
        if normalized == "lw" {
            return 93
        }
        if let loft = leadingNumber(in: normalized), normalized.hasSuffix("w") {
            return 100 + loft
        }
        if normalized.contains("wedge") {
            return 95
        }

        return 200
    }

    private static func leadingNumber(in normalized: String) -> Int? {
        let pattern = #"^\d+"#
        guard let match = normalized.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        return Int(normalized[match])
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
