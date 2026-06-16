import Foundation

public struct CaddieRecommendationPacket: Equatable, Sendable {
    public let status: RecommendationStatus
    public let courseId: String?
    public let holeNumber: Int?
    public let par: Int?
    public let shotNumber: Int?
    public let remainingDistanceM: Double?
    public let lie: ShotLie?
    public let strategyPreference: StrategyPreference?
    public let shotIntent: ShotIntent?
    public let target: String?
    public let recommendedClub: String?
    public let clubCarryDistanceM: Double?
    public let distanceBasisM: Double?
    public let expectedDispersionM: Double?
    public let primaryReason: String
    public let riskNote: String?
    public let confidence: RecommendationConfidence
    public let debugInfo: RecommendationDebugInfo?

    public init(
        status: RecommendationStatus,
        courseId: String?,
        holeNumber: Int?,
        par: Int?,
        shotNumber: Int?,
        remainingDistanceM: Double?,
        lie: ShotLie?,
        strategyPreference: StrategyPreference?,
        shotIntent: ShotIntent?,
        target: String?,
        recommendedClub: String?,
        clubCarryDistanceM: Double?,
        distanceBasisM: Double?,
        expectedDispersionM: Double?,
        primaryReason: String,
        riskNote: String?,
        confidence: RecommendationConfidence,
        debugInfo: RecommendationDebugInfo? = nil
    ) {
        self.status = status
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.par = par
        self.shotNumber = shotNumber
        self.remainingDistanceM = remainingDistanceM
        self.lie = lie
        self.strategyPreference = strategyPreference
        self.shotIntent = shotIntent
        self.target = target
        self.recommendedClub = recommendedClub
        self.clubCarryDistanceM = clubCarryDistanceM
        self.distanceBasisM = distanceBasisM
        self.expectedDispersionM = expectedDispersionM
        self.primaryReason = primaryReason
        self.riskNote = riskNote
        self.confidence = confidence
        self.debugInfo = debugInfo
    }

    public var isReady: Bool {
        status == .ready
    }
}

public struct RecommendationDebugInfo: Equatable, Sendable {
    public let mode: RecommendationDebugMode
    public let summary: String
    public let clubEvaluations: [RecommendationClubEvaluation]

    public init(
        mode: RecommendationDebugMode,
        summary: String,
        clubEvaluations: [RecommendationClubEvaluation]
    ) {
        self.mode = mode
        self.summary = summary
        self.clubEvaluations = clubEvaluations
    }
}

public enum RecommendationDebugMode: String, Equatable, Sendable {
    case tee
    case approach
    case advancement
    case recovery
    case unavailable
}

public struct RecommendationClubEvaluation: Equatable, Sendable, Identifiable {
    public let clubName: String
    public let carryDistanceM: Double
    public let expectedDispersionM: Double?
    public let distanceGapM: Double?
    public let totalRisk: Double?
    public let widthRisk: Double?
    public let hazardRisk: Double?
    public let overshootRisk: Double?
    public let isSelected: Bool
    public let note: String

    public var id: String { clubName }

    public init(
        clubName: String,
        carryDistanceM: Double,
        expectedDispersionM: Double?,
        distanceGapM: Double?,
        totalRisk: Double?,
        widthRisk: Double?,
        hazardRisk: Double?,
        overshootRisk: Double?,
        isSelected: Bool,
        note: String
    ) {
        self.clubName = clubName
        self.carryDistanceM = carryDistanceM
        self.expectedDispersionM = expectedDispersionM
        self.distanceGapM = distanceGapM
        self.totalRisk = totalRisk
        self.widthRisk = widthRisk
        self.hazardRisk = hazardRisk
        self.overshootRisk = overshootRisk
        self.isSelected = isSelected
        self.note = note
    }
}

public enum RecommendationStatus: String, Equatable, Sendable {
    case ready
    case noCourseLoaded
    case unknownHole
    case missingDistance
    case missingLie
    case unavailable
}

public enum RecommendationConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
}

public enum ShotIntent: String, Equatable, Sendable {
    case teePosition
    case advance
    case layup
    case approach
    case recovery
}
