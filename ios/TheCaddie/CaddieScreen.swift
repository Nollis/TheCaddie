import SwiftUI
import UIKit

struct CaddieScreen: View {
    @StateObject var viewModel: CaddieViewModel
    
    @State private var showDebugDrawer = false
    @State private var puttCount = 2
    @State private var actionLogs: [String] = ["Caddie screen loaded and ready."]
    @State private var debugCopyConfirmation: String?

    init(viewModel: CaddieViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let viewState = viewModel.viewState

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.98, blue: 0.93),
                    Color(red: 0.98, green: 0.96, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header(viewState)
                liveDistancePanel()
                holeNavigator()
                recommendationCard(viewState)
                quickUpdates(viewState)
                Spacer(minLength: 0)
                
                // Hands-Free Banner
                handsFreeBanner()
                
                // Debug Log Trigger Button
                Button(action: {
                    showDebugDrawer = true
                }) {
                    Label("Decision Debug Log", systemImage: "chart.bar.doc.horizontal")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.86), in: Capsule())
                        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showDebugDrawer) {
            debugDrawer(viewState: viewState)
        }
    }

    private func liveDistancePanel() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(liveDistanceStatusColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Live GPS")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.black)

                    Text(liveDistanceStatusText)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let liveDistanceLabel = viewModel.liveDistanceLabel {
                    Text(liveDistanceLabel)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
                }
            }

            if let liveAccuracyLabel = viewModel.liveAccuracyLabel {
                Text(liveAccuracyLabel)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let liveProgressLabel = viewModel.liveProgressLabel {
                Text(liveProgressLabel + (viewModel.liveCenterlineOffsetLabel.map { " • \($0)" } ?? ""))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let liveLocationError = viewModel.liveLocationError {
                Text(liveLocationError)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color(red: 0.70, green: 0.16, blue: 0.12))
            }

            HStack(spacing: 10) {
                Button {
                    if viewModel.isUsingLiveDistance {
                        viewModel.stopLiveDistance()
                        logAction("Paused live GPS distance.")
                    } else {
                        viewModel.startLiveDistance()
                        logAction("Started live GPS distance.")
                    }
                } label: {
                    Label(
                        viewModel.isUsingLiveDistance ? "Pause GPS" : "Use GPS",
                        systemImage: viewModel.isUsingLiveDistance ? "location.slash" : "location"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CaddiePillButtonStyle())

                Button {
                    viewModel.refreshLiveDistance()
                    logAction("Requested GPS refresh.")
                } label: {
                    Label("Refresh", systemImage: "location.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CaddiePillButtonStyle())
                .disabled(!viewModel.canUseLiveDistance && !viewModel.isUsingLiveDistance)
                .opacity((!viewModel.canUseLiveDistance && !viewModel.isUsingLiveDistance) ? 0.45 : 1)
            }

            Text(viewModel.canUseLiveDistance
                ? "GPS updates distance to the green and infers tee, fairway, rough, bunker, or green from mapped course surfaces."
                : "This selected course does not have live GPS mapping yet.")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
    }

    private func header(_ viewState: CaddieViewState) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewState.holeLabel)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)

                Text("Grounded by local shot context")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Text(viewState.shotLabel)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
            }

            Spacer()

            Text(viewState.distanceLabel)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.78), in: Capsule())
        }
    }

    @ViewBuilder
    private func holeNavigator() -> some View {
        let holes = viewModel.availableHoleNumbers

        if holes.count > 1 {
            HStack(spacing: 10) {
                Button {
                    logAction("Navigated to previous hole")
                    viewModel.selectPreviousHole()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CaddieIconButtonStyle())
                .disabled(!viewModel.canSelectPreviousHole)
                .opacity(viewModel.canSelectPreviousHole ? 1 : 0.42)

                Menu {
                    ForEach(holes, id: \.self) { holeNumber in
                        Button("Hole \(holeNumber)") {
                            logAction("Navigated to Hole \(holeNumber)")
                            viewModel.selectHole(holeNumber)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Hole \(viewModel.selectedHoleNumber)")
                            .font(.system(.headline, design: .rounded).weight(.black))
                        Image(systemName: "chevron.down")
                            .font(.system(.caption, design: .rounded).weight(.black))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(CaddiePillButtonStyle())

                Button {
                    logAction("Navigated to next hole")
                    viewModel.selectNextHole()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CaddieIconButtonStyle())
                .disabled(!viewModel.canSelectNextHole)
                .opacity(viewModel.canSelectNextHole ? 1 : 0.42)
            }
        }
    }

    private func recommendationCard(_ viewState: CaddieViewState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(statusEyebrow(for: viewState.kind))
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(statusColor(for: viewState.kind))

            Text(viewState.title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.72)
                .lineLimit(3)

            Text(viewState.subtitle)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            if let noteText = viewState.noteText {
                Text(noteText)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.23, blue: 0.08))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(red: 0.98, green: 0.94, blue: 0.82),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }

            if let primaryActionLabel = viewState.primaryActionLabel {
                Button(primaryActionLabel) {
                    handlePrimaryAction()
                }
                .buttonStyle(CaddiePrimaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 18)
    }

    private func quickUpdates(_ viewState: CaddieViewState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewState.kind == .onGreen {
                Text("Finish the hole")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.black)
                
                HStack(spacing: 12) {
                    // Putt Stepper
                    HStack(spacing: 12) {
                        Button(action: {
                            if puttCount > 1 {
                                puttCount -= 1
                                logAction("Adjusted putt count to \(puttCount)")
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                        }
                        
                        Text("\(puttCount) Putts")
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(width: 80)
                        
                        Button(action: {
                            if puttCount < 6 {
                                puttCount += 1
                                logAction("Adjusted putt count to \(puttCount)")
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.86))
                    .cornerRadius(20)
                    
                    Button("Save & Finish") {
                        logAction("Finished hole with \(puttCount) putts.")
                        viewModel.finishHoleFromGreen(putts: puttCount)
                        puttCount = 2 // Reset default for next hole
                    }
                    .buttonStyle(CaddiePrimaryButtonStyle())
                }
            } else {
                Text(quickUpdateTitle(for: viewState))
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.black)

                HStack(spacing: 10) {
                    ForEach(viewState.quickActions, id: \.kind) { action in
                        quickUpdateButton(action)
                    }
                }
                .opacity(viewState.quickActions.isEmpty ? 0.35 : 1)
                .disabled(viewState.quickActions.isEmpty)
            }
        }
    }

    private func quickUpdateButton(_ action: CaddieViewState.QuickAction) -> some View {
        Button {
            logAction("Recorded shot result: \(action.label)")
            viewModel.recordQuickAction(action.kind)
        } label: {
            Text(action.label)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CaddiePillButtonStyle())
    }

    private func handlePrimaryAction() {
        switch viewModel.viewState.kind {
        case .noCourseLoaded:
            logAction("Loaded sample course.")
            viewModel.loadSample()
        case .missingContext:
            switch viewModel.packet.status {
            case .missingDistance:
                logAction("Added manual distance: 142m.")
                viewModel.addDistance(142)
            case .missingLie:
                logAction("Marked lie: Fairway.")
                viewModel.markLie(.fairway)
            case .ready, .noCourseLoaded, .unknownHole, .unavailable:
                break
            }
        case .holeComplete:
            logAction("Moved to next open hole.")
            viewModel.selectNextOpenHole()
        case .ready, .unavailable, .onGreen, .roundComplete:
            break
        }
    }

    private func handsFreeBanner() -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isHandsFreeListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(viewModel.isHandsFreeListening ? "Listening (Hands-Free)..." : "Hands-Free Muted")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(viewModel.isHandsFreeListening ? Color(red: 0.06, green: 0.56, blue: 0.24) : .secondary)
            }
            Spacer()
            Button(action: {
                viewModel.isHandsFreeListening.toggle()
                logAction("Toggled hands-free: \(viewModel.isHandsFreeListening ? "ON" : "OFF")")
            }) {
                Text(viewModel.isHandsFreeListening ? "Mute" : "Listen")
                    .font(.system(.caption, design: .rounded).bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.1))
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.01), radius: 2, x: 0, y: 1)
    }

    private func debugDrawer(viewState: CaddieViewState) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.95),
                    Color(red: 0.99, green: 0.98, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Decision Debug Log")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Raw recommendation metrics & risk scores")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: copyDebugReport) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.9), in: Circle())
                    }
                    Button(action: {
                        showDebugDrawer = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()

                if let debugCopyConfirmation {
                    Text(debugCopyConfirmation)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let debugInfo = viewModel.packet.debugInfo
                        
                        // Calculation Metrics Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation Metrics")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                metricItem(label: "GPS Distance", value: viewModel.packet.remainingDistanceM != nil ? "\(Int(viewModel.packet.remainingDistanceM!))m" : "--")
                                Spacer()
                                metricItem(label: "Progress", value: viewModel.liveProgressLabel ?? "--")
                                Spacer()
                                metricItem(label: "Wind", value: viewModel.roundState.currentShotContext()?.wind?.direction.rawValue.capitalized ?? "None")
                                Spacer()
                                metricItem(label: "Adjusted Basis", value: viewModel.packet.distanceBasisM != nil ? "\(Int(viewModel.packet.distanceBasisM!))m" : "--")
                                Spacer()
                                metricItem(label: "Centerline", value: viewModel.liveCenterlineOffsetLabel ?? "--")
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Live Mapping")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 10) {
                                debugKeyValueRow(
                                    label: "Hole Resolution",
                                    value: viewModel.liveHoleResolutionLabel
                                )

                                if let mappingHoleSummary = viewModel.mappingHoleSummary {
                                    debugKeyValueRow(
                                        label: "Mapped Assets",
                                        value: mappingHoleSummary
                                    )
                                }

                                if let liveCoordinateLabel = viewModel.liveCoordinateLabel {
                                    debugKeyValueRow(
                                        label: "GPS Fix",
                                        value: liveCoordinateLabel
                                    )
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        if let liveFixTimestampLabel = viewModel.liveFixTimestampLabel {
                                            debugMetaPill(label: "Fix", value: liveFixTimestampLabel)
                                        }
                                        if let liveAccuracyLabel = viewModel.liveAccuracyLabel {
                                            debugMetaPill(label: "Accuracy", value: liveAccuracyLabel.replacingOccurrences(of: "Accuracy ", with: ""))
                                        }
                                        debugMetaPill(label: "Switch", value: viewModel.holeSwitchMissesLabel)
                                    }
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        if let liveInferredLieLabel = viewModel.liveInferredLieLabel {
                                            debugMetaPill(label: "Lie", value: liveInferredLieLabel)
                                        }
                                        if let liveProgressLabel = viewModel.liveProgressLabel {
                                            debugMetaPill(label: "Progress", value: liveProgressLabel)
                                        }
                                        if let liveCenterlineOffsetLabel = viewModel.liveCenterlineOffsetLabel {
                                            debugMetaPill(label: "Offset", value: liveCenterlineOffsetLabel)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)

                        if let debugInfo {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Decision Summary")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(.secondary)

                                HStack(spacing: 10) {
                                    Text(debugInfo.mode.rawValue.capitalized)
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.05, green: 0.38, blue: 0.19).opacity(0.1))
                                        .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                                        .clipShape(Capsule())

                                    Text(debugInfo.summary)
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }

                        if let debugInfo, !debugInfo.hazardEvaluations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Hazard Relevance")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(.secondary)

                                ForEach(debugInfo.hazardEvaluations) { evaluation in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(evaluation.label)
                                                    .font(.system(.subheadline, design: .rounded).bold())

                                                Text(evaluation.note)
                                                    .font(.system(.caption2, design: .rounded))
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }

                                            Spacer(minLength: 8)

                                            Text(evaluation.isRelevant ? "RELEVANT" : "IGNORED")
                                                .font(.system(size: 8, design: .rounded).bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(hazardBadgeColor(evaluation.isRelevant).opacity(0.12))
                                                .foregroundColor(hazardBadgeColor(evaluation.isRelevant))
                                                .cornerRadius(4)
                                        }

                                        HStack(spacing: 10) {
                                            debugMetaPill(label: "Kind", value: evaluation.kind.rawValue.capitalized)
                                            debugMetaPill(label: "Side", value: evaluation.sideLabel.capitalized)
                                            if let progressM = evaluation.progressM {
                                                debugMetaPill(label: "Progress", value: "\(Int(progressM.rounded()))m")
                                            }
                                            if let lateralOffsetM = evaluation.lateralOffsetM {
                                                debugMetaPill(label: "Lateral", value: "\(Int(lateralOffsetM.rounded()))m")
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        
                        // Risk Budgets Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Club Risk Evaluation")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)

                            ForEach(debugInfo?.clubEvaluations ?? []) { evaluation in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(evaluation.clubName)
                                            .font(.system(.subheadline, design: .rounded).bold())

                                        Text(evaluation.note)
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 8)

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(Int(evaluation.carryDistanceM))m carry")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)

                                        if let spread = evaluation.expectedDispersionM {
                                            Text("±\(Int(spread))m")
                                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if evaluation.isSelected {
                                        Text("SELECTED")
                                            .font(.system(size: 8, design: .rounded).bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color(red: 0.05, green: 0.38, blue: 0.19).opacity(0.12))
                                            .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                                            .cornerRadius(4)
                                    } else if let totalRisk = evaluation.totalRisk {
                                        Text(String(format: "%.2f risk", totalRisk))
                                            .font(.system(.caption2, design: .rounded).bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(riskBadgeColor(totalRisk).opacity(0.12))
                                            .foregroundColor(riskBadgeColor(totalRisk))
                                            .cornerRadius(4)
                                    } else if let gap = evaluation.distanceGapM {
                                        Text(gap >= 0 ? "+\(Int(gap))m" : "\(Int(gap))m")
                                            .font(.system(.caption2, design: .rounded).bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.05))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 4)

                                if let totalRisk = evaluation.totalRisk {
                                    HStack(spacing: 10) {
                                        debugBreakdownPill(label: "Total", value: totalRisk)
                                        if let widthRisk = evaluation.widthRisk {
                                            debugBreakdownPill(label: "Width", value: widthRisk)
                                        }
                                        if let hazardRisk = evaluation.hazardRisk {
                                            debugBreakdownPill(label: "Hazard", value: hazardRisk)
                                        }
                                        if let overshootRisk = evaluation.overshootRisk {
                                            debugBreakdownPill(label: "Long", value: overshootRisk)
                                        }
                                    }
                                }
                            }

                            if (debugInfo?.clubEvaluations.isEmpty ?? true) {
                                Text("No club evaluation data for this state.")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 6)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        
                        // History Log
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activity History")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(actionLogs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.04))
                            .cornerRadius(8)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).bold())
                .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    private func debugBreakdownPill(label: String, value: Double) -> some View {
        Text("\(label) \(String(format: "%.2f", value))")
            .font(.system(size: 10, design: .rounded).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.05))
            .foregroundColor(.secondary)
            .cornerRadius(6)
    }

    private func debugMetaPill(label: String, value: String) -> some View {
        Text("\(label) \(value)")
            .font(.system(size: 10, design: .rounded).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.05))
            .foregroundColor(.secondary)
            .cornerRadius(6)
    }

    private func debugKeyValueRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func riskBadgeColor(_ totalRisk: Double) -> Color {
        if totalRisk <= 0.6 {
            return Color(red: 0.06, green: 0.56, blue: 0.24)
        }
        if totalRisk <= 1.0 {
            return Color(red: 0.76, green: 0.48, blue: 0.11)
        }
        return .red
    }

    private func hazardBadgeColor(_ isRelevant: Bool) -> Color {
        isRelevant
            ? Color(red: 0.06, green: 0.56, blue: 0.24)
            : Color(red: 0.47, green: 0.50, blue: 0.53)
    }

    private var liveDistanceStatusColor: Color {
        if viewModel.liveLocationError != nil {
            return Color(red: 0.70, green: 0.16, blue: 0.12)
        }
        if viewModel.isUsingLiveDistance {
            return Color(red: 0.06, green: 0.56, blue: 0.24)
        }
        if viewModel.canUseLiveDistance {
            return Color(red: 0.76, green: 0.48, blue: 0.11)
        }
        return .gray
    }

    private var liveDistanceStatusText: String {
        if let autoDetectedHoleNumber = viewModel.autoDetectedHoleNumber,
           viewModel.isUsingLiveDistance {
            return "Hole \(autoDetectedHoleNumber) auto-detected • \(viewModel.liveLocationStatus)"
        }

        return viewModel.liveLocationStatus
    }

    private func logAction(_ action: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: Date())
        actionLogs.append("[\(timeString)] \(action)")
        if actionLogs.count > 20 {
            actionLogs.removeFirst()
        }
    }

    private func copyDebugReport() {
        let export = buildDebugExport()
        UIPasteboard.general.string = export
        debugCopyConfirmation = "Copied debug report"
        logAction("Copied debug report to clipboard.")
    }

    private func buildDebugExport() -> String {
        let actionSection = actionLogs.joined(separator: "\n")
        if actionSection.isEmpty {
            return viewModel.debugExportText
        }

        return """
        \(viewModel.debugExportText)

        Activity History
        \(actionSection)
        """
    }

    private func quickUpdateTitle(for viewState: CaddieViewState) -> String {
        switch viewState.kind {
        case .onGreen:
            return "Finish the hole"
        case .ready, .missingContext:
            return "After the shot"
        case .noCourseLoaded, .unavailable, .holeComplete, .roundComplete:
            return "Shot updates"
        }
    }

    private func statusEyebrow(for kind: CaddieViewState.Kind) -> String {
        switch kind {
        case .ready:
            return "Recommendation"
        case .noCourseLoaded:
            return "Setup"
        case .missingContext:
            return "Needs detail"
        case .unavailable:
            return "Unavailable"
        case .onGreen:
            return "On the green"
        case .holeComplete:
            return "Hole finished"
        case .roundComplete:
            return "Round complete"
        }
    }

    private func statusColor(for kind: CaddieViewState.Kind) -> Color {
        switch kind {
        case .ready:
            return Color(red: 0.06, green: 0.44, blue: 0.20)
        case .noCourseLoaded:
            return Color(red: 0.34, green: 0.36, blue: 0.39)
        case .missingContext:
            return Color(red: 0.77, green: 0.43, blue: 0.10)
        case .unavailable:
            return Color(red: 0.70, green: 0.16, blue: 0.12)
        case .onGreen:
            return Color(red: 0.13, green: 0.49, blue: 0.28)
        case .holeComplete, .roundComplete:
            return Color(red: 0.05, green: 0.38, blue: 0.19)
        }
    }
}

private struct CaddiePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.06, green: 0.56, blue: 0.24), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct CaddiePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
            .padding(.vertical, 14)
            .background(.white.opacity(configuration.isPressed ? 0.65 : 0.86), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct CaddieIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.05, green: 0.38, blue: 0.19))
            .background(.white.opacity(configuration.isPressed ? 0.65 : 0.86), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

#Preview("Ready") {
    CaddieScreen(viewModel: .sample())
}

#Preview("No course") {
    CaddieScreen(viewModel: .noCourseLoaded())
}

#Preview("Missing distance") {
    CaddieScreen(viewModel: .missingDistance())
}

#Preview("Missing lie") {
    CaddieScreen(viewModel: .missingLie())
}

#Preview("On green") {
    CaddieScreen(viewModel: .onGreen())
}

#Preview("Hole complete") {
    CaddieScreen(viewModel: .holeComplete())
}

#Preview("Round complete") {
    CaddieScreen(viewModel: .roundComplete())
}
