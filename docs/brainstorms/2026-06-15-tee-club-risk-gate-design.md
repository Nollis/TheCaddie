---
date: 2026-06-15
topic: tee-club-risk-gate
status: design-approved
---

# Smarter Tee Club Selection — Risk-Gated Recommendation

## Problem Frame

The recommendation engine recommends driver from the tee too readily. Today a
tee shot routes through `advancementClub`, which for `normal`/`aggressive`
strategy returns the **longest playable club** (driver). The only thing that
ever clubs it down is `saferTeeClub`, and that fires *only* when water or
out-of-bounds **pinches both the left and right** of the landing zone at once
(`hasPinchedSevereHazardsNearLanding` requires a superset of `{left, right}`).

As a result the engine ignores:

- **Fairway width** — there is no width data in the model at all.
- **Single-sided hazards** — a lone water hazard on one side does nothing.
- **Player dispersion / handicap** — `expectedDispersion` and
  `skillProfile.dispersionMultiplier` are computed but never used in tee club
  selection. A 20-handicap with a ~40m driver spread is treated the same as a
  scratch player on a tight, hazard-lined hole.

The goal: driver should have to *earn* its place against the fairway width, the
hazards on the line, and the player's own shot dispersion — rather than being
the default.

## Decision Summary

| Decision | Choice |
| --- | --- |
| Fairway-width signal | **Add explicit width data** to the hole (no inference). |
| Club-selection model | **Risk-gated longest club** — pick the longest club whose risk stays within a budget. |
| Hazard weighting | **Severity-weighted** (borrowed from an EV model): water/OB heavy, trees medium, bunker light. |
| Handicap influence | **Through dispersion only** — handicap widens the shot cone, which drives the risk gate. No separate budget tax or hard driver cap (avoids double-counting). |
| Scope | **Tee shots only.** Approach, layup, and recovery paths untouched. |

## Data Model Changes

Add an optional fairway descriptor to `CourseHole`:

```swift
public struct FairwayContext: Equatable, Sendable {
    public let landingWidthM: Double        // usable fairway width through the main driving zone
    public let drivingZoneEndM: Double?     // optional: distance where the safe corridor ends
                                            //   (dogleg, fairway runs out, pinch point)

    public init(landingWidthM: Double, drivingZoneEndM: Double? = nil)
}
```

- `CourseHole` gains `public let fairway: FairwayContext?` — **optional**, so
  every existing course and test compiles and runs unchanged.
- `landingWidthM` is the core signal driving the width-risk term.
- `drivingZoneEndM` captures the second-most-common real reason not to hit
  driver ("the fairway turns or runs out at 250m"). Optional, cheap to support,
  high value for the stated complaint.

## Tee Club Selection — The Risk Gate

Replaces `saferTeeClub`. New path is reached from `advancementClub` when
`lie == .tee` **and** `hole.fairway != nil`.

For each playable club, **longest carry first**, compute:

- `landingM = currentProgressM + club.carryDistanceM`
  (`currentProgressM` is 0 from the tee, but the formula is kept general).
- `lateralSpread = expectedDispersion(club, player, lie: .tee)` — this already
  scales with handicap via `skillProfile.dispersionMultiplier`, so higher
  handicaps automatically get a wider cone.
- **Width risk** — how much `lateralSpread` exceeds the fairway half-width
  (`landingWidthM / 2`) at the landing zone. Zero when the cone fits.
- **Hazard risk** — for each hazard near `landingM` on the line:
  `severityWeight × proximityFactor × spreadOverlap`. A single-sided hazard now
  contributes (today it is ignored unless mirrored).
- **Overshoot risk** — a penalty when `landingM` runs past `drivingZoneEndM`.

Sum these into `totalRisk`. Then:

1. **Pick the longest club whose `totalRisk` ≤ the risk budget.**
2. If no club qualifies (forced carry, trouble everywhere), **fall back to the
   lowest-risk club**, respecting strategy.

Driver survives on a wide, open hole; it is the first club dropped on a tight or
hazard-lined one, and it is dropped sooner for a higher-handicap player because
their cone is wider.

### Risk Budget

Set by `strategyPreference`:

- `safe` → small budget
- `normal` → medium budget
- `aggressive` → large budget

Deliberately **not** also scaled by handicap. Dispersion already widens for
higher handicaps and flows through the width and hazard risk terms; making the
budget handicap-dependent as well would double-count and over-correct into
"never let a high-handicapper hit driver," even on wide holes where a big miss
has no consequence.

### Severity Weights

- Water / Out-of-bounds → **high** (vetoes driver when near the cone).
- Trees → **medium**.
- Bunker → **low** (nudges, does not veto).

## Integration & Backward Compatibility

- Change is contained to the tee path: a new `riskGatedTeeClub` helper called
  from `advancementClub` for `lie == .tee`.
- `selectClub` (approach), layup, and recovery paths are **unchanged**.
- When `hole.fairway == nil`, the engine falls back to today's behavior
  (including the existing left/right pinch check), so **no existing test
  regresses**. The new intelligence activates only where width data exists.

## Output / Explainability

Reuse existing `primaryReason` / `riskNote` fields — **no packet shape change.**
When the engine clubs down, `riskNote` explains why in plain terms, e.g.
"Driver's spread brings the right-side water in play — 3-wood keeps you short of
it and in the fairway." `confidence` already factors hazards and dispersion and
stays consistent.

## Testing

New cases in `RecommendationEngineTests`:

- Wide, open hole → driver held.
- Same hole made tight + high handicap → clubs down.
- Tight hole + low (scratch) handicap → driver still held (dispersion fits).
- Single-sided water near the driver landing zone → clubs down / biases away.
- `drivingZoneEndM` cap shorter than driver carry → driver dropped.
- Forced carry / trouble everywhere → fallback picks the lowest-risk club.
- `fairway == nil` hole → reproduces legacy behavior (regression guard).

## Out of Scope

- Inference of fairway width from hazard density (explicit data was chosen).
- Changes to approach, layup, or recovery club selection.
- An expected-strokes (EV) scoring engine — only its severity-weighting idea is
  borrowed.
- A hard handicap-based driver cap.
