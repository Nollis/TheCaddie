import MapKit
import SwiftUI

struct HoleMapScreen: View {
    private struct RecordedShotFix {
        let coordinate: GeoCoordinate
        let horizontalAccuracyM: Double?
    }

    @ObservedObject var viewModel: CaddieViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var customWaypoints: [PlanningWaypoint]?
    @State private var hasCenteredOnLivePosition = false
    @State private var lieOverride: ShotLie?
    @State private var showingPuttSelection = false
    @State private var showingExtendedPuttSelection = false
    @State private var puttSelectionHoleNumber: Int?
    @State private var showingManualDistanceEntry = false
    @State private var manualDistanceText = ""
    @State private var recordedShotFixByHole: [Int: RecordedShotFix] = [:]
    @State private var isRecordingMapShot = false

    private let accent = Color(red: 0.20, green: 0.82, blue: 0.43)

    init(
        viewModel: CaddieViewModel,
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            if let hole = activeHole,
               let greenCoordinate = hole.green.centerCoordinate {
                holeMap(hole: hole, greenCoordinate: greenCoordinate)
                mapOverlay(hole: hole)
            } else {
                unavailableState
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            if !viewModel.isUsingLiveDistance && viewModel.canUseLiveDistance {
                viewModel.startLiveDistance()
            }
            resetPlanner(recenter: true)
        }
        .onChange(of: viewModel.selectedHoleNumber) { _, _ in
            lieOverride = nil
            showingPuttSelection = false
            showingExtendedPuttSelection = false
            puttSelectionHoleNumber = nil
            resetPlanner(recenter: true)
        }
        .onChange(of: viewModel.roundSessionID) { _, _ in
            lieOverride = nil
            showingPuttSelection = false
            showingExtendedPuttSelection = false
            puttSelectionHoleNumber = nil
            showingManualDistanceEntry = false
            manualDistanceText = ""
            recordedShotFixByHole = [:]
            isRecordingMapShot = false
            resetPlanner(recenter: true)
        }
        .onChange(of: viewModel.liveCoordinate) { _, coordinate in
            guard !hasCenteredOnLivePosition,
                  let coordinate,
                  let hole = activeHole,
                  HoleDetector.fixMatchesHole(fix: coordinate, hole: hole) else {
                return
            }

            recenter(on: hole)
            hasCenteredOnLivePosition = true
        }
        .confirmationDialog(
            "How many putts?",
            isPresented: $showingPuttSelection,
            titleVisibility: .visible
        ) {
            Button("0 · Holed from off green") {
                finishHole(putts: 0)
            }
            ForEach(1...3, id: \.self) { putts in
                Button("\(putts) \(putts == 1 ? "putt" : "putts")") {
                    finishHole(putts: putts)
                }
            }
            Button("More…") {
                showingPuttSelection = false
                DispatchQueue.main.async {
                    showingExtendedPuttSelection = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This completes Hole \(puttSelectionHoleNumber ?? viewModel.selectedHoleNumber).")
        }
        .confirmationDialog(
            "More putts",
            isPresented: $showingExtendedPuttSelection,
            titleVisibility: .visible
        ) {
            ForEach(4...GreenCompletionScoring.supportedPutts.upperBound, id: \.self) { putts in
                Button("\(putts) putts") {
                    finishHole(putts: putts)
                }
            }
            Button("Back") {
                showingExtendedPuttSelection = false
                DispatchQueue.main.async {
                    showingPuttSelection = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This completes Hole \(puttSelectionHoleNumber ?? viewModel.selectedHoleNumber).")
        }
        .alert("Distance to green", isPresented: $showingManualDistanceEntry) {
            TextField("Meters", text: $manualDistanceText)
                .keyboardType(.decimalPad)
            Button("Save") {
                guard let distanceM = Double(manualDistanceText.replacingOccurrences(of: ",", with: ".")),
                      distanceM > 0 else {
                    return
                }
                viewModel.addDistance(distanceM)
                viewModel.logDebugEvent("Added manual map distance: \(Int(distanceM.rounded()))m")
                manualDistanceText = ""
            }
            Button("Cancel", role: .cancel) {
                manualDistanceText = ""
            }
        } message: {
            Text("Enter the current distance so deterministic scoring can continue without GPS.")
        }
    }

    private var activeHole: CourseHole? {
        viewModel.course?.hole(number: viewModel.selectedHoleNumber)
    }

    private var isCustomPlan: Bool {
        customWaypoints != nil
    }

    private struct PlanningWaypoint: Identifiable {
        enum ID: Hashable {
            case caddie
            case custom(UUID)
        }

        let id: ID
        var coordinate: GeoCoordinate
    }

    private func holeMap(
        hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> some View {
        MapReader { mapProxy in
            Map(
                position: $cameraPosition,
                interactionModes: [.pan, .zoom]
            ) {
                ForEach(Array(hole.surfaces.enumerated()), id: \.offset) { _, surface in
                    if surface.ring.count >= 3 && shouldDisplaySurface(surface.kind) {
                        MapPolygon(coordinates: surface.ring.map(\.mapCoordinate))
                            .foregroundStyle(surfaceColor(for: surface.kind).opacity(0.08))
                            .stroke(surfaceColor(for: surface.kind).opacity(0.52), lineWidth: 1)
                    }
                }

                ForEach(hole.hazards) { hazard in
                    if let coordinate = hazard.coordinate {
                        Annotation("", coordinate: coordinate.mapCoordinate) {
                            hazardMarker(hazard.kind)
                                .accessibilityLabel(Text(hazard.kind.mapLabel))
                        }
                    }
                }

                if viewModel.isUsingLiveDistance,
                   let liveCoordinate = viewModel.liveCoordinate,
                   let accuracyM = viewModel.liveAccuracyM,
                   accuracyM > 0,
                   HoleDetector.fixMatchesHole(fix: liveCoordinate, hole: hole) {
                    MapCircle(
                        center: liveCoordinate.mapCoordinate,
                        radius: max(1, accuracyM)
                    )
                    .foregroundStyle(Color.blue.opacity(0.14))
                    .stroke(Color.blue.opacity(0.82), lineWidth: 2)
                }

                let route = plannedRoute(on: hole, greenCoordinate: greenCoordinate)
                if route.count >= 2 {
                    ForEach(Array(route.indices.dropFirst()), id: \.self) { index in
                        let start = route[index - 1]
                        let target = route[index]
                        MapCircle(
                            center: target.mapCoordinate,
                            radius: max(1, shotPlanningMarginM(from: start, to: target))
                        )
                        .foregroundStyle(Color.yellow.opacity(0.10))
                        .stroke(Color.yellow.opacity(0.78), lineWidth: 1.5)
                    }

                    MapPolyline(coordinates: route.map(\.mapCoordinate))
                        .stroke(.white.opacity(0.94), lineWidth: 3)

                    ForEach(Array(route.indices.dropLast()), id: \.self) { index in
                        let start = route[index]
                        let end = route[index + 1]
                        Annotation(
                            "",
                            coordinate: midpoint(from: start, to: end).mapCoordinate
                        ) {
                            segmentDistanceBubble(
                                from: start,
                                to: end,
                                club: index == route.startIndex && !isCustomPlan
                                    ? viewModel.packet.recommendedClub
                                    : nil
                            )
                        }
                    }
                }

                if let origin = planningOrigin(on: hole) {
                    Annotation("", coordinate: origin.mapCoordinate) {
                        mapMarker(
                            systemImage: viewModel.liveCoordinate == nil ? "circle.fill" : "location.fill",
                            color: .white,
                            foreground: .black
                        )
                        .accessibilityLabel("Current position")
                    }
                }

                let waypoints = planningWaypoints(on: hole)
                ForEach(waypoints) { waypoint in
                    let index = waypoints.firstIndex { $0.id == waypoint.id } ?? 0
                    Annotation(
                        "",
                        coordinate: waypoint.coordinate.mapCoordinate
                    ) {
                        waypointMarker(index: index, isCaddieTarget: !isCustomPlan)
                            .accessibilityLabel("Waypoint \(index + 1)")
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onChanged { value in
                                        guard let coordinate = mapProxy.convert(value.location, from: .global) else {
                                            return
                                        }

                                        let waypointCoordinate = GeoCoordinate(
                                            latitude: coordinate.latitude,
                                            longitude: coordinate.longitude
                                        )
                                        guard canPlaceWaypoint(waypointCoordinate, on: hole) else {
                                            return
                                        }
                                        updateWaypoint(
                                            waypoint.id,
                                            to: waypointCoordinate,
                                            startingFrom: waypoints,
                                            on: hole
                                        )
                                    }
                            )
                    }
                }

                Annotation("", coordinate: greenCoordinate.mapCoordinate) {
                    mapMarker(
                        systemImage: "flag.fill",
                        color: accent,
                        foreground: .black
                    )
                    .accessibilityLabel("Green")
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()
            .onTapGesture { point in
                guard let coordinate = mapProxy.convert(point, from: .local) else {
                    return
                }
                let waypointCoordinate = GeoCoordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                guard canPlaceWaypoint(waypointCoordinate, on: hole) else {
                    return
                }
                var updatedWaypoints = customWaypoints ?? planningWaypoints(on: hole)
                guard !updatedWaypoints.contains(where: {
                    $0.coordinate.distance(to: waypointCoordinate) < 1
                }) else {
                    return
                }
                updatedWaypoints.append(
                    PlanningWaypoint(id: .custom(UUID()), coordinate: waypointCoordinate)
                )
                customWaypoints = sortedWaypoints(updatedWaypoints, on: hole)
            }
        }
    }

    private func mapOverlay(hole: CourseHole) -> some View {
        VStack(spacing: 12) {
            mapHeader(hole)

            Spacer()

            HStack {
                Spacer()
                VStack(spacing: 10) {
                    compactMapButton(
                        title: "Recenter",
                        systemImage: "scope"
                    ) {
                        recenter(on: hole)
                    }

                    compactMapButton(
                        title: viewModel.isUsingLiveDistance ? "GPS live" : "Start GPS",
                        systemImage: viewModel.isUsingLiveDistance ? "location.fill" : "location.slash"
                    ) {
                        toggleGPS()
                    }

                    if isCustomPlan {
                        compactMapButton(
                            title: "Reset line",
                            systemImage: "arrow.counterclockwise"
                        ) {
                            customWaypoints = nil
                        }
                    }
                }
            }

            compactPlannerBar()
            onCourseActionBar()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func mapHeader(_ hole: CourseHole) -> some View {
        HStack(spacing: 10) {
            if onClose == nil {
                Button {
                    closeMap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 40, height: 40)
                }
                .background(.black.opacity(0.68), in: Circle())
            }

            Button {
                viewModel.selectPreviousHole()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 40)
            }
            .disabled(!viewModel.canSelectPreviousHole)
            .opacity(viewModel.canSelectPreviousHole ? 1 : 0.35)

            VStack(spacing: 2) {
                Text("HOLE \(hole.number)")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(accent)
                Text("Par \(hole.par)  ·  \(Int(hole.teeLengthM.rounded())) m")
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.selectNextHole()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 40)
            }
            .disabled(!viewModel.canSelectNextHole)
            .opacity(viewModel.canSelectNextHole ? 1 : 0.35)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func compactPlannerBar() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isCustomPlan ? "YOUR LINE" : "CADDIE LINE")
                .font(.system(.caption2, design: .rounded).weight(.black))
                .tracking(1.1)
                .foregroundStyle(isCustomPlan ? .yellow : accent)

            Text(plannerHeadline)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if !isCustomPlan,
               let riskNote = viewModel.packet.riskNote {
                Label(riskNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func onCourseActionBar() -> some View {
        let actionContent = primaryMapActionContent

        HStack(spacing: 10) {
            Button {
                viewModel.undoLastScoringAction()
                viewModel.logDebugEvent("Undid last scoring action from map")
                lieOverride = nil
                customWaypoints = nil
                recordedShotFixByHole[viewModel.selectedHoleNumber] = nil
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .black))
                    .frame(width: 46, height: 46)
            }
            .disabled(!viewModel.canUndoLastScoringAction)
            .opacity(viewModel.canUndoLastScoringAction ? 1 : 0.35)
            .accessibilityLabel("Back one shot")

            Button {
                performPrimaryMapAction()
            } label: {
                VStack(spacing: 1) {
                    Label(actionContent.title, systemImage: actionContent.systemImage)
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                    Text(actionContent.subtitle)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .foregroundStyle(.black)
            .background(
                accent.opacity(canPerformPrimaryMapAction ? 1 : 0.42),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .disabled(!canPerformPrimaryMapAction)

            Menu {
                if viewModel.packet.status == .missingDistance {
                    Section("Fix current shot") {
                        Button {
                            showingManualDistanceEntry = true
                        } label: {
                            Label("Enter distance", systemImage: "ruler")
                        }
                    }
                }

                if viewModel.packet.status == .missingLie {
                    Section("Set current lie") {
                        currentLieButton("Fairway", lie: .fairway, systemImage: "leaf.fill")
                        currentLieButton("Rough", lie: .rough, systemImage: "circle.dotted")
                        currentLieButton("Bunker", lie: .bunker, systemImage: "triangle.fill")
                        currentLieButton("Recovery", lie: .recovery, systemImage: "tree.fill")
                        currentLieButton("Green", lie: .green, systemImage: "flag.fill")
                    }
                }

                if viewModel.canRecordShotResultFromCurrentContext {
                    Section("Correct next lie") {
                        lieOverrideButton("Fairway", lie: .fairway, systemImage: "leaf.fill")
                        lieOverrideButton("Rough", lie: .rough, systemImage: "circle.dotted")
                        lieOverrideButton("Bunker", lie: .bunker, systemImage: "triangle.fill")
                        lieOverrideButton("Recovery", lie: .recovery, systemImage: "tree.fill")
                        lieOverrideButton("Green", lie: .green, systemImage: "flag.fill")

                        if lieOverride != nil {
                            Button {
                                lieOverride = nil
                            } label: {
                                Label("Use GPS inference", systemImage: "location.fill")
                            }
                        }
                    }

                    Section("Penalty") {
                        Button {
                            recordPenaltyDrop()
                        } label: {
                            Label("Water", systemImage: "drop.fill")
                        }
                        Button {
                            recordStrokeAndDistancePenalty(label: "Lost ball")
                        } label: {
                            Label("Lost ball", systemImage: "questionmark.circle")
                        }
                        Button {
                            recordStrokeAndDistancePenalty(label: "OB")
                        } label: {
                            Label("OB", systemImage: "exclamationmark.octagon.fill")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .black))
                    .frame(width: 46, height: 46)
            }
            .disabled(!canUseMapScoringActions)
            .opacity(canUseMapScoringActions ? 1 : 0.35)
            .accessibilityLabel("Lie correction and penalties")
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var canUseMapScoringActions: Bool {
        switch viewModel.viewState.kind {
        case .ready, .unavailable:
            return viewModel.canRecordShotResultFromCurrentContext
        case .missingContext:
            return viewModel.packet.status == .missingDistance
                || viewModel.packet.status == .missingLie
        case .noCourseLoaded, .onGreen, .holeComplete, .roundComplete:
            return false
        }
    }

    private var canPerformPrimaryMapAction: Bool {
        primaryMapAction != .none && !isRecordingMapShot
    }

    private var primaryMapAction: OnCourseMapPrimaryAction {
        OnCourseMapActionResolver.resolve(
            viewStateKind: viewModel.viewState.kind,
            remainingDistanceM: viewModel.packet.remainingDistanceM,
            canRecordShotResult: viewModel.canRecordShotResultFromCurrentContext,
            hasTrustedLiveFix: viewModel.hasTrustedLiveFixForSelectedHole,
            hasNewBallPosition: hasNewBallPosition,
            allowsManualFallback: !viewModel.hasTrustedLiveFixForSelectedHole,
            inferredLie: viewModel.inferredNextShotLie,
            lieOverride: lieOverride
        )
    }

    private var hasNewBallPosition: Bool {
        let lastFix = recordedShotFixByHole[viewModel.selectedHoleNumber]
        return RecordedShotPositionGate.allowsRecording(
            lastRecordedCoordinate: lastFix?.coordinate,
            currentCoordinate: viewModel.liveCoordinate,
            lastHorizontalAccuracyM: lastFix?.horizontalAccuracyM,
            currentHorizontalAccuracyM: viewModel.liveAccuracyM
        )
    }

    private var primaryMapActionContent: (
        title: String,
        systemImage: String,
        subtitle: String
    ) {
        switch primaryMapAction {
        case .choosePutts:
            return ("Finish hole", "flag.checkered", "Enter putts after holing out")
        case .nextHole:
            return ("Next hole", "arrow.right", "Continue to the next tee")
        case let .recordShot(resultingLie):
            if let lieOverride {
                return (
                    "Next shot",
                    "figure.golf",
                    "\(lieOverride.rawValue.capitalized) selected"
                )
            }
            return (
                "Next shot",
                "figure.golf",
                "\(resultingLie.rawValue.capitalized) · GPS inferred"
            )
        case .none:
            if viewModel.viewState.kind == .roundComplete {
                return ("Round complete", "checkmark.circle.fill", "All holes finished")
            }
            if viewModel.viewState.kind == .noCourseLoaded {
                return ("Next shot", "figure.golf", "Choose a course first")
            }
            if viewModel.packet.status == .missingDistance {
                return ("Next shot", "figure.golf", "Enter the distance in the menu")
            }
            if viewModel.packet.status == .missingLie {
                return ("Next shot", "figure.golf", "Set the current lie in the menu")
            }
            if viewModel.hasTrustedLiveFixForSelectedHole && !hasNewBallPosition {
                return ("Next shot", "figure.golf", "Move to the ball or correct the lie")
            }
            let subtitle = viewModel.isUsingLiveDistance
                ? "Walk to your ball for GPS"
                : "Start GPS or correct the lie"
            return ("Next shot", "figure.golf", subtitle)
        }
    }

    private func lieOverrideButton(
        _ title: String,
        lie: ShotLie,
        systemImage: String
    ) -> some View {
        Button {
            lieOverride = lie
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func currentLieButton(
        _ title: String,
        lie: ShotLie,
        systemImage: String
    ) -> some View {
        Button {
            viewModel.markLie(lie)
            viewModel.logDebugEvent("Set current lie from map: \(title)")
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func performPrimaryMapAction() {
        switch primaryMapAction {
        case .choosePutts:
            puttSelectionHoleNumber = viewModel.selectedHoleNumber
            showingPuttSelection = true
        case .nextHole:
            viewModel.selectNextOpenHole()
            lieOverride = nil
            customWaypoints = nil
        case let .recordShot(resultingLie):
            guard !isRecordingMapShot else {
                return
            }
            isRecordingMapShot = true
            let previousState = viewModel.roundState
            let source = lieOverride == nil ? "GPS inferred" : "manually corrected"
            let useLivePosition = viewModel.hasTrustedLiveFixForSelectedHole
            viewModel.recordShotResult(resultingLie, useLivePosition: useLivePosition)
            if viewModel.roundState != previousState {
                if useLivePosition,
                   let liveCoordinate = viewModel.liveCoordinate {
                    recordedShotFixByHole[viewModel.selectedHoleNumber] = RecordedShotFix(
                        coordinate: liveCoordinate,
                        horizontalAccuracyM: viewModel.liveAccuracyM
                    )
                }
                viewModel.logDebugEvent(
                    "Recorded next shot from map: \(resultingLie.rawValue.capitalized) (\(source))"
                )
            } else {
                viewModel.logDebugEvent("Next shot from map was not recorded")
            }
            lieOverride = nil
            customWaypoints = nil
            DispatchQueue.main.async {
                isRecordingMapShot = false
            }
        case .none:
            break
        }
    }

    private func finishHole(putts: Int) {
        guard puttSelectionHoleNumber == viewModel.selectedHoleNumber,
              viewModel.viewState.kind == .onGreen else {
            viewModel.logDebugEvent("Cancelled stale putt entry after hole changed")
            showingPuttSelection = false
            showingExtendedPuttSelection = false
            puttSelectionHoleNumber = nil
            return
        }

        viewModel.logDebugEvent("Finished hole from map with \(putts) putts")
        viewModel.finishHoleFromGreen(putts: putts)
        puttSelectionHoleNumber = nil
        lieOverride = nil
        customWaypoints = nil
    }

    private func recordPenaltyDrop() {
        let previousState = viewModel.roundState
        viewModel.recordPenaltyDrop()
        viewModel.logDebugEvent(
            viewModel.roundState == previousState
                ? "Water penalty from map was not recorded"
                : "Recorded penalty drop from map: Water"
        )
        lieOverride = nil
        customWaypoints = nil
    }

    private func recordStrokeAndDistancePenalty(label: String) {
        let previousState = viewModel.roundState
        viewModel.recordStrokeAndDistancePenalty()
        viewModel.logDebugEvent(
            viewModel.roundState == previousState
                ? "\(label) penalty from map was not recorded"
                : "Recorded stroke-and-distance penalty from map: \(label)"
        )
        lieOverride = nil
        customWaypoints = nil
    }

    private var plannerHeadline: String {
        if isCustomPlan {
            return "Compare with \(viewModel.packet.recommendedClub ?? "the recommendation")"
        }

        if let club = viewModel.packet.recommendedClub,
           let target = viewModel.packet.target {
            return "\(club) · \(target)"
        }

        return viewModel.packet.target ?? "Plan the next shot"
    }

    private func recommendedTarget(on hole: CourseHole) -> GeoCoordinate? {
        guard let origin = planningOrigin(on: hole) else {
            return hole.green.centerCoordinate
        }

        let currentProgressM = HoleProgressInference.sample(fix: origin, on: hole)?.progressM
            ?? viewModel.roundState.currentShotContext()?.progressM
            ?? 0
        let advanceM = viewModel.packet.clubCarryDistanceM
            ?? viewModel.packet.distanceBasisM
            ?? 0

        guard advanceM > 0 else {
            return hole.green.centerCoordinate
        }

        return HoleProgressInference.landingCoordinate(
            fromProgressM: currentProgressM,
            carryDistanceM: advanceM,
            on: hole
        )
    }

    private func planningWaypoints(on hole: CourseHole) -> [PlanningWaypoint] {
        if let customWaypoints {
            let originProgressM = viewModel.liveProgressM
                ?? planningOrigin(on: hole).flatMap {
                    HoleProgressInference.sample(fix: $0, on: hole)?.progressM
                }
            guard let originProgressM else {
                return customWaypoints
            }

            let passedWaypointMarginM = max(5, viewModel.liveAccuracyM ?? 0)
            return customWaypoints.filter { waypoint in
                guard let waypointProgressM = HoleProgressInference.sample(
                    fix: waypoint.coordinate,
                    on: hole
                )?.progressM else {
                    return true
                }
                return waypointProgressM + passedWaypointMarginM >= originProgressM
            }
        }

        guard let target = recommendedTarget(on: hole) else {
            return []
        }
        if let green = hole.green.centerCoordinate,
           target.distance(to: green) <= 0.5 {
            return []
        }
        return [PlanningWaypoint(id: .caddie, coordinate: target)]
    }

    private func sortedWaypoints(
        _ waypoints: [PlanningWaypoint],
        on hole: CourseHole
    ) -> [PlanningWaypoint] {
        waypoints.enumerated()
            .map { index, waypoint in
                (
                    index: index,
                    waypoint: waypoint,
                    progressM: HoleProgressInference.sample(
                        fix: waypoint.coordinate,
                        on: hole
                    )?.progressM
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.progressM, rhs.progressM) {
                case let (lhsProgress?, rhsProgress?):
                    return lhsProgress == rhsProgress
                        ? lhs.index < rhs.index
                        : lhsProgress < rhsProgress
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.index < rhs.index
                }
            }
            .map { $0.waypoint }
    }

    private func updateWaypoint(
        _ id: PlanningWaypoint.ID,
        to coordinate: GeoCoordinate,
        startingFrom displayedWaypoints: [PlanningWaypoint],
        on hole: CourseHole
    ) {
        var updatedWaypoints = customWaypoints ?? displayedWaypoints
        guard let index = updatedWaypoints.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard !updatedWaypoints.contains(where: {
            $0.id != id && $0.coordinate.distance(to: coordinate) < 1
        }) else {
            return
        }

        updatedWaypoints[index].coordinate = coordinate
        customWaypoints = sortedWaypoints(updatedWaypoints, on: hole)
    }

    private func canPlaceWaypoint(
        _ coordinate: GeoCoordinate,
        on hole: CourseHole
    ) -> Bool {
        guard let origin = planningOrigin(on: hole),
              let originProgressM = HoleProgressInference.sample(fix: origin, on: hole)?.progressM,
              let sample = HoleProgressInference.sample(fix: coordinate, on: hole) else {
            return true
        }

        return sample.progressM > originProgressM + 1
            && sample.remainingCenterlineM > 1
    }

    private func planningOrigin(on hole: CourseHole) -> GeoCoordinate? {
        if let liveCoordinate = viewModel.liveCoordinate,
           HoleDetector.fixMatchesHole(fix: liveCoordinate, hole: hole) {
            return liveCoordinate
        }

        if let progressM = viewModel.roundState.currentShotContext()?.progressM,
           let projectedCoordinate = HoleProgressInference.coordinate(atProgress: progressM, on: hole) {
            return projectedCoordinate
        }

        return hole.defaultTeeCoordinate ?? hole.centerlineCoordinates.first
    }

    private func plannedRoute(
        on hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> [GeoCoordinate] {
        var coordinates = planningWaypoints(on: hole).map(\.coordinate)
        if let origin = planningOrigin(on: hole) {
            coordinates.insert(origin, at: 0)
        }
        coordinates.append(greenCoordinate)

        return coordinates.reduce(into: []) { route, coordinate in
            if (route.last?.distance(to: coordinate) ?? 1) > 0.5 {
                route.append(coordinate)
            }
        }
    }

    private func midpoint(
        from start: GeoCoordinate,
        to end: GeoCoordinate
    ) -> GeoCoordinate {
        GeoCoordinate(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }

    private func toggleGPS() {
        if viewModel.isUsingLiveDistance {
            viewModel.stopLiveDistance()
        } else {
            viewModel.startLiveDistance()
        }
    }

    private func closeMap() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func resetPlanner(recenter shouldRecenter: Bool) {
        customWaypoints = nil
        hasCenteredOnLivePosition = false

        if shouldRecenter, let hole = activeHole {
            recenter(on: hole)
        }
    }

    private func recenter(on hole: CourseHole) {
        let liveRouteCoordinates = [planningOrigin(on: hole), hole.green.centerCoordinate]
            .compactMap { $0 }
        let coordinates = liveRouteCoordinates.count == 2
            ? liveRouteCoordinates
            : (hole.centerlineCoordinates.isEmpty
                ? [hole.defaultTeeCoordinate, hole.green.centerCoordinate].compactMap { $0 }
                : hole.centerlineCoordinates)

        guard let camera = mapCamera(
            for: coordinates,
            toward: hole.green.centerCoordinate,
            from: planningOrigin(on: hole)
        ) else {
            cameraPosition = .automatic
            return
        }
        cameraPosition = .camera(camera)
    }

    private func mapCamera(
        for coordinates: [GeoCoordinate],
        toward target: GeoCoordinate?,
        from origin: GeoCoordinate?
    ) -> MapCamera? {
        guard !coordinates.isEmpty else {
            return nil
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(),
              let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(),
              let maxLongitude = longitudes.max() else {
            return nil
        }

        let center = GeoCoordinate(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let farthestDistanceM = coordinates
            .map { $0.distance(to: center) }
            .max() ?? 0
        let heading = (origin.flatMap { origin in
            target.map { mapHeading(from: origin, to: $0) }
        }) ?? 0

        return MapCamera(
            centerCoordinate: center.mapCoordinate,
            distance: max(400, farthestDistanceM * 4.6),
            heading: heading,
            pitch: 0
        )
    }

    private func mapHeading(from start: GeoCoordinate, to end: GeoCoordinate) -> CLLocationDirection {
        let latitude1 = start.latitude * .pi / 180
        let latitude2 = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2)
            - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)

        return (atan2(y, x) * 180 / .pi + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    private func compactMapButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.caption, design: .rounded).weight(.black))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.70), in: Capsule())
    }

    private func waypointMarker(index: Int, isCaddieTarget: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCaddieTarget ? accent : Color.white)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
            Text("\(index + 1)")
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(.black)
        }
        .padding(5)
        .contentShape(Circle())
    }

    private func segmentDistanceBubble(
        from start: GeoCoordinate,
        to end: GeoCoordinate,
        club: String?
    ) -> some View {
        let distanceM = start.distance(to: end)
        let marginM = shotPlanningMarginM(from: start, to: end)
        let distanceLabel = "\(Int(distanceM.rounded()))m · ±\(Int(marginM.rounded()))m"

        return VStack(spacing: 1) {
            if let club {
                Text(club)
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .foregroundStyle(accent)
            }
            Text(distanceLabel)
                .font(.system(.caption, design: .rounded).weight(.black))
        }
            .foregroundStyle(.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(club.map { "\($0), \(distanceLabel)" } ?? distanceLabel))
    }

    private func shotPlanningMarginM(
        from start: GeoCoordinate,
        to end: GeoCoordinate
    ) -> Double {
        start.distance(to: end) * 0.10
    }

    private func mapMarker(
        systemImage: String,
        color: Color,
        foreground: Color
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(foreground)
            .frame(width: 34, height: 34)
            .background(color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
    }

    private func hazardMarker(_ kind: HazardKind) -> some View {
        Image(systemName: kind.mapSymbol)
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(kind.mapColor, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
    }

    private func shouldDisplaySurface(_ kind: HoleSurfaceKind) -> Bool {
        switch kind {
        case .water, .bunker, .green:
            return true
        case .fairway, .rough, .tee, .woods:
            return false
        }
    }

    private func surfaceColor(for kind: HoleSurfaceKind) -> Color {
        switch kind {
        case .water:
            return .cyan
        case .bunker:
            return .yellow
        case .green:
            return accent
        case .fairway, .tee:
            return .green
        case .woods:
            return .orange
        case .rough:
            return .white
        }
    }

    private var unavailableState: some View {
        ZStack {
            Color(red: 0.04, green: 0.10, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "map.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(accent)
                Text(viewModel.course == nil ? "Choose a course" : "Hole map unavailable")
                    .font(.system(.title2, design: .rounded).weight(.black))
                Text(
                    viewModel.course == nil
                        ? "Start a round before using the on-course caddie."
                        : "This hole needs a mapped tee and green before the planner can draw a trustworthy line."
                )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(onClose == nil ? "Close" : "Choose course") { closeMap() }
                    .buttonStyle(HoleMapPrimaryButtonStyle(color: accent))
            }
            .padding(28)
        }
    }
}

private struct HoleMapPrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.black))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension GeoCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension HazardKind {
    var mapLabel: String {
        switch self {
        case .outOfBounds:
            return "Out of bounds"
        default:
            return rawValue.capitalized
        }
    }

    var mapSymbol: String {
        switch self {
        case .water:
            return "drop.fill"
        case .bunker:
            return "triangle.fill"
        case .trees:
            return "tree.fill"
        case .outOfBounds:
            return "exclamationmark"
        }
    }

    var mapColor: Color {
        switch self {
        case .water:
            return .blue
        case .bunker:
            return .orange
        case .trees:
            return .green
        case .outOfBounds:
            return .red
        }
    }
}
