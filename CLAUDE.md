# CLAUDE.md — edt-glucose

## Project Overview

A personal blood glucose tracking app for iPhone built with SwiftUI and SwiftData.
Tracks BG measurements, meals, medicine, walks, A1C results, and related daily events.

## Build & Run

- **Platform:** iOS 17.0+
- **IDE:** Xcode 16.0+
- **Frameworks:** SwiftUI, SwiftData, Charts, UserNotifications, CoreLocation
- Build via Xcode or `xcodebuild -scheme edt-glucose -destination 'platform=iOS Simulator,name=iPhone 16'`
- No tests exist yet

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
| `DailyReadingsChartView.swift` | Day's BG readings chart with day picker |
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
| `LocationManager.swift` | GPS + reverse geocoding (`@MainActor @Observable`) |
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

Extended fields: `medicineName?`, `medicineDose?`, `medicineDoseUnit?`, `bloodGlucoseGuess?`, `walkDistanceMiles?`, `foodDescription?`, `calorieGuess?`, `carbGuess?`, `proteinGuess?`, `glycemicIndexGuess?`, `locationName?`, `a1cValue?`, `testStripLot?`, `testStripExpiration?`, `experimentQuantity?`, `experimentQuantityUnit?`

## Event Types & Conditional Logic

| Event Type | Shows |
|---|---|
| Blood Glucose Measurement | BG input, meter picker, BG guess, medicine, test strip lot/expiration |
| Start of Meal / End of Meal | Meal type, food description, calorie/carb/protein guess, glycemic index |
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

Export saves to `iCloud Drive/Documents/edt-glucose/` when available, falls back to file picker.
