---
date: 2026-06-22
status: active
origin: docs/brainstorms/2026-06-15-native-caddie-core-requirements.md
supersedes: docs/plans/2026-06-15-001-feature-native-caddie-core-plan.md
---

# GPS and Round-State Validation Plan

## Overview
The project is past the original "minimal native caddie core" slice. The deterministic engine, SwiftUI caddie screen, live GPS hooks, hole detection, lie inference, centerline progress, mapped hazards, and debug export are already in place.

The next phase is not to add another major surface area immediately. It is to make the existing caddie trustworthy on course by validating and tightening three things in order:

1. live GPS and mapping fidelity
2. round-state progression from real position
3. course data quality

The product rule remains unchanged: deterministic local logic owns golf decisions, and future speech or model layers sit on top of that contract rather than replacing it.

## Current State Snapshot

### Already Implemented
- Deterministic recommendation engine with structured packet output
- Sample/player context plus round-state updates
- Tee-shot risk gating and mapped hazard context
- Live GPS distance updates
- Hole auto-detection
- Lie inference from mapped surfaces
- Centerline-based progress inference
- Hazard-side, hazard-progress, and lateral-offset-aware recommendation logic
- Player-facing caddie screen with ongoing UI simplification
- Copyable debug export for field testing

### What Changed Since the June 15 Plan
- Real GPS/course detection is no longer deferred; it is already part of the current product slice
- The main risk has shifted from "can we produce a recommendation packet?" to "can we trust this packet from real course position and data?"
- UI work is now about reducing debug dominance while preserving diagnostic depth for testing

## Requirements Trace
- R1-R4: Preserve deterministic local golf logic as the source of truth
- R5, R7, R8: Keep the on-course experience compact and trustworthy while debug remains secondary
- R9-R11: Keep future voice and AI layers downstream from the packet contract
- R12-R13: Continue avoiding prototype transport/prompt complexity

## Scope Boundaries
- No live voice loop in this phase
- No Foundation Models phrasing implementation in this phase
- No OpenAI realtime/WebRTC migration in this phase
- No broad multi-course publishing work in this phase
- No speculative analytics/stats expansion unless required for shot-state correctness

## Goals of This Phase
- Make field testing decisive instead of ambiguous
- Reduce recommendation mistakes caused by stale or guessed shot progression
- Separate engine issues from bad mapping data quickly
- Keep the player-facing caddie screen calm while retaining exportable debug context

## Execution Order

- [ ] **Unit 1: Field validation workflow**

**Goal:** Make on-course testing systematic enough that each odd recommendation can be diagnosed from one exported report.

**Requirements:** R1, R4, R5, R7

**Dependencies:** Existing debug export and live GPS flow

**Files:**
- Update as needed: `ios/TheCaddie/CaddieScreen.swift`
- Update as needed: `ios/TheCaddie/CaddieViewModel.swift`
- Create if useful: `docs/field-testing/`

**Approach:**
- Ensure the debug export contains hole resolution, live fix, inferred lie, progress, centerline offset, chosen recommendation, club comparisons, and hazard relevance.
- Keep the debug affordance off the main critical reading path.
- If helpful, add a small field-testing note template under `docs/field-testing/` so exported reports can be logged consistently by hole and shot.

**Verification:**
- A tester can capture one report per suspicious shot and later reconstruct why the app made the decision it did.

- [ ] **Unit 2: GPS-driven round-state fidelity**

**Goal:** Reduce dependence on button heuristics by letting real progress and inferred lie drive shot advancement more directly.

**Requirements:** R1-R5, R7

**Dependencies:** Unit 1

**Files:**
- Update: `Sources/TheCaddieDomain/Models/RoundState.swift`
- Update: `Sources/TheCaddieDomain/Models/ShotContext.swift`
- Update: `ios/TheCaddie/CaddieViewModel.swift`
- Update tests: `Tests/TheCaddieDomainTests/`

**Approach:**
- Use explicit progress and live lie more heavily when recording shot results.
- Tighten transitions so the next-shot state reflects actual movement down the hole, not just static lie multipliers.
- Keep deterministic fallback behavior for cases where GPS is unavailable or mapping is incomplete.

**Test scenarios:**
- Happy path: a fairway result after a live GPS fix advances remaining distance consistently with measured progress.
- Edge case: bunker/green transitions do not overshoot or under-advance because of stale progress.
- Error path: missing GPS or weak mapping falls back to deterministic non-crashing heuristics.

**Verification:**
- The same live position should not produce materially different post-shot states depending on which quick-action button was used.

- [ ] **Unit 3: Course data audit and correction pass**

**Goal:** Treat Kungsbacka mapping as production data that needs review, not as unquestioned fixtures.

**Requirements:** R1-R5, R7

**Dependencies:** Unit 2

**Files:**
- Update: `Sources/TheCaddieDomain/SampleData/KungsbackaNyaCourse.swift`
- Update: `Sources/TheCaddieDomain/SampleData/KungsbackaNyaCenterlineData.swift`
- Update: `Sources/TheCaddieDomain/SampleData/KungsbackaNyaSurfaceData.swift`
- Update tests: `Tests/TheCaddieDomainTests/KungsbackaNyaCourseTests.swift`

**Approach:**
- Audit each hole for:
  - centerline shape
  - fairway/rough/green/bunker/water polygons
  - hazard progress markers
  - hazard side and lateral offsets
- Prefer correcting mapped data before complicating engine logic when a recommendation issue is clearly data-driven.

**Verification:**
- Known problem holes can be explained by either corrected data or explicit remaining engine limitations, not by guesswork.

- [ ] **Unit 4: Main-screen simplification pass**

**Goal:** Keep the player-facing caddie screen focused on the recommendation while preserving optional diagnostics.

**Requirements:** R5, R7, R8

**Dependencies:** Unit 1

**Files:**
- Update: `ios/TheCaddie/CaddieScreen.swift`
- Update as needed: `Sources/TheCaddieDomain/Presentation/CaddieViewState.swift`

**Approach:**
- Continue reducing stacked chrome and utility surfaces on the main screen.
- Treat GPS as background assistance rather than a primary block unless actively needed.
- Keep debug export and mapping insight accessible but secondary.

**Verification:**
- The recommendation remains the dominant visual element on first glance.

- [ ] **Unit 5: Decide the next major branch**

**Goal:** Choose between "trust the caddie brain first" and "start the presentation/speech layer."

**Decision Gate:**
- If field testing still reveals frequent trust issues, stay on GPS/data/round-state hardening.
- If recommendation trust is high, begin the presentation-layer track in `docs/plans/2026-06-22-002-feat-foundation-models-phrasing-plan.md`, starting with deterministic phrasing abstraction and optional Foundation Models explanation.

## Open Questions
- How much of shot advancement should become GPS-derived automatically versus explicitly confirmed by the golfer?
- Which mapping issues are isolated bad-hole data and which point to a broader geometry/modeling issue?
- At what point is the caddie trustworthy enough to make speech the next investment rather than more domain hardening?
- Should the Foundation Models phrasing layer land before or after the first Apple Speech command loop?

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Recommendation bugs are misdiagnosed as engine problems when the real issue is bad course data | Audit mapped data hole by hole and use exported debug reports to separate logic from geometry |
| GPS-derived progression makes state feel jumpy or too automatic | Prefer explicit progress when high-confidence, retain deterministic fallback, and test transitions at lie boundaries |
| Debug keeps leaking into the main player flow | Continue simplifying the main screen and keep diagnostics behind the existing debug affordance |
| The project drifts into voice/UI novelty before trust is earned | Make field validation and round-state fidelity the gate before starting speech work |

## Verification Notes
- Windows-side shell validation remains available for diffs and structure checks.
- Swift/Xcode compile, simulator, and device validation still require macOS tooling.
- Field-testing feedback should be treated as first-class input to this phase.

## Sources and References
- [docs/brainstorms/2026-06-15-native-caddie-core-requirements.md](../brainstorms/2026-06-15-native-caddie-core-requirements.md)
- [docs/plans/2026-06-15-001-feature-native-caddie-core-plan.md](./2026-06-15-001-feature-native-caddie-core-plan.md)
- [docs/plans/2026-06-22-002-feat-foundation-models-phrasing-plan.md](./2026-06-22-002-feat-foundation-models-phrasing-plan.md)
