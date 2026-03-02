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

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "drop.fill",
                        description: Text("Tap + to log your first event.")
                    )
                } else {
                    ForEach(groupedByDay, id: \.0) { date, dayEvents in
                        Section(header: Text(date, style: .date)) {
                            ForEach(dayEvents) { event in
                                EventRow(event: event)
                                    .contentShape(Rectangle())
                                    .onTapGesture { eventToEdit = event }
                            }
                            .onDelete { offsets in
                                deleteEvents(dayEvents: dayEvents, offsets: offsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Blood Glucose")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                EventFormView()
            }
            .sheet(item: $eventToEdit) { event in
                EventFormView(event: event)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.eventType)
                    .font(.headline)
                Spacer()
                Text(event.timestamp, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let mealType = event.mealType {
                    Label(mealType, systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let glucose = event.bloodGlucose {
                    Label("\(glucose) mg/dL", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(glucoseColor(for: glucose))
                }
                if let meter = event.meterType {
                    Label(meter, systemImage: "sensor.tag.radiowaves.forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !event.activityDescription.isEmpty {
                Text(event.activityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
}

#Preview {
    ContentView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
