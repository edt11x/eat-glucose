# SPEC.md — edt-glucose Change Plan

This document tracks a batch of requested changes. Work proceeds in **small, independently-shippable steps** so the app is never left broken. Each step has a status marker; update it as work lands.

**Status legend:** ⬜ Pending · 🔷 In Progress · ✅ Done · 🔬 Research/spike · ❓ Needs decision

> ⚠️ **Safety note (insulin features):** The Insulin Tracking & Estimation feature is a *personal estimation aid*, not medical advice. All dose suggestions must be reviewed against a clinician's guidance. The UI must make this clear.

---

## Locked Decisions (confirmed with user 2026-07-11)

1. **Overnight chart** — The bedtime→fasting difference + bedtime-insulin chart the user described **already exists** as `OvernightProcessingChartView`. We will **enhance that existing chart** (true insulin-units axis + "Nights w/o Insulin" stat), *not* build a duplicate.
2. **Cross-device sync** — Enable **SwiftData + CloudKit** (`NSPersistentCloudKitContainer` via `.cloudKitDatabase(.automatic)`). Model is already CloudKit-compatible. Watch/iPad/Mac read the same synced store.
3. **Insulin model** — Start with a **replaceable `InsulinEstimator` protocol**: pharmacokinetic dose-response curve per insulin type + an empirical dose→overnight-drop fit from the user's own history. Kalman/alpha-beta swapped in later behind the same protocol.
4. **Build order** — **Quick wins first**, then medium (perf/tests/integrity), then big features (insulin estimator, CloudKit, Watch, HealthKit).

---

## Progress Summary

| Phase | Items | Done | In Progress | Pending |
|---|---|---|---|---|
| 1 — Quick wins | 8 | 8 | 0 | 0 |
| 2 — Medium | 4 | 4 | 0 | 0 |
| 3 — Big features | 4 | 0 | 1 | 3 |
| 4 — Research / future | 5 | 0 | 0 | 5 |

_Update this table as steps complete._

---

## Phase 1 — Quick Wins (small, safe, mostly one file each)

### 1.1 ✅ Copy activity from Start of Meal to End of Meal
- **Problem:** `EventFormView.populateFromStartOfMeal()` (≈lines 576–586) copies food/nutrition/location fields but **not** `activityDescription`.
- **Done:** `populateFromStartOfMeal()` now copies `activityDescription` from the matched Start of Meal, but only when the End of Meal's activity is still empty (won't clobber user input). Diagnostics clean.
- **Verify:** Add a Start of Meal with an activity, then add End of Meal → activity auto-fills.
- **Test:** ⬜ Unit test the copy helper (deferred to Phase 2.3).

### 1.2 ✅ Overnight Processing: real insulin-units axis + "Nights w/o Insulin" stat
- **Was:** Insulin bars *scaled into* the BG-delta axis; label read "Δ mg/dL | Insulin units (scaled)". Stat row had "Nights w/ Insulin" but no "Nights w/o Insulin".
- **Done:**
  1. Dual axis — **left axis now reads insulin units** (`insulinUnitTicks` at nice integer steps 0,2,4,…, mapped onto the shared y-domain via `insulinToDelta`), Δ mg/dL moved to the **right (trailing) axis**. Bars grow from 0 units at the bottom. When there's no insulin data, the Δ axis stays on the left as before. Removed the `(scaled)` label; caption now names each axis.
  2. Added **"Nights w/o Insulin"** `StatBox` (= total nights − nights with insulin) next to "Nights w/ Insulin".
- **Verify:** Open Overnight Processing with insulin nights → left ticks read whole units, orange bars sized to dose, right axis shows Δ; summary shows both Nights w/ and w/o Insulin. Diagnostics clean.

### 1.3 ✅ Daily Readings: separate meter types into differently-colored lines
- **Was:** `DailyReadingsChartView` plotted one blue series regardless of `meterType`.
- **Done:**
  1. Added file-scoped `MeterReadingPoint` (date/glucose/meterType) — did **not** mutate the shared `FastingDataPoint`.
  2. Current-period line (Day/Week/Month) now renders **one `LineMark` series per meter type** via `series: .value("Meter", …)`, colored from a fixed `meterPalette` (blue/teal/indigo/cyan/mint/pink/brown/gray — deliberately avoids the red/yellow/green glucose-range colors, orange MM line, purple prev-night marker). Missing meter → "Unknown".
  3. Points keep glucose-range coloring; historical overlays stay dimmed blue (per-code decision, avoids clutter); orange MM line and prev-night marker unchanged.
  4. Legend: dynamic per-meter chips (`meterLegend`) replace the old single "Selected Day" blue chip; faded historical chips kept (`historicalLegend`).
- **Verify:** Open Daily Readings on a day/period with ≥2 meters → distinct colored lines + meter legend. Full project build passed.

### 1.4 ✅ Glycemic Load on Start/End of Meal
- **Formula:** `GL = glycemicIndexGuess × carbGuess / 100` (only when both present).
- **Done:**
  1. Added derived (getter-only, non-persisted) `glycemicLoad: Double?` on `GlucoseEvent` in `Item.swift` — reusable for future EventRow display + tests.
  2. `EventFormView` shows a read-only **"Glycemic Load"** row in Meal Details when GI and carbs are both entered, computed live from the text fields. Color-banded per standard GL: Low ≤10 green, Medium 11–19 yellow, High ≥20 red.
  3. EventRow display deferred (optional).
- **Verify:** Enter GI 70, carbs 30 → GL shows "21". Diagnostics clean.
- **Test:** ⬜ Unit test the model `glycemicLoad` incl. nil handling (Phase 2.3).

### 1.5 ✅ "Non-Diabetic Meal" flag on Start of Meal
- **Done:**
  1. Added `nonDiabeticMeal: Bool = false` (default → CloudKit-safe) to `GlucoseEvent` (property, init param, assignment).
  2. `EventFormView`: `Toggle("Non-Diabetic Meal")` at the top of Meal Details, **shown only for Start of Meal**; state var + init; persisted in both save branches as `(eventType == "Start of Meal") ? nonDiabeticMeal : false`.
  3. `DataExporter` DTO: property + backward-compatible `decodeIfPresent(... ) ?? false` + map from/to event.
  4. EventRow badge deferred (optional).
- **Verify:** Full build passed. Round-trip check when running: flag a Start of Meal, export JSON → key present; import → flag restored.

### 1.6 ✅ Split "time since last meal" into two summary entries
- **Was:** ContentView showed one line from the last **End of Meal** (`timeSinceLastMealEnd`).
- **Done:** Added `timeSinceLastMealStart(now:)` (last **Start of Meal**) + shared `mealDurationText(_:)` formatter. Summary now renders two labels — "…since start of last meal" and "…since end of last meal" — each independently hidden when its event type doesn't exist yet.
- **Verify:** Diagnostics clean. In-app: both lines appear with correct durations; start-only or end-only cases degrade gracefully.

### 1.7 ✅ Experiment-name data integrity check
- **Done:** Added check #16 "Unknown Experiment" to `DataIntegrityView`. Any event carrying experiment data (`experimentQuantity` or `experimentQuantityUnit` set — only ever produced for experiment event types) whose `eventType` is **not** in `Set(settings.experiments)` is flagged as a warning. Catches experiments renamed/removed in Settings that orphan historical records. Standard event types never carry experiment data, so no false positives.
- **Verify:** Diagnostics clean. In-app: rename/remove an experiment in Settings → its past events surface under "Unknown Experiment".
- **Test:** ⬜ Deferred to Phase 2.3 — `issues` is a View computed property over `@Query` + `SettingsManager.shared`; needs extraction to a pure function to unit-test (as do the other 15 checks).

### 1.8 ✅ "App-recommended insulin" checkbox in Medicine section
- **Rationale:** Enables feedback loop for the estimator (Phase 3). The *field* is independent of the estimator, so it ships now.
- **Done:**
  1. Added `insulinRecommendedByApp: Bool = false` to `GlucoseEvent` (property, init param, assignment).
  2. `EventFormView`: `Toggle("App-Recommended Dose")` inside the Medicine section, shown only when a medicine (dose) is set. Persisted in both save branches as `(showMedicine && effectiveMedicineName != nil) ? insulinRecommendedByApp : false`.
  3. `DataExporter` DTO: property + backward-compatible `decodeIfPresent(...) ?? false` + both maps.
- **Verify:** Full suite (22 tests; round-trip + legacy-default assertions extended to cover this field) — `** TEST SUCCEEDED **` on the iOS 26.5 sim.

---

## Phase 2 — Medium (quality, correctness, performance)

### 2.1 ✅ Chart performance pass
- **Findings:** Data scale is modest (~376 events/month in the bundled export → low-thousands total), so per-pass array filtering is cheap in absolute terms. Confirmed `A1CEstimate` and `RollingAverages` already use the two-pointer sliding window (O(N+D), not O(N·D)), and `MultiMeterEstimator.computeDeviations` is already MainActor-cached. The real smell was **expensive derived collections recomputed many times per render**.
- **Done:**
  - `RollingAveragesChartView`: `rollingPoints` / `rollingMultiMeterPoints` were each recomputed ~7× per render (empty-check, chart, y-scale, 4× latest-stats, MM equivalents). Now computed **once** in `body` and threaded through; `yDomain`/`latestAverage` converted to take the precomputed arrays.
  - `A1CEstimateChartView`: `a1cDataPoints` / `a1cMultiMeterPoints` (each a full filter + per-reading estimate + 90-day sliding window) were recomputed ~6–8× per render. Now computed **once** in `body`; `averageA1C`/`yDomain` converted to functions over the precomputed arrays. This is the biggest win (the MM series runs the estimator per reading).
  - Behavior-identical (same marks, scales, stats). Full build + suite green.
- **Left as-is (diminishing returns):** Fasting/Bedtime/Average/Peak/DailyReadings do lighter per-render work (single-period filters, not repeated 90-day windows). DailyReadings' 1.3 meter-grouping is computed a few times per render but each pass is one period's readings — flagged for a future compute-once if profiling ever shows need.
- **Note:** True open-time profiling needs Instruments + UI interaction (can't automate here); optimizations are algorithmic/structural and verified for parity via build + tests.

### 2.2 ✅ More data-integrity checks
- **Done:** Extracted all checks out of the view into a pure `enum IntegrityChecker.issues(events:meterTypes:medicineTypes:experiments:now:)` (testable without SwiftData/SwiftUI; `now` injected for deterministic future-date/A1C-window tests). Added 3 new checks:
  - **Unknown Meter** — BG reading with a non-empty `meterType` not in `settings.meterTypes` (empty is still handled by "Missing Meter").
  - **Unknown Medicine** — `medicineName` (≠ "None") not in `settings.medicineTypes`.
  - **Implausible A1C** — `a1cValue` outside 3–20% (error).
  - Total checks now 19. View recomputes the list once per render (compute-once, per 2.1).
- **Verify:** Each new check covered by a unit test with a crafted failing example (and a passing counter-example for the "unknown" ones).

### 2.3 ✅ More unit tests
- **Done:** Added an **IntegrityChecker** suite (8 tests: clean data, implausible BG, unknown meter ±, unknown medicine, implausible A1C, unknown experiment ±, future timestamp, missing dose) — enabled by the 2.2 extraction. Earlier added the Glycemic Load suite (3) and extended DataExporter round-trip/legacy for `nonDiabeticMeal` + `insulinRecommendedByApp`. Suite now 30 tests, green.
- **Deferred test debt (needs the same extract-to-pure-function treatment):** meal-activity copy, two meal-timer summary logic, overnight insulin windowing / nights-with-vs-without counts, DailyReadings meter grouping. Estimator math will get tests in Phase 3.

### 2.4 ✅ Atomic transactions review
- **Audited** every `modelContext` write site. Findings + fixes:
  - **JSON import (`SettingsView`)** — was a bare per-event `insert` loop relying on autosave, with **no error handling**, reporting "Successfully imported N" unconditionally. Now wrapped in `try modelContext.transaction { … }` (single atomic save via SwiftData; verified API signature), with `rollback()` + an honest failure message on error. This was the real gap.
  - **Batch delete (`ContentView.deleteEvents`)** — multi-delete loop now wrapped in a `transaction` with `rollback()` on failure, so a partial failure can't delete some rows and leave others.
  - **`EventFormView.saveEvent`** — a single event insert/update (atomic under autosave). Its settings promotion (named locations, injection sites, meal presets, activities) writes to **UserDefaults**, a *separate* store — cross-store (UserDefaults + SwiftData) atomicity isn't practically achievable and is low-stakes/idempotent (promoting a name even if the event didn't persist is harmless). Left as-is by design; documented here.
- **Scope note:** "atomic" here = *local* transaction integrity. CloudKit (3.2) sync is eventually-consistent and orthogonal.
- **Verify:** Full build + suite green.

---

## Phase 3 — Big Features

### 3.1 ⬜ Insulin Tracking & Estimation (new top-level screen)
Multi-step; ships incrementally so each step is usable.

**Reference — insulin/supplement pharmacokinetics (literature values, USER MUST VERIFY & make editable):**

| Agent | Class | Onset | Peak | Duration | Notes |
|---|---|---|---|---|---|
| Lispro (Humalog) | Rapid | ~15 min | ~1–2 h | ~4–5 h | Meal/correction bolus |
| Lantus (glargine U-100) | Long, basal | ~1–2 h | ~flat (no true peak) | ~24 h | Once daily |
| Toujeo (glargine U-300) | Long, basal | ~6 h | flat | >24 h (up to ~36 h) | More gradual than Lantus |
| Berberine | Oral supplement | hours | n/a (chronic) | chronic | **Not insulin**; sustained effect over weeks — model as chronic, not per-dose acute |
| Inositol | Oral supplement | n/a | n/a (chronic) | chronic | **Not insulin**; insulin sensitizer, chronic |

> These are starting parameters to store in a config the user can edit. Berberine/Inositol are supplements with chronic (not acute per-dose) glucose effects — the estimator should treat them separately from injected insulin.

**Increment 1 (estimator core) — ✅ DONE.** New `InsulinEstimator.swift` (pure logic, no UI): `InsulinClass`, `InsulinProfile` (editable PK params + `fractionActive(at:)` cumulative curve — triangular for peaked rapid, uniform ramp for flat basals, 0 for chronic supplements) with `InsulinProfile.defaults` (Lispro/Lantus/Toujeo/Berberine/Inositol), `InsulinEstimateInput`/`DoseRecommendation`/`BGPredictionPoint`, the `InsulinEstimator` protocol, and `PKCurveEstimator` (dose = clamp(round(gap / effectiveISFPerUnit)), gap from a drift-adjusted no-insulin projection; PK curve shapes the predicted trajectory). 9 unit tests, green. Safety disclaimer in the file header.

**Steps:**
1. ✅ **Estimator abstraction** — `protocol InsulinEstimator` with `recommend(_:)` + `predictedCurve(units:input:step:)`. Concrete `PKCurveEstimator`; swappable.
2. ⬜ **Input screen** — new selectable screen (same pattern as charts): current BG, activity (Bedtime/Before Lunch/etc.), target BG + target time (+ target activity like "Waking up"), insulin type, max dose cap.
3. ✅ **PK-curve model** — `InsulinProfile.fractionActive(at:)` / `effectShape(at:targetHours:)` from editable params.
4. ⬜ **Empirical fit (basic)** — regress overnight `bedtimeBG − fastingBG` against bedtime dose to estimate an **Insulin Sensitivity Factor (ISF)** = mg/dL drop per unit. Recommended dose ≈ `clamp(round(baseline + (currentBG − targetBG)/ISF), 0, maxDose)`.
5. 🔷 **Liver-reservoir / drift term** — the additive drift term (`endogenousDriftPerHour`) is modeled and used in `PKCurveEstimator` (no-insulin baseline = `currentBG + drift·h`). **Pending:** estimating its value from history (a fixed/user input for now).
6. ⬜ **Filtering (v1, replaceable)** — apply a simple recursive filter (start with exponentially-weighted / alpha-beta on ISF and drift) over history, per insulin type. Documented as v1 with a clear seam to replace with **Kalman** (recommended end-state: 2-state model = glucose + reservoir/drift). Rationale captured in code comments.
7. 🔷 **Prediction graph** — the data (`PKCurveEstimator.predictedCurve`) exists and is tested; **pending** the chart UI plotting no-insulin vs suggested dose.
8. ⬜ **Interpolated recommendation display** — show the single rounded integer dose for current circumstances with confidence/uncertainty context. (Design needs care — show the "why": current BG, target, ISF, curve.)
9. ⬜ **Feedback loop** — consume the `insulinRecommendedByApp` flag (1.8): compare recommended vs. actual outcomes to refine the filter over time.

**Verify (worked example from user):** BG 123 at bedtime + 13 u Toujeo → ~80 by morning; goal wake at 75. The estimator/curve should reproduce this order of magnitude once fit to history.

### 3.2 ⬜ CloudKit cross-device sync (SwiftData + NSPersistentCloudKit)
- **Steps:**
  1. ⬜ Add `.cloudKitDatabase(.automatic)` to the `ModelConfiguration` in `edt_glucoseApp.swift`.
  2. ⬜ Add CloudKit container capability + verify entitlements (iCloud container already declared; needs CloudKit service, currently only `CloudDocuments`).
  3. ⬜ Confirm schema is CloudKit-valid (all attrs optional/defaulted — already true; no unique constraints — confirmed). Add defaults to any new fields (1.5, 1.8).
  4. ⬜ Test two-device sync; handle first-run/migration of existing local store.
  5. ⬜ Reconcile with iCloud JSON export path (keep as backup/interop).
- **Verify:** Create event on device A → appears on device B.

### 3.3 ⬜ Apple Watch companion app
- **Depends on:** 3.2 (shared synced store) — decided.
- **Steps:**
  1. ⬜ Add watchOS target sharing the model + CloudKit store (App Group if needed).
  2. ⬜ Watch view: latest BG measurement + latest average info.
  3. ⬜ (Optional) complication / quick summary.
- **Verify:** Watch shows latest reading matching phone.

### 3.4 🔬 Apple Health (HealthKit) import — exercise & movement
- **Steps:**
  1. 🔬 Confirm HealthKit entitlement + `Info.plist` usage strings (not currently configured).
  2. ⬜ Read workouts / step / distance / active energy via `HKHealthStore`.
  3. ⬜ Decide storage: mirror into `GlucoseEvent` (e.g. Walk events) vs. a separate read-only overlay on charts.
- **Verify:** A logged Apple workout appears in the app.
- **Note:** HealthKit is read-focused here; can also *write* BG/meals to Health later (future).

---

## Phase 4 — Research / Future ("Bigger Goals")

### 4.1 🔬 Libre CGM data import
- **Finding:** No official public consumer API. Options: LibreLinkUp (unofficial, ToS-gray), Nightscout bridge, or HealthKit (if a bridging app writes glucose to Health — cleanest & sanctioned). **Recommend routing Libre → Apple Health → our HealthKit import (3.4)** rather than a direct unofficial API.
- **Action:** Spike feasibility; document chosen path before building.

### 4.2 🔬 BG estimates from recent readings + time-since-meal + est. calories
- Predictive model reusing the estimator infra (3.1) and meal data. Design after estimator v1 exists.

### 4.3 ⬜ Symptom tracking (pains / shocks / tickles vs. BG)
- **Steps:** Add a "Symptom" event type (or fields) capturing sensation type + intensity + location; then a correlation chart vs. BG. Reuses event/chart patterns.

### 4.4 ⬜ Walking-before/after-meal effect analysis
- Chart/analysis comparing post-meal BG when a Walk occurred near a meal vs. not. Reuses Walk + meal events.

### 4.5 🔬 Multi-device data-sharing hardening
- Covered largely by 3.2; this tracks edge cases (conflict handling, large-history sync perf, Watch offline).

---

## Open Questions / To Confirm Later
- **Glycemic Load display location** — form only, or also `EventRow`/summaries? (Defaulting to Meal Details section in form; revisit.)
- **Insulin PK parameters** — user to verify literature values and whether Berberine/Inositol should appear in the insulin estimator at all (they're chronic supplements).
- **Filter end-state** — confirm Kalman (2-state: glucose + liver reservoir) as the target once v1 empirical fit is validated.
- **HealthKit write-back** — do we also push BG/meals into Apple Health? (Deferred.)

---

## Changelog
- 2026-07-11 — Initial spec created. 4 key decisions locked (overnight chart, CloudKit sync, estimator protocol-first, quick-wins-first ordering).
- 2026-07-11 — Shipped 1.1–1.6 (committed as v1.1, build 2).
- 2026-08-08 — Shipped 1.7 (experiment-name integrity check) and 1.8 (app-recommended-insulin checkbox). **Phase 1 complete (8/8).** Suite green (22 tests) on the iOS 26.5 sim. Not yet committed.

## Testing Note
- The test target's deployment target is **iOS 26.5**. Tests only run on a simulator with that runtime — a booted iPhone on 26.3/26.4 reports "TEST FAILED / No result" for every test (even pure-logic ones) with no crash log. Boot a 26.5 iPhone; if the RunAllTests MCP still reports "No result", run `xcodebuild test -scheme edt-glucose -destination 'platform=iOS Simulator,id=<26.5 udid>'` directly.
