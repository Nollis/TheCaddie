import SwiftUI
import TheCaddieDomain

struct CaddieScreen: View {
    @StateObject var viewModel: CaddieViewModel

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

            VStack(alignment: .leading, spacing: 22) {
                header(viewState)
                recommendationCard(viewState)
                quickUpdates(viewState)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
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
            }

            Spacer()

            Text(viewState.distanceLabel)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.78), in: Capsule())
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
            Text("After the shot")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.black)

            HStack(spacing: 10) {
                quickUpdateButton("Fairway", lie: .fairway)
                quickUpdateButton("Rough", lie: .rough)
                quickUpdateButton("Bunker", lie: .bunker)
            }
            .opacity(viewState.quickUpdateLabels.isEmpty ? 0.35 : 1)
            .disabled(viewState.quickUpdateLabels.isEmpty)
        }
    }

    private func quickUpdateButton(_ label: String, lie: ShotLie) -> some View {
        Button {
            viewModel.markLie(lie)
        } label: {
            Text(label)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CaddiePillButtonStyle())
    }

    private func handlePrimaryAction() {
        switch viewModel.packet.status {
        case .noCourseLoaded:
            viewModel.loadSample()
        case .missingDistance:
            viewModel.addDistance(142)
        case .missingLie:
            viewModel.markLie(.fairway)
        case .ready, .unknownHole, .unavailable:
            break
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
