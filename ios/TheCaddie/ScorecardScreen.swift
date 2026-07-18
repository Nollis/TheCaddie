import SwiftUI

struct ScorecardScreen: View {
    @ObservedObject var viewModel: CaddieViewModel
    @State private var editingHoleNumber: Int?
    
    // Edit state
    @State private var editStrokes = 4
    @State private var editPutts = 2
    @State private var editFairwayHit: Bool? = true
    @State private var editGIR = true
    
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
                
                if let course = viewModel.course {
                    ScrollView {
                        VStack(spacing: 20) {
                            roundSnapshot(course: course)
                            
                            // Stats Dashboard Panel
                            statsDashboard(course: course)
                            
                            // Scorecard Grid
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Hole by Hole")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                
                                ForEach(course.holes) { hole in
                                    let score = viewModel.roundState.holeScores[hole.number]
                                    let isCurrentHole = hole.number == viewModel.selectedHoleNumber
                                    let isComplete = viewModel.roundState.completedHoleNumbers.contains(hole.number)
                                    
                                    Button(action: {
                                        prepareEdit(for: hole.number, defaultPar: hole.par, defaultFairway: hole.par > 3)
                                    }) {
                                        HStack(spacing: 12) {
                                            // Hole ID
                                            Text("\(hole.number)")
                                                .font(.system(.headline, design: .rounded).bold())
                                                .frame(width: 30, height: 30)
                                                .background(Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.1))
                                                .foregroundColor(Color(red: 0.06, green: 0.56, blue: 0.24))
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Par \(hole.par) • \(Int(hole.teeLengthM))m")
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundColor(.secondary)

                                                Text(holeStatusLabel(isCurrentHole: isCurrentHole, isComplete: isComplete))
                                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                                    .foregroundColor(holeStatusColor(isCurrentHole: isCurrentHole, isComplete: isComplete))
                                            }
                                            
                                            Spacer()
                                            
                                            if let score = score {
                                                // Badges for FIR/GIR
                                                HStack(spacing: 6) {
                                                    if score.fairwayHit == true {
                                                        Text("FIR")
                                                            .font(.system(.caption2, design: .rounded).bold())
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue.opacity(0.1))
                                                            .foregroundColor(.blue)
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    if score.greenInRegulation {
                                                        Text("GIR")
                                                            .font(.system(.caption2, design: .rounded).bold())
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.purple.opacity(0.1))
                                                            .foregroundColor(.purple)
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text("\(score.strokes)")
                                                            .font(.system(.title3, design: .rounded).weight(.bold))
                                                            .foregroundColor(strokeColor(strokes: score.strokes, par: hole.par))

                                                        Text(scoreRelativeToPar(score.strokes, par: hole.par))
                                                            .font(.system(.caption2, design: .rounded).weight(.bold))
                                                            .foregroundColor(strokeColor(strokes: score.strokes, par: hole.par))
                                                        
                                                        Text("\(score.putts) \(score.putts == 1 ? "putt" : "putts")")
                                                            .font(.system(.caption2, design: .rounded))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            } else {
                                                Text("-")
                                                    .font(.system(.headline, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 4)
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .background(
                                            isCurrentHole
                                                ? Color(red: 0.06, green: 0.56, blue: 0.24).opacity(0.08)
                                                : Color(white: 1.0).opacity(0.9)
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(22)
                    }
                } else {
                    // Empty state when no course is active
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Active Round")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Select a course and start a round to see your scorecard and statistics.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Scorecard")
            .sheet(item: Binding<HoleEditWrapper?>(
                get: { editingHoleNumber.map { HoleEditWrapper(holeNumber: $0) } },
                set: { editingHoleNumber = $0?.holeNumber }
            )) { wrapper in
                scoreEditorView(holeNumber: wrapper.holeNumber)
            }
        }
    }
    
    // Stats Dashboard Component
    private func roundSnapshot(course: Course) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("Current hole \(viewModel.selectedHoleNumber)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ROUND")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text("\(viewModel.roundState.completedHoleNumbers.count) / \(course.holes.count)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
            }

            HStack(spacing: 10) {
                snapshotPill(label: "GPS", value: viewModel.liveStatusBadgeLabel ?? "Unavailable")
                if let fixAge = viewModel.liveFixAgeLabel, viewModel.isUsingLiveDistance {
                    snapshotPill(label: "Fix", value: fixAge)
                }
                if let distance = viewModel.packet.remainingDistanceM {
                    snapshotPill(label: "Yardage", value: "\(Int(distance.rounded()))m")
                }
                if let lie = viewModel.packet.lie {
                    snapshotPill(label: "Lie", value: lie.rawValue.capitalized)
                }
            }
        }
        .padding(20)
        .background(Color(white: 1.0).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func statsDashboard(course: Course) -> some View {
        let scores = viewModel.roundState.holeScores.values
        let completedCount = scores.count
        
        let totalStrokes = scores.map(\.strokes).reduce(0, +)
        let totalPar = course.holes.filter { viewModel.roundState.holeScores[$0.number] != nil }.map(\.par).reduce(0, +)
        let diff = totalStrokes - totalPar
        let diffText = diff == 0 ? "E" : (diff > 0 ? "+\(diff)" : "\(diff)")
        
        let totalPutts = scores.map(\.putts).reduce(0, +)
        let avgPutts = completedCount > 0 ? Double(totalPutts) / Double(completedCount) : 0.0
        
        let firHoles = scores.filter { $0.fairwayHit != nil }
        let firHits = firHoles.filter { $0.fairwayHit == true }.count
        let firPct = firHoles.count > 0 ? Double(firHits) / Double(firHoles.count) * 100.0 : 0.0
        
        let girHits = scores.filter { $0.greenInRegulation }.count
        let girPct = completedCount > 0 ? Double(girHits) / Double(completedCount) * 100.0 : 0.0
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ROUND SCORE")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text("\(totalStrokes) (\(diffText))")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundColor(diff > 0 ? .red : (diff < 0 ? .blue : .primary))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("COMPLETED")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text("\(completedCount) / \(course.holes.count) Holes")
                        .font(.system(.body, design: .rounded).bold())
                }
            }
            .padding(.bottom, 8)
            
            Divider()
            
            HStack(spacing: 12) {
                // Putts
                VStack(spacing: 4) {
                    Text("PUTTS")
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", avgPutts))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("Avg per hole")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.02))
                .cornerRadius(10)
                
                // FIR
                VStack(spacing: 4) {
                    Text("FIR")
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", firPct))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.blue)
                    Text("Fairways Hit")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.02))
                .cornerRadius(10)
                
                // GIR
                VStack(spacing: 4) {
                    Text("GIR")
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", girPct))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.purple)
                    Text("Greens Hit")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.02))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(white: 1.0).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    // Score editor sheet
    private func scoreEditorView(holeNumber: Int) -> some View {
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
                    Text("Edit Hole \(holeNumber) Score")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        editingHoleNumber = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    // Strokes Stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Strokes")
                                .font(.system(.headline, design: .rounded))
                            Text("Total shots taken on this hole")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Stepper(
                            "\(editStrokes)",
                            value: $editStrokes,
                            in: 1...max(30, editStrokes)
                        )
                            .labelsHidden()
                        Text("\(editStrokes)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .frame(width: 32)
                    }
                    
                    // Putts Stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Putts")
                                .font(.system(.headline, design: .rounded))
                            Text("Shots taken on the putting green")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Stepper(
                            "\(editPutts)",
                            value: $editPutts,
                            in: GreenCompletionScoring.supportedPutts
                        )
                            .labelsHidden()
                        Text("\(editPutts)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .frame(width: 32)
                    }
                    
                    Divider()
                    
                    // Fairway Hit Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fairway Hit")
                            .font(.system(.headline, design: .rounded))
                        Text("Tee shot outcome (Par 4s and 5s)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Button(action: { editFairwayHit = true }) {
                                Text("Hit")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(editFairwayHit == true ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(editFairwayHit == true ? Color.blue : Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: { editFairwayHit = false }) {
                                Text("Miss")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(editFairwayHit == false ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(editFairwayHit == false ? Color.red : Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: { editFairwayHit = nil }) {
                                Text("N/A")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(editFairwayHit == nil ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(editFairwayHit == nil ? Color.gray : Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // GIR Toggle
                    Toggle(isOn: $editGIR) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Green in Regulation (GIR)")
                                .font(.system(.headline, design: .rounded))
                            Text("Reached putting green in Par - 2 strokes")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.06, green: 0.56, blue: 0.24)))
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.updateHoleScore(
                        holeNumber: holeNumber,
                        strokes: editStrokes,
                        putts: editPutts,
                        fairwayHit: editFairwayHit,
                        gir: editGIR
                    )
                    editingHoleNumber = nil
                }) {
                    Text("Save Changes")
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
    
    private func prepareEdit(for holeNumber: Int, defaultPar: Int, defaultFairway: Bool) {
        if let score = viewModel.roundState.holeScores[holeNumber] {
            editStrokes = score.strokes
            editPutts = score.putts
            editFairwayHit = score.fairwayHit
            editGIR = score.greenInRegulation
        } else {
            editStrokes = defaultPar
            editPutts = 2
            editFairwayHit = defaultFairway ? true : nil
            editGIR = true
        }
        editingHoleNumber = holeNumber
    }
    
    private func strokeColor(strokes: Int, par: Int) -> Color {
        let diff = strokes - par
        if diff == 0 {
            return .primary
        } else if diff == -1 {
            return .blue // Birdie
        } else if diff <= -2 {
            return .cyan // Eagle or better
        } else if diff == 1 {
            return .orange // Bogey
        } else {
            return .red // Double Bogey or worse
        }
    }

    private func scoreRelativeToPar(_ strokes: Int, par: Int) -> String {
        let diff = strokes - par
        if diff == 0 {
            return "E"
        }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func holeStatusLabel(isCurrentHole: Bool, isComplete: Bool) -> String {
        if isCurrentHole && !isComplete {
            return "Playing now"
        }
        if isComplete {
            return "Finished"
        }
        return "Not started"
    }

    private func holeStatusColor(isCurrentHole: Bool, isComplete: Bool) -> Color {
        if isCurrentHole && !isComplete {
            return Color(red: 0.06, green: 0.56, blue: 0.24)
        }
        if isComplete {
            return .secondary
        }
        return Color(red: 0.76, green: 0.48, blue: 0.11)
    }

    private func snapshotPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.03))
        .cornerRadius(10)
    }
}

// Wrapper for Identifiable sheet binding
struct HoleEditWrapper: Identifiable {
    let holeNumber: Int
    var id: Int { holeNumber }
}
