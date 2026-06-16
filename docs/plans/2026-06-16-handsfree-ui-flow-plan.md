# Hands-Free & Manual UI Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a cohesive Tab-based iOS navigation system for The Caddie that supports a hands-free on-course flow, manual backup entry, scorecard history (with putts/FIR/GIR), course setup, club settings, and an on-course decision debugging log.

**Architecture:** Extend the domain models to store hole-by-hole scores, putts, and statistics, updating them automatically during hands-free play. Introduce a TabView-based app shell in SwiftUI with tabs for Caddie (current shot + debug drawer), Scorecard (interactive scorecard + stats), Bag (handicap + club editor), and Course Selection (setup wizard).

**Tech Stack:** Swift 6, SwiftUI, Combine, TheCaddieDomain package.

---

### Task 1: Extend Domain Models for Scoring & Statistics

**Files:**
- Create: `Sources/TheCaddieDomain/Models/HoleScore.swift`
- Modify: `Sources/TheCaddieDomain/Models/RoundState.swift`
- Test: `Tests/TheCaddieDomainTests/DomainModelTests.swift`

**Step 1: Write the failing test**

Add to `Tests/TheCaddieDomainTests/DomainModelTests.swift`:

```swift
@Test func roundStateTracksHoleScoresAndStats() {
    let holeScore = HoleScore(
        holeNumber: 1,
        strokes: 4,
        putts: 2,
        fairwayHit: true,
        greenInRegulation: true
    )
    
    let roundState = RoundState(
        courseId: "sample",
        selectedHoleNumber: 1,
        shotContexts: [:],
        completedHoleNumbers: [1],
        holeScores: [1: holeScore]
    )
    
    #expect(roundState.holeScores[1]?.strokes == 4)
    #expect(roundState.holeScores[1]?.putts == 2)
    #expect(roundState.holeScores[1]?.fairwayHit == true)
    #expect(roundState.holeScores[1]?.greenInRegulation == true)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter roundStateTracksHoleScoresAndStats`
Expected: FAIL to compile (HoleScore undefined, RoundState has no holeScores property or init parameter).

**Step 3: Implement HoleScore and extend RoundState**

Create `Sources/TheCaddieDomain/Models/HoleScore.swift`:

```swift
import Foundation

public struct HoleScore: Equatable, Sendable {
    public let holeNumber: Int
    public let strokes: Int
    public let putts: Int
    public let fairwayHit: Bool?  // nil for par 3s
    public let greenInRegulation: Bool

    public init(
        holeNumber: Int,
        strokes: Int,
        putts: Int,
        fairwayHit: Bool?,
        greenInRegulation: Bool
    ) {
        self.holeNumber = holeNumber
        self.strokes = strokes
        self.putts = putts
        self.fairwayHit = fairwayHit
        self.greenInRegulation = greenInRegulation
    }
}
```

Modify `Sources/TheCaddieDomain/Models/RoundState.swift` to include `holeScores`:

```swift
public struct RoundState: Equatable, Sendable {
    public let courseId: String
    public let selectedHoleNumber: Int
    public let shotContexts: [Int: ShotContext]
    public let completedHoleNumbers: Set<Int>
    public let holeScores: [Int: HoleScore] // NEW

    public init(
        courseId: String,
        selectedHoleNumber: Int,
        shotContexts: [Int: ShotContext],
        completedHoleNumbers: Set<Int> = [],
        holeScores: [Int: HoleScore] = [:] // NEW
    ) {
        self.courseId = courseId
        self.selectedHoleNumber = selectedHoleNumber
        self.shotContexts = shotContexts
        self.completedHoleNumbers = completedHoleNumbers
        self.holeScores = holeScores
    }
```

Also modify the initializer and existing methods (`selectHole`, `updateShotContext`, `recordShotResult`, `finishCurrentHole`) in `RoundState.swift` to pass `holeScores` along when returning copies of `RoundState`.

Implement automatic score compilation on hole completion in `finishCurrentHole`:
```swift
    public func finishCurrentHole(
        course: Course?,
        strokes: Int? = nil,
        putts: Int? = nil,
        fairwayHit: Bool? = nil,
        greenInRegulation: Bool? = nil
    ) -> RoundState {
        guard let course,
              let hole = course.hole(number: selectedHoleNumber) else {
            return self
        }

        var completed = completedHoleNumbers
        completed.insert(selectedHoleNumber)

        var updatedScores = holeScores
        
        // Calculate defaults from shot history if not manually provided
        let finalStrokes: Int
        let finalPutts: Int
        let finalFairwayHit: Bool?
        let finalGIR: Bool
        
        if let manualStrokes = strokes, let manualPutts = putts {
            finalStrokes = manualStrokes
            finalPutts = manualPutts
            finalFairwayHit = fairwayHit
            finalGIR = greenInRegulation ?? false
        } else {
            // Find all shots tracked for this hole
            let shots = shotContexts.filter { $0.key == selectedHoleNumber }
            // Stroke count defaults to last shot number or 1 if empty
            let lastShotNumber = shotContexts[selectedHoleNumber]?.shotNumber ?? 1
            finalStrokes = lastShotNumber
            
            // Reconstructed putts: count shots where lie was .green
            // In a real app, this is determined by counting shot contexts with lie == .green
            // We assume a simple default of 2 putts if on green, or 1 if holed from off green.
            let reachedGreen = shotContexts[selectedHoleNumber]?.lie.value == .green
            finalPutts = reachedGreen ? 2 : 1
            
            // FIR: True if second shot was from fairway on a Par 4/5
            finalFairwayHit = hole.par > 3 ? true : nil
            
            // GIR: reached green in Par - 2
            finalGIR = finalStrokes - finalPutts <= (hole.par - 2)
        }
        
        updatedScores[selectedHoleNumber] = HoleScore(
            holeNumber: selectedHoleNumber,
            strokes: finalStrokes,
            putts: finalPutts,
            fairwayHit: finalFairwayHit,
            greenInRegulation: finalGIR
        )

        let nextHoleNumber = course.nextHole(after: selectedHoleNumber)?.number
            ?? selectedHoleNumber

        return RoundState(
            courseId: courseId,
            selectedHoleNumber: nextHoleNumber,
            shotContexts: shotContexts,
            completedHoleNumbers: completed,
            holeScores: updatedScores
        )
    }
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter roundStateTracksHoleScoresAndStats`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/TheCaddieDomain/Models/HoleScore.swift Sources/TheCaddieDomain/Models/RoundState.swift Tests/TheCaddieDomainTests/DomainModelTests.swift
git commit -m "feat: Extend domain models to track hole scorecard, strokes, and putts"
```

---

### Task 2: Build Course Selection & Setup Screen

**Files:**
- Create: `ios/TheCaddie/CourseSelectionScreen.swift`
- Modify: `ios/TheCaddie/CaddieViewModel.swift`

**Step 1: Write View Model tests for course management**

Add to `Tests/TheCaddieDomainTests/CaddieViewModelTests.swift` (create file if it doesn't exist, or verify package tests):

```swift
@Test func viewModelCanStartAndResetRounds() {
    let vm = CaddieViewModel(course: nil, player: SampleRound.player, roundState: SampleRound.roundState)
    #expect(vm.course == nil)
    
    vm.startRound(course: KungsbackaNyaCourse.course, startingHole: 1)
    #expect(vm.course?.id == KungsbackaNyaCourse.course.id)
    #expect(vm.selectedHoleNumber == 1)
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL (no `startRound` method on view model).

**Step 3: Implement view model updates**

In `ios/TheCaddie/CaddieViewModel.swift`, add:

```swift
    func startRound(course: Course, startingHole: Int = 1) {
        self.course = course
        self.roundState = RoundState(
            courseId: course.id,
            selectedHoleNumber: startingHole,
            shotContexts: [
                startingHole: ShotContext(
                    shotNumber: 1,
                    remainingDistanceM: .known(course.hole(number: startingHole)?.teeLengthM ?? 300),
                    lie: .known(.tee),
                    wind: nil
                )
            ]
        )
    }
    
    func endRound() {
        self.course = nil
        self.roundState = SampleRound.roundState
    }
```

**Step 4: Create Course Selection Screen UI**

Create `ios/TheCaddie/CourseSelectionScreen.swift`:
- Lists available courses (from a courses registry or sample database).
- Displays a wizard when a course is tapped.
- Configuration options: Tee selection, Player handicap adjustment, strategy preference, and hands-free voice toggle.
- Button to "Start Round" which calls `viewModel.startRound(...)`.

**Step 5: Verify tests and commit**

Run: `swift test`
Expected: PASS

```bash
git add ios/TheCaddie/CourseSelectionScreen.swift ios/TheCaddie/CaddieViewModel.swift
git commit -m "feat: Add course selection screen and view model actions"
```

---

### Task 3: Build scorecard & stats screen

**Files:**
- Create: `ios/TheCaddie/ScorecardScreen.swift`
- Modify: `ios/TheCaddie/CaddieViewModel.swift`

**Step 1: Add manual scorecard override to ViewModel**

In `ios/TheCaddie/CaddieViewModel.swift`, add:

```swift
    func updateHoleScore(holeNumber: Int, strokes: Int, putts: Int, fairwayHit: Bool?, gir: Bool) {
        var updatedScores = roundState.holeScores
        updatedScores[holeNumber] = HoleScore(
            holeNumber: holeNumber,
            strokes: strokes,
            putts: putts,
            fairwayHit: fairwayHit,
            greenInRegulation: gir
        )
        self.roundState = RoundState(
            courseId: roundState.courseId,
            selectedHoleNumber: roundState.selectedHoleNumber,
            shotContexts: roundState.shotContexts,
            completedHoleNumbers: roundState.completedHoleNumbers.union([holeNumber]),
            holeScores: updatedScores
        )
    }
```

**Step 2: Create Scorecard Screen UI**

Create `ios/TheCaddie/ScorecardScreen.swift`:
- Displays key statistics at the top:
  - Total Score (e.g. `+3` or `42 strokes`)
  - Total Putts & Average Putts
  - Fairway In Regulation (FIR) %
  - Green In Regulation (GIR) %
- Render a traditional 18-hole grid list. Each row displays:
  - Hole number, Par, Yardage.
  - Final Score / Strokes.
  - Putts count.
  - FIR / GIR badges.
- Tapping a row opens a SwiftUI `.sheet` with stepper controls to manually override:
  - Strokes (e.g., 1 to 10)
  - Putts (0 to 5)
  - Fairway Hit status (Hit, Miss Left, Miss Right, N/A)
  - GIR status (Yes, No)

**Step 3: Commit**

```bash
git add ios/TheCaddie/ScorecardScreen.swift ios/TheCaddie/CaddieViewModel.swift
git commit -m "feat: Add interactive scorecard and manual stat override sheets"
```

---

### Task 4: Build Club Settings & Bag Customization Screen

**Files:**
- Create: `ios/TheCaddie/BagSettingsScreen.swift`
- Modify: `ios/TheCaddie/CaddieViewModel.swift`

**Step 1: Create Club Editor method in ViewModel**

In `ios/TheCaddie/CaddieViewModel.swift`, add:

```swift
    func updateClubDistance(clubId: String, distanceM: Double) {
        var updatedClubs = player.clubs
        if let index = updatedClubs.firstIndex(where: { $0.id == clubId }) {
            let original = updatedClubs[index]
            updatedClubs[index] = PlayerClub(
                id: original.id,
                name: original.name,
                carryDistanceM: distanceM,
                dispersionM: original.dispersionM,
                suitableLies: original.suitableLies
            )
            self.player = PlayerContext(
                handicapIndex: player.handicapIndex,
                clubs: updatedClubs,
                strategyPreference: player.strategyPreference
            )
        }
    }
    
    func updatePlayerHandicap(_ handicap: Double) {
        self.player = PlayerContext(
            handicapIndex: handicap,
            clubs: player.clubs,
            strategyPreference: player.strategyPreference
        )
    }
    
    func updateStrategyPreference(_ strategy: StrategyPreference) {
        self.player = PlayerContext(
            handicapIndex: player.handicapIndex,
            clubs: player.clubs,
            strategyPreference: strategy
        )
    }
```

**Step 2: Create Bag Settings Screen UI**

Create `ios/TheCaddie/BagSettingsScreen.swift`:
- Top panel: Player settings:
  - Stepper to adjust handicap index (displays current dispersion multiplier, e.g. `20.0 Handicap -> 1.40x dispersion spread`).
  - Picker to switch strategy preference (`Safe`, `Normal`, `Aggressive`).
- List of Clubs:
  - Shows each club in the bag, carry distance, and computed spread.
  - Tapping a club opens a modal sheet with a slider or textField to change the stock carry distance.

**Step 3: Commit**

```bash
git add ios/TheCaddie/BagSettingsScreen.swift ios/TheCaddie/CaddieViewModel.swift
git commit -m "feat: Add Bag and Club settings customization screens"
```

---

### Task 5: Refactor Main Screen for Hands-Free & Decision Debug Log

**Files:**
- Modify: `ios/TheCaddie/CaddieScreen.swift`
- Modify: `ios/TheCaddie/CaddieViewModel.swift`

**Step 1: Create local Hands-Free active state**

In `ios/TheCaddie/CaddieViewModel.swift`, add:
```swift
    @Published var isHandsFreeListening: Bool = false
```

In `CaddieScreen.swift`, refactor the bottom area of the `VStack` to include:
- A hands-free status banner: Displays "Listening..." in green if `viewModel.isHandsFreeListening` is true, or "Hands-Free Muted" in grey.
- Toggle button to activate/deactivate listening (hands-free emulation).

**Step 2: Implement Decision Debug Log Drawer**

Add a sliding drawer (using a bottom `.sheet(isPresented:)` or a disclosure group) to `CaddieScreen.swift`:
- Shows raw calculation numbers:
  - Total GPS/measured distance.
  - Wind speed + direction adjustments.
  - Adjusted playing distance.
  - Lateral shot spread (e.g. `± 24.5 meters`).
- A list of all clubs in the bag with their risk scores. Mark driver as `[EXCEEDS RISK BUDGET]` if appropriate.
- History log: A scrolling text area displaying recent voice/manual actions (e.g., *"Parsed voice command: 'rough' -> Recorded Rough shot result."*).

**Step 3: Add Putt Counter to on-the-green view state**

In `CaddieScreen.swift`, modify `quickUpdates` and `recommendationCard` for `.onGreen` viewState:
- Instead of just a single "Holed" button, show:
  - Stepper for putts: `[ - ] 2 Putts [ + ]`
  - Action button: `"Save Score & Move to Next Hole"` which calls `viewModel.finishCurrentHole(strokes: totalStrokes, putts: puttCount, ...)`

**Step 4: Commit**

```bash
git add ios/TheCaddie/CaddieScreen.swift ios/TheCaddie/CaddieViewModel.swift
git commit -m "feat: Add hands-free controls, scorecard putt entry, and decision debug drawer"
```

---

### Task 6: Wire the TabView App Navigation Shell

**Files:**
- Modify: `ios/TheCaddie/TheCaddieApp.swift`

**Step 1: Replace main view with TabView**

Modify `ios/TheCaddie/TheCaddieApp.swift`:

```swift
import SwiftUI

@main
struct TheCaddieApp: App {
    @StateObject private var viewModel = CaddieViewModel.sample()
    @State private var selectedTab = 0
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CaddieScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Caddie", systemImage: "target")
                    }
                    .tag(0)
                
                ScorecardScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Scorecard", systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                
                BagSettingsScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Bag", systemImage: "briefcase")
                    }
                    .tag(2)
                
                CourseSelectionScreen(viewModel: viewModel)
                    .tabItem {
                        Label("Courses", systemImage: "map")
                    }
                    .tag(3)
            }
            .accentColor(Color(red: 0.06, green: 0.56, blue: 0.24))
        }
    }
}
```

**Step 2: Run verification**

Build and verify that the app successfully compiles and displays all tabs, maintaining independent and synchronized state in `CaddieViewModel`.

**Step 3: Commit**

```bash
git add ios/TheCaddie/TheCaddieApp.swift
git commit -m "feat: Wire the main TabView navigation shell"
```
