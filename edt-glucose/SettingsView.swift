//
//  SettingsView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings = SettingsManager.shared

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
