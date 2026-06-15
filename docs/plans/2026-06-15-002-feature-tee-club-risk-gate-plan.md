# Tee Club Risk-Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the engine defaulting to driver off the tee by choosing the longest tee club whose risk — driven by fairway width, severity-weighted hazards, and the player's own dispersion — stays within a strategy budget.

**Architecture:** Add an optional `FairwayContext` (landing width + optional driving-zone end) to `CourseHole`. In `CaddieRecommendationEngine`, when a tee shot has fairway data, route club selection through a new risk-gated helper that scores each candidate club and picks the longest one under budget (falling back to the lowest-risk club). All other paths and the no-fairway-data case keep today's behavior.

**Tech Stack:** Swift 6, SwiftPM (`TheCaddieDomain` library + `TheCaddieDomainTests`), swift-testing (`import Testing`, `@Test`, `#expect`).

**Test command:** `swift test` (run a single test with `swift test --filter <functionName>`). On macOS this runs as-is. This repo's working machine is Windows; if no Swift toolchain is available locally, run the suite on macOS/CI — but every task below still defines its exact test and expected result so the engineer knows precisely what must pass.

**Numeric model (used throughout — implement exactly):**
- `lateralSpread = expectedDispersion(club, player, lie: .tee)` (existing helper; already scales with handicap via `skillProfile.dispersionMultiplier`).
- `halfWidth = max(1, fairway.landingWidthM / 2)`
- `widthRisk = max(0, (lateralSpread - halfWidth) / halfWidth)`
- `hazardRisk = Σ severityWeight(kind) × proximity` over hazards with a parseable distance `d` where `along = |d - landingM| ≤ 35`, `proximity = 1 - along/35`.
- `severityWeight`: water `1.0`, outOfBounds `1.2`, trees `0.5`, bunker `0.3`.
- `overshootRisk = (landingM - drivingZoneEndM) / 50` when `drivingZoneEndM` is set and `landingM` exceeds it, else `0`.
- `totalRisk = widthRisk + hazardRisk + overshootRisk`.
- `riskBudget`: safe `0.6`, normal `1.0`, aggressive `1.6`.
- Selection: among playable tee clubs sorted by carry **descending**, pick the first with `totalRisk ≤ budget` (= longest acceptable). If none, pick the lowest `totalRisk`, tie-broken by longest carry.

---

### Task 1: Add `FairwayContext` to the hole model

**Files:**
- Modify: `Sources/TheCaddieDomain/Models/CourseModels.swift`
- Test: `Tests/TheCaddieDomainTests/DomainModelTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `Tests/TheCaddieDomainTests/DomainModelTests.swift`:

```swift
@Test func courseHoleCarriesOptionalFairwayContext() {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: 380,
        green: GreenContext(frontDistanceM: 360, centerDistanceM: 372, backDistanceM: 384),
        hazards: [],
        fairway: FairwayContext(landingWidthM: 30, drivingZoneEndM: 250)
    )

    #expect(hole.fairway?.landingWidthM == 30)
    #expect(hole.fairway?.drivingZoneEndM == 250)

    let holeWithoutFairway = CourseHole(
        number: 2,
        par: 3,
        teeLengthM: 150,
        green: GreenContext(frontDistanceM: 140, centerDistanceM: 150, backDistanceM: 160),
        hazards: []
    )
    #expect(holeWithoutFairway.fairway == nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter courseHoleCarriesOptionalFairwayContext`
Expected: FAIL to compile — `FairwayContext` is undefined and `CourseHole.init` has no `fairway:` parameter.

- [ ] **Step 3: Add `FairwayContext` and the optional property**

In `Sources/TheCaddieDomain/Models/CourseModels.swift`, add the struct (place it after `GreenContext`):

```swift
public struct FairwayContext: Equatable, Sendable {
    public let landingWidthM: Double
    public let drivingZoneEndM: Double?

    public init(landingWidthM: Double, drivingZoneEndM: Double? = nil) {
        self.landingWidthM = landingWidthM
        self.drivingZoneEndM = drivingZoneEndM
    }
}
```

Then modify `CourseHole` to add the stored property and the init parameter (defaulted to `nil` so all existing call sites compile unchanged):

```swift
public struct CourseHole: Equatable, Sendable, Identifiable {
    public let number: Int
    public let par: Int
    public let teeLengthM: Double
    public let green: GreenContext
    public let hazards: [Hazard]
    public let fairway: FairwayContext?

    public var id: Int { number }

    public init(
        number: Int,
        par: Int,
        teeLengthM: Double,
        green: GreenContext,
        hazards: [Hazard],
        fairway: FairwayContext? = nil
    ) {
        self.number = number
        self.par = par
        self.teeLengthM = teeLengthM
        self.green = green
        self.hazards = hazards
        self.fairway = fairway
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter courseHoleCarriesOptionalFairwayContext`
Expected: PASS.

- [ ] **Step 5: Verify no existing call site broke**

Run: `swift build`
Expected: builds clean (SampleRound and KungsbackaNyaCourse omit `fairway:`, which is allowed by the default).

- [ ] **Step 6: Commit**

```bash
git add Sources/TheCaddieDomain/Models/CourseModels.swift Tests/TheCaddieDomainTests/DomainModelTests.swift
git commit -m "Add optional FairwayContext to CourseHole

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Risk-gated tee club selection (core)

**Files:**
- Modify: `Sources/TheCaddieDomain/Recommendation/CaddieRecommendationEngine.swift`
- Test: `Tests/TheCaddieDomainTests/RecommendationEngineTests.swift`

This is the behavior change. The first test reproduces the complaint: a high-handicap player on a tight fairway should NOT be handed driver.

- [ ] **Step 1: Add a shared test helper for tee scenarios**

Add to the top of `Tests/TheCaddieDomainTests/RecommendationEngineTests.swift` (below the imports). It builds a one-hole course with fairway data and resolves a tee shot:

```swift
private func teePacket(
    landingWidthM: Double,
    drivingZoneEndM: Double? = nil,
    hazards: [Hazard] = [],
    player: PlayerContext = SampleRound.player,
    teeLengthM: Double = 380
) -> CaddieRecommendationPacket {
    let hole = CourseHole(
        number: 1,
        par: 4,
        teeLengthM: teeLengthM,
        green: GreenContext(
            frontDistanceM: teeLengthM - 20,
            centerDistanceM: teeLengthM - 8,
            backDistanceM: teeLengthM + 4
        ),
        hazards: hazards,
        fairway: FairwayContext(landingWidthM: landingWidthM, drivingZoneEndM: drivingZoneEndM)
    )
    let course = Course(id: "tee-test", name: "Tee Test", holes: [hole])
    let roundState = RoundState(
        courseId: course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(teeLengthM),
                lie: .known(.tee),
                wind: nil
            )
        ]
    )
    return CaddieRecommendationEngine.build(course: course, player: player, roundState: roundState)
}
```

- [ ] **Step 2: Write the failing test (tight fairway clubs down for high handicap)**

Add:

```swift
@Test func tightFairwayClubsDownFromDriverForHighHandicap() {
    // SampleRound.player is a 21.8 handicap (dispersion multiplier 1.45).
    let packet = teePacket(landingWidthM: 30)

    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.recommendedClub != "Driver")
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter tightFairwayClubsDownFromDriverForHighHandicap`
Expected: FAIL — current engine returns `"Driver"` (legacy `advancementClub` returns the longest club).

- [ ] **Step 4: Add the risk-model helpers**

In `CaddieRecommendationEngine.swift`, add these private helpers (place them near `advancementClub`):

```swift
private static func riskBudget(for strategy: StrategyPreference) -> Double {
    switch strategy {
    case .safe: return 0.6
    case .normal: return 1.0
    case .aggressive: return 1.6
    }
}

private static func severityWeight(for kind: HazardKind) -> Double {
    switch kind {
    case .water: return 1.0
    case .outOfBounds: return 1.2
    case .trees: return 0.5
    case .bunker: return 0.3
    }
}

private static func teeHazardRisk(
    hazards: [Hazard],
    landingM: Double
) -> Double {
    let windowM = 35.0
    return hazards.reduce(0) { sum, hazard in
        guard let distanceM = hazardDistance(for: hazard) else {
            return sum
        }
        let alongM = abs(distanceM - landingM)
        guard alongM <= windowM else {
            return sum
        }
        let proximity = 1 - alongM / windowM
        return sum + severityWeight(for: hazard.kind) * proximity
    }
}

private static func teeShotRisk(
    club: PlayerClub,
    player: PlayerContext,
    fairway: FairwayContext,
    hazards: [Hazard],
    currentProgressM: Double
) -> Double {
    let landingM = currentProgressM + club.carryDistanceM
    let lateralSpread = expectedDispersion(for: club, player: player, lie: .tee)
    let halfWidth = max(1, fairway.landingWidthM / 2)
    let widthRisk = max(0, (lateralSpread - halfWidth) / halfWidth)
    let hazardRisk = teeHazardRisk(hazards: hazards, landingM: landingM)

    let overshootRisk: Double
    if let endM = fairway.drivingZoneEndM, landingM > endM {
        overshootRisk = (landingM - endM) / 50
    } else {
        overshootRisk = 0
    }

    return widthRisk + hazardRisk + overshootRisk
}

private static func riskGatedTeeClub(
    from clubs: [PlayerClub],
    player: PlayerContext,
    fairway: FairwayContext,
    hazards: [Hazard],
    currentProgressM: Double,
    strategy: StrategyPreference
) -> PlayerClub? {
    let candidates = clubs.sorted { lhs, rhs in
        lhs.carryDistanceM > rhs.carryDistanceM
    }
    guard !candidates.isEmpty else {
        return nil
    }

    let budget = riskBudget(for: strategy)
    let scored = candidates.map { club in
        (club: club, risk: teeShotRisk(
            club: club,
            player: player,
            fairway: fairway,
            hazards: hazards,
            currentProgressM: currentProgressM
        ))
    }

    if let acceptable = scored.first(where: { $0.risk <= budget }) {
        return acceptable.club
    }

    return scored.min { lhs, rhs in
        if lhs.risk != rhs.risk {
            return lhs.risk < rhs.risk
        }
        return lhs.club.carryDistanceM > rhs.club.carryDistanceM
    }?.club
}
```

- [ ] **Step 5: Wire the helper into `advancementPacket`**

In `advancementPacket`, replace the opening `guard let club = advancementClub(...)` block with a tee-aware selection. The new opening of `advancementPacket` reads:

```swift
let progressM = currentProgressM(
    holeLengthM: hole.teeLengthM,
    remainingDistanceM: remainingDistanceM
)
let teeClubs = playableClubs(from: player.clubs, lie: lie)

let selectedClub: PlayerClub?
if lie == .tee, let fairway = hole.fairway {
    selectedClub = riskGatedTeeClub(
        from: teeClubs,
        player: player,
        fairway: fairway,
        hazards: hole.hazards,
        currentProgressM: progressM,
        strategy: player.strategyPreference
    )
} else {
    selectedClub = advancementClub(
        from: teeClubs,
        strategy: player.strategyPreference,
        lie: lie,
        hazards: hole.hazards,
        currentProgressM: progressM
    )
}

guard let club = selectedClub else {
    return contextPacket(
        status: .unavailable,
        course: course,
        hole: hole,
        player: player,
        shot: shot,
        reason: "No club in the current bag covers this shot.",
        confidence: .low
    )
}
```

Then delete the now-duplicated `let progressM = currentProgressM(...)` line that appeared later in the original `advancementPacket` body (it is computed above now). The rest of the method (`landingHazards`, `leaveDistance`, `target`, `primaryReason`, the returned packet) stays unchanged.

- [ ] **Step 6: Run the failing test to verify it now passes**

Run: `swift test --filter tightFairwayClubsDownFromDriverForHighHandicap`
Expected: PASS — `recommendedClub == "5 Iron"`.

(Manual check of the model: Driver spread `28×1.45 = 40.6`, halfWidth `15` → widthRisk `1.71`; 3 Hybrid `22×1.45 = 31.9` → `1.13`; 5 Iron `16×1.45 = 23.2` → `0.547 ≤ 1.0`. Longest acceptable = 5 Iron.)

- [ ] **Step 7: Commit**

```bash
git add Sources/TheCaddieDomain/Recommendation/CaddieRecommendationEngine.swift Tests/TheCaddieDomainTests/RecommendationEngineTests.swift
git commit -m "Risk-gate tee club selection by width, hazards, dispersion

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Behavior coverage tests

**Files:**
- Test: `Tests/TheCaddieDomainTests/RecommendationEngineTests.swift`

All of these exercise the helper added in Task 2. Add them as separate `@Test` functions, run after each.

- [ ] **Step 1: Wide hole keeps driver (high handicap)**

```swift
@Test func wideOpenFairwayKeepsDriverForHighHandicap() {
    let packet = teePacket(landingWidthM: 50)

    #expect(packet.recommendedClub == "Driver")
}
```

Run: `swift test --filter wideOpenFairwayKeepsDriverForHighHandicap`
Expected: PASS (Driver widthRisk `(40.6-25)/25 = 0.624 ≤ 1.0`).

- [ ] **Step 2: Same tight hole keeps driver for a scratch player (handicap via dispersion)**

```swift
@Test func tightFairwayKeepsDriverForScratchPlayer() {
    let scratch = PlayerContext(
        handicapIndex: 2.0,
        clubs: SampleRound.player.clubs,
        strategyPreference: .normal
    )
    let packet = teePacket(landingWidthM: 30, player: scratch)

    #expect(packet.recommendedClub == "Driver")
}
```

Run: `swift test --filter tightFairwayKeepsDriverForScratchPlayer`
Expected: PASS (handicap 2.0 → multiplier 1.0 → Driver spread `28`, widthRisk `(28-15)/15 = 0.867 ≤ 1.0`). This is the proof that handicap acts through dispersion: same hole, scratch keeps driver, 21.8 clubs down.

- [ ] **Step 3: Single-sided water at the driver landing zone clubs down**

```swift
@Test func waterAtDriverLandingZoneClubsDown() {
    let water = Hazard(
        id: "tee-water-right",
        kind: .water,
        position: "right 220m",
        note: "Water down the right at the driver landing zone."
    )
    let packet = teePacket(landingWidthM: 56, hazards: [water])

    #expect(packet.recommendedClub == "3 Hybrid")

    let noHazard = teePacket(landingWidthM: 56)
    #expect(noHazard.recommendedClub == "Driver")
}
```

Run: `swift test --filter waterAtDriverLandingZoneClubsDown`
Expected: PASS. With water: Driver total `0.45 (width) + 1.0 (hazard) = 1.45 > 1.0` → skip; 3 Hybrid `0.139 + 0.143 = 0.282 ≤ 1.0`. Without water: Driver `0.45 ≤ 1.0` → held.

- [ ] **Step 4: Driving-zone end cap drops driver**

```swift
@Test func drivingZoneEndCapDropsDriver() {
    let packet = teePacket(landingWidthM: 56, drivingZoneEndM: 180)

    #expect(packet.recommendedClub == "3 Hybrid")
}
```

Run: `swift test --filter drivingZoneEndCapDropsDriver`
Expected: PASS. Driver lands 220 > 180 → overshoot `0.8`, total `0.45 + 0.8 = 1.25 > 1.0`; 3 Hybrid lands 190 → overshoot `0.2`, total `0.139 + 0.2 = 0.339 ≤ 1.0`.

- [ ] **Step 5: Trouble everywhere falls back to the lowest-risk club**

```swift
@Test func extremelyTightFairwayFallsBackToLowestRiskClub() {
    let packet = teePacket(landingWidthM: 12)

    // No club fits a 6m half-width; fallback picks the lowest-spread club,
    // tie-broken by longest carry (PW over 50W).
    #expect(packet.recommendedClub == "PW")
    #expect(packet.recommendedClub != "Driver")
}
```

Run: `swift test --filter extremelyTightFairwayFallsBackToLowestRiskClub`
Expected: PASS. Every club exceeds budget; PW and 50W tie at the lowest widthRisk `(17.4-6)/6 = 1.9`, tie-break longest carry → PW (105m).

- [ ] **Step 6: No fairway data preserves legacy behavior**

```swift
@Test func teeShotWithoutFairwayDataUsesLegacyLongestClub() {
    // SampleRound hole 1 has no fairway data; a tee shot should still return Driver.
    let teeRound = RoundState(
        courseId: SampleRound.course.id,
        selectedHoleNumber: 1,
        shotContexts: [
            1: ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(356),
                lie: .known(.tee),
                wind: nil
            )
        ]
    )
    let packet = CaddieRecommendationEngine.build(
        course: SampleRound.course,
        player: SampleRound.player,
        roundState: teeRound
    )

    #expect(packet.shotIntent == .teePosition)
    #expect(packet.recommendedClub == "Driver")
}
```

Run: `swift test --filter teeShotWithoutFairwayDataUsesLegacyLongestClub`
Expected: PASS — `hole.fairway == nil`, so the legacy `advancementClub` path runs and returns the longest club.

- [ ] **Step 7: Commit**

```bash
git add Tests/TheCaddieDomainTests/RecommendationEngineTests.swift
git commit -m "Cover tee risk-gate behavior across width, hazards, handicap

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Explain the club-down in the risk note

**Files:**
- Modify: `Sources/TheCaddieDomain/Recommendation/CaddieRecommendationEngine.swift`
- Test: `Tests/TheCaddieDomainTests/RecommendationEngineTests.swift`

When the engine clubs down off the tee, the risk note should say why. This only affects tee shots with fairway data where the chosen club is shorter than the longest playable club, so existing tests are unaffected.

- [ ] **Step 1: Write the failing test**

```swift
@Test func clubbedDownTeeShotExplainsWhyInRiskNote() {
    let packet = teePacket(landingWidthM: 30)

    #expect(packet.recommendedClub == "5 Iron")
    #expect(packet.riskNote == "Driver brings the trouble into range here — 5 Iron keeps the tee shot in play.")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter clubbedDownTeeShotExplainsWhyInRiskNote`
Expected: FAIL — current `riskNote` comes from `advancementRiskNote` over landing hazards (here `nil`).

- [ ] **Step 3: Compute the tee risk note in `advancementPacket`**

In `advancementPacket`, the packet currently sets:

```swift
riskNote: advancementRiskNote(for: landingHazards, strategy: player.strategyPreference),
```

Replace that argument with a computed `riskNote` local. Just before the `return CaddieRecommendationPacket(` in `advancementPacket`, add:

```swift
let riskNote: String?
if lie == .tee,
   hole.fairway != nil,
   let longest = teeClubs.max(by: { $0.carryDistanceM < $1.carryDistanceM }),
   club.carryDistanceM < longest.carryDistanceM {
    riskNote = "\(longest.name) brings the trouble into range here — \(club.name) keeps the tee shot in play."
} else {
    riskNote = advancementRiskNote(for: landingHazards, strategy: player.strategyPreference)
}
```

Then change the packet field to use it:

```swift
riskNote: riskNote,
```

(`teeClubs` is the local already created in Task 2 Step 5.)

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter clubbedDownTeeShotExplainsWhyInRiskNote`
Expected: PASS.

- [ ] **Step 5: Confirm driver-held tee shots keep the hazard-based note**

Run: `swift test --filter wideOpenFairwayKeepsDriverForHighHandicap`
Expected: PASS (driver is the longest club, so the `else` branch runs — behavior unchanged).

- [ ] **Step 6: Commit**

```bash
git add Sources/TheCaddieDomain/Recommendation/CaddieRecommendationEngine.swift Tests/TheCaddieDomainTests/RecommendationEngineTests.swift
git commit -m "Explain tee club-down in the risk note

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Full regression run

**Files:** none (verification only).

- [ ] **Step 1: Run the entire suite**

Run: `swift test`
Expected: all tests pass, including the pre-existing `RecommendationEngineTests`, `KungsbackaNyaCourseTests`, `DomainModelTests`, `CaddieViewStateTests`, `CaddieResponseTextTests`. None of them set `fairway`, so they exercise the legacy path and must be unchanged.

- [ ] **Step 2: If any pre-existing test changed behavior, stop and investigate**

The design guarantees no regression when `fairway == nil`. A failure here means the tee branch leaked into a non-tee or no-fairway path — re-check the `lie == .tee, let fairway = hole.fairway` guard in `advancementPacket`.

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "Finalize tee club risk-gate

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Optional follow-ups (out of scope — do NOT implement now)

- Populate `FairwayContext` on real courses (`KungsbackaNyaCourse`, `SampleRound`) so the feature activates in the shipped app. This is data entry, tracked separately.
- Extend risk-gating to fairway layup/advance shots (currently tee-only).
