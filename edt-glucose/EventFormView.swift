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
    @Query(sort: \GlucoseEvent.timestamp, order: .reverse) private var allEvents: [GlucoseEvent]

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
    @State private var injectionSite: String
    @State private var injectionAngleText: String
    @State private var injectionDistanceText: String
    @State private var injectionDistanceUnit: String
    @State private var insulinRecommendedByApp: Bool

    // Blood Glucose Guess
    @State private var bloodGlucoseGuessText: String

    // Walk
    @State private var walkDistanceText: String

    // Meal Enhancements
    @State private var foodDescription: String
    @State private var calorieGuessText: String
    @State private var carbGuessText: String
    @State private var locationName: String
    @State private var streetAddress: String
    @State private var gpsCoordinates: String

    // A1C
    @State private var a1cValueText: String

    // Meal nutrition
    @State private var proteinGuessText: String
    @State private var glycemicIndexGuessText: String
    @State private var nonDiabeticMeal: Bool

    // Test strip
    @State private var testStripLot: String
    @State private var testStripExpiration: Date?
    @State private var hasTestStripExpiration: Bool

    // Finger used for BG measurement
    @State private var fingerUsed: String
    @State private var fingerSide: String

    // Experiment
    @State private var experimentQuantityText: String
    @State private var experimentQuantityUnit: String

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
        _injectionSite = State(initialValue: event?.injectionSite ?? "")
        _injectionAngleText = State(initialValue: {
            if let angle = event?.injectionAngleDegrees {
                return angle.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", angle)
                    : String(format: "%.1f", angle)
            }
            return ""
        }())
        _injectionDistanceText = State(initialValue: {
            if let dist = event?.injectionDistanceValue {
                return dist.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", dist)
                    : String(format: "%.1f", dist)
            }
            return ""
        }())
        _injectionDistanceUnit = State(initialValue: event?.injectionDistanceUnit ?? "in")
        _insulinRecommendedByApp = State(initialValue: event?.insulinRecommendedByApp ?? false)

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
        _streetAddress = State(initialValue: event?.streetAddress ?? "")
        _gpsCoordinates = State(initialValue: event?.gpsCoordinates ?? "")

        // A1C
        _a1cValueText = State(initialValue:
            event?.a1cValue != nil ? String(format: "%.1f", event!.a1cValue!) : "")

        // Meal nutrition
        _proteinGuessText = State(initialValue:
            event?.proteinGuess != nil ? "\(event!.proteinGuess!)" : "")
        _glycemicIndexGuessText = State(initialValue:
            event?.glycemicIndexGuess != nil ? "\(event!.glycemicIndexGuess!)" : "")
        _nonDiabeticMeal = State(initialValue: event?.nonDiabeticMeal ?? false)

        // Experiment
        _experimentQuantityText = State(initialValue: {
            if let qty = event?.experimentQuantity {
                return qty.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", qty)
                    : String(qty)
            }
            return ""
        }())
        _experimentQuantityUnit = State(initialValue: event?.experimentQuantityUnit ?? "mg")

        // Test strip - auto-fill from settings for new events
        if let event = event {
            _testStripLot = State(initialValue: event.testStripLot ?? "")
            _testStripExpiration = State(initialValue: event.testStripExpiration)
            _hasTestStripExpiration = State(initialValue: event.testStripExpiration != nil)
        } else {
            let meter = event?.meterType ?? ""
            let defaults = settings.testStripDefaults[meter]
            _testStripLot = State(initialValue: defaults?.lot ?? "")
            _testStripExpiration = State(initialValue: defaults?.expiration)
            _hasTestStripExpiration = State(initialValue: defaults?.expiration != nil)
        }

        _fingerUsed = State(initialValue: event?.fingerUsed ?? "")
        _fingerSide = State(initialValue: event?.fingerSide ?? "")
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

    private var showExperiment: Bool {
        settings.experiments.contains(eventType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Event Type", selection: $eventType) {
                        ForEach(settings.eventTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                        if !settings.experiments.isEmpty {
                            ForEach(settings.experiments, id: \.self) { exp in
                                Text("🧪 \(exp)").tag(exp)
                            }
                        }
                    }

                    if showMealType {
                        Picker("Meal Type", selection: $mealType) {
                            Text("None").tag("")
                            ForEach(settings.mealTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .onChange(of: mealType) { _, _ in
                            populateFromStartOfMeal()
                        }
                    }
                }

                Section("Date & Time") {
                    DatePicker("Date & Time", selection: $timestamp)
                }
                .onChange(of: eventType) { _, newType in
                    if newType == "End of Meal" {
                        populateFromStartOfMeal()
                    }
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
                        .onChange(of: meterType) { _, newMeter in
                            if let defaults = settings.testStripDefaults[newMeter] {
                                if testStripLot.isEmpty {
                                    testStripLot = defaults.lot
                                }
                                if testStripExpiration == nil {
                                    testStripExpiration = defaults.expiration
                                    hasTestStripExpiration = defaults.expiration != nil
                                }
                            }
                        }

                        TextField("Strip Lot #", text: $testStripLot)

                        Toggle("Strip Expiration", isOn: $hasTestStripExpiration)
                        if hasTestStripExpiration {
                            DatePicker("Expiration", selection: Binding(
                                get: { testStripExpiration ?? Date() },
                                set: { testStripExpiration = $0 }
                            ), displayedComponents: .date)
                        }

                        Picker("Finger Used", selection: $fingerUsed) {
                            Text("None").tag("")
                            ForEach(SettingsManager.fingerOptions, id: \.self) { finger in
                                Text(finger).tag(finger)
                            }
                        }

                        Picker("Finger Side", selection: $fingerSide) {
                            Text("None").tag("")
                            ForEach(SettingsManager.fingerSideOptions, id: \.self) { side in
                                Text(side).tag(side)
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

                            HStack {
                                TextField("Injection Site", text: $injectionSite)
                                if !settings.injectionSites.isEmpty {
                                    Picker("", selection: $injectionSite) {
                                        Text("Custom").tag("")
                                        ForEach(settings.injectionSites, id: \.self) { site in
                                            Text(site).tag(site)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }

                            HStack {
                                TextField("Angle", text: $injectionAngleText)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: injectionAngleText) { _, newValue in
                                        let filtered = newValue.filter { "0123456789.".contains($0) }
                                        if let v = Double(filtered), v > 360 {
                                            injectionAngleText = "360"
                                        } else {
                                            injectionAngleText = filtered
                                        }
                                    }
                                Text("° from navel (R=0°, L=180°)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                TextField("Distance", text: $injectionDistanceText)
                                    .keyboardType(.decimalPad)
                                Picker("Unit", selection: $injectionDistanceUnit) {
                                    Text("in").tag("in")
                                    Text("cm").tag("cm")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 110)
                            }

                            Toggle("App-Recommended Dose", isOn: $insulinRecommendedByApp)
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
                        if eventType == "Start of Meal" {
                            Toggle("Non-Diabetic Meal", isOn: $nonDiabeticMeal)
                        }
                        if !settings.mealPresets.isEmpty {
                            Picker("Saved Meal", selection: Binding(
                                get: { foodDescription },
                                set: { newValue in
                                    foodDescription = newValue
                                    if let preset = settings.mealPresets.first(where: { $0.name == newValue }) {
                                        if let cal = preset.calorieGuess { calorieGuessText = "\(cal)" }
                                        if let carbs = preset.carbGuess { carbGuessText = "\(carbs)" }
                                        if let protein = preset.proteinGuess { proteinGuessText = "\(protein)" }
                                        if let gi = preset.glycemicIndexGuess { glycemicIndexGuessText = "\(gi)" }
                                    }
                                }
                            )) {
                                Text("Custom").tag("")
                                ForEach(settings.mealPresets) { preset in
                                    Text(preset.name).tag(preset.name)
                                }
                            }
                        }
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
                            TextField("Protein guess", text: $proteinGuessText)
                                .keyboardType(.numberPad)
                            Text("g protein")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            TextField("Glycemic index", text: $glycemicIndexGuessText)
                                .keyboardType(.numberPad)
                                .onChange(of: glycemicIndexGuessText) { _, newValue in
                                    let filtered = newValue.filter(\.isNumber)
                                    if let value = Int(filtered), value > 100 {
                                        glycemicIndexGuessText = "100"
                                    } else {
                                        glycemicIndexGuessText = filtered
                                    }
                                }
                            Text("GI (0–100)")
                                .foregroundStyle(.secondary)
                        }

                        // Glycemic Load = GI × carbs / 100, shown when both are present.
                        if let gl = glycemicLoad {
                            HStack {
                                Text("Glycemic Load")
                                Spacer()
                                Text(String(format: "%.0f", gl))
                                    .fontWeight(.medium)
                                    .foregroundStyle(glycemicLoadColor(gl))
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

                if showExperiment {
                    Section("Experiment Details") {
                        HStack {
                            TextField("Quantity", text: $experimentQuantityText)
                                .keyboardType(.decimalPad)
                            Picker("Unit", selection: $experimentQuantityUnit) {
                                ForEach(settings.unitsOfMeasure, id: \.self) { unit in
                                    Text(unit).tag(unit)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Location") {
                    HStack {
                        TextField("Location", text: $locationName)
                        if !settings.namedLocations.isEmpty {
                            Picker("", selection: $locationName) {
                                Text("Custom").tag("")
                                ForEach(settings.namedLocations) { loc in
                                    Text(loc.name).tag(loc.name)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .onChange(of: locationName) { _, newName in
                        // When the user picks a saved location, copy its stored
                        // address and GPS coords into the corresponding fields
                        // so the event carries them in the text display.
                        if let saved = settings.namedLocation(named: newName) {
                            if let addr = saved.streetAddress { streetAddress = addr }
                            if let coords = saved.gpsCoordinates { gpsCoordinates = coords }
                        }
                    }

                    TextField("Street Address", text: $streetAddress, axis: .vertical)
                        .lineLimit(1...3)

                    TextField("GPS Coordinates (lat,lon)", text: $gpsCoordinates)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        Task {
                            if let details = await LocationManager.shared.requestLocationDetails() {
                                if let name = details.displayName { locationName = name }
                                if let addr = details.streetAddress { streetAddress = addr }
                                if let coords = details.gpsCoordinates { gpsCoordinates = coords }
                            }
                        }
                    } label: {
                        if LocationManager.shared.isLocating {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Getting location...")
                            }
                        } else {
                            Label("Use Current Location", systemImage: "location.fill")
                        }
                    }
                    .disabled(LocationManager.shared.isLocating)
                }

                Section("Activity") {
                    HStack {
                        TextField("Activity Description", text: $activityDescription)
                        if !settings.activities.isEmpty {
                            Picker("", selection: $activityDescription) {
                                Text("Custom").tag("")
                                ForEach(settings.activities, id: \.self) { activity in
                                    Text(activity).tag(activity)
                                }
                            }
                            .labelsHidden()
                        }
                    }
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

    /// Live Glycemic Load from the entered GI and carb text fields
    /// (GI × carbs / 100). `nil` until both are valid numbers.
    private var glycemicLoad: Double? {
        guard let gi = Int(glycemicIndexGuessText), let carbs = Int(carbGuessText) else { return nil }
        return Double(gi) * Double(carbs) / 100.0
    }

    /// Standard Glycemic Load bands: Low ≤10 (green), Medium 11–19 (yellow), High ≥20 (red).
    private func glycemicLoadColor(_ gl: Double) -> Color {
        if gl >= 20 { return .red }
        if gl > 10 { return .yellow }
        return .green
    }

    private func findMatchingStartOfMeal(mealType: String) -> GlucoseEvent? {
        allEvents.first { event in
            event.eventType == "Start of Meal"
            && event.mealType == mealType
            && !mealType.isEmpty
        }
    }

    private func populateFromStartOfMeal() {
        guard eventType == "End of Meal", !mealType.isEmpty, !isEditing else { return }
        if let startEvent = findMatchingStartOfMeal(mealType: mealType) {
            if activityDescription.isEmpty { activityDescription = startEvent.activityDescription }
            if let food = startEvent.foodDescription { foodDescription = food }
            if let cal = startEvent.calorieGuess { calorieGuessText = "\(cal)" }
            if let carbs = startEvent.carbGuess { carbGuessText = "\(carbs)" }
            if let protein = startEvent.proteinGuess { proteinGuessText = "\(protein)" }
            if let gi = startEvent.glycemicIndexGuess { glycemicIndexGuessText = "\(gi)" }
            if let loc = startEvent.locationName { locationName = loc }
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
        let proteinGuess = Int(proteinGuessText)
        let glycemicIndexGuess = Int(glycemicIndexGuessText).map { min(max($0, 0), 100) }

        let effectiveMedicineName = (showMedicine && medicineName != "None") ? medicineName : nil
        let effectiveMedicineDose = effectiveMedicineName != nil ? medicineDose : nil
        let effectiveMedicineDoseUnit = effectiveMedicineName != nil ? medicineDoseUnit : nil
        let trimmedSite = injectionSite.trimmingCharacters(in: .whitespaces)
        let effectiveInjectionSite = effectiveMedicineName != nil && !trimmedSite.isEmpty ? trimmedSite : nil
        let effectiveInjectionAngle = effectiveMedicineName != nil
            ? Double(injectionAngleText).map { min(max($0, 0), 360) }
            : nil
        let effectiveInjectionDistance = effectiveMedicineName != nil ? Double(injectionDistanceText) : nil
        let effectiveInjectionDistanceUnit = effectiveInjectionDistance != nil ? injectionDistanceUnit : nil
        let trimmedAddress = streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveStreetAddress = trimmedAddress.isEmpty ? nil : trimmedAddress
        let trimmedCoords = gpsCoordinates.trimmingCharacters(in: .whitespaces)
        let effectiveGPSCoordinates = trimmedCoords.isEmpty ? nil : trimmedCoords
        let effectiveFingerUsed = showBloodGlucose && !fingerUsed.isEmpty ? fingerUsed : nil
        let effectiveFingerSide = showBloodGlucose && !fingerSide.isEmpty ? fingerSide : nil
        let effectiveGlucoseGuess = showBloodGlucose ? glucoseGuess : nil
        let effectiveWalkDistance = showWalkDistance ? walkDistance : nil
        let effectiveFoodDescription = showMealDetails && !foodDescription.isEmpty ? foodDescription : nil
        let effectiveCalorieGuess = showMealDetails ? calorieGuess : nil
        let effectiveCarbGuess = showMealDetails ? carbGuess : nil
        let effectiveProteinGuess = showMealDetails ? proteinGuess : nil
        let effectiveGlycemicIndexGuess = showMealDetails ? glycemicIndexGuess : nil
        let effectiveLocationName = !locationName.isEmpty ? locationName : nil
        let effectiveA1cValue = showA1C ? a1cValue : nil
        let effectiveTestStripLot = showBloodGlucose && !testStripLot.isEmpty ? testStripLot : nil
        let effectiveTestStripExpiration = showBloodGlucose && hasTestStripExpiration ? testStripExpiration : nil
        let experimentQuantity = Double(experimentQuantityText)
        let effectiveExperimentQuantity = showExperiment ? experimentQuantity : nil
        let effectiveExperimentQuantityUnit = showExperiment && experimentQuantity != nil ? experimentQuantityUnit : nil

        // Auto-save (or update) the named location with the captured address
        // and GPS coords so the next time it's selected, those fields fill in.
        if let loc = effectiveLocationName {
            settings.addOrUpdateNamedLocation(
                name: loc,
                streetAddress: effectiveStreetAddress,
                gpsCoordinates: effectiveGPSCoordinates
            )
        }

        // Auto-save new injection site
        if let site = effectiveInjectionSite {
            settings.addInjectionSiteIfNew(site)
        }

        // Auto-save test strip defaults for this meter type
        if let lot = effectiveTestStripLot, !meterType.isEmpty {
            settings.updateTestStripDefault(for: meterType, lot: lot, expiration: effectiveTestStripExpiration)
        }

        // Auto-save new activity
        if !activityDescription.isEmpty {
            settings.addActivityIfNew(activityDescription)
        }

        // Auto-save meal preset if all nutrition fields are filled
        if showMealDetails, let food = effectiveFoodDescription,
           let cal = calorieGuess, let carbs = carbGuess,
           let protein = proteinGuess, let gi = glycemicIndexGuess {
            settings.saveMealPreset(MealPreset(
                name: food,
                calorieGuess: cal,
                carbGuess: carbs,
                proteinGuess: protein,
                glycemicIndexGuess: gi
            ))
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
            event.proteinGuess = effectiveProteinGuess
            event.glycemicIndexGuess = effectiveGlycemicIndexGuess
            event.nonDiabeticMeal = (eventType == "Start of Meal") ? nonDiabeticMeal : false
            event.testStripLot = effectiveTestStripLot
            event.testStripExpiration = effectiveTestStripExpiration
            event.experimentQuantity = effectiveExperimentQuantity
            event.experimentQuantityUnit = effectiveExperimentQuantityUnit
            event.injectionSite = effectiveInjectionSite
            event.injectionAngleDegrees = effectiveInjectionAngle
            event.injectionDistanceValue = effectiveInjectionDistance
            event.injectionDistanceUnit = effectiveInjectionDistanceUnit
            event.insulinRecommendedByApp = (showMedicine && effectiveMedicineName != nil) ? insulinRecommendedByApp : false
            event.streetAddress = effectiveStreetAddress
            event.gpsCoordinates = effectiveGPSCoordinates
            event.fingerUsed = effectiveFingerUsed
            event.fingerSide = effectiveFingerSide
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
                a1cValue: effectiveA1cValue,
                proteinGuess: effectiveProteinGuess,
                glycemicIndexGuess: effectiveGlycemicIndexGuess,
                nonDiabeticMeal: (eventType == "Start of Meal") ? nonDiabeticMeal : false,
                testStripLot: effectiveTestStripLot,
                testStripExpiration: effectiveTestStripExpiration,
                experimentQuantity: effectiveExperimentQuantity,
                experimentQuantityUnit: effectiveExperimentQuantityUnit,
                injectionSite: effectiveInjectionSite,
                injectionAngleDegrees: effectiveInjectionAngle,
                injectionDistanceValue: effectiveInjectionDistance,
                injectionDistanceUnit: effectiveInjectionDistanceUnit,
                insulinRecommendedByApp: (showMedicine && effectiveMedicineName != nil) ? insulinRecommendedByApp : false,
                streetAddress: effectiveStreetAddress,
                gpsCoordinates: effectiveGPSCoordinates,
                fingerUsed: effectiveFingerUsed,
                fingerSide: effectiveFingerSide
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
