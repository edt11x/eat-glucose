//
//  ContentView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GlucoseEvent.timestamp, order: .reverse) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared

    @State private var showingAddEvent = false
    @State private var eventToEdit: GlucoseEvent?
    @State private var showingSettings = false
    @State private var showingFastingChart = false
    @State private var showingMeterDeviation = false
    @State private var showingDailyChart = false
    @State private var showingPeakChart = false
    @State private var showingWeeklyCurve = false
    @State private var showingA1CEstimate = false

    private var theme: AppTheme { settings.currentTheme }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
            List {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "drop.fill",
                        description: Text("Tap + to log your first event.")
                    )
                } else {
                    // Time summary at top
                    Section {
                        if let bgInterval = timeSinceLastBG(now: context.date) {
                            let totalMinutes = Int(bgInterval) / 60
                            let hours = totalMinutes / 60
                            let minutes = totalMinutes % 60
                            Label(
                                hours > 0 ? "\(hours)h \(minutes)m since last BG" : "\(minutes)m since last BG",
                                systemImage: "drop.fill"
                            )
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryTextColor)
                        }
                        if let mealInterval = timeSinceLastMealEnd(now: context.date) {
                            let totalMinutes = Int(mealInterval) / 60
                            let hours = totalMinutes / 60
                            let minutes = totalMinutes % 60
                            Label(
                                hours > 0 ? "\(hours)h \(minutes)m since last meal" : "\(minutes)m since last meal",
                                systemImage: "fork.knife"
                            )
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryTextColor)
                        }
                        if let eA1C = estimatedA1C {
                            Label(String(format: "eA1C: %.1f%%", eA1C), systemImage: "percent")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(a1cColor(for: eA1C))
                        }
                    }
                    .listRowBackground(theme.rowBackground)

                    ForEach(groupedByDay, id: \.0) { date, dayEvents in
                        Section {
                            ForEach(dayEvents) { event in
                                EventRow(
                                    event: event,
                                    theme: theme,
                                    timeTo95: timeTo95(after: event),
                                    timeSinceLastMeal: timeSinceLastMeal(for: event),
                                    meterDeviations: meterDeviations
                                )
                                .listRowBackground(theme.rowBackground)
                                .contentShape(Rectangle())
                                .onTapGesture { eventToEdit = event }
                            }
                            .onDelete { offsets in
                                deleteEvents(dayEvents: dayEvents, offsets: offsets)
                            }
                        } header: {
                            Text(date, style: .date)
                                .foregroundStyle(theme.sectionHeaderColor)
                        }
                    }
                }
            }
            } // TimelineView
            .navigationTitle("Blood Glucose")
            .tint(theme.accentColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .tint(theme.toolbarIconColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showingDailyChart = true
                            } label: {
                                Label("Daily Readings", systemImage: "chart.line.uptrend.xyaxis")
                            }
                            Button {
                                showingFastingChart = true
                            } label: {
                                Label("Fasting BG Chart", systemImage: "chart.xyaxis.line")
                            }
                            Button {
                                showingPeakChart = true
                            } label: {
                                Label("Peak Readings", systemImage: "chart.line.flattrend.xyaxis")
                            }
                            Divider()
                            Button {
                                showingWeeklyCurve = true
                            } label: {
                                Label("Weekly Curve", systemImage: "waveform.path.ecg")
                            }
                            Button {
                                showingA1CEstimate = true
                            } label: {
                                Label("A1C Estimate", systemImage: "percent")
                            }
                            Divider()
                            Button {
                                showingMeterDeviation = true
                            } label: {
                                Label("Meter Comparison", systemImage: "arrow.left.arrow.right")
                            }
                        } label: {
                            Label("Charts", systemImage: "chart.bar")
                        }
                        .tint(theme.toolbarIconColor)

                        Button {
                            showingAddEvent = true
                        } label: {
                            Label("Add Event", systemImage: "plus")
                        }
                        .tint(theme.toolbarIconColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                EventFormView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(item: $eventToEdit) { event in
                EventFormView(event: event)
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingFastingChart) {
                FastingChartView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingDailyChart) {
                DailyReadingsChartView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingPeakChart) {
                PeakReadingsChartView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingMeterDeviation) {
                MeterDeviationView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingWeeklyCurve) {
                WeeklyCurveChartView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .sheet(isPresented: $showingA1CEstimate) {
                A1CEstimateChartView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
        }
        .preferredColorScheme(settings.preferredColorScheme)
    }

    // Group events by calendar day
    private var groupedByDay: [(Date, [GlucoseEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // Find how long after an "End of Meal" event until BG reaches 95 or below
    private func timeTo95(after event: GlucoseEvent) -> TimeInterval? {
        guard event.eventType == "End of Meal" else { return nil }
        let subsequent = events
            .filter { $0.timestamp > event.timestamp && $0.bloodGlucose != nil }
            .sorted { $0.timestamp < $1.timestamp }
        guard let target = subsequent.first(where: { ($0.bloodGlucose ?? 999) <= 95 }) else {
            return nil
        }
        return target.timestamp.timeIntervalSince(event.timestamp)
    }

    // Find the time since the most recent meal event before this event
    private func timeSinceLastMeal(for event: GlucoseEvent) -> TimeInterval? {
        // Look for the most recent "Start of Meal" or "End of Meal" before this event
        let mealEvents = events
            .filter { ($0.eventType == "Start of Meal" || $0.eventType == "End of Meal") && $0.timestamp < event.timestamp }
            .sorted { $0.timestamp > $1.timestamp }
        guard let lastMeal = mealEvents.first else { return nil }
        return event.timestamp.timeIntervalSince(lastMeal.timestamp)
    }

    // Meter deviation data for multi-meter estimates
    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    // Time since the most recent blood glucose measurement
    private func timeSinceLastBG(now: Date) -> TimeInterval? {
        guard let last = events.first(where: {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }) else { return nil }
        return now.timeIntervalSince(last.timestamp)
    }

    // Time since the most recent "End of Meal" event
    private func timeSinceLastMealEnd(now: Date) -> TimeInterval? {
        guard let last = events.first(where: { $0.eventType == "End of Meal" }) else { return nil }
        return now.timeIntervalSince(last.timestamp)
    }

    // Estimated A1C from all blood glucose readings using ADAG formula
    private var estimatedA1C: Double? {
        let bgValues = events.compactMap { event -> Int? in
            guard event.eventType == "Blood Glucose Measurement" else { return nil }
            return event.bloodGlucose
        }
        guard !bgValues.isEmpty else { return nil }
        let avgBG = Double(bgValues.reduce(0, +)) / Double(bgValues.count)
        return (avgBG + 46.7) / 28.7
    }

    private func a1cColor(for value: Double) -> Color {
        if value < 5.7 { return .green }
        else if value < 6.5 { return .yellow }
        else { return .red }
    }

    private func deleteEvents(dayEvents: [GlucoseEvent], offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(dayEvents[index])
            }
        }
    }
}

struct EventRow: View {
    let event: GlucoseEvent
    var theme: AppTheme = .dark
    var timeTo95: TimeInterval? = nil
    var timeSinceLastMeal: TimeInterval? = nil
    var meterDeviations: [MultiMeterEstimator.MeterDeviation] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.eventType)
                    .font(.headline)
                    .foregroundStyle(theme.eventTypeColor)
                Spacer()
                Text(event.timestamp, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            // Time since last meal
            if let interval = timeSinceLastMeal {
                let totalMinutes = Int(interval) / 60
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                Label(
                    hours > 0 ? "\(hours)h \(minutes)m since meal" : "\(minutes)m since meal",
                    systemImage: "clock"
                )
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
            }

            HStack(spacing: 12) {
                if let mealType = event.mealType {
                    Label(mealType, systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
                if let glucose = event.bloodGlucose {
                    Label("\(glucose) mg/dL", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(glucoseColor(for: glucose))
                }
                if let meter = event.meterType {
                    Label(meter, systemImage: "sensor.tag.radiowaves.forward")
                        .font(.caption)
                        .foregroundStyle(theme.meterColor)
                }
            }

            // Multi-meter average estimate
            if let bg = event.bloodGlucose, let meter = event.meterType,
               let estimate = MultiMeterEstimator.estimate(
                   reading: bg, meterType: meter, deviations: meterDeviations
               ) {
                Label(String(format: "~%.0f avg (all meters)", estimate), systemImage: "function")
                    .font(.caption2)
                    .foregroundStyle(theme.tertiaryTextColor)
            }

            // BG Guess vs Actual
            if let guess = event.bloodGlucoseGuess {
                if let actual = event.bloodGlucose {
                    let diff = actual - guess
                    let icon = diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "equal"
                    Label("Guessed \(guess), off by \(abs(diff))", systemImage: icon)
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                } else {
                    Label("Guessed \(guess) mg/dL", systemImage: "questionmark.circle")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
            }

            // Medicine
            if let med = event.medicineName {
                HStack(spacing: 4) {
                    Label(med, systemImage: "pills.fill")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                    if let dose = event.medicineDose, let unit = event.medicineDoseUnit {
                        Text("(\(dose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dose) : String(dose)) \(unit))")
                            .font(.caption)
                            .foregroundStyle(theme.tertiaryTextColor)
                    }
                }
            }

            // Walk distance
            if let distance = event.walkDistanceMiles {
                Label(String(format: "%.2f mi", distance), systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            // Meal details
            if let food = event.foodDescription {
                Label(food, systemImage: "takeoutbag.and.cup.and.straw.fill")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            HStack(spacing: 12) {
                if let cal = event.calorieGuess {
                    Label("~\(cal) cal", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
                if let carbs = event.carbGuess {
                    Label("~\(carbs)g carbs", systemImage: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
                if let protein = event.proteinGuess {
                    Label("~\(protein)g protein", systemImage: "fish.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
                if let gi = event.glycemicIndexGuess {
                    Label("GI ~\(gi)", systemImage: "gauge.with.needle")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
            }

            // Test strip info
            if let lot = event.testStripLot {
                HStack(spacing: 12) {
                    Label("Lot: \(lot)", systemImage: "tag.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                    if let exp = event.testStripExpiration {
                        Label {
                            Text(exp, format: .dateTime.month().year())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption2)
                        .foregroundStyle(exp < Date() ? .red : theme.tertiaryTextColor)
                    }
                }
            }

            if let location = event.locationName {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(theme.tertiaryTextColor)
            }

            // A1C
            if let a1c = event.a1cValue {
                Label(String(format: "%.1f%%", a1c), systemImage: "percent")
                    .font(.caption)
                    .foregroundStyle(a1cColor(for: a1c))
            }

            // Time to 95
            if let interval = timeTo95 {
                let totalMinutes = Int(interval) / 60
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                Label(
                    hours > 0 ? "\(hours)h \(minutes)m to 95" : "\(minutes)m to 95",
                    systemImage: "timer"
                )
                .font(.caption2)
                .foregroundStyle(.green)
            }

            if !event.activityDescription.isEmpty {
                Text(event.activityDescription)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.caption2)
                    .foregroundStyle(theme.tertiaryTextColor)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func glucoseColor(for value: Int) -> Color {
        if value <= 69 || value > 180 {
            return .red
        } else if value > 120 {
            return .yellow
        } else {
            return .green
        }
    }

    private func a1cColor(for value: Double) -> Color {
        if value < 5.7 { return .green }
        else if value < 6.5 { return .yellow }
        else { return .red }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
