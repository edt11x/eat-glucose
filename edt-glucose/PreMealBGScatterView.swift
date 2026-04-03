//
//  PreMealBGScatterView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/3/26.
//

import SwiftUI
import SwiftData
import Charts

struct PreMealScatterPoint: Identifiable {
    let id = UUID()
    let mealType: String
    let preMealBG: Int
    let hoursSinceLastMeal: Double
}

struct PreMealBGScatterView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    @State private var selectedMealType: String = "All"

    private var scatterPoints: [PreMealScatterPoint] {
        let mealStarts = events
            .filter { $0.eventType == "Start of Meal" && $0.mealType != nil && !$0.mealType!.isEmpty }
            .sorted { $0.timestamp < $1.timestamp }
        let bgEvents = events
            .filter { $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil }
            .sorted { $0.timestamp < $1.timestamp }

        var results: [PreMealScatterPoint] = []

        for meal in mealStarts {
            // Find BG measurement immediately PRECEDING this meal
            guard let precedingBG = bgEvents.last(where: { $0.timestamp < meal.timestamp }),
                  let bgValue = precedingBG.bloodGlucose else { continue }

            // Find the previous "Start of Meal" event
            guard let prevMeal = mealStarts.last(where: { $0.timestamp < meal.timestamp }) else { continue }

            let hoursSince = meal.timestamp.timeIntervalSince(prevMeal.timestamp) / 3600.0

            results.append(PreMealScatterPoint(
                mealType: meal.mealType!,
                preMealBG: bgValue,
                hoursSinceLastMeal: hoursSince
            ))
        }

        return results
    }

    private var filteredPoints: [PreMealScatterPoint] {
        if selectedMealType == "All" {
            return scatterPoints
        }
        return scatterPoints.filter { $0.mealType == selectedMealType }
    }

    private var availableMealTypes: [String] {
        let types = Set(scatterPoints.map(\.mealType))
        return ["All"] + types.sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if scatterPoints.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.dots.scatter",
                        description: Text("Need BG measurements before meals and at least 2 meals to plot.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("BG measurement preceding each meal vs. time since previous meal")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            // Meal type filter
                            Picker("Meal Type", selection: $selectedMealType) {
                                ForEach(availableMealTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            Chart {
                                ForEach(filteredPoints) { point in
                                    PointMark(
                                        x: .value("Hours Since Last Meal", point.hoursSinceLastMeal),
                                        y: .value("Pre-Meal BG (mg/dL)", point.preMealBG)
                                    )
                                    .foregroundStyle(by: .value("Meal", point.mealType))
                                    .symbolSize(50)
                                }
                            }
                            .chartYAxisLabel("Pre-Meal BG (mg/dL)")
                            .chartXAxisLabel("Hours Since Last Meal")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Summary stats per meal type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                let grouped = Dictionary(grouping: filteredPoints, by: \.mealType)
                                ForEach(grouped.keys.sorted(), id: \.self) { type in
                                    if let points = grouped[type] {
                                        let avgBG = points.map(\.preMealBG).reduce(0, +) / max(points.count, 1)
                                        let avgHours = points.map(\.hoursSinceLastMeal).reduce(0, +) / Double(max(points.count, 1))
                                        HStack {
                                            Text(type)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(points.count) pts")
                                                .font(.caption2)
                                                .foregroundStyle(theme.tertiaryTextColor)
                                            Text(String(format: "Avg BG: %d", avgBG))
                                                .font(.caption)
                                            Text(String(format: "Avg %.1fh gap", avgHours))
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryTextColor)
                                        }
                                    }
                                }
                            }
                            .padding()

                            // Detail table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data Points")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(filteredPoints.sorted(by: { $0.hoursSinceLastMeal < $1.hoursSinceLastMeal })) { point in
                                    HStack {
                                        Text(point.mealType)
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text(String(format: "%.1fh gap", point.hoursSinceLastMeal))
                                            .font(.caption)
                                            .foregroundStyle(theme.tertiaryTextColor)
                                        Text("\(point.preMealBG) mg/dL")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(glucoseColor(for: point.preMealBG))
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                }
            }
            .navigationTitle("Pre-Meal BG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = filteredPoints.map(\.preMealBG)
        let minVal = max((values.min() ?? 60) - 10, 0)
        let maxVal = (values.max() ?? 200) + 10
        return minVal...maxVal
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
    PreMealBGScatterView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
