//
//  SettingsView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings = SettingsManager.shared

    @Query(sort: \GlucoseEvent.timestamp, order: .reverse) private var events: [GlucoseEvent]

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: JSONDocument?
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    @State private var showingImportConfirm = false
    @State private var pendingImportEvents: [GlucoseEvent] = []
    @State private var showingAddTimerAlert = false
    @State private var newTimerValue = ""
    @State private var showingDataIntegrity = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearanceMode) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                }

                Section("Data") {
                    Button {
                        exportData()
                    } label: {
                        Label("Export Data (\(events.count) events)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(events.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        loadBundledTestData()
                    } label: {
                        Label("Load Bundled Test Data", systemImage: "doc.on.doc")
                    }

                    Button {
                        showingDataIntegrity = true
                    } label: {
                        Label("Data Integrity", systemImage: "checkmark.shield")
                    }
                }

                Section {
                    Toggle("Enable Post-Meal Timer", isOn: $settings.postMealTimerEnabled)

                    if settings.postMealTimerEnabled {
                        ForEach(settings.postMealTimerValues, id: \.self) { value in
                            Text("\(value) minutes")
                        }
                        .onDelete { offsets in
                            settings.postMealTimerValues.remove(atOffsets: offsets)
                        }

                        Button {
                            showingAddTimerAlert = true
                        } label: {
                            Label("Add Timer Value", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    HStack {
                        Text("Post-Meal Timer")
                        Spacer()
                        Button("Reset") { settings.resetTimerValues() }
                            .font(.caption)
                            .textCase(.none)
                    }
                }

                ConfigurableListSection(
                    title: "Event Types",
                    items: $settings.eventTypes,
                    onReset: { settings.resetEventTypes() }
                )

                ConfigurableListSection(
                    title: "Meal Types",
                    items: $settings.mealTypes,
                    onReset: { settings.resetMealTypes() }
                )

                ConfigurableListSection(
                    title: "Meter Types",
                    items: $settings.meterTypes,
                    onReset: { settings.resetMeterTypes() }
                )

                MedicineTypeListSection(
                    items: $settings.medicineTypes,
                    units: settings.unitsOfMeasure,
                    onReset: { settings.resetMedicineTypes() }
                )

                NamedLocationListSection(
                    items: $settings.namedLocations,
                    onReset: { settings.resetLocations() }
                )

                ConfigurableListSection(
                    title: "Activities",
                    items: $settings.activities,
                    onReset: { settings.resetActivities() }
                )

                MealPresetListSection(
                    items: $settings.mealPresets,
                    onReset: { settings.resetMealPresets() }
                )

                ConfigurableListSection(
                    title: "Experiments",
                    items: $settings.experiments,
                    onReset: { settings.resetExperiments() }
                )

                ConfigurableListSection(
                    title: "Injection Sites",
                    items: $settings.injectionSites,
                    onReset: { settings.resetInjectionSites() }
                )

                ConfigurableListSection(
                    title: "Units of Measure",
                    items: $settings.unitsOfMeasure,
                    onReset: { settings.resetUnitsOfMeasure() }
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    importMessage = "Export failed: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .alert("Import Data", isPresented: $showingImportConfirm) {
                Button("Import") {
                    for event in pendingImportEvents {
                        modelContext.insert(event)
                    }
                    importMessage = "Successfully imported \(pendingImportEvents.count) events."
                    pendingImportEvents = []
                    showingImportAlert = true
                }
                Button("Cancel", role: .cancel) {
                    pendingImportEvents = []
                }
            } message: {
                Text("Import \(pendingImportEvents.count) events? This will add them to your existing data.")
            }
            .alert("Data Transfer", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
            .sheet(isPresented: $showingDataIntegrity) {
                DataIntegrityView()
                    .preferredColorScheme(settings.preferredColorScheme)
            }
            .alert("Add Timer Value", isPresented: $showingAddTimerAlert) {
                TextField("Minutes", text: $newTimerValue)
                    .keyboardType(.numberPad)
                Button("Add") {
                    if let value = Int(newTimerValue), !settings.postMealTimerValues.contains(value) {
                        settings.postMealTimerValues.append(value)
                        settings.postMealTimerValues.sort()
                    }
                    newTimerValue = ""
                }
                Button("Cancel", role: .cancel) { newTimerValue = "" }
            }
        }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy-HHmmss"
        return "edt-glucose-export-\(formatter.string(from: Date())).json"
    }

    private func exportData() {
        do {
            let data = try DataExporter.exportJSON(events: events)

            if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
                let docsURL = containerURL.appendingPathComponent("Documents")
                try FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
                let filename = exportFilename
                let fileURL = docsURL.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .withoutOverwriting)
                importMessage = "Exported \(events.count) events to iCloud Drive/edt-glucose/\(filename)"
                showingImportAlert = true
            } else {
                exportDocument = JSONDocument(data: data)
                showingExporter = true
            }
        } catch {
            importMessage = "Export failed: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = "Could not access the selected file."
                showingImportAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let imported = try DataExporter.importJSON(data: data)
                pendingImportEvents = imported
                showingImportConfirm = true
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
                showingImportAlert = true
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }

    private func loadBundledTestData() {
        guard let url = Bundle.main.url(forResource: "edt-glucose-export-04-02-2026-201706", withExtension: "json") else {
            importMessage = "Bundled test file not found."
            showingImportAlert = true
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let imported = try DataExporter.importJSON(data: data)
            pendingImportEvents = imported
            showingImportConfirm = true
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
}

struct ConfigurableListSection: View {
    let title: String
    @Binding var items: [String]
    let onReset: () -> Void

    @State private var newItemName = ""
    @State private var showingAddAlert = false

    var body: some View {
        Section {
            ForEach(items, id: \.self) { item in
                Text(item)
            }
            .onDelete { offsets in
                items.remove(atOffsets: offsets)
            }
            .onMove { from, to in
                items.move(fromOffsets: from, toOffset: to)
            }

            Button {
                showingAddAlert = true
            } label: {
                Label("Add \(title.dropLast())", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Button("Reset") { onReset() }
                    .font(.caption)
                    .textCase(.none)
            }
        }
        .alert("Add \(title.dropLast())", isPresented: $showingAddAlert) {
            TextField("Name", text: $newItemName)
            Button("Add") {
                let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !items.contains(trimmed) {
                    items.append(trimmed)
                }
                newItemName = ""
            }
            Button("Cancel", role: .cancel) {
                newItemName = ""
            }
        }
    }
}

struct MedicineTypeListSection: View {
    @Binding var items: [MedicineTypeConfig]
    let units: [String]
    let onReset: () -> Void

    @State private var showingEditor = false
    @State private var editingIndex: Int?
    @State private var draftName = ""
    @State private var draftDose = ""
    @State private var draftUnit = "units"

    var body: some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                Button {
                    editingIndex = idx
                    draftName = item.name
                    draftDose = item.defaultDose.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", item.defaultDose)
                        : String(item.defaultDose)
                    draftUnit = item.defaultUnit
                    showingEditor = true
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .foregroundStyle(.primary)
                        if item.name != "None" {
                            Text("Default: \(item.defaultDose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.defaultDose) : String(item.defaultDose)) \(item.defaultUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in items.remove(atOffsets: offsets) }
            .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }

            Button {
                editingIndex = nil
                draftName = ""
                draftDose = ""
                draftUnit = "units"
                showingEditor = true
            } label: {
                Label("Add Medicine Type", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Medicine Types")
                Spacer()
                Button("Reset") { onReset() }
                    .font(.caption)
                    .textCase(.none)
            }
        }
        .sheet(isPresented: $showingEditor) {
            MedicineTypeEditorSheet(
                editingIndex: editingIndex,
                draftName: $draftName,
                draftDose: $draftDose,
                draftUnit: $draftUnit,
                units: units,
                onSave: { commitDraft() }
            )
            .presentationDetents([.medium])
        }
    }

    private func commitDraft() {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let dose = Double(draftDose) ?? 0
        let entry = MedicineTypeConfig(name: name, defaultDose: dose, defaultUnit: draftUnit)
        if let idx = editingIndex {
            items[idx] = entry
        } else if !items.contains(where: { $0.name == name }) {
            items.append(entry)
        }
    }
}

private struct MedicineTypeEditorSheet: View {
    let editingIndex: Int?
    @Binding var draftName: String
    @Binding var draftDose: String
    @Binding var draftUnit: String
    let units: [String]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingIndex != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine") {
                    TextField("Name", text: $draftName)
                }
                Section("Default Dose") {
                    HStack {
                        TextField("Dose", text: $draftDose)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $draftUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Medicine" : "Add Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct MealPresetListSection: View {
    @Binding var items: [MealPreset]
    let onReset: () -> Void

    var body: some View {
        Section {
            ForEach(items) { preset in
                VStack(alignment: .leading) {
                    Text(preset.name)
                    HStack(spacing: 8) {
                        if let cal = preset.calorieGuess { Text("\(cal) cal") }
                        if let carbs = preset.carbGuess { Text("\(carbs)g carbs") }
                        if let protein = preset.proteinGuess { Text("\(protein)g protein") }
                        if let gi = preset.glycemicIndexGuess { Text("GI \(gi)") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in items.remove(atOffsets: offsets) }
            .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }
        } header: {
            HStack {
                Text("Meal Presets")
                Spacer()
                Button("Reset") { onReset() }
                    .font(.caption)
                    .textCase(.none)
            }
        }
    }
}

struct NamedLocationListSection: View {
    @Binding var items: [NamedLocation]
    let onReset: () -> Void

    @State private var showingEditor = false
    @State private var editingIndex: Int?
    @State private var draftName = ""
    @State private var draftAddress = ""
    @State private var draftCoords = ""

    var body: some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, loc in
                Button {
                    editingIndex = idx
                    draftName = loc.name
                    draftAddress = loc.streetAddress ?? ""
                    draftCoords = loc.gpsCoordinates ?? ""
                    showingEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.name)
                            .foregroundStyle(.primary)
                        if let addr = loc.streetAddress, !addr.isEmpty {
                            Text(addr)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let coords = loc.gpsCoordinates, !coords.isEmpty {
                            Text(coords)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in items.remove(atOffsets: offsets) }
            .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }

            Button {
                editingIndex = nil
                draftName = ""
                draftAddress = ""
                draftCoords = ""
                showingEditor = true
            } label: {
                Label("Add Location", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Locations")
                Spacer()
                Button("Reset") { onReset() }
                    .font(.caption)
                    .textCase(.none)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NamedLocationEditorSheet(
                editingIndex: editingIndex,
                draftName: $draftName,
                draftAddress: $draftAddress,
                draftCoords: $draftCoords,
                onSave: { commitDraft() }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func commitDraft() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedAddress = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCoords = draftCoords.trimmingCharacters(in: .whitespaces)
        let entry = NamedLocation(
            name: trimmedName,
            streetAddress: trimmedAddress.isEmpty ? nil : trimmedAddress,
            gpsCoordinates: trimmedCoords.isEmpty ? nil : trimmedCoords
        )
        if let idx = editingIndex {
            items[idx] = entry
        } else if !items.contains(where: { $0.name == trimmedName }) {
            items.append(entry)
        }
    }
}

private struct NamedLocationEditorSheet: View {
    let editingIndex: Int?
    @Binding var draftName: String
    @Binding var draftAddress: String
    @Binding var draftCoords: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editingIndex != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $draftName)
                }
                Section("Address") {
                    TextField("Street Address", text: $draftAddress, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("GPS Coordinates") {
                    TextField("lat,lon", text: $draftCoords)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(isEditing ? "Edit Location" : "Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
