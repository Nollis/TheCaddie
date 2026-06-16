import SwiftUI

struct CaddieScreen: View {
    @StateObject var viewModel: CaddieViewModel
    
    @State private var showDebugDrawer = false
    @State private var puttCount = 2
    @State private var actionLogs: [String] = ["Caddie screen loaded and ready."]

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
                    Button(action: {
                        showDebugDrawer = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Calculation Metrics Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation Metrics")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                metricItem(label: "GPS Distance", value: viewModel.packet.remainingDistanceM != nil ? "\(Int(viewModel.packet.remainingDistanceM!))m" : "--")
                                Spacer()
                                metricItem(label: "Wind", value: viewModel.roundState.currentShotContext()?.wind?.direction.rawValue.capitalized ?? "None")
                                Spacer()
                                metricItem(label: "Adjusted Basis", value: viewModel.packet.distanceBasisM != nil ? "\(Int(viewModel.packet.distanceBasisM!))m" : "--")
                                Spacer()
                                metricItem(label: "Dispersion Spread", value: viewModel.packet.expectedDispersionM != nil ? "±\(Int(viewModel.packet.expectedDispersionM!))m" : "--")
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        
                        // Risk Budgets Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Club Risk Evaluation")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            let currentLie = viewModel.roundState.currentShotContext()?.lie.value ?? .tee
                            let isOffFairway = currentLie != .tee && currentLie != .fairway
                            
                            ForEach(viewModel.player.clubs) { club in
                                HStack {
                                    Text(club.name)
                                        .font(.system(.subheadline, design: .rounded).bold())
                                    Spacer()
                                    Text("\(Int(club.carryDistanceM))m carry")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                    
                                    // Calculate simple visual risk
                                    let isDriver = club.name.lowercased().contains("driver")
                                    let tooLong = viewModel.packet.remainingDistanceM != nil && club.carryDistanceM > (viewModel.packet.remainingDistanceM! + 30)
                                    let exceedsBudget = (isDriver && isOffFairway) || tooLong
                                    
                                    if exceedsBudget {
                                        Text("EXCEEDS RISK BUDGET")
                                            .font(.system(.system(size: 8), design: .rounded).bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.red.opacity(0.1))
                                            .foregroundColor(.red)
                                            .cornerRadius(4)
                                    } else {
                                        let riskVal = isDriver ? 65 : (isOffFairway ? 45 : 20)
                                        Text("\(riskVal)% risk")
                                            .font(.system(.caption2, design: .rounded).bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.green.opacity(0.1))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 4)
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
                                        .font(.system(.system(size: 11), design: .monospaced))
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
                .font(.system(.system(size: 8), design: .rounded))
                .foregroundColor(.secondary)
        }
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
