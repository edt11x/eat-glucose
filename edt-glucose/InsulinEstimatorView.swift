//
//  InsulinEstimatorView.swift
//  edt-glucose
//
//  Input screen + prediction graph for the Insulin Tracking & Estimation
//  feature (SPEC 3.1). Drives the pure `PKCurveEstimator`.
//
//  ⚠️ Estimation aid only — NOT medical advice.
//

import SwiftUI
import Charts

struct InsulinEstimatorView: View {
    @Environment(\.dismiss) private var dismiss

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private let profiles = InsulinProfile.defaults
    private let estimator = PKCurveEstimator()

    // Inputs
    @State private var currentBGText = ""
    @State private var targetBGText = "75"
    @State private var hoursToTargetText = "8"
    @State private var maxDoseText = "8"
    @State private var isfText = "5"
    @State private var driftText = "0"
    @State private var selectedProfileName: String
    @State private var activity = ""

    init() {
        // Default to the first non-supplement (injectable) profile.
        let defaultName = InsulinProfile.defaults.first { $0.kind != .supplement }?.name
            ?? InsulinProfile.defaults.first?.name ?? ""
        _selectedProfileName = State(initialValue: defaultName)
    }

    private var selectedProfile: InsulinProfile {
        profiles.first { $0.name == selectedProfileName } ?? profiles[0]
    }

    /// Parsed inputs, or nil until the required numeric fields are valid.
    private var estimateInput: InsulinEstimateInput? {
        guard let bg = Double(currentBGText),
              let target = Double(targetBGText),
              let hours = Double(hoursToTargetText), hours > 0,
              let maxDose = Int(maxDoseText), maxDose >= 0,
              let isf = Double(isfText),
              let drift = Double(driftText) else { return nil }
        return InsulinEstimateInput(
            currentBG: bg, targetBG: target, hoursToTarget: hours,
            profile: selectedProfile, maxDose: maxDose,
            effectiveISFPerUnit: isf, endogenousDriftPerHour: drift
        )
    }

    private var recommendation: DoseRecommendation? {
        estimateInput.map { estimator.recommend($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current State") {
                    labeledField("Current BG", text: $currentBGText, unit: "mg/dL")
                    if !settings.activities.isEmpty {
                        Picker("Activity", selection: $activity) {
                            Text("—").tag("")
                            ForEach(settings.activities, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }

                Section("Insulin") {
                    Picker("Type", selection: $selectedProfileName) {
                        ForEach(profiles) { Text($0.name).tag($0.name) }
                    }
                    labeledField("Max dose", text: $maxDoseText, unit: "units")
                    labeledField("Est. drop per unit", text: $isfText, unit: "mg/dL·u")
                }

                Section("Target") {
                    labeledField("Target BG", text: $targetBGText, unit: "mg/dL")
                    labeledField("Reach target in", text: $hoursToTargetText, unit: "hours")
                    labeledField("BG drift w/o insulin", text: $driftText, unit: "mg/dL·h")
                }

                if selectedProfile.kind == .supplement {
                    Section {
                        Text("\(selectedProfile.name) is a supplement with a chronic (not per-dose) effect, so no acute dose is estimated.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }

                if let rec = recommendation, let input = estimateInput {
                    Section("Recommendation") {
                        HStack(spacing: 24) {
                            StatBox(label: "Suggested", value: "\(rec.units)", unit: "units",
                                    theme: theme, valueColor: .orange)
                            StatBox(label: "At Target", value: "\(Int(rec.projectedBGAtTarget.rounded()))",
                                    unit: "mg/dL", theme: theme)
                            StatBox(label: "No Insulin", value: "\(Int(rec.projectedBGNoInsulin.rounded()))",
                                    unit: "mg/dL", theme: theme)
                        }
                        Text(rec.rationale)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryTextColor)
                    }

                    Section("Projected BG") {
                        predictionChart(rec: rec, input: input)
                            .frame(height: 240)
                    }
                }

                Section {
                    Text("Estimation aid only — not medical advice. Confirm doses with your clinician. \"Est. drop per unit\" and drift will be auto-fit from your history in a later update.")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
            }
            .navigationTitle("Insulin Estimator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func predictionChart(rec: DoseRecommendation, input: InsulinEstimateInput) -> some View {
        let noInsulin = estimator.predictedCurve(units: 0, input: input, step: 0.25)
        let suggested = estimator.predictedCurve(units: Double(rec.units), input: input, step: 0.25)
        let suggestedLabel = "Suggested (\(rec.units)u)"

        return Chart {
            ForEach(noInsulin) { p in
                LineMark(x: .value("Hour", p.hour), y: .value("mg/dL", p.bg),
                         series: .value("Series", "No Insulin"))
                .foregroundStyle(by: .value("Series", "No Insulin"))
                .interpolationMethod(.catmullRom)
            }
            ForEach(suggested) { p in
                LineMark(x: .value("Hour", p.hour), y: .value("mg/dL", p.bg),
                         series: .value("Series", suggestedLabel))
                .foregroundStyle(by: .value("Series", suggestedLabel))
                .interpolationMethod(.catmullRom)
            }
            RuleMark(y: .value("Target", input.targetBG))
                .foregroundStyle(.orange.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Target \(Int(input.targetBG.rounded()))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
        }
        .chartForegroundStyleScale([
            "No Insulin": Color.gray,
            suggestedLabel: Color.blue
        ])
        .chartXAxisLabel("Hours from now")
        .chartYAxisLabel("mg/dL")
    }

    private func labeledField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    InsulinEstimatorView()
}
