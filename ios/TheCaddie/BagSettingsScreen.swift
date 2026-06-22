import SwiftUI

struct BagSettingsScreen: View {
    @ObservedObject var viewModel: CaddieViewModel
    @State private var editingClub: PlayerClub?
    @State private var editDistanceM = 150.0
    @State private var isShowingClubPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.98, blue: 0.93),
                        Color(red: 0.98, green: 0.96, blue: 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Player Context Section
                        playerContextCard()
                        
                        // Clubs List
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clubs in Bag")
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.player.clubs.count) clubs active")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    isShowingClubPicker = true
                                }) {
                                    Label("Add Club", systemImage: "plus")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.95))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 4)

                            ForEach(viewModel.player.clubs) { club in
                                clubRow(club)
                            }
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("My Bag")
            .sheet(item: $editingClub) { club in
                clubEditorView(for: club)
            }
            .sheet(isPresented: $isShowingClubPicker) {
                clubPickerView()
            }
        }
    }
    
    // Player Context Dashboard Card
    private func playerContextCard() -> some View {
        let currentHandicap = viewModel.player.handicapIndex ?? 18.0
        let skillProfile = viewModel.player.skillProfile
        
        return VStack(spacing: 20) {
            Text("Player Profile")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Handicap Stepper
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Handicap Index")
                        .font(.system(.body, design: .rounded).bold())
                    Text(String(format: "Dispersion multiplier: %.2fx", skillProfile.dispersionMultiplier))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        let current = viewModel.player.handicapIndex ?? 0.0
                        viewModel.updatePlayerHandicap(max(0, current - 0.5))
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                    }
                    
                    Text(String(format: "%.1f", currentHandicap))
                        .font(.system(.title3, design: .rounded).bold())
                        .frame(width: 48)
                    
                    Button(action: {
                        let current = viewModel.player.handicapIndex ?? 0.0
                        viewModel.updatePlayerHandicap(min(54, current + 0.5))
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                    }
                }
            }
            
            Divider()
            
            // Strategy Preference Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Strategy Aggressiveness")
                    .font(.system(.body, design: .rounded).bold())
                
                Picker("Strategy", selection: Binding<StrategyPreference>(
                    get: { viewModel.player.strategyPreference },
                    set: { viewModel.updateStrategyPreference($0) }
                )) {
                    Text("Safe").tag(StrategyPreference.safe)
                    Text("Normal").tag(StrategyPreference.normal)
                    Text("Aggressive").tag(StrategyPreference.aggressive)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding(20)
        .background(Color(white: 1.0).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private var availableStandardClubs: [StandardBagClub] {
        StandardBagCatalog.clubs.filter { standardClub in
            !viewModel.player.clubs.contains(where: { $0.name == standardClub.name })
        }
    }

    private func clubRow(_ club: PlayerClub) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)

                let multiplier = viewModel.player.skillProfile.dispersionMultiplier
                let baseDisp = club.typicalDispersionM ?? (club.carryDistanceM * 0.08)
                let spread = baseDisp * multiplier

                Text("Estimated dispersion: ±\(Int(spread))m")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(club.carryDistanceM))m")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))

            Button(action: {
                editDistanceM = club.carryDistanceM
                editingClub = club
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                    .frame(width: 34, height: 34)
                    .background(Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                viewModel.removeClub(named: club.name)
            }) {
                Image(systemName: "minus")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(Color(red: 0.70, green: 0.16, blue: 0.12))
                    .frame(width: 34, height: 34)
                    .background(Color(red: 0.70, green: 0.16, blue: 0.12).opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color(white: 1.0).opacity(0.95))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private func clubPickerView() -> some View {
        NavigationView {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add standard clubs that match your real bag. You can fine-tune the carry distance after adding them.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)

                        if availableStandardClubs.isEmpty {
                            Text("All standard clubs are already in your bag.")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundColor(.secondary)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.95))
                                .cornerRadius(16)
                        } else {
                            ForEach(availableStandardClubs) { standardClub in
                                Button(action: {
                                    viewModel.addClub(named: standardClub.name)
                                    isShowingClubPicker = false
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(standardClub.name)
                                                .font(.system(.body, design: .rounded).weight(.bold))
                                                .foregroundColor(.primary)
                                            Text("Default carry \(Int(standardClub.defaultCarryDistanceM))m")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.95))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Add Club")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isShowingClubPicker = false
                    }
                }
            }
        }
    }
    
    // Club Editor Sheet view
    private func clubEditorView(for club: PlayerClub) -> some View {
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
            
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Edit Club Carry")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        editingClub = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(club.name)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stock Carry Distance")
                        .font(.system(.headline, design: .rounded))
                    
                    HStack {
                        Slider(value: $editDistanceM, in: 40...320, step: 1)
                            .accentColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                        
                        Text("\(Int(editDistanceM))m")
                            .font(.system(.title3, design: .rounded).bold())
                            .frame(width: 60, alignment: .trailing)
                    }
                    
                    Text("Enter the average carry distance for this club under normal, flat, and windless conditions. The caddie will adjust this playing distance for wind, slope, and lie during your round.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.updateClubDistance(clubName: club.name, distanceM: editDistanceM)
                    editingClub = nil
                }) {
                    Text("Save Club Distance")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.06, green: 0.56, blue: 0.24))
                        .cornerRadius(14)
                }
            }
            .padding(24)
        }
    }
}
