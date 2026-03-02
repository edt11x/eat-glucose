//
//  EventFormView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import SwiftUI
import SwiftData

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let settings = SettingsManager.shared

    var existingEvent: GlucoseEvent?

    @State private var timestamp: Date
    @State private var eventType: String
    @State private var mealType: String
    @State private var bloodGlucoseText: String
    @State private var meterType: String
    @State private var activityDescription: String
    @State private var notes: String

    private var isEditing: Bool { existingEvent != nil }

    init(event: GlucoseEvent? = nil) {
        self.existingEvent = event
        let settings = SettingsManager.shared
        _timestamp = State(initialValue: event?.timestamp ?? Date())
        _eventType = State(initialValue: event?.eventType ?? settings.eventTypes.first ?? "")
        _mealType = State(initialValue: event?.mealType ?? "")
        _bloodGlucoseText = State(initialValue: event?.bloodGlucose != nil ? "\(event!.bloodGlucose!)" : "")
        _meterType = State(initialValue: event?.meterType ?? "")
        _activityDescription = State(initialValue: event?.activityDescription ?? "")
        _notes = State(initialValue: event?.notes ?? "")
    }

    private var showMealType: Bool {
        eventType == "Start of Meal" || eventType == "End of Meal"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Event Type", selection: $eventType) {
                        ForEach(settings.eventTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    if showMealType {
                        Picker("Meal Type", selection: $mealType) {
                            Text("None").tag("")
                            ForEach(settings.mealTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                    }
                }

                Section("Date & Time") {
                    DatePicker("Date & Time", selection: $timestamp)
                }

                Section("Blood Glucose") {
                    HStack {
                        TextField("0–600", text: $bloodGlucoseText)
                            .keyboardType(.numberPad)
                            .onChange(of: bloodGlucoseText) { _, newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if let value = Int(filtered), value > 600 {
                                    bloodGlucoseText = "600"
                                } else {
                                    bloodGlucoseText = filtered
                                }
                            }
                        Text("mg/dL")
                            .foregroundStyle(.secondary)
                    }

                    Picker("Meter", selection: $meterType) {
                        Text("None").tag("")
                        ForEach(settings.meterTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                Section("Activity") {
                    TextField("Activity Description", text: $activityDescription)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                }
            }
        }
    }

    private func saveEvent() {
        let glucose = Int(bloodGlucoseText).map { min(max($0, 0), 600) }

        if let event = existingEvent {
            event.timestamp = timestamp
            event.eventType = eventType
            event.mealType = showMealType && !mealType.isEmpty ? mealType : nil
            event.bloodGlucose = glucose
            event.meterType = !meterType.isEmpty ? meterType : nil
            event.activityDescription = activityDescription
            event.notes = notes
        } else {
            let newEvent = GlucoseEvent(
                timestamp: timestamp,
                eventType: eventType,
                mealType: showMealType && !mealType.isEmpty ? mealType : nil,
                bloodGlucose: glucose,
                meterType: !meterType.isEmpty ? meterType : nil,
                activityDescription: activityDescription,
                notes: notes
            )
            modelContext.insert(newEvent)
        }

        dismiss()
    }
}

#Preview {
    EventFormView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
