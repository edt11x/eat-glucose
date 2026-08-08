# 2026-08-08 — Phase 3.1 Increment 1: Insulin estimator core

Started the biggest SPEC item (3.1 Insulin Tracking & Estimation) with its
foundational, pure-logic increment, then committed via the Commit Workflow
(v1.4, build 5).

## Prompts (verbatim) and responses

### 1. "Continue the phases" (after Phase 2 commit) → chose 3.1 first
Built **Increment 1 — the estimator core** in a new `InsulinEstimator.swift`
(pure logic, no UI, fully unit-tested):
- `InsulinClass` (rapid / longActing / supplement).
- `InsulinProfile` — editable PK params + `fractionActive(at:)` cumulative
  dose-response curve (triangular for peaked rapid, uniform ramp for flat
  basals, 0 for chronic supplements) + `effectShape(at:targetHours:)`; ships
  `.defaults` for Lispro/Lantus/Toujeo/Berberine/Inositol.
- `InsulinEstimateInput` / `DoseRecommendation` / `BGPredictionPoint`.
- `InsulinEstimator` protocol + `PKCurveEstimator` concrete impl. Recommendation:
  `gap = (currentBG + drift·h) − targetBG`; `dose = clamp(round(gap /
  effectiveISFPerUnit), 0…maxDose)`. Drift term models the liver-reservoir/dawn
  effect; the PK curve shapes the predicted trajectory for the eventual graph.
- 9 unit tests (fractionActive shape, supplement inactive, basic recommend,
  rounding, clamp, no-need, drift, predicted-curve endpoints). Safety
  disclaimer in the header (aid, not medical advice).

### 2. "Run the commit workflow"
This commit (v1.4, build 5).

## Key design finding
The user's worked example (123 → 80 on 13u Toujeo overnight) exposes tension:
Toujeo's textbook PK fraction active by morning is small, yet a real overnight
drop is observed. So the recommendation is driven by **`effectiveISFPerUnit`**
(empirically observed mg/dL drop per unit by target time), NOT raw textbook PK;
the PK curve only shapes the displayed trajectory. This sets up the empirical-fit
increment (fit `effectiveISFPerUnit` + `drift` from the user's overnight
bedtime→fasting deltas).

## Verification
- New file auto-included via Xcode 16 file-system-synchronized group (no pbxproj
  change needed; confirmed by clean build + passing tests referencing it).
- Full clean build succeeded; suite green (`** TEST SUCCEEDED **`, 39 tests).
- Version bumped 1.3 → 1.4 (build 4 → 5).

## Pickup Context (for the next session)
- **Phase 3.1 in progress.** Done: step 1 (protocol), step 3 (PK model); drift
  term + predicted-curve *logic* done (UI pending). **Next increment:** step 2
  **input screen** (new selectable screen like the charts: current BG, activity,
  target BG + time, insulin type, max dose) + step 7 **prediction graph** wired
  to `PKCurveEstimator.predictedCurve` (no-insulin vs suggested). Then step 4
  **empirical fit** of `effectiveISFPerUnit`/drift from overnight deltas, step 6
  filtering v1, step 8 recommendation display, step 9 feedback via
  `insulinRecommendedByApp` (field already shipped in 1.8).
- **Sharp edges:**
  - Tests require an **iOS 26.5** simulator (`BCB25CCF-51C1-4AC6-867F-F1D177D58F28`).
  - New source files are auto-added to the target via the synchronized group —
    no pbxproj edits needed; just create with the file tools.
  - Estimator recommendation is driven by empirical `effectiveISFPerUnit`, not
    raw PK; PK curve is display-only. Berberine/Inositol are `.supplement`
    (excluded from acute dose math). Aid, not medical advice.
- **Nothing else in flight.**
