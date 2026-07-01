import Combine
import CoreLocation
import Foundation

private enum LiveGPSTiming {
    static let freshFixWindowS = 15.0
    static let staleFixWindowS = 45.0
    static let shotOverrideWindowS = 90.0
}

@MainActor
final class CaddieViewModel: ObservableObject {
    @Published private(set) var course: Course?
    @Published private(set) var player: PlayerContext
    @Published private(set) var roundState: RoundState
    @Published var isHandsFreeListening: Bool = false
    @Published private(set) var isUsingLiveDistance = false
    @Published private(set) var liveDistanceM: Double?
    @Published private(set) var liveProgressM: Double?
    @Published private(set) var liveCenterlineOffsetM: Double?
    @Published private(set) var liveAccuracyM: Double?
    @Published private(set) var liveCoordinate: GeoCoordinate?
    @Published private(set) var liveFixTimestamp: Date?
    @Published private(set) var liveInferredLie: ShotLie?
    @Published private(set) var liveLocationStatus = "GPS off"
    @Published private(set) var liveLocationError: String?
    @Published private(set) var autoDetectedHoleNumber: Int?
    @Published private(set) var debugLogEntries: [DebugLogEntry] = []
    @Published private var liveStatusNow = Date()

    private let locationManager: LiveRoundLocationManager
    private let playerProfileStore: PlayerProfileStore
    private let debugLogStore: DebugLogStore
    private var cancellables = Set<AnyCancellable>()
    private var consecutiveHoleMisses = 0

    init(
        course: Course?,
        player: PlayerContext,
        roundState: RoundState,
        locationManager: LiveRoundLocationManager? = nil
    ) {
        self.course = course
        self.playerProfileStore = .shared
        self.debugLogStore = .shared
        let resolvedPlayer = self.playerProfileStore.loadPlayer(base: player) ?? player
        self.player = resolvedPlayer
        self.roundState = roundState
        self.locationManager = locationManager ?? LiveRoundLocationManager()
        self.debugLogEntries = debugLogStore.load()
        bindLocationManager()
        bindLiveStatusClock()
    }

    var packet: CaddieRecommendationPacket {
        CaddieRecommendationEngine.build(
            course: course,
            player: player,
            roundState: roundState
        )
    }

    var viewState: CaddieViewState {
        CaddieViewState.make(
            from: packet,
            roundState: roundState,
            course: course
        )
    }

    var selectedHoleNumber: Int {
        roundState.selectedHoleNumber
    }

    var availableHoleNumbers: [Int] {
        course?.holes.map(\.number) ?? []
    }

    var canSelectPreviousHole: Bool {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber) else {
            return false
        }

        return currentIndex > availableHoleNumbers.startIndex
    }

    var canSelectNextHole: Bool {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber) else {
            return false
        }

        return currentIndex < availableHoleNumbers.index(before: availableHoleNumbers.endIndex)
    }

    var canUseLiveDistance: Bool {
        course?.hole(number: selectedHoleNumber)?.green.centerCoordinate != nil
    }

    var liveDistanceLabel: String? {
        guard let liveDistanceM else {
            return nil
        }

        if liveDistanceM.rounded() == liveDistanceM {
            return "\(Int(liveDistanceM)) m"
        }

        return String(format: "%.1f m", liveDistanceM)
    }

    var liveFixAgeS: TimeInterval? {
        guard let liveFixTimestamp else {
            return nil
        }

        return max(0, liveStatusNow.timeIntervalSince(liveFixTimestamp))
    }

    var hasFreshLiveFix: Bool {
        guard let age = liveFixAgeS else {
            return false
        }

        return age <= LiveGPSTiming.freshFixWindowS
    }

    var usingProjectedDistance: Bool {
        !hasFreshLiveFix
    }

    var liveFixAgeLabel: String? {
        guard let age = liveFixAgeS else {
            return nil
        }

        return "\(Int(age.rounded()))s ago"
    }

    var packetDistanceLabel: String? {
        guard let remainingDistanceM = packet.remainingDistanceM else {
            return nil
        }

        if remainingDistanceM.rounded() == remainingDistanceM {
            return "\(Int(remainingDistanceM)) m"
        }

        return String(format: "%.1f m", remainingDistanceM)
    }

    var liveAccuracyLabel: String? {
        guard let liveAccuracyM else {
            return nil
        }

        return "Accuracy ±\(Int(liveAccuracyM.rounded()))m"
    }

    var liveProgressLabel: String? {
        guard let liveProgressM else {
            return nil
        }

        return "\(Int(liveProgressM.rounded())) m played"
    }

    var liveCenterlineOffsetLabel: String? {
        guard let liveCenterlineOffsetM else {
            return nil
        }

        return "\(Int(liveCenterlineOffsetM.rounded())) m off centerline"
    }

    var liveCoordinateLabel: String? {
        guard let liveCoordinate else {
            return nil
        }

        return String(
            format: "%.6f, %.6f",
            liveCoordinate.latitude,
            liveCoordinate.longitude
        )
    }

    var liveFixTimestampLabel: String? {
        guard let liveFixTimestamp else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: liveFixTimestamp)
    }

    var liveInferredLieLabel: String? {
        guard let liveInferredLie else {
            return nil
        }

        return liveInferredLie.rawValue.capitalized
    }

    var mappingHoleSummary: String? {
        guard let activeHole = course?.hole(number: selectedHoleNumber) else {
            return nil
        }

        return "Hole \(activeHole.number) • \(activeHole.centerlineCoordinates.count) centerline pts • \(activeHole.surfaces.count) surfaces • \(activeHole.hazards.count) hazards"
    }

    var liveHoleResolutionLabel: String {
        let selected = "Selected \(selectedHoleNumber)"
        guard let autoDetectedHoleNumber else {
            return selected
        }

        if autoDetectedHoleNumber == selectedHoleNumber {
            return "\(selected) • detected match"
        }

        return "\(selected) • detected \(autoDetectedHoleNumber)"
    }

    var holeSwitchMissesLabel: String {
        "\(consecutiveHoleMisses) misses toward switch"
    }

    var liveStatusBadgeLabel: String? {
        guard course != nil else {
            return nil
        }

        if let liveLocationError {
            return liveLocationError == "Location permission denied."
                ? "GPS denied"
                : "GPS issue"
        }

        if isUsingLiveDistance {
            guard let fixAgeS = liveFixAgeS else {
                return "GPS seeking"
            }

            if fixAgeS > LiveGPSTiming.staleFixWindowS {
                return "Projected"
            }

            return autoDetectedHoleNumber == selectedHoleNumber
                ? "GPS live"
                : "GPS H\(autoDetectedHoleNumber ?? selectedHoleNumber)"
        }

        if canUseLiveDistance {
            return "GPS ready"
        }

        return nil
    }

    var liveStatusBadgeTone: LiveStatusBadgeTone {
        if liveLocationError != nil {
            return .error
        }
        if hasFreshLiveFix {
            return .active
        }
        return .idle
    }

    var distanceSourceSummary: String? {
        guard course != nil else {
            return nil
        }

        if let liveLocationError {
            return "Projected distance. \(liveLocationError)"
        }

        if hasFreshLiveFix {
            let fixAge = liveFixAgeLabel ?? "now"
            let accuracy = liveAccuracyLabel ?? "Accuracy n/a"
            return "Live GPS to green center. \(accuracy). Fix \(fixAge)."
        }

        if isUsingLiveDistance {
            if let fixAge = liveFixAgeLabel {
                return "Projected distance. Last GPS fix was \(fixAge)."
            }

            return "Projected distance while waiting for the first GPS fix."
        }

        if canUseLiveDistance {
            return "Projected distance. GPS is ready but not active."
        }

        return "Projected distance. This hole is not mapped for live GPS."
    }

    var debugExportText: String {
        let packet = packet
        let activeHole = course?.hole(number: selectedHoleNumber)
        var lines: [String] = []

        lines.append("The Caddie Debug Export")
        lines.append("Exported At: \(debugExportTimestamp)")
        lines.append("Course: \(course?.name ?? "n/a")")
        lines.append("Hole: \(selectedHoleNumber)")
        lines.append("Detected Hole: \(autoDetectedHoleNumber.map(String.init) ?? "n/a")")
        lines.append("Shot: \(packet.shotNumber.map(String.init) ?? "n/a")")
        lines.append("Status: \(packet.status.rawValue)")
        lines.append("Intent: \(packet.shotIntent?.rawValue ?? "n/a")")
        lines.append("Recommended Club: \(packet.recommendedClub ?? "n/a")")
        lines.append("Target: \(packet.target ?? "n/a")")
        lines.append("Primary Reason: \(packet.primaryReason)")
        lines.append("Risk Note: \(packet.riskNote ?? "n/a")")
        lines.append("Confidence: \(packet.confidence.rawValue)")
        lines.append("Distance: \(packet.remainingDistanceM.map { formatDebugNumber($0) + "m" } ?? "n/a")")
        lines.append("Adjusted Basis: \(packet.distanceBasisM.map { formatDebugNumber($0) + "m" } ?? "n/a")")
        lines.append("Lie: \(packet.lie?.rawValue ?? "n/a")")
        lines.append("Inferred Live Lie: \(liveInferredLie?.rawValue ?? "n/a")")
        lines.append("Live Progress: \(liveProgressM.map { formatDebugNumber($0) + "m" } ?? "n/a")")
        lines.append("Centerline Offset: \(liveCenterlineOffsetM.map { formatDebugNumber($0) + "m" } ?? "n/a")")
        lines.append("Live GPS Enabled: \(isUsingLiveDistance ? "yes" : "no")")
        lines.append("Live GPS Status: \(liveLocationStatus)")
        lines.append("Live GPS Error: \(liveLocationError ?? "n/a")")
        lines.append("GPS Fix: \(liveCoordinateLabel ?? "n/a")")
        lines.append("GPS Accuracy: \(liveAccuracyM.map { "±" + formatDebugNumber($0) + "m" } ?? "n/a")")
        lines.append("Fix Time: \(liveFixTimestampLabel ?? "n/a")")
        lines.append("Hole Switch Misses: \(consecutiveHoleMisses)")

        if let activeHole {
            lines.append("Mapped Assets: \(activeHole.centerlineCoordinates.count) centerline pts, \(activeHole.surfaces.count) surfaces, \(activeHole.hazards.count) hazards")
        }

        lines.append("Completed Holes: \(roundState.completedHoleNumbers.count)")
        if let scoreSummary = debugScoreSummary {
            lines.append("Score Summary: \(scoreSummary)")
        }

        if let debugInfo = packet.debugInfo {
            lines.append("")
            lines.append("Decision Summary")
            lines.append("Mode: \(debugInfo.mode.rawValue)")
            lines.append("Summary: \(debugInfo.summary)")

            if !debugInfo.clubEvaluations.isEmpty {
                lines.append("")
                lines.append("Club Evaluations")
                for evaluation in debugInfo.clubEvaluations {
                    var parts = [
                        evaluation.clubName,
                        "carry \(formatDebugNumber(evaluation.carryDistanceM))m"
                    ]
                    if let spread = evaluation.expectedDispersionM {
                        parts.append("dispersion ±\(formatDebugNumber(spread))m")
                    }
                    if let gap = evaluation.distanceGapM {
                        parts.append("gap \(formatSignedDebugNumber(gap))m")
                    }
                    if let totalRisk = evaluation.totalRisk {
                        parts.append("risk \(String(format: "%.2f", totalRisk))")
                    }
                    if evaluation.isSelected {
                        parts.append("SELECTED")
                    }
                    parts.append("- \(evaluation.note)")
                    lines.append(parts.joined(separator: " | "))
                }
            }

            if !debugInfo.hazardEvaluations.isEmpty {
                lines.append("")
                lines.append("Hazard Evaluations")
                for evaluation in debugInfo.hazardEvaluations {
                    var parts = [
                        evaluation.label,
                        evaluation.isRelevant ? "RELEVANT" : "IGNORED",
                        evaluation.kind.rawValue,
                        evaluation.sideLabel
                    ]
                    if let progressM = evaluation.progressM {
                        parts.append("progress \(formatDebugNumber(progressM))m")
                    }
                    if let lateralOffsetM = evaluation.lateralOffsetM {
                        parts.append("lateral \(formatDebugNumber(lateralOffsetM))m")
                    }
                    parts.append("- \(evaluation.note)")
                    lines.append(parts.joined(separator: " | "))
                }
            }
        }

        lines.append("")
        lines.append("Field Notes")
        lines.append("Observed Outcome: ")
        lines.append("Expected Outcome: ")
        lines.append("Suspected Issue: ")

        if !debugHoleSessionLines.isEmpty {
            lines.append("")
            lines.append("Hole Sessions")
            lines.append(contentsOf: debugHoleSessionLines)
        }

        if !debugGPSTraceLines.isEmpty {
            lines.append("")
            lines.append("GPS Trace")
            lines.append(contentsOf: debugGPSTraceLines)
        }

        if !debugActivityHistoryLines.isEmpty {
            lines.append("")
            lines.append("Recent Activity")
            lines.append(contentsOf: debugActivityHistoryLines)
        }

        return lines.joined(separator: "\n")
    }

    var debugActivityHistoryLines: [String] {
        Array(debugLogEntries.suffix(20)).map(\.activityLine)
    }

    var debugHoleSessionLines: [String] {
        let groupedEntries = Dictionary(grouping: debugLogEntries, by: \.holeNumber)
        let sortedHoleNumbers = groupedEntries.keys.sorted()
        var lines: [String] = []

        for holeNumber in sortedHoleNumbers {
            guard let entries = groupedEntries[holeNumber] else {
                continue
            }

            lines.append("Hole \(holeNumber)")
            lines.append(contentsOf: entries.map { "  \($0.activityLine)" })
        }

        return lines
    }

    var debugGPSTraceLines: [String] {
        let gpsEntries = debugLogEntries.filter { $0.eventType == .gpsUpdate }
        let groupedEntries = Dictionary(grouping: gpsEntries, by: \.holeNumber)
        let sortedHoleNumbers = groupedEntries.keys.sorted()
        var lines: [String] = []

        for holeNumber in sortedHoleNumbers {
            guard let entries = groupedEntries[holeNumber] else {
                continue
            }

            lines.append("Hole \(holeNumber)")
            lines.append(contentsOf: entries.suffix(12).map { "  \($0.gpsTraceLine)" })
        }

        return lines
    }

    func markLie(_ lie: ShotLie) {
        let currentShot = resolvedShotContext()
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: currentShot.remainingDistanceM,
            lie: .known(lie),
            wind: currentShot.wind,
            progressM: currentShot.progressM
        )
        roundState = roundState.updateShotContext(updatedShot)
    }

    func recordShotResult(_ lie: ShotLie) {
        roundState = roundState.recordShotResult(
            course: course,
            player: player,
            resultingLie: lie
        )

        if let liveOverrideShot = liveShotOverride(after: lie) {
            roundState = roundState.updateShotContext(liveOverrideShot)
        }
    }

    func recordPenaltyDrop() {
        roundState = roundState.recordPenaltyDrop(
            course: course,
            player: player
        )

        if let liveOverrideShot = liveShotOverride(after: .recovery) {
            roundState = roundState.updateShotContext(liveOverrideShot)
        }
    }

    func recordQuickAction(_ action: CaddieViewState.QuickAction.Kind) {
        switch action {
        case .fairway:
            recordShotResult(.fairway)
        case .rough:
            recordShotResult(.rough)
        case .bunker:
            recordShotResult(.bunker)
        case .green:
            recordShotResult(.green)
        case .water:
            recordPenaltyDrop()
        case .holed:
            finishCurrentHole()
        }
    }

    func selectHole(_ holeNumber: Int) {
        guard availableHoleNumbers.contains(holeNumber) else {
            return
        }

        roundState = roundState.selectHole(holeNumber)
        autoDetectedHoleNumber = holeNumber
        consecutiveHoleMisses = 0
        syncLiveDistanceIfNeeded()
    }

    func selectPreviousHole() {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber),
              currentIndex > availableHoleNumbers.startIndex else {
            return
        }

        let previousIndex = availableHoleNumbers.index(before: currentIndex)
        selectHole(availableHoleNumbers[previousIndex])
    }

    func selectNextHole() {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber),
              currentIndex < availableHoleNumbers.index(before: availableHoleNumbers.endIndex) else {
            return
        }

        let nextIndex = availableHoleNumbers.index(after: currentIndex)
        selectHole(availableHoleNumbers[nextIndex])
    }

    func addDistance(_ distanceM: Double) {
        let currentShot = resolvedShotContext()
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: .known(distanceM),
            lie: currentShot.lie,
            wind: currentShot.wind,
            progressM: currentShot.progressM
        )
        roundState = roundState.updateShotContext(updatedShot)
    }

    func startLiveDistance() {
        liveLocationError = nil
        isUsingLiveDistance = true
        liveLocationStatus = canUseLiveDistance
            ? "Requesting GPS..."
            : "This course is not mapped for live GPS yet."
        locationManager.activate()
        syncLiveDistanceIfNeeded()
    }

    func stopLiveDistance() {
        isUsingLiveDistance = false
        locationManager.deactivate()
        liveLocationStatus = "GPS paused"
        autoDetectedHoleNumber = selectedHoleNumber
        consecutiveHoleMisses = 0
    }

    func refreshLiveDistance() {
        liveLocationError = nil
        guard canUseLiveDistance else {
            liveLocationStatus = "This course is not mapped for live GPS yet."
            return
        }

        if !isUsingLiveDistance {
            isUsingLiveDistance = true
        }
        liveLocationStatus = "Refreshing GPS..."
        locationManager.requestSingleFix()
    }

    func finishCurrentHole() {
        roundState = roundState.finishCurrentHole(course: course)
        syncLiveDistanceIfNeeded()
    }

    func finishHoleFromGreen(putts: Int) {
        guard let course,
              let hole = course.hole(number: selectedHoleNumber) else {
            return
        }
        let shotNumber = roundState.currentShotContext()?.shotNumber ?? 1
        let finalStrokes = shotNumber + putts - 1
        let finalFairwayHit = hole.par > 3 ? true : nil
        let finalGIR = (finalStrokes - putts) <= (hole.par - 2)
        
        roundState = roundState.finishCurrentHole(
            course: course,
            strokes: finalStrokes,
            putts: putts,
            fairwayHit: finalFairwayHit,
            greenInRegulation: finalGIR
        )
        syncLiveDistanceIfNeeded()
    }

    func selectNextOpenHole() {
        guard let course else {
            return
        }

        if let nextHole = course.holes.first(where: { hole in
            hole.number > selectedHoleNumber
                && !roundState.completedHoleNumbers.contains(hole.number)
        }) {
            selectHole(nextHole.number)
            return
        }

        if let firstOpenHole = course.holes.first(where: { hole in
            !roundState.completedHoleNumbers.contains(hole.number)
        }) {
            selectHole(firstOpenHole.number)
        }
    }

    func startRound(course: Course, startingHole: Int = 1) {
        self.course = course
        self.roundState = RoundState(
            courseId: course.id,
            selectedHoleNumber: startingHole,
            shotContexts: [
                startingHole: ShotContext(
                    shotNumber: 1,
                    remainingDistanceM: .known(course.hole(number: startingHole)?.teeLengthM ?? 300),
                    lie: .known(.tee),
                    wind: nil,
                    progressM: nil
                )
            ]
        )
        autoDetectedHoleNumber = startingHole
        consecutiveHoleMisses = 0
        clearDebugLog()
        enableLiveDistanceIfSupported()
    }
    
    func endRound() {
        self.course = nil
        self.roundState = SampleRound.roundState
        stopLiveDistance()
        liveDistanceM = nil
        liveProgressM = nil
        liveCenterlineOffsetM = nil
        liveAccuracyM = nil
        liveCoordinate = nil
        liveFixTimestamp = nil
        liveInferredLie = nil
        liveLocationError = nil
        liveLocationStatus = "GPS off"
        autoDetectedHoleNumber = nil
        consecutiveHoleMisses = 0
    }

    func updatePlayerHandicap(_ handicap: Double) {
        persistPlayer(PlayerContext(
            handicapIndex: handicap,
            clubs: player.clubs,
            strategyPreference: player.strategyPreference
        ))
    }
    
    func updateStrategyPreference(_ strategy: StrategyPreference) {
        persistPlayer(PlayerContext(
            handicapIndex: player.handicapIndex,
            clubs: player.clubs,
            strategyPreference: strategy
        ))
    }

    func updateClubDistance(clubName: String, distanceM: Double) {
        var updatedClubs = player.clubs
        if let index = updatedClubs.firstIndex(where: { $0.name == clubName }) {
            let original = updatedClubs[index]
            updatedClubs[index] = PlayerClub(
                name: original.name,
                carryDistanceM: distanceM,
                typicalDispersionM: original.typicalDispersionM,
                playableLies: original.playableLies
            )
            persistPlayer(PlayerContext(
                handicapIndex: player.handicapIndex,
                clubs: updatedClubs,
                strategyPreference: player.strategyPreference
            ))
        }
    }

    func addClub(named clubName: String) {
        guard !player.clubs.contains(where: { $0.name == clubName }) else {
            return
        }

        let newClub = StandardBagCatalog.club(named: clubName)?.playerClub
            ?? PlayerClub(name: clubName, carryDistanceM: 100)
        persistPlayer(PlayerContext(
            handicapIndex: player.handicapIndex,
            clubs: player.clubs + [newClub],
            strategyPreference: player.strategyPreference
        ))
    }

    func removeClub(named clubName: String) {
        let updatedClubs = player.clubs.filter { $0.name != clubName }
        guard updatedClubs.count != player.clubs.count else {
            return
        }

        persistPlayer(PlayerContext(
            handicapIndex: player.handicapIndex,
            clubs: updatedClubs,
            strategyPreference: player.strategyPreference
        ))
    }

    func updateHoleScore(holeNumber: Int, strokes: Int, putts: Int, fairwayHit: Bool?, gir: Bool) {
        var updatedScores = roundState.holeScores
        updatedScores[holeNumber] = HoleScore(
            holeNumber: holeNumber,
            strokes: strokes,
            putts: putts,
            fairwayHit: fairwayHit,
            greenInRegulation: gir
        )
        self.roundState = RoundState(
            courseId: roundState.courseId,
            selectedHoleNumber: roundState.selectedHoleNumber,
            shotContexts: roundState.shotContexts,
            completedHoleNumbers: roundState.completedHoleNumbers.union([holeNumber]),
            holeScores: updatedScores
        )
        syncLiveDistanceIfNeeded()
    }

    func logDebugEvent(_ action: String) {
        appendDebugEntry(action: action, eventType: .userAction)
    }

    private func resolvedShotContext() -> ShotContext {
        if let shot = roundState.currentShotContext() {
            return shot
        }

        if let course,
           let hole = course.hole(number: selectedHoleNumber) {
            return ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(hole.teeLengthM),
                lie: .known(.tee),
                wind: nil,
                progressM: nil
            )
        }

        return SampleRound.readyShot
    }

    private func persistPlayer(_ player: PlayerContext) {
        self.player = player
        playerProfileStore.save(player)
    }

    private func bindLocationManager() {
        locationManager.$authorizationStatus
            .sink { [weak self] status in
                self?.handleAuthorization(status)
            }
            .store(in: &cancellables)

        locationManager.$latestFix
            .compactMap { $0 }
            .sink { [weak self] fix in
                self?.applyLiveDistance(from: fix)
            }
            .store(in: &cancellables)

        locationManager.$lastError
            .sink { [weak self] error in
                self?.liveLocationError = error
            }
            .store(in: &cancellables)
    }

    private func bindLiveStatusClock() {
        Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.liveStatusNow = now
            }
            .store(in: &cancellables)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if isUsingLiveDistance {
                liveLocationStatus = "GPS active"
                locationManager.requestSingleFix()
            }
        case .notDetermined:
            if isUsingLiveDistance {
                liveLocationStatus = "Waiting for location permission..."
            }
        case .denied, .restricted:
            liveLocationStatus = "Location permission denied"
            liveLocationError = "Enable location access in Settings to use live yardage."
            isUsingLiveDistance = false
        @unknown default:
            liveLocationStatus = "Location status unavailable"
        }
    }

    private func syncLiveDistanceIfNeeded() {
        guard isUsingLiveDistance else {
            return
        }

        let now = Date()
        if let fix = locationManager.latestFix,
           fix.isFresh(asOf: now) {
            applyLiveDistance(from: fix)
        } else {
            liveLocationStatus = "Waiting for fresh GPS..."
            locationManager.requestSingleFix()
        }
    }

    private func enableLiveDistanceIfSupported() {
        guard canUseLiveDistance else {
            isUsingLiveDistance = false
            liveLocationStatus = "This course is not mapped for live GPS yet."
            return
        }

        startLiveDistance()
    }

    private var debugExportTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    private var debugScoreSummary: String? {
        guard let course else {
            return nil
        }

        let scoredHoles = course.holes.filter { roundState.holeScores[$0.number] != nil }
        guard !scoredHoles.isEmpty else {
            return nil
        }

        let totalStrokes = scoredHoles.compactMap { roundState.holeScores[$0.number]?.strokes }.reduce(0, +)
        let totalPar = scoredHoles.map(\.par).reduce(0, +)
        let diff = totalStrokes - totalPar
        let diffText = diff == 0 ? "E" : (diff > 0 ? "+\(diff)" : "\(diff)")
        return "\(totalStrokes) (\(diffText)) through \(scoredHoles.count)"
    }

    private func appendDebugEntry(
        action: String,
        eventType: DebugLogEventType,
        coordinate: GeoCoordinate? = nil,
        accuracyM: Double? = nil,
        timestamp: Date = Date()
    ) {
        let packet = packet
        let entry = DebugLogEntry(
            timestamp: timestamp,
            eventType: eventType,
            holeNumber: selectedHoleNumber,
            detectedHoleNumber: autoDetectedHoleNumber,
            shotNumber: packet.shotNumber ?? roundState.currentShotContext()?.shotNumber,
            action: action,
            packetDistanceM: packet.remainingDistanceM,
            adjustedBasisM: packet.distanceBasisM,
            liveDistanceM: liveDistanceM,
            progressM: liveProgressM,
            centerlineOffsetM: liveCenterlineOffsetM,
            lie: packet.lie?.rawValue,
            inferredLiveLie: liveInferredLie?.rawValue,
            recommendedClub: packet.recommendedClub,
            target: packet.target,
            primaryReason: packet.primaryReason,
            riskNote: packet.riskNote,
            status: packet.status.rawValue,
            confidence: packet.confidence.rawValue,
            coordinate: coordinate ?? liveCoordinate,
            accuracyM: accuracyM ?? liveAccuracyM
        )
        debugLogEntries.append(entry)
        if debugLogEntries.count > 400 {
            debugLogEntries.removeFirst(debugLogEntries.count - 400)
        }
        debugLogStore.save(debugLogEntries)
    }

    private func clearDebugLog() {
        debugLogEntries = []
        debugLogStore.save(debugLogEntries)
    }

    private func liveShotOverride(after resultingLie: ShotLie) -> ShotContext? {
        guard isUsingLiveDistance,
              let currentShot = roundState.currentShotContext(),
              let liveFixTimestamp,
              Date().timeIntervalSince(liveFixTimestamp) <= LiveGPSTiming.shotOverrideWindowS else {
            return nil
        }

        let distanceM: Double
        let progressM: Double?
        if resultingLie == .green {
            distanceM = 0
            progressM = course?.hole(number: selectedHoleNumber)?.teeLengthM
        } else if let liveDistanceM {
            distanceM = liveDistanceM
            progressM = liveProgressM
        } else {
            return nil
        }

        return ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: .known(distanceM),
            lie: .known(resultingLie),
            wind: currentShot.wind,
            progressM: progressM
        )
    }

    private func applyLiveDistance(from fix: LiveRoundLocationManager.LocationFix) {
        liveAccuracyM = fix.horizontalAccuracyM
        liveCoordinate = fix.coordinate
        liveFixTimestamp = fix.timestamp

        guard isUsingLiveDistance else {
            return
        }

        guard course?.hole(number: selectedHoleNumber) != nil else {
            liveLocationStatus = "No active hole selected"
            return
        }

        updateDetectedHole(from: fix.coordinate)

        guard let activeHole = course?.hole(number: selectedHoleNumber) else {
            liveLocationStatus = "No active hole selected"
            return
        }

        guard let distanceM = activeHole.green.distanceToCenter(from: fix.coordinate) else {
            liveLocationStatus = "This hole is not mapped for live GPS yet."
            return
        }

        liveDistanceM = distanceM
        let progressSample = HoleProgressInference.sample(
            fix: fix.coordinate,
            on: activeHole
        )
        liveProgressM = progressSample?.progressM
        liveCenterlineOffsetM = progressSample?.distanceFromCenterlineM
        let currentShot = resolvedShotContext()
        let inferredLie = HoleLieInference.inferLie(
            fix: fix.coordinate,
            on: activeHole
        )
        liveInferredLie = inferredLie
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: .known(distanceM),
            lie: currentShot.lie,
            wind: currentShot.wind,
            progressM: progressSample?.progressM
        )
        roundState = roundState.updateShotContext(updatedShot)

        let lieStatus = updatedShot.lie.value.map { " • \($0.rawValue.capitalized)" } ?? ""
        let inferredStatus = inferredLie.map { " • GPS \($0.rawValue.capitalized)" } ?? ""
        let progressStatus = progressSample.map { " • \(Int($0.progressM.rounded()))m played" } ?? ""
        liveLocationStatus = autoDetectedHoleNumber == selectedHoleNumber
            ? "Live distance synced\(lieStatus)\(inferredStatus)\(progressStatus)"
            : "Live distance synced on Hole \(selectedHoleNumber)\(lieStatus)\(inferredStatus)\(progressStatus)"

        appendDebugEntry(
            action: "GPS update synced",
            eventType: .gpsUpdate,
            coordinate: fix.coordinate,
            accuracyM: fix.horizontalAccuracyM,
            timestamp: fix.timestamp
        )
    }

    private func updateDetectedHole(from coordinate: GeoCoordinate) {
        guard let course else {
            autoDetectedHoleNumber = nil
            consecutiveHoleMisses = 0
            return
        }

        if let currentHole = course.hole(number: selectedHoleNumber),
           HoleDetector.fixIsBeyondSwitchRadius(fix: coordinate, hole: currentHole) {
            consecutiveHoleMisses += 1
        } else {
            consecutiveHoleMisses = 0
        }

        let detectedHole = HoleDetector.activeHole(
            fix: coordinate,
            course: course,
            current: selectedHoleNumber,
            consecutiveMisses: consecutiveHoleMisses
        )
        autoDetectedHoleNumber = detectedHole ?? selectedHoleNumber

        guard let detectedHole,
              detectedHole != selectedHoleNumber else {
            return
        }

        roundState = roundState.selectHole(detectedHole)
        consecutiveHoleMisses = 0
    }

    func injectLocationFixForTesting(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyM: Double = 5
    ) {
        let fix = LiveRoundLocationManager.LocationFix(
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            horizontalAccuracyM: horizontalAccuracyM,
            timestamp: Date()
        )
        applyLiveDistance(from: fix)
    }
}

private func formatDebugNumber(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
}

private func formatSignedDebugNumber(_ value: Double) -> String {
    let formatted = formatDebugNumber(abs(value))
    return value >= 0 ? "+\(formatted)" : "-\(formatted)"
}

final class LiveRoundLocationManager: NSObject, CLLocationManagerDelegate {
    struct LocationFix: Equatable, Sendable {
        let coordinate: GeoCoordinate
        let horizontalAccuracyM: Double
        let timestamp: Date

        func age(asOf now: Date = Date()) -> TimeInterval {
            max(0, now.timeIntervalSince(timestamp))
        }

        func isFresh(
            asOf now: Date = Date(),
            maxAgeS: TimeInterval = LiveGPSTiming.staleFixWindowS
        ) -> Bool {
            age(asOf: now) <= maxAgeS
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestFix: LocationFix?
    @Published private(set) var lastError: String?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func activate() {
        lastError = nil
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "Location permission denied."
        @unknown default:
            lastError = "Location permission status unavailable."
        }
    }

    func deactivate() {
        manager.stopUpdatingLocation()
    }

    func requestSingleFix() {
        activate()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        let fix = LocationFix(
            coordinate: GeoCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            horizontalAccuracyM: location.horizontalAccuracy,
            timestamp: location.timestamp
        )

        guard fix.isFresh() else {
            if let latestFix, !latestFix.isFresh() {
                self.latestFix = nil
            }
            lastError = nil
            return
        }

        latestFix = fix
        lastError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}

extension CaddieViewModel {
    static func sample() -> CaddieViewModel {
        CaddieViewModel(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            roundState: KungsbackaNyaCourse.openingRoundState
        )
    }

    static func noCourseLoaded() -> CaddieViewModel {
        CaddieViewModel(
            course: nil,
            player: SampleRound.player,
            roundState: SampleRound.roundState
        )
    }

    static func missingDistance() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.missingDistanceRoundState
        )
    }

    static func missingLie() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.missingLieRoundState
        )
    }

    static func onGreen() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.roundState.updateShotContext(
                ShotContext(
                    shotNumber: 3,
                    remainingDistanceM: .known(0),
                    lie: .known(.green),
                    wind: nil
                )
            )
        )
    }

    static func holeComplete() -> CaddieViewModel {
        CaddieViewModel(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            roundState: RoundState(
                courseId: KungsbackaNyaCourse.course.id,
                selectedHoleNumber: 8,
                shotContexts: [
                    8: ShotContext(
                        shotNumber: 3,
                        remainingDistanceM: .known(0),
                        lie: .known(.green),
                        wind: nil
                    )
                ],
                completedHoleNumbers: [8]
            )
        )
    }

    static func roundComplete() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: RoundState(
                courseId: SampleRound.course.id,
                selectedHoleNumber: 2,
                shotContexts: [
                    2: ShotContext(
                        shotNumber: 3,
                        remainingDistanceM: .known(0),
                        lie: .known(.green),
                        wind: nil
                    )
                ],
                completedHoleNumbers: [1, 2]
            )
        )
    }
}

enum LiveStatusBadgeTone {
    case active
    case idle
    case error
}

struct DebugLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let eventType: DebugLogEventType
    let holeNumber: Int
    let detectedHoleNumber: Int?
    let shotNumber: Int?
    let action: String
    let packetDistanceM: Double?
    let adjustedBasisM: Double?
    let liveDistanceM: Double?
    let progressM: Double?
    let centerlineOffsetM: Double?
    let lie: String?
    let inferredLiveLie: String?
    let recommendedClub: String?
    let target: String?
    let primaryReason: String
    let riskNote: String?
    let status: String
    let confidence: String
    let coordinate: GeoCoordinate?
    let accuracyM: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: DebugLogEventType,
        holeNumber: Int,
        detectedHoleNumber: Int?,
        shotNumber: Int?,
        action: String,
        packetDistanceM: Double?,
        adjustedBasisM: Double?,
        liveDistanceM: Double?,
        progressM: Double?,
        centerlineOffsetM: Double?,
        lie: String?,
        inferredLiveLie: String?,
        recommendedClub: String?,
        target: String?,
        primaryReason: String,
        riskNote: String?,
        status: String,
        confidence: String,
        coordinate: GeoCoordinate?,
        accuracyM: Double?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.holeNumber = holeNumber
        self.detectedHoleNumber = detectedHoleNumber
        self.shotNumber = shotNumber
        self.action = action
        self.packetDistanceM = packetDistanceM
        self.adjustedBasisM = adjustedBasisM
        self.liveDistanceM = liveDistanceM
        self.progressM = progressM
        self.centerlineOffsetM = centerlineOffsetM
        self.lie = lie
        self.inferredLiveLie = inferredLiveLie
        self.recommendedClub = recommendedClub
        self.target = target
        self.primaryReason = primaryReason
        self.riskNote = riskNote
        self.status = status
        self.confidence = confidence
        self.coordinate = coordinate
        self.accuracyM = accuracyM
    }

    var activityLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)

        var parts: [String] = ["[\(timeString)]"]
        parts.append(eventType.rawValue)
        parts.append("H\(holeNumber)")
        if let detectedHoleNumber {
            parts.append("D\(detectedHoleNumber)")
        }
        if let shotNumber {
            parts.append("S\(shotNumber)")
        }
        parts.append(action)

        var context: [String] = []
        if let packetDistanceM {
            context.append("packet \(formatDebugNumber(packetDistanceM))m")
        }
        if let adjustedBasisM {
            context.append("basis \(formatDebugNumber(adjustedBasisM))m")
        }
        if let liveDistanceM {
            context.append("live \(formatDebugNumber(liveDistanceM))m")
        }
        if let progressM {
            context.append("progress \(formatDebugNumber(progressM))m")
        }
        if let centerlineOffsetM {
            context.append("offset \(formatDebugNumber(centerlineOffsetM))m")
        }
        if let lie {
            context.append("lie \(lie)")
        }
        if let inferredLiveLie {
            context.append("gps-lie \(inferredLiveLie)")
        }
        if let recommendedClub {
            context.append("club \(recommendedClub)")
        }
        if let target {
            context.append("target \(target)")
        }
        context.append("why \(primaryReason)")
        if let riskNote {
            context.append("risk \(riskNote)")
        }
        context.append("status \(status)")
        context.append("confidence \(confidence)")

        return "\(parts.joined(separator: " | ")) | \(context.joined(separator: " | "))"
    }

    var gpsTraceLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)

        var parts: [String] = ["[\(timeString)]"]
        if let coordinate {
            parts.append(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
        } else {
            parts.append("no-fix")
        }
        if let accuracyM {
            parts.append("±\(formatDebugNumber(accuracyM))m")
        }
        if let liveDistanceM {
            parts.append("live \(formatDebugNumber(liveDistanceM))m")
        }
        if let progressM {
            parts.append("progress \(formatDebugNumber(progressM))m")
        }
        if let centerlineOffsetM {
            parts.append("offset \(formatDebugNumber(centerlineOffsetM))m")
        }
        if let inferredLiveLie {
            parts.append("lie \(inferredLiveLie)")
        }
        if let recommendedClub {
            parts.append("club \(recommendedClub)")
        }
        if let target {
            parts.append("target \(target)")
        }

        return parts.joined(separator: " | ")
    }
}

enum DebugLogEventType: String, Codable {
    case userAction = "ACTION"
    case gpsUpdate = "GPS"
}

private final class DebugLogStore {
    static let shared = DebugLogStore()

    private let defaults: UserDefaults
    private let storageKey = "debugLogEntriesSnapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [DebugLogEntry] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        return (try? JSONDecoder().decode([DebugLogEntry].self, from: data)) ?? []
    }

    func save(_ entries: [DebugLogEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

private final class PlayerProfileStore {
    static let shared = PlayerProfileStore()

    private let defaults: UserDefaults
    private let storageKey = "playerProfileSnapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPlayer(base: PlayerContext) -> PlayerContext? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        do {
            let snapshot = try JSONDecoder().decode(PlayerProfileSnapshot.self, from: data)
            return snapshot.resolvePlayer(base: base)
        } catch {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
    }

    func save(_ player: PlayerContext) {
        do {
            let data = try JSONEncoder().encode(PlayerProfileSnapshot(player: player))
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist player profile: \(error)")
        }
    }
}
