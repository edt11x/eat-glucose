# CLAUDE.md — edt-glucose

## Project Overview

A personal blood glucose tracking app for iPhone built with SwiftUI and SwiftData.
Tracks BG measurements, meals, medicine, walks, A1C results, and related daily events.

## Build & Run

- **Platform:** iOS 17.0+
- **IDE:** Xcode 16.0+
- **No external dependencies** — pure Apple frameworks (SwiftUI, SwiftData, Charts, UserNotifications)
- Build via Xcode or `xcodebuild -scheme edt-glucose -destination 'platform=iOS Simulator,name=iPhone 16'`
- No tests exist yet

## Architecture

- **SwiftUI** — all views
- **SwiftData** — single `@Model` class `GlucoseEvent` in `Item.swift`, on-device SQLite
- **UserDefaults** — user-configurable lists and preferences via `SettingsManager` singleton
- **@Observable** — `SettingsManager` uses Observation framework for reactive updates
- **No Combine** — uses Swift async/await (e.g., `NotificationManager` is an `actor`)

## Key Files

| File | Purpose |
|---|---|
| `edt_glucoseApp.swift` | App entry point, `ModelContainer` setup |
| `ContentView.swift` | Main event list grouped by day, `EventRow` display |
| `EventFormView.swift` | Add/edit event form with conditional sections |
| `SettingsView.swift` | Settings, data import/export, configurable lists |
| `SettingsManager.swift` | `@Observable` singleton, UserDefaults persistence |
| `AppTheme.swift` | `AppTheme` enum with color palettes (Dark, Light, System, Obsidianite) |
| `Item.swift` | `GlucoseEvent` SwiftData model |
| `DataExporter.swift` | JSON import/export, `Codable` DTO, `FileDocument` |
| `FastingChartView.swift` | Fasting BG chart (first reading after 5 AM daily) using Swift Charts |
| `MeterDeviationView.swift` | Meter comparison (pairs within 5 min vs Precision Neo reference) |
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

## Data Model — GlucoseEvent

Core fields: `timestamp`, `eventType`, `mealType?`, `bloodGlucose?`, `meterType?`, `activityDescription`, `notes`

Extended fields: `medicineName?`, `medicineDose?`, `medicineDoseUnit?`, `bloodGlucoseGuess?`, `walkDistanceMiles?`, `foodDescription?`, `calorieGuess?`, `carbGuess?`, `locationName?`, `a1cValue?`

## Event Types & Conditional Logic

| Event Type | Shows |
|---|---|
| Blood Glucose Measurement | BG input, meter picker, BG guess, medicine section |
| Start of Meal / End of Meal | Meal type picker, food description, calorie/carb guess, location |
| Walk | Walk distance in miles |
| A1C | A1C percentage input |
| Bedtime | Activity + notes only |

## Export Format

JSON via `DataExporter`. Structure: `{ exportDate, events: [GlucoseEventData] }`. ISO 8601 dates. Backwards-compatible decoder handles missing fields from older exports.

## iCloud

Export saves to `iCloud Drive/Documents/edt-glucose/` when available, falls back to file picker.
