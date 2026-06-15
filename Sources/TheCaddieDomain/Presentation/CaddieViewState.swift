import Foundation

public struct CaddieViewState: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case ready
        case noCourseLoaded
        case missingContext
        case unavailable
    }

    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let holeLabel: String
    public let shotLabel: String
    public let distanceLabel: String
    public let primaryActionLabel: String?
    public let quickUpdateLabels: [String]

    public init(
        kind: Kind,
        title: String,
        subtitle: String,
        holeLabel: String,
        shotLabel: String,
        distanceLabel: String,
        primaryActionLabel: String?,
        quickUpdateLabels: [String]
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.holeLabel = holeLabel
        self.shotLabel = shotLabel
        self.distanceLabel = distanceLabel
        self.primaryActionLabel = primaryActionLabel
        self.quickUpdateLabels = quickUpdateLabels
    }

    public static func make(from packet: CaddieRecommendationPacket) -> CaddieViewState {
        switch packet.status {
        case .ready:
            return CaddieViewState(
                kind: .ready,
                title: CaddieResponseText.displayHeadline(for: packet),
                subtitle: detailText(for: packet),
                holeLabel: holeLabel(for: packet),
                shotLabel: shotLabel(for: packet),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: nil,
                quickUpdateLabels: ["Fairway", "Rough", "Bunker", "Green"]
            )

        case .noCourseLoaded:
            return CaddieViewState(
                kind: .noCourseLoaded,
                title: "Choose a course",
                subtitle: "Load sample course context to see the first grounded recommendation.",
                holeLabel: "No course",
                shotLabel: "No shot",
                distanceLabel: "--",
                primaryActionLabel: "Load sample",
                quickUpdateLabels: []
            )

        case .missingDistance:
            return CaddieViewState(
                kind: .missingContext,
                title: "Distance needed",
                subtitle: packet.primaryReason,
                holeLabel: holeLabel(for: packet),
                shotLabel: shotLabel(for: packet),
                distanceLabel: "--",
                primaryActionLabel: "Add distance",
                quickUpdateLabels: ["Fairway", "Rough", "Bunker", "Green"]
            )

        case .missingLie:
            return CaddieViewState(
                kind: .missingContext,
                title: "Lie needed",
                subtitle: packet.primaryReason,
                holeLabel: holeLabel(for: packet),
                shotLabel: shotLabel(for: packet),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: "Mark lie",
                quickUpdateLabels: ["Fairway", "Rough", "Bunker", "Green"]
            )

        case .unknownHole, .unavailable:
            return CaddieViewState(
                kind: .unavailable,
                title: CaddieResponseText.displayHeadline(for: packet),
                subtitle: packet.primaryReason,
                holeLabel: holeLabel(for: packet),
                shotLabel: shotLabel(for: packet),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: nil,
                quickUpdateLabels: []
            )
        }
    }

    private static func detailText(for packet: CaddieRecommendationPacket) -> String {
        if let riskNote = packet.riskNote {
            return "\(packet.primaryReason) \(riskNote)"
        }

        return packet.primaryReason
    }

    private static func holeLabel(for packet: CaddieRecommendationPacket) -> String {
        guard let holeNumber = packet.holeNumber else {
            return "No hole"
        }

        if let par = packet.par {
            return "Hole \(holeNumber) · Par \(par)"
        }

        return "Hole \(holeNumber)"
    }

    private static func shotLabel(for packet: CaddieRecommendationPacket) -> String {
        guard let shotNumber = packet.shotNumber else {
            return "No shot"
        }

        return "Shot \(shotNumber)"
    }

    private static func distanceLabel(for packet: CaddieRecommendationPacket) -> String {
        guard let remainingDistanceM = packet.remainingDistanceM else {
            return "--"
        }

        return "\(formatMeters(remainingDistanceM)) m"
    }
}

private func formatMeters(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
}
