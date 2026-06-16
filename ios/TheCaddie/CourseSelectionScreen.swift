import SwiftUI

struct CourseSelectionScreen: View {
    @ObservedObject var viewModel: CaddieViewModel
    @State private var selectedCourse: Course?
    
    // Setup state
    @State private var selectedTee = "Standard"
    @State private var handicap = 18.0
    @State private var strategyPreference: StrategyPreference = .normal
    @State private var voiceToggle = false
    
    private let courses: [Course] = [
        KungsbackaNyaCourse.course,
        SampleRound.course
    ]
    
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
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Active Round Panel
                        if let activeCourse = viewModel.course {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "flag.fill")
                                        .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                                    Text("ACTIVE ROUND")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                                }
                                
                                Text(activeCourse.name)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Text("Currently playing Hole \(viewModel.selectedHoleNumber)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    viewModel.endRound()
                                }) {
                                    Text("End Active Round")
                                        .font(.system(.body, design: .rounded).bold())
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(20)
                            .background(Color(white: 1.0).opacity(0.9))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        }
                        
                        Text("Available Courses")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)
                        
                        ForEach(courses, id: \.id) { course in
                            courseRow(for: course)
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Select Course")
            .sheet(item: $selectedCourse) { course in
                setupWizardView(for: course)
            }
        }
    }

    private func courseRow(for course: Course) -> some View {
        let holeCountText = "\(course.holes.count) Holes"
        let totalPar = course.holes.reduce(0) { $0 + $1.par }
        let parText = "Par \(totalPar)"

        return Button(action: {
            // Initialize local setup state from current view model values
            handicap = viewModel.player.handicapIndex ?? 18.0
            strategyPreference = viewModel.player.strategyPreference
            voiceToggle = viewModel.isHandsFreeListening
            selectedCourse = course
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(holeCountText, systemImage: "flag")
                        Label(parText, systemImage: "sparkles")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
            }
            .padding(20)
            .background(Color(white: 1.0).opacity(0.9))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }
    
    private func setupWizardView(for course: Course) -> some View {
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
                    Text("Round Setup")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        selectedCourse = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(course.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Tee Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECT TEE")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            Picker("Tee", selection: $selectedTee) {
                                Text("Gold (Back)").tag("Gold")
                                Text("Blue (Standard)").tag("Standard")
                                Text("Red (Forward)").tag("Red")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Handicap Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("PLAYER HANDICAP")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f", handicap))
                                    .font(.system(.body, design: .rounded).bold())
                                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                            }
                            
                            Slider(value: $handicap, in: 0...54, step: 0.1)
                                .accentColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                        }
                        
                        // Strategy Preference
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STRATEGY MODE")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            
                            Picker("Strategy", selection: $strategyPreference) {
                                Text("Safe").tag(StrategyPreference.safe)
                                Text("Normal").tag(StrategyPreference.normal)
                                Text("Aggressive").tag(StrategyPreference.aggressive)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Hands-free voice toggle
                        Toggle(isOn: $voiceToggle) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hands-Free Voice Control")
                                    .font(.system(.body, design: .rounded).bold())
                                Text("Listen for ambient updates on-course")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.06, green: 0.56, blue: 0.24)))
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Update settings on view model
                    viewModel.updatePlayerHandicap(handicap)
                    viewModel.updateStrategyPreference(strategyPreference)
                    viewModel.isHandsFreeListening = voiceToggle
                    
                    // Start Round
                    viewModel.startRound(course: course, startingHole: 1)
                    selectedCourse = nil
                }) {
                    Text("Start Round")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.06, green: 0.56, blue: 0.24))
                        .cornerRadius(14)
                        .shadow(color: Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(24)
        }
    }
}

extension Course: Identifiable {
    // Already conforms to Equatable, let's satisfy Identifiable
}
