import MapKit
import SwiftUI

struct HoleMapScreen: View {
    @ObservedObject var viewModel: CaddieViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedTarget: GeoCoordinate?
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
                mapOverlay(hole: hole, greenCoordinate: greenCoordinate)
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
    }

    private var activeHole: CourseHole? {
        viewModel.course?.hole(number: viewModel.selectedHoleNumber)
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
                    if surface.ring.count >= 3 {
                        MapPolygon(coordinates: surface.ring.map(\.mapCoordinate))
                            .foregroundStyle(surfaceColor(for: surface.kind).opacity(0.16))
                            .stroke(surfaceColor(for: surface.kind).opacity(0.72), lineWidth: 1)
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
                   selectedTarget == nil {
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
                        .stroke(.white.opacity(0.94), lineWidth: 4)
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
                            label: viewModel.liveCoordinate == nil ? "Start" : "You",
                            color: .white,
                            foreground: .black
                        )
                    }
                }

                if let target = activeTarget(on: hole) {
                    Annotation(
                        selectedTarget == nil ? "Caddie target" : "Selected target",
                        coordinate: target.mapCoordinate
                    ) {
                        targetMarker(isCustom: selectedTarget != nil)
                    }
                }

                Annotation("Green", coordinate: greenCoordinate.mapCoordinate) {
                    mapMarker(
                        systemImage: "flag.fill",
                        label: "Green",
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
                selectedTarget = GeoCoordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        }
    }

    private func mapOverlay(
        hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> some View {
        VStack(spacing: 12) {
            mapHeader(hole)
            greenDistanceStrip(hole: hole, greenCoordinate: greenCoordinate)

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

                    if selectedTarget != nil {
                        compactMapButton(
                            title: "Caddie line",
                            systemImage: "arrow.counterclockwise"
                        ) {
                            selectedTarget = nil
                        }
                    }
                }
            }

            plannerCard(hole: hole, greenCoordinate: greenCoordinate)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func mapHeader(_ hole: CourseHole) -> some View {
        HStack(spacing: 10) {
            Button {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .frame(width: 40, height: 40)
            }
            .background(.black.opacity(0.68), in: Circle())

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

    private func greenDistanceStrip(
        hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> some View {
        let distances = greenDistances(
            from: planningOrigin(on: hole),
            hole: hole,
            greenCoordinate: greenCoordinate
        )

        return HStack(spacing: 0) {
            distanceMetric(label: "Front", value: distances.front)
            Divider().overlay(.white.opacity(0.18))
            distanceMetric(label: "Center", value: distances.center, emphasized: true)
            Divider().overlay(.white.opacity(0.18))
            distanceMetric(label: "Back", value: distances.back)
        }
        .frame(height: 58)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func distanceMetric(
        label: String,
        value: Int?,
        emphasized: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
            Text(value.map { "\($0)m" } ?? "--")
                .font(.system(emphasized ? .title3 : .headline, design: .rounded).weight(.black))
                .foregroundStyle(emphasized ? accent : .white)
        }
        .frame(maxWidth: .infinity)
    }

    private func plannerCard(
        hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> some View {
        let origin = planningOrigin(on: hole)
        let target = activeTarget(on: hole)
        let toTargetM = distance(from: origin, to: target)
        let targetToGreenM = distance(from: target, to: greenCoordinate)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTarget == nil ? "CADDIE LINE" : "YOUR TARGET")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(selectedTarget == nil ? accent : .yellow)
                    Text(plannerHeadline)
                        .font(.system(.title3, design: .rounded).weight(.black))
                }

                Spacer()

                if let toTargetM {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(toTargetM.rounded())) m")
                            .font(.system(.title2, design: .rounded).weight(.black))
                        Text("to target")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }

            if let targetToGreenM {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundStyle(accent)
                    Text("Then \(Int(targetToGreenM.rounded())) m to green center")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
            }

            Text(targetAssessment(toTargetM: toTargetM))
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            if let riskNote = viewModel.packet.riskNote {
                Label(riskNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.yellow)
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
        .padding(17)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var plannerHeadline: String {
        if selectedTarget != nil {
            return "Compare with \(viewModel.packet.recommendedClub ?? "the recommendation")"
        }

        if let club = viewModel.packet.recommendedClub,
           let target = viewModel.packet.target {
            return "\(club) · \(target)"
        }

        return viewModel.packet.target ?? "Plan the next shot"
    }

    private func targetAssessment(toTargetM: Double?) -> String {
        if selectedTarget == nil {
            if let dispersionM = viewModel.packet.expectedDispersionM {
                return "The highlighted landing zone includes about ±\(Int(dispersionM.rounded())) m of expected dispersion."
            }
            return "Tap the map to compare another landing point."
        }

        guard let toTargetM,
              let carryM = viewModel.packet.clubCarryDistanceM else {
            return "Tap the map to compare another landing point."
        }

        let differenceM = toTargetM - carryM
        if abs(differenceM) <= max(6, (viewModel.packet.expectedDispersionM ?? 18) * 0.35) {
            return "Your target is inside the recommended club's carry window."
        }

        if differenceM > 0 {
            return "Your target is \(Int(abs(differenceM).rounded())) m beyond the recommended carry."
        }

        return "Your target is \(Int(abs(differenceM).rounded())) m shorter than the recommended carry."
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

    private func activeTarget(on hole: CourseHole) -> GeoCoordinate? {
        selectedTarget ?? recommendedTarget(on: hole)
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
        [planningOrigin(on: hole), activeTarget(on: hole), greenCoordinate]
            .compactMap { $0 }
            .reduce(into: []) { route, coordinate in
                if (route.last?.distance(to: coordinate) ?? 1) > 0.5 {
                    route.append(coordinate)
                }
            }
    }

    private func greenDistances(
        from origin: GeoCoordinate?,
        hole: CourseHole,
        greenCoordinate: GeoCoordinate
    ) -> (front: Int?, center: Int?, back: Int?) {
        guard let origin else {
            return (nil, nil, nil)
        }

        let centerM = origin.distance(to: greenCoordinate)
        let greenRing = hole.surfaces.first(where: { $0.kind == .green })?.ring ?? []
        if !greenRing.isEmpty {
            let ringDistances = greenRing.map { origin.distance(to: $0) }
            return (
                Int((ringDistances.min() ?? centerM).rounded()),
                Int(centerM.rounded()),
                Int((ringDistances.max() ?? centerM).rounded())
            )
        }

        let frontOffsetM = max(0, hole.green.centerDistanceM - hole.green.frontDistanceM)
        let backOffsetM = max(0, hole.green.backDistanceM - hole.green.centerDistanceM)
        return (
            Int(max(0, centerM - frontOffsetM).rounded()),
            Int(centerM.rounded()),
            Int((centerM + backOffsetM).rounded())
        )
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

    private func resetPlanner(recenter shouldRecenter: Bool) {
        selectedTarget = nil
        measurementStart = nil
        measurementEnd = nil
        isMeasuringShot = false

        if shouldRecenter, let hole = activeHole {
            recenter(on: hole)
        }
    }

    private func recenter(on hole: CourseHole) {
        let coordinates = hole.centerlineCoordinates.isEmpty
            ? [hole.defaultTeeCoordinate, hole.green.centerCoordinate].compactMap { $0 }
            : hole.centerlineCoordinates

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

    private func targetMarker(isCustom: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCustom ? Color.yellow : accent)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
            Image(systemName: isCustom ? "scope" : "sparkles")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.black)
        }
    }

    private func mapMarker(
        systemImage: String,
        label: String,
        color: Color,
        foreground: Color
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background(color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.72), in: Capsule())
        }
    }

    private func hazardMarker(_ kind: HazardKind) -> some View {
        Image(systemName: kind.mapSymbol)
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 27, height: 27)
            .background(kind.mapColor, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
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
                Button("Close") { dismiss() }
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
