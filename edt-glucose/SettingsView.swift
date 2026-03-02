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
                defaultFilename: "edt-glucose-export.json"
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
        }
    }

    private func exportData() {
        do {
            let data = try DataExporter.exportJSON(events: events)
            exportDocument = JSONDocument(data: data)
            showingExporter = true
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

#Preview {
    SettingsView()
}
