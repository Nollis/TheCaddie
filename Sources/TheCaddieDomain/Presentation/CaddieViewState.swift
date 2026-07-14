import Foundation

public struct CaddieViewState: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case ready
        case noCourseLoaded
        case missingContext
        case unavailable
        case onGreen
        case holeComplete
        case roundComplete
    }

    public struct QuickAction: Equatable, Sendable {
        public enum Kind: Equatable, Hashable, Sendable {
            case fairway
            case rough
            case bunker
            case green
            case water
            case lostBall
            case outOfBounds
            case holed
        }

        public let kind: Kind
        public let label: String

        public init(kind: Kind, label: String) {
            self.kind = kind
            self.label = label
        }
    }

    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let noteText: String?
    public let holeLabel: String
    public let shotLabel: String
    public let distanceLabel: String
    public let primaryActionLabel: String?
    public let quickActions: [QuickAction]

    public init(
        kind: Kind,
        title: String,
        subtitle: String,
        noteText: String?,
        holeLabel: String,
        shotLabel: String,
        distanceLabel: String,
        primaryActionLabel: String?,
        quickActions: [QuickAction]
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.noteText = noteText
        self.holeLabel = holeLabel
        self.shotLabel = shotLabel
        self.distanceLabel = distanceLabel
        self.primaryActionLabel = primaryActionLabel
        self.quickActions = quickActions
    }

    public static func make(
        from packet: CaddieRecommendationPacket,
        roundState: RoundState? = nil,
        course: Course? = nil
    ) -> CaddieViewState {
        if let roundState, let course {
            if roundState.isRoundComplete(course: course) {
                return CaddieViewState(
                    kind: .roundComplete,
                    title: "Round complete",
                    subtitle: "All loaded holes are finished.",
                    noteText: nil,
                    holeLabel: "Round finished",
                    shotLabel: "Nice work",
                    distanceLabel: "--",
                    primaryActionLabel: nil,
                    quickActions: []
                )
            }

            if roundState.isHoleComplete(roundState.selectedHoleNumber) {
                return CaddieViewState(
                    kind: .holeComplete,
                    title: "Hole finished",
                    subtitle: "Move to the next tee when you're ready.",
                    noteText: nil,
                    holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                    shotLabel: "Hole complete",
                    distanceLabel: "--",
                    primaryActionLabel: nextOpenHoleExists(in: course, roundState: roundState)
                        ? "Next hole"
                        : nil,
                    quickActions: []
                )
            }

            if currentLie(for: packet, roundState: roundState) == .green {
                return CaddieViewState(
                    kind: .onGreen,
                    title: "Putt it out",
                    subtitle: "You're on the green. Finish the hole from here.",
                    noteText: nil,
                    holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                    shotLabel: shotLabel(for: packet, roundState: roundState),
                    distanceLabel: "On green",
                    primaryActionLabel: nil,
                    quickActions: [.init(kind: .holed, label: "Holed")]
                )
            }
        }

        switch packet.status {
        case .ready:
            return CaddieViewState(
                kind: .ready,
                title: CaddieResponseText.displayHeadline(for: packet),
                subtitle: packet.primaryReason,
                noteText: packet.riskNote,
                holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                shotLabel: shotLabel(for: packet, roundState: roundState),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: nil,
                quickActions: shotResultActions
            )

        case .noCourseLoaded:
            return CaddieViewState(
                kind: .noCourseLoaded,
                title: "Choose a course",
                subtitle: "Start a round from course setup before trusting on-course yardage.",
                noteText: nil,
                holeLabel: "No course",
                shotLabel: "No shot",
                distanceLabel: "--",
                primaryActionLabel: "Choose course",
                quickActions: []
            )

        case .missingDistance:
            return CaddieViewState(
                kind: .missingContext,
                title: "Distance needed",
                subtitle: packet.primaryReason,
                noteText: nil,
                holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                shotLabel: shotLabel(for: packet, roundState: roundState),
                distanceLabel: "--",
                primaryActionLabel: "Add distance",
                quickActions: shotResultActions
            )

        case .missingLie:
            return CaddieViewState(
                kind: .missingContext,
                title: "Lie needed",
                subtitle: packet.primaryReason,
                noteText: nil,
                holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                shotLabel: shotLabel(for: packet, roundState: roundState),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: "Mark lie",
                quickActions: shotResultActions
            )

        case .unknownHole, .unavailable:
            let quickActions = canStillRecordShotResult(from: packet)
                ? shotResultActions
                : []
            return CaddieViewState(
                kind: .unavailable,
                title: CaddieResponseText.displayHeadline(for: packet),
                subtitle: packet.primaryReason,
                noteText: packet.riskNote,
                holeLabel: holeLabel(for: packet, roundState: roundState, course: course),
                shotLabel: shotLabel(for: packet, roundState: roundState),
                distanceLabel: distanceLabel(for: packet),
                primaryActionLabel: nil,
                quickActions: quickActions
            )
        }
    }

    private static let shotResultActions: [QuickAction] = [
        .init(kind: .fairway, label: "Fairway"),
        .init(kind: .rough, label: "Rough"),
        .init(kind: .bunker, label: "Bunker"),
        .init(kind: .green, label: "Green"),
        .init(kind: .water, label: "Water"),
        .init(kind: .lostBall, label: "Lost ball"),
        .init(kind: .outOfBounds, label: "OB")
    ]

    private static func canStillRecordShotResult(
        from packet: CaddieRecommendationPacket
    ) -> Bool {
        guard packet.status == .unavailable,
              packet.lie != .green,
              let remainingDistanceM = packet.remainingDistanceM else {
            return false
        }

        return remainingDistanceM <= 2
    }

    private static func currentLie(
        for packet: CaddieRecommendationPacket,
        roundState: RoundState
    ) -> ShotLie? {
        packet.lie ?? roundState.currentShotContext()?.lie.value
    }

    private static func nextOpenHoleExists(
        in course: Course,
        roundState: RoundState
    ) -> Bool {
        course.holes.contains { hole in
            hole.number != roundState.selectedHoleNumber
                && !roundState.completedHoleNumbers.contains(hole.number)
        }
    }

    private static func holeLabel(
        for packet: CaddieRecommendationPacket,
        roundState: RoundState?,
        course: Course?
    ) -> String {
        let holeNumber = roundState?.selectedHoleNumber ?? packet.holeNumber
        let par = holeNumber.flatMap { course?.hole(number: $0)?.par } ?? packet.par

        guard let holeNumber else {
            return "No hole"
        }

        if let par {
            return "Hole \(holeNumber) · Par \(par)"
        }

        return "Hole \(holeNumber)"
    }

    private static func shotLabel(
        for packet: CaddieRecommendationPacket,
        roundState: RoundState?
    ) -> String {
        let shotNumber = packet.shotNumber ?? roundState?.currentShotContext()?.shotNumber
        guard let shotNumber else {
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
