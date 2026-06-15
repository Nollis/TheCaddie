import Foundation

public enum CaddieResponseText {
    public static func spokenFallback(for packet: CaddieRecommendationPacket) -> String {
        switch packet.status {
        case .ready:
            guard let club = packet.recommendedClub,
                  let target = packet.target else {
                return packet.primaryReason
            }

            let riskSuffix = packet.riskNote.map { " \($0)" } ?? ""
            return "I'd take \(club) here. Aim \(target). \(packet.primaryReason)\(riskSuffix)"

        case .noCourseLoaded:
            return "Load a course first, then I can help with the shot."

        case .unknownHole:
            if let holeNumber = packet.holeNumber {
                return "I don't have hole \(holeNumber) loaded."
            }
            return "I don't have that hole loaded."

        case .missingDistance:
            return "I need the distance before I can choose a club."

        case .missingLie:
            return "Mark the lie first, then I can give you a better play."

        case .unavailable:
            return packet.primaryReason
        }
    }

    public static func displayHeadline(for packet: CaddieRecommendationPacket) -> String {
        guard packet.status == .ready,
              let club = packet.recommendedClub,
              let target = packet.target else {
            return fallbackHeadline(for: packet.status)
        }

        return "\(club) to \(target)"
    }

    private static func fallbackHeadline(for status: RecommendationStatus) -> String {
        switch status {
        case .ready:
            return "Recommendation ready"
        case .noCourseLoaded:
            return "Load a course"
        case .unknownHole:
            return "Hole unavailable"
        case .missingDistance:
            return "Distance needed"
        case .missingLie:
            return "Lie needed"
        case .unavailable:
            return "No recommendation"
        }
    }
}
