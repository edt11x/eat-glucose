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

                ConfigurableListSection(
                    title: "Locations",
                    items: $settings.locations,
                    onReset: { settings.resetLocations() }
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

            // Try to save to iCloud Drive edt-glucose folder
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
                .appendingPathComponent("edt-glucose") {
                try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
                let filename = exportFilename
                let fileURL = iCloudURL.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .withoutOverwriting)
                importMessage = "Exported \(events.count) events to iCloud Drive/edt-glucose/\(filename)"
                showingImportAlert = true
            } else {
                // Fallback to file exporter if iCloud is not available
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
        guard let url = Bundle.main.url(forResource: "edt-glucose-export-03-07-2026", withExtension: "json") else {
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

    @State private var showingAddAlert = false
    @State private var newName = ""
    @State private var newDose = ""
    @State private var newUnit = "units"

    var body: some View {
        Section {
            ForEach(items) { item in
                VStack(alignment: .leading) {
                    Text(item.name)
                    if item.name != "None" {
                        Text("Default: \(item.defaultDose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.defaultDose) : String(item.defaultDose)) \(item.defaultUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in items.remove(atOffsets: offsets) }
            .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }

            Button {
                showingAddAlert = true
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
        .alert("Add Medicine Type", isPresented: $showingAddAlert) {
            TextField("Name", text: $newName)
            TextField("Default Dose", text: $newDose)
            TextField("Unit (e.g., units, mg)", text: $newUnit)
            Button("Add") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && !items.contains(where: { $0.name == name }) {
                    let dose = Double(newDose) ?? 0
                    items.append(MedicineTypeConfig(name: name, defaultDose: dose, defaultUnit: newUnit))
                }
                newName = ""; newDose = ""; newUnit = "units"
            }
            Button("Cancel", role: .cancel) {
                newName = ""; newDose = ""; newUnit = "units"
            }
        }
    }
}

#Preview {
    SettingsView()
}
