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

    // Medicine
    @State private var medicineName: String
    @State private var medicineDoseText: String
    @State private var medicineDoseUnit: String

    // Blood Glucose Guess
    @State private var bloodGlucoseGuessText: String

    // Walk
    @State private var walkDistanceText: String

    // Meal Enhancements
    @State private var foodDescription: String
    @State private var calorieGuessText: String
    @State private var carbGuessText: String
    @State private var locationName: String

    // A1C
    @State private var a1cValueText: String

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

        // Medicine
        _medicineName = State(initialValue: event?.medicineName ?? "None")
        _medicineDoseText = State(initialValue: {
            if let dose = event?.medicineDose {
                return dose.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", dose)
                    : String(dose)
            }
            return ""
        }())
        _medicineDoseUnit = State(initialValue: event?.medicineDoseUnit ?? "units")

        // BG Guess
        _bloodGlucoseGuessText = State(initialValue:
            event?.bloodGlucoseGuess != nil ? "\(event!.bloodGlucoseGuess!)" : "")

        // Walk
        _walkDistanceText = State(initialValue:
            event?.walkDistanceMiles != nil ? String(format: "%.2f", event!.walkDistanceMiles!) : "")

        // Meal enhancements
        _foodDescription = State(initialValue: event?.foodDescription ?? "")
        _calorieGuessText = State(initialValue:
            event?.calorieGuess != nil ? "\(event!.calorieGuess!)" : "")
        _carbGuessText = State(initialValue:
            event?.carbGuess != nil ? "\(event!.carbGuess!)" : "")
        _locationName = State(initialValue: event?.locationName ?? "")

        // A1C
        _a1cValueText = State(initialValue:
            event?.a1cValue != nil ? String(format: "%.1f", event!.a1cValue!) : "")
    }

    private var showMealType: Bool {
        eventType == "Start of Meal" || eventType == "End of Meal"
    }

    private var showMealDetails: Bool {
        eventType == "Start of Meal" || eventType == "End of Meal"
    }

    private var showBloodGlucose: Bool {
        eventType == "Blood Glucose Measurement"
    }

    private var showMedicine: Bool {
        eventType == "Blood Glucose Measurement"
    }

    private var showWalkDistance: Bool {
        eventType == "Walk"
    }

    private var showA1C: Bool {
        eventType == "A1C"
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

                if showBloodGlucose {
                    Section("Blood Glucose") {
                        HStack {
                            TextField("Guess", text: $bloodGlucoseGuessText)
                                .keyboardType(.numberPad)
                                .onChange(of: bloodGlucoseGuessText) { _, newValue in
                                    let filtered = newValue.filter(\.isNumber)
                                    if let value = Int(filtered), value > 600 {
                                        bloodGlucoseGuessText = "600"
                                    } else {
                                        bloodGlucoseGuessText = filtered
                                    }
                                }
                            Text("mg/dL guess")
                                .foregroundStyle(.secondary)
                        }

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
                }

                if showMedicine {
                    Section("Medicine") {
                        Picker("Medicine", selection: $medicineName) {
                            ForEach(settings.medicineTypes) { med in
                                Text(med.name).tag(med.name)
                            }
                        }
                        .onChange(of: medicineName) { _, newName in
                            if let config = settings.medicineTypes.first(where: { $0.name == newName }) {
                                medicineDoseText = config.defaultDose > 0
                                    ? (config.defaultDose.truncatingRemainder(dividingBy: 1) == 0
                                        ? String(format: "%.0f", config.defaultDose)
                                        : String(config.defaultDose))
                                    : ""
                                medicineDoseUnit = config.defaultUnit
                            }
                        }

                        if medicineName != "None" {
                            HStack {
                                TextField("Dose", text: $medicineDoseText)
                                    .keyboardType(.decimalPad)
                                Picker("Unit", selection: $medicineDoseUnit) {
                                    ForEach(settings.unitsOfMeasure, id: \.self) { unit in
                                        Text(unit).tag(unit)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }

                if showWalkDistance {
                    Section("Walk Details") {
                        HStack {
                            TextField("0.00", text: $walkDistanceText)
                                .keyboardType(.decimalPad)
                            Text("miles")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if showMealDetails {
                    Section("Meal Details") {
                        TextField("Food Description", text: $foodDescription)

                        HStack {
                            TextField("Calorie guess", text: $calorieGuessText)
                                .keyboardType(.numberPad)
                            Text("cal")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            TextField("Carb guess", text: $carbGuessText)
                                .keyboardType(.numberPad)
                            Text("g carbs")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            TextField("Location", text: $locationName)
                            if !settings.locations.isEmpty {
                                Picker("", selection: $locationName) {
                                    Text("Custom").tag("")
                                    ForEach(settings.locations, id: \.self) { loc in
                                        Text(loc).tag(loc)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }

                if showA1C {
                    Section("A1C Result") {
                        HStack {
                            TextField("0.0", text: $a1cValueText)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundStyle(.secondary)
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
        let glucoseGuess = Int(bloodGlucoseGuessText).map { min(max($0, 0), 600) }
        let medicineDose = Double(medicineDoseText)
        let walkDistance = Double(walkDistanceText)
        let calorieGuess = Int(calorieGuessText)
        let carbGuess = Int(carbGuessText)
        let a1cValue = Double(a1cValueText)

        let effectiveMedicineName = (showMedicine && medicineName != "None") ? medicineName : nil
        let effectiveMedicineDose = effectiveMedicineName != nil ? medicineDose : nil
        let effectiveMedicineDoseUnit = effectiveMedicineName != nil ? medicineDoseUnit : nil
        let effectiveGlucoseGuess = showBloodGlucose ? glucoseGuess : nil
        let effectiveWalkDistance = showWalkDistance ? walkDistance : nil
        let effectiveFoodDescription = showMealDetails && !foodDescription.isEmpty ? foodDescription : nil
        let effectiveCalorieGuess = showMealDetails ? calorieGuess : nil
        let effectiveCarbGuess = showMealDetails ? carbGuess : nil
        let effectiveLocationName = showMealDetails && !locationName.isEmpty ? locationName : nil
        let effectiveA1cValue = showA1C ? a1cValue : nil

        // Auto-save new location
        if let loc = effectiveLocationName {
            settings.addLocationIfNew(loc)
        }

        if let event = existingEvent {
            event.timestamp = timestamp
            event.eventType = eventType
            event.mealType = showMealType && !mealType.isEmpty ? mealType : nil
            event.bloodGlucose = showBloodGlucose ? glucose : nil
            event.meterType = showBloodGlucose && !meterType.isEmpty ? meterType : nil
            event.activityDescription = activityDescription
            event.notes = notes
            event.medicineName = effectiveMedicineName
            event.medicineDose = effectiveMedicineDose
            event.medicineDoseUnit = effectiveMedicineDoseUnit
            event.bloodGlucoseGuess = effectiveGlucoseGuess
            event.walkDistanceMiles = effectiveWalkDistance
            event.foodDescription = effectiveFoodDescription
            event.calorieGuess = effectiveCalorieGuess
            event.carbGuess = effectiveCarbGuess
            event.locationName = effectiveLocationName
            event.a1cValue = effectiveA1cValue
        } else {
            let newEvent = GlucoseEvent(
                timestamp: timestamp,
                eventType: eventType,
                mealType: showMealType && !mealType.isEmpty ? mealType : nil,
                bloodGlucose: showBloodGlucose ? glucose : nil,
                meterType: showBloodGlucose && !meterType.isEmpty ? meterType : nil,
                activityDescription: activityDescription,
                notes: notes,
                medicineName: effectiveMedicineName,
                medicineDose: effectiveMedicineDose,
                medicineDoseUnit: effectiveMedicineDoseUnit,
                bloodGlucoseGuess: effectiveGlucoseGuess,
                walkDistanceMiles: effectiveWalkDistance,
                foodDescription: effectiveFoodDescription,
                calorieGuess: effectiveCalorieGuess,
                carbGuess: effectiveCarbGuess,
                locationName: effectiveLocationName,
                a1cValue: effectiveA1cValue
            )
            modelContext.insert(newEvent)
        }

        // Schedule post-meal timer if enabled and this is an End of Meal event
        if eventType == "End of Meal" && settings.postMealTimerEnabled {
            Task {
                await NotificationManager.shared.scheduleRandomPostMealTimer()
            }
        }

        dismiss()
    }
}

#Preview {
    EventFormView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
