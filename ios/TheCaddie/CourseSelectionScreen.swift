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

    private var featuredCourse: Course? {
        courses.first
    }
    
    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        welcomeHeader

                        if let activeCourse = viewModel.course {
                            activeRoundPanel(for: activeCourse)
                        }

                        if let featuredCourse {
                            closestCoursePanel(for: featuredCourse)
                        }

                        readinessStrip

                        Text("All Courses")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundColor(.primary)
                        
                        ForEach(courses, id: \.id) { course in
                            courseRow(for: course)
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Courses")
            .sheet(item: $selectedCourse) { course in
                setupWizardView(for: course)
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The Caddie")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            Text("Start a round, confirm your setup, then let the caddie brain stay grounded in the course map.")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(.top, 4)
    }

    private var readinessStrip: some View {
        HStack(spacing: 10) {
            readinessPill(
                icon: "location.fill",
                title: "GPS",
                value: viewModel.course == nil ? "Starts with round" : viewModel.liveStatusBadgeLabel ?? "Ready"
            )
            readinessPill(
                icon: "person.fill",
                title: "Player",
                value: String(format: "%.1f hcp", viewModel.player.handicapIndex ?? 18.0)
            )
            readinessPill(
                icon: "slider.horizontal.3",
                title: "Mode",
                value: viewModel.player.strategyPreference.rawValue.capitalized
            )
        }
    }

    private func readinessPill(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))

            Text(title)
                .font(.system(size: 9, design: .rounded).weight(.black))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.86))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }

    private func activeRoundPanel(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Active round", systemImage: "flag.fill")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))

            Text(course.name)
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
        .padding(18)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func closestCoursePanel(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Suggested mapped course", systemImage: "location.circle.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))

                Spacer()

                Text(mappedStatus(for: course))
                    .font(.system(size: 10, design: .rounded).weight(.black))
                    .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.12))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(course.name)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)

                Text(courseSummary(for: course))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                courseMetric(label: "Holes", value: "\(course.holes.count)")
                courseMetric(label: "Par", value: "\(totalPar(for: course))")
                courseMetric(label: "Mapped", value: "\(mappedHoleCount(for: course))")
            }

            Button(action: {
                prepareSetup(for: course)
            }) {
                Text("Start Round")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(red: 0.06, green: 0.56, blue: 0.24))
                    .cornerRadius(14)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.92))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    private func courseMetric(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundColor(Color(red: 0.05, green: 0.38, blue: 0.19))

            Text(label)
                .font(.system(size: 9, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.04))
        .cornerRadius(10)
    }

    private func courseRow(for course: Course) -> some View {
        let holeCountText = "\(course.holes.count) Holes"
        let totalPar = course.holes.reduce(0) { $0 + $1.par }
        let parText = "Par \(totalPar)"

        return Button(action: {
            prepareSetup(for: course)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(holeCountText, systemImage: "flag")
                        Label(parText, systemImage: "sparkles")
                        Label(mappedStatus(for: course), systemImage: "location")
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

    private func prepareSetup(for course: Course) {
        handicap = viewModel.player.handicapIndex ?? 18.0
        strategyPreference = viewModel.player.strategyPreference
        voiceToggle = viewModel.isHandsFreeListening
        selectedCourse = course
    }

    private func totalPar(for course: Course) -> Int {
        course.holes.reduce(0) { $0 + $1.par }
    }

    private func mappedHoleCount(for course: Course) -> Int {
        course.holes.filter { hole in
            hole.green.centerCoordinate != nil
                && !hole.centerlineCoordinates.isEmpty
        }.count
    }

    private func mappedStatus(for course: Course) -> String {
        let mappedCount = mappedHoleCount(for: course)
        return mappedCount == course.holes.count
            ? "GPS mapped"
            : "\(mappedCount)/\(course.holes.count) mapped"
    }

    private func courseSummary(for course: Course) -> String {
        "\(course.holes.count) holes - Par \(totalPar(for: course)) - \(mappedStatus(for: course))"
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
