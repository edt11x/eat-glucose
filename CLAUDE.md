# CLAUDE.md — edt-glucose

## Project Overview

A personal blood glucose tracking app for iPhone built with SwiftUI and SwiftData.
Tracks BG measurements, meals, medicine, walks, A1C results, and related daily events.

## Build & Run

- **Platform:** iOS 26.2+
- **IDE:** Xcode 16.0+
- **Frameworks:** SwiftUI, SwiftData, Charts, UserNotifications, CoreLocation, MapKit (reverse geocoding via `MKReverseGeocodingRequest`)
- Build via Xcode or `xcodebuild -scheme edt-glucose -destination 'platform=iOS Simulator,name=iPhone 16'`
- Unit tests live in `edt-glucoseTests/edt_glucoseTests.swift` (Swift Testing framework). Run via Xcode Cmd+U or `RunAllTests` MCP. Use `@testable import edt_glucose` and `MultiMeterEstimator.computeDeviationsUncached(from:)` for tests of cached APIs so the test doesn't have to be `@MainActor`.

## Architecture

- **SwiftUI** — all views
- **SwiftData** — single `@Model` class `GlucoseEvent` in `Item.swift`, on-device SQLite
- **Swift Charts** — fasting, bedtime, daily, average, peak, weekly curve, A1C estimate, meal spacing, pre-meal scatter, and experiment comparison charts
- **CoreLocation** — GPS location with reverse geocoding via `LocationManager`
- **UserDefaults** — user-configurable lists and preferences via `SettingsManager` singleton
- **@Observable** — `SettingsManager` and `LocationManager` use Observation framework
- **No Combine** — uses Swift async/await (e.g., `NotificationManager` is an `actor`)

## Key Files

| File | Purpose |
|---|---|
| `edt_glucoseApp.swift` | App entry point, `ModelContainer` setup |
| `ContentView.swift` | Main event list grouped by day, `EventRow` display, time summary, eA1C |
| `EventFormView.swift` | Add/edit event form with conditional sections |
| `SettingsView.swift` | Settings, data import/export, configurable lists |
| `SettingsManager.swift` | `@Observable` singleton, UserDefaults persistence |
| `AppTheme.swift` | `AppTheme` enum with color palettes (Dark, Light, System, Obsidianite) |
| `Item.swift` | `GlucoseEvent` SwiftData model |
| `DataExporter.swift` | JSON import/export, `Codable` DTO, `FileDocument` |
| `FastingChartView.swift` | Fasting BG chart with average line |
| `BedtimeChartView.swift` | Bedtime BG chart (last reading before 5 AM) |
| `DailyReadingsChartView.swift` | Day/Week/Month BG readings with historical overlays and previous night reading; current-period line split into one color-coded series per meter type |
| `PeakReadingsChartView.swift` | Peak (max) BG per day chart |
| `WeeklyCurveChartView.swift` | Historical smoothed vs current week comparison |
| `A1CEstimateChartView.swift` | Rolling 90-day estimated A1C chart |
| `AvgTimeBetweenMealsChartView.swift` | Daily average hours between meals over time |
| `BestMealSpacingView.swift` | Meal spacing vs BG scatter plot |
| `PreMealBGScatterView.swift` | Pre-meal BG vs time since last meal scatter |
| `AverageBGChartView.swift` | Daily average BG chart with multi-meter estimates |
| `ExperimentComparisonChartView.swift` | Before vs during experiment BG comparison |
| `MeterDeviationView.swift` | Meter comparison (pairs within 5 min vs Precision Neo) |
| `MultiMeterEstimator.swift` | Shared deviation computation and multi-meter average formula |
| `RollingAveragesChartView.swift` | Trailing 7 / 14 / 30 / 90-day average BG per day, distinct colors. Per-window two-pointer sliding window (O(N+D)) |
| `OvernightProcessingChartView.swift` | Per-night `fastingBG − bedtimeBG` line (right axis) + bedtime-window insulin bars on a units-labelled left axis; "Nights w/ Insulin" and "Nights w/o Insulin" stats |
| `ChartTimeRange.swift` | Shared `.week/.month/.year/.all` enum + `ChartTimeRangePicker` |
| `DataIntegrityView.swift` | Surfaces orphan meal halves, BG out-of-range, duplicates, etc. |
| `LocationManager.swift` | GPS via CLLocationManager + MapKit `MKReverseGeocodingRequest`; returns `LocationDetails(displayName, streetAddress, gpsCoordinates)` |
| `NotificationManager.swift` | Post-meal timer notifications (`actor`) |

## Code Conventions

- **Naming:** PascalCase for types, camelCase for properties/methods
- **State:** `@State private var` for SwiftUI state, `let` for constants
- **Views:** Conform to `View`, define UI in `body`
- **Indentation:** 4 spaces
- **Imports:** Minimal — only what's needed (SwiftUI, SwiftData, Charts, etc.)
- **No force unwrapping** in view code; safe optionals with `if let`
- **Theme system:** All views reference `theme` (from `SettingsManager.shared.currentTheme`) for colors
- **Conditional form sections:** `EventFormView` shows/hides sections based on `eventType`
- **Glucose color coding:** Red <=69 or >180, Yellow 121-180, Green 70-120
- **A1C color coding:** Green <5.7, Yellow 5.7-6.4, Red >=6.5
- **Charts:** Use dotted orange `RuleMark` for average lines on all charts

## Data Model — GlucoseEvent

Core fields: `timestamp`, `eventType`, `mealType?`, `bloodGlucose?`, `meterType?`, `activityDescription`, `notes`

Extended fields: `medicineName?`, `medicineDose?`, `medicineDoseUnit?`, `injectionSite?`, `injectionAngleDegrees?`, `injectionDistanceValue?`, `injectionDistanceUnit?`, `bloodGlucoseGuess?`, `walkDistanceMiles?`, `foodDescription?`, `calorieGuess?`, `carbGuess?`, `proteinGuess?`, `glycemicIndexGuess?`, `nonDiabeticMeal` (Bool, default false), `locationName?`, `streetAddress?`, `gpsCoordinates?`, `a1cValue?`, `testStripLot?`, `testStripExpiration?`, `fingerUsed?`, `fingerSide?`, `experimentQuantity?`, `experimentQuantityUnit?`

Derived (getter-only, non-persisted): `glycemicLoad: Double?` = `glycemicIndexGuess × carbGuess / 100` when both are present.

## Event Types & Conditional Logic

| Event Type | Shows |
|---|---|
| Blood Glucose Measurement | BG input, meter picker, BG guess, medicine + injection site/angle/distance, test strip lot/expiration, finger used + finger side |
| Start of Meal / End of Meal | Meal type, food description, calorie/carb/protein guess, glycemic index, live Glycemic Load (when GI + carbs present); Start of Meal also shows a "Non-Diabetic Meal" toggle |
| Walk | Walk distance in miles |
| A1C | A1C percentage input |
| Bedtime | Activity + notes only |
| Experiments (user-defined) | Experiment quantity, unit of measure |
| All types | Location (with GPS), activity, notes |

## Multi-Meter Average Formula

```
MultiMeterAvg = P * (N + d1 + d2 + ... + d(N-1)) / N
```
Where P = Precision Neo reading (or estimated equivalent), N = total meter count, d_i = fractional avg % deviation. For non-reference meter M: `P_est = M_reading / (1 + d_M)`.

## Export Format

JSON via `DataExporter`. Structure: `{ exportDate, events: [GlucoseEventData] }`. ISO 8601 dates. Backwards-compatible decoder handles missing fields from older exports.

## iCloud

Export saves to the app's iCloud Drive container (`iCloud Drive/edt-glucose/`) when available, falls back to file picker.

## Commit Workflow

See `COMMIT_WORKFLOW.md` for the full procedure. Quick version:
1. `git status` + `git diff --stat` to assess state
2. Stage new files (check `.gitignore` first)
3. Log the session's prompts + responses to `prompts/YYYY-MM-DD-topic.md`
4. Update MEMORY.md, CLAUDE.md, README.md as needed
5. Commit with descriptive message + `Co-Authored-By` trailer
6. Push to remote

Shell script: `./scripts/commit-workflow.sh "message"`

## Conventions

- **Most-recent-first** — every list/table keyed on date or time (event list, chart readings tables, meter comparison pairs, etc.) displays newest entries at the top.
- **Orange multi-meter summary rows** — Daily Readings, Fasting, Bedtime, Average BG, Peak, Weekly Curve, A1C Estimate, Rolling Averages, Pre-Meal BG Scatter, and Best Meal Spacing render a secondary `HStack` of `StatBox(... valueColor: .orange)` (or an inline orange caption for scatter views) under the primary summary when meter deviations exist. Labels are suffixed with `(MM)`. `StatBox` accepts an optional `valueColor: Color?` that overrides `theme.eventTypeColor`.
- **MM deviations from full history** — chart views that filter by `ChartTimeRange` must compute `MultiMeterEstimator.computeDeviations(from: allEvents)` (the un-filtered `@Query`), not from the time-range-filtered `events`. Deviations are stable per-meter calibration; short windows often contain no Precision Neo pairs and would otherwise hide the MM line and stats.
- **`ChartTimeRange` picker** — charts without their own day/week/month nav expose a `.week/.month/.year/.all` segmented picker at the top, default `.month`. Filter-input charts (Fasting, Bedtime, Average BG, Peak, AvgTimeBetweenMeals, PreMealScatter, BestMealSpacing, MeterDeviation) filter the underlying `events`. Filter-output charts (A1C Estimate, Rolling Averages) keep `events` full and filter only the displayed points so the rolling lookback windows stay intact.
- **NamedLocation** — `SettingsManager.namedLocations: [NamedLocation]` is the source of truth for saved locations. Each entry carries optional `streetAddress` and `gpsCoordinates`. The location picker in `EventFormView` auto-fills those fields when an existing name is selected, and `saveEvent` calls `addOrUpdateNamedLocation(...)` so every save promotes the form's address/coords onto the saved entry.
- **Finger options** — `SettingsManager.fingerOptions` (10 entries L/R × thumb / index / middle / ring / little) and `SettingsManager.fingerSideOptions` (Thumb Side / Little Finger Side) are static `[String]` arrays — not user-configurable since the list is closed.
- **`MultiMeterEstimator.computeDeviations(from:)` is memoized** — keyed by event count + latest timestamp + a hashed map of meter-type counts. `@MainActor`-isolated cache; chart views call it freely without performance cost on re-render. Use `computeDeviationsUncached(from:)` from tests and `invalidateCache()` from callers that mutate the underlying data outside the normal MainActor write path (e.g. if SwiftData iCloud sync ever imports on a background context).
- **Rolling-window chart algorithm** — A1CEstimate and RollingAverages use two-pointer sliding windows over date-sorted readings (running sum maintained incrementally). When adding new rolling-window charts, follow the same pattern instead of re-filtering all readings per day.
- **Overnight Processing chart dividing line** — uses the same 5:00 AM convention as Fasting and Bedtime (fasting = first reading ≥ 5 AM that day, bedtime = last reading between 5 AM the prior day and 5 AM). Bedtime-window insulin = 8 PM–5 AM. If 5 AM ever becomes configurable, update Fasting, Bedtime, and OvernightProcessing together.
- **DataIntegrityView "Duplicate Meal Type" check** — intentionally excludes Snack and Energy Drink, which are designed to repeat in a day.
