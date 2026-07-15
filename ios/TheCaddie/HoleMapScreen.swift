import MapKit
import SwiftUI

struct HoleMapScreen: View {
    @ObservedObject var viewModel: CaddieViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var customWaypoints: [PlanningWaypoint]?
    @State private var hasCenteredOnLivePosition = false
    @State private var measurementStart: GeoCoordinate?
    @State private var measurementEnd: GeoCoordinate?
    @State private var isMeasuringShot = false

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
        .preferredColorScheme(.dark)
        .onAppear {
            if !viewModel.isUsingLiveDistance && viewModel.canUseLiveDistance {
                viewModel.startLiveDistance()
            }
            resetPlanner(recenter: true)
        }
        .onChange(of: viewModel.selectedHoleNumber) { _, _ in
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
                interactionModes: [.pan, .zoom, .rotate]
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
                        Annotation(hazard.kind.mapLabel, coordinate: coordinate.mapCoordinate) {
                            hazardMarker(hazard.kind)
                        }
                    }
                }

                if let recommendedTarget = recommendedTarget(on: hole),
                   !isCustomPlan {
                    MapCircle(
                        center: recommendedTarget.mapCoordinate,
                        radius: max(12, viewModel.packet.expectedDispersionM ?? 18)
                    )
                    .foregroundStyle(accent.opacity(0.16))
                    .stroke(accent.opacity(0.9), lineWidth: 2)
                }

                let route = plannedRoute(on: hole, greenCoordinate: greenCoordinate)
                if route.count >= 2 {
                    MapPolyline(coordinates: route.map(\.mapCoordinate))
                        .stroke(.white.opacity(0.94), lineWidth: 3)

                    ForEach(Array(route.indices.dropLast()), id: \.self) { index in
                        let start = route[index]
                        let end = route[index + 1]
                        Annotation(
                            "Segment distance",
                            coordinate: midpoint(from: start, to: end).mapCoordinate
                        ) {
                            segmentDistanceBubble(from: start, to: end)
                        }
                    }
                }

                if let measurementStart,
                   let measuredEnd = measurementEnd ?? viewModel.liveCoordinate {
                    MapPolyline(
                        coordinates: [measurementStart.mapCoordinate, measuredEnd.mapCoordinate]
                    )
                    .stroke(.yellow, lineWidth: 4)

                    Annotation("Shot start", coordinate: measurementStart.mapCoordinate) {
                        Image(systemName: "smallcircle.filled.circle")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(.black.opacity(0.72), in: Circle())
                    }
                }

                if let origin = planningOrigin(on: hole) {
                    Annotation("Current position", coordinate: origin.mapCoordinate) {
                        mapMarker(
                            systemImage: viewModel.liveCoordinate == nil ? "circle.fill" : "location.fill",
                            color: .white,
                            foreground: .black
                        )
                    }
                }

                let waypoints = planningWaypoints(on: hole)
                ForEach(waypoints) { waypoint in
                    let index = waypoints.firstIndex { $0.id == waypoint.id } ?? 0
                    Annotation(
                        "Waypoint \(index + 1)",
                        coordinate: waypoint.coordinate.mapCoordinate
                    ) {
                        waypointMarker(index: index, isCaddieTarget: !isCustomPlan)
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

                Annotation("Green", coordinate: greenCoordinate.mapCoordinate) {
                    mapMarker(
                        systemImage: "flag.fill",
                        color: accent,
                        foreground: .black
                    )
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

            compactPlannerBar(hole: hole)
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

    private func compactPlannerBar(hole: CourseHole) -> some View {
        let waypointCount = planningWaypoints(on: hole).count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCustomPlan ? "YOUR LINE" : "CADDIE LINE")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(isCustomPlan ? .yellow : accent)
                    Text(plannerHeadline)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(waypointCount) \(waypointCount == 1 ? "point" : "points")")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Text("Drag a point to adjust · tap the map to add another")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.62))

            if !isCustomPlan,
               let riskNote = viewModel.packet.riskNote {
                Label(riskNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
            }

            if let measurementM = measuredShotDistanceM {
                HStack {
                    Label(
                        isMeasuringShot ? "Shot tracking" : "Last measurement",
                        systemImage: isMeasuringShot ? "dot.radiowaves.left.and.right" : "checkmark.circle.fill"
                    )
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(accent)

                    Spacer()

                    Text("\(Int(measurementM.rounded())) m")
                        .font(.system(.headline, design: .rounded).weight(.black))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                Button {
                    toggleGPS()
                } label: {
                    Label(
                        viewModel.isUsingLiveDistance ? "GPS live" : "Start GPS",
                        systemImage: viewModel.isUsingLiveDistance ? "location.fill" : "location.slash"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(HoleMapSecondaryButtonStyle())

                Button {
                    toggleShotMeasurement()
                } label: {
                    Label(
                        isMeasuringShot ? "Finish measure" : "Measure shot",
                        systemImage: isMeasuringShot ? "stop.fill" : "ruler"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(HoleMapPrimaryButtonStyle(color: accent))
                .disabled(viewModel.liveCoordinate == nil)
                .opacity(viewModel.liveCoordinate == nil ? 0.45 : 1)
            }

            if measurementStart != nil {
                Button("Clear shot measurement") {
                    measurementStart = nil
                    measurementEnd = nil
                    isMeasuringShot = false
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
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

        return HoleProgressInference.coordinate(
            atProgress: currentProgressM + advanceM,
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

    private func distance(
        from start: GeoCoordinate?,
        to end: GeoCoordinate?
    ) -> Double? {
        guard let start, let end else {
            return nil
        }
        return start.distance(to: end)
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

    private var measuredShotDistanceM: Double? {
        guard let measurementStart else {
            return nil
        }

        let end = measurementEnd ?? viewModel.liveCoordinate
        return distance(from: measurementStart, to: end)
    }

    private func toggleShotMeasurement() {
        if isMeasuringShot {
            measurementEnd = viewModel.liveCoordinate
            isMeasuringShot = false
            return
        }

        measurementStart = viewModel.liveCoordinate
        measurementEnd = nil
        isMeasuringShot = measurementStart != nil
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
        measurementStart = nil
        measurementEnd = nil
        isMeasuringShot = false

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

        guard let region = mapRegion(for: coordinates) else {
            cameraPosition = .automatic
            return
        }
        cameraPosition = .region(region)
    }

    private func mapRegion(for coordinates: [GeoCoordinate]) -> MKCoordinateRegion? {
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

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.00065, (maxLatitude - minLatitude) * 1.42),
                longitudeDelta: max(0.00065, (maxLongitude - minLongitude) * 1.42)
            )
        )
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
        to end: GeoCoordinate
    ) -> some View {
        Text("\(Int(start.distance(to: end).rounded()))m")
            .font(.system(.caption, design: .rounded).weight(.black))
            .foregroundStyle(.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
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
                Text("Hole map unavailable")
                    .font(.system(.title2, design: .rounded).weight(.black))
                Text("This hole needs a mapped tee and green before the planner can draw a trustworthy line.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close") { closeMap() }
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

private struct HoleMapSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 14))
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
