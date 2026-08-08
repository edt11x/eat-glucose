//
//  DataIntegrityView.swift
//  edt-glucose
//

import SwiftUI
import SwiftData

struct IntegrityIssue: Identifiable {
    enum Severity {
        case error
        case warning

        var color: Color {
            switch self {
            case .error:   return .red
            case .warning: return .yellow
            }
        }

        var systemImage: String {
            switch self {
            case .error:   return "exclamationmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let category: String
    let message: String
    /// Anchor event for navigation/editing (if any).
    let event: GlucoseEvent?
}

struct DataIntegrityView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    @State private var editingEvent: GlucoseEvent?

    /// Maximum time we'd expect a meal to remain open before its End of Meal.
    private let maxMealDuration: TimeInterval = 6 * 60 * 60 // 6 hours

    private var issues: [IntegrityIssue] {
        var results: [IntegrityIssue] = []

        // 1. Orphan Start of Meal (no matching End of Meal within 6h)
        let starts = events.filter { $0.eventType == "Start of Meal" }
        let ends = events.filter { $0.eventType == "End of Meal" }
        for start in starts {
            let cutoff = start.timestamp.addingTimeInterval(maxMealDuration)
            let hasMatch = ends.contains { end in
                end.timestamp > start.timestamp
                && end.timestamp <= cutoff
                && (end.mealType == start.mealType || end.mealType == nil || start.mealType == nil)
            }
            if !hasMatch {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Unfinished Meal",
                    message: "Start of Meal at \(formatted(start.timestamp))" +
                             (start.mealType.map { " (\($0))" } ?? "") +
                             " has no End of Meal within 6 hours.",
                    event: start
                ))
            }
        }

        // 2. End of Meal without a preceding Start of Meal
        for end in ends {
            let lowerBound = end.timestamp.addingTimeInterval(-maxMealDuration)
            let hasStart = starts.contains { start in
                start.timestamp >= lowerBound
                && start.timestamp < end.timestamp
                && (start.mealType == end.mealType || start.mealType == nil || end.mealType == nil)
            }
            if !hasStart {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Orphan Meal End",
                    message: "End of Meal at \(formatted(end.timestamp))" +
                             (end.mealType.map { " (\($0))" } ?? "") +
                             " has no Start of Meal within the prior 6 hours.",
                    event: end
                ))
            }
        }

        // 3. BG outside plausible physiological range
        for event in events where event.eventType == "Blood Glucose Measurement" {
            guard let bg = event.bloodGlucose else {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Missing Reading",
                    message: "Blood Glucose Measurement at \(formatted(event.timestamp)) has no value.",
                    event: event
                ))
                continue
            }
            if bg < 20 || bg > 600 {
                results.append(IntegrityIssue(
                    severity: .error,
                    category: "Implausible BG",
                    message: "BG of \(bg) mg/dL at \(formatted(event.timestamp)) is outside the plausible 20–600 range.",
                    event: event
                ))
            }
        }

        // 4. BG without a meter
        for event in events where event.eventType == "Blood Glucose Measurement" {
            if event.bloodGlucose != nil, event.meterType?.isEmpty != false {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Missing Meter",
                    message: "BG reading at \(formatted(event.timestamp)) has no meter selected.",
                    event: event
                ))
            }
        }

        // 5. Future-dated events
        let now = Date()
        for event in events where event.timestamp > now {
            results.append(IntegrityIssue(
                severity: .warning,
                category: "Future Timestamp",
                message: "Event \"\(event.eventType)\" is dated \(formatted(event.timestamp)) — in the future.",
                event: event
            ))
        }

        // 6. Duplicate-looking BG entries (same minute, same value, same meter)
        let bgEvents = events
            .filter { $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil }
            .sorted { $0.timestamp < $1.timestamp }
        for i in 1..<max(bgEvents.count, 1) {
            let prev = bgEvents[i - 1]
            let curr = bgEvents[i]
            if abs(curr.timestamp.timeIntervalSince(prev.timestamp)) < 60,
               curr.bloodGlucose == prev.bloodGlucose,
               curr.meterType == prev.meterType {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Possible Duplicate",
                    message: "Two identical BG readings near \(formatted(curr.timestamp)).",
                    event: curr
                ))
            }
        }

        // 7. Medicine without a dose
        for event in events {
            if let med = event.medicineName, med != "None",
               event.medicineDose == nil {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Missing Dose",
                    message: "\(med) at \(formatted(event.timestamp)) has no dose recorded.",
                    event: event
                ))
            }
        }

        // 8. Test strip used after its expiration date
        for event in events {
            if let lot = event.testStripLot,
               let exp = event.testStripExpiration,
               event.timestamp > exp {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Expired Strip",
                    message: "BG reading at \(formatted(event.timestamp)) used strip lot \(lot) which expired \(formattedDate(exp)).",
                    event: event
                ))
            }
        }

        // 9. Bedtime event with no nearby BG reading (within 2 h)
        let twoHours: TimeInterval = 2 * 60 * 60
        for event in events where event.eventType == "Bedtime" {
            let hasNearby = events.contains { other in
                other.eventType == "Blood Glucose Measurement"
                && other.bloodGlucose != nil
                && abs(other.timestamp.timeIntervalSince(event.timestamp)) <= twoHours
            }
            if !hasNearby {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Bedtime Without BG",
                    message: "Bedtime event at \(formatted(event.timestamp)) has no BG reading within 2 hours.",
                    event: event
                ))
            }
        }

        // 10. Unusually long walk distance — probably a typo (units mix-up)
        for event in events {
            if let miles = event.walkDistanceMiles, miles > 30 {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Implausible Walk",
                    message: "Walk on \(formatted(event.timestamp)) recorded \(String(format: "%.1f", miles)) miles — over 30 mi is unusual.",
                    event: event
                ))
            }
        }

        // 11. Injection distance outside a believable range
        for event in events {
            guard let dist = event.injectionDistanceValue,
                  let unit = event.injectionDistanceUnit else { continue }
            let maxAllowed: Double = (unit == "cm") ? 30 : 12
            if dist > maxAllowed {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Implausible Injection Distance",
                    message: "Injection at \(formatted(event.timestamp)) recorded \(String(format: "%.1f", dist)) \(unit) from navel — over \(String(format: "%.0f", maxAllowed)) \(unit) is unusual.",
                    event: event
                ))
            }
        }

        // 12. Two same-mealType meal starts on the same day
        let calendar = Calendar.current
        let mealStarts = events.filter { $0.eventType == "Start of Meal" && $0.mealType != nil }
        let groupedByDay = Dictionary(grouping: mealStarts) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        for (day, dayMeals) in groupedByDay {
            let byType = Dictionary(grouping: dayMeals) { $0.mealType ?? "" }
            for (mealType, instances) in byType where instances.count > 1 && !mealType.isEmpty {
                // Skip Snack and Energy Drink — those legitimately repeat.
                guard mealType != "Snack", mealType != "Energy Drink" else { continue }
                let anchor = instances.min(by: { $0.timestamp < $1.timestamp })
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Duplicate Meal Type",
                    message: "\(instances.count) \"\(mealType)\" events on \(formattedDate(day)).",
                    event: anchor
                ))
            }
        }

        // 13. GPS coordinates that don't parse as "lat,lon"
        for event in events {
            guard let coords = event.gpsCoordinates, !coords.isEmpty else { continue }
            if !parsesAsLatLon(coords) {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Malformed GPS",
                    message: "GPS \"\(coords)\" on event at \(formatted(event.timestamp)) is not in lat,lon format.",
                    event: event
                ))
            }
        }

        // 14. A1C event with no BG readings in the previous 90 days for context
        let ninetyDays: TimeInterval = 90 * 24 * 60 * 60
        for event in events where event.eventType == "A1C" {
            let windowStart = event.timestamp.addingTimeInterval(-ninetyDays)
            let priorBGCount = events.filter {
                $0.eventType == "Blood Glucose Measurement"
                && $0.bloodGlucose != nil
                && $0.timestamp >= windowStart
                && $0.timestamp <= event.timestamp
            }.count
            if priorBGCount < 5 {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Unverified A1C",
                    message: "A1C event at \(formatted(event.timestamp)) has only \(priorBGCount) BG readings in the prior 90 days.",
                    event: event
                ))
            }
        }

        // 15. Injection angle outside the valid 0–360 range (defensive — the
        // form clamps inputs, but imported / legacy data may not)
        for event in events {
            if let angle = event.injectionAngleDegrees, angle < 0 || angle > 360 {
                results.append(IntegrityIssue(
                    severity: .error,
                    category: "Bad Injection Angle",
                    message: "Injection angle \(String(format: "%.1f", angle))° at \(formatted(event.timestamp)) is outside 0–360°.",
                    event: event
                ))
            }
        }

        // 16. Experiment records whose name no longer matches a configured
        // experiment. An event carrying experiment data (quantity / unit) is
        // only ever produced for an experiment event type, so if its eventType
        // isn't in the configured list the name was renamed or removed in
        // Settings and the record is now orphaned.
        let configuredExperiments = Set(settings.experiments)
        for event in events {
            let hasExperimentData = event.experimentQuantity != nil
                || event.experimentQuantityUnit != nil
            if hasExperimentData, !configuredExperiments.contains(event.eventType) {
                results.append(IntegrityIssue(
                    severity: .warning,
                    category: "Unknown Experiment",
                    message: "Event \"\(event.eventType)\" at \(formatted(event.timestamp)) has experiment data but \"\(event.eventType)\" is not in the configured experiments list.",
                    event: event
                ))
            }
        }

        return results
    }

    /// Validates that a "lat,lon" string parses to two finite numbers within
    /// Earth's coordinate bounds.
    private func parsesAsLatLon(_ raw: String) -> Bool {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]),
              lat.isFinite, lon.isFinite,
              (-90...90).contains(lat),
              (-180...180).contains(lon)
        else { return false }
        return true
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var groupedByCategory: [(String, [IntegrityIssue])] {
        Dictionary(grouping: issues, by: \.category)
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if issues.isEmpty {
                    ContentUnavailableView(
                        "All Clear",
                        systemImage: "checkmark.shield.fill",
                        description: Text("No data integrity issues found.")
                    )
                } else {
                    List {
                        Section {
                            Text("Found \(issues.count) issue\(issues.count == 1 ? "" : "s"). Tap an issue to open the related event.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                        ForEach(groupedByCategory, id: \.0) { category, items in
                            Section(category) {
                                ForEach(items) { issue in
                                    Button {
                                        if let event = issue.event {
                                            editingEvent = event
                                        }
                                    } label: {
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: issue.severity.systemImage)
                                                .foregroundStyle(issue.severity.color)
                                            Text(issue.message)
                                                .font(.caption)
                                                .foregroundStyle(theme.eventTypeColor)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .listRowBackground(theme.rowBackground)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Data Integrity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingEvent) { event in
                EventFormView(event: event)
                    .preferredColorScheme(settings.preferredColorScheme)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    DataIntegrityView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
