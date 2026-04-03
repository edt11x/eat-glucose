//
//  AvgTimeBetweenMealsChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/3/26.
//

import SwiftUI
import SwiftData
import Charts

struct MealSpacingDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let avgHoursBetweenMeals: Double
}

struct AvgTimeBetweenMealsChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var dataPoints: [MealSpacingDataPoint] {
        let calendar = Calendar.current
        let mealStarts = events.filter { $0.eventType == "Start of Meal" }
        let grouped = Dictionary(grouping: mealStarts) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        var results: [MealSpacingDataPoint] = []
        for (dayStart, dayMeals) in grouped {
            let sorted = dayMeals.sorted { $0.timestamp < $1.timestamp }
            guard sorted.count >= 2 else { continue }

            var gaps: [TimeInterval] = []
            for i in 1..<sorted.count {
                gaps.append(sorted[i].timestamp.timeIntervalSince(sorted[i-1].timestamp))
            }

            let avgGapHours = (gaps.reduce(0, +) / Double(gaps.count)) / 3600.0
            results.append(MealSpacingDataPoint(date: dayStart, avgHoursBetweenMeals: avgGapHours))
        }

        return results.sorted { $0.date < $1.date }
    }

    private var averageSpacing: Double {
        let values = dataPoints.map(\.avgHoursBetweenMeals)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataPoints.isEmpty {
                    ContentUnavailableView(
                        "No Meal Data",
                        systemImage: "clock.arrow.2.circlepath",
                        description: Text("Need at least 2 meals in a day to calculate spacing.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Average time between consecutive meals each day")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(dataPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("Hours", point.avgHoursBetweenMeals)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("Hours", point.avgHoursBetweenMeals)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .symbolSize(30)
                                }

                                RuleMark(y: .value("Average", averageSpacing))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text(String(format: "Avg: %.1fh", averageSpacing))
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                            }
                            .chartYAxisLabel("Hours")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = dataPoints.map(\.avgHoursBetweenMeals)
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Average", value: String(format: "%.1f", averageSpacing), unit: "hours", theme: theme)
                                    StatBox(label: "Min", value: String(format: "%.1f", minVal), unit: "hours", theme: theme)
                                    StatBox(label: "Max", value: String(format: "%.1f", maxVal), unit: "hours", theme: theme)
                                    StatBox(label: "Days", value: "\(dataPoints.count)", unit: "", theme: theme)
                                }
                            }
                            .padding()

                            // Daily detail table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Spacing")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(dataPoints.reversed()) { point in
                                    HStack {
                                        Text(point.date, format: .dateTime.month().day().year())
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text(String(format: "%.1f hours", point.avgHoursBetweenMeals))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(theme.eventTypeColor)
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
            .navigationTitle("Avg Time Between Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = dataPoints.map(\.avgHoursBetweenMeals)
        let minVal = max((values.min() ?? 1) - 0.5, 0)
        let maxVal = (values.max() ?? 8) + 0.5
        return minVal...maxVal
    }
}

#Preview {
    AvgTimeBetweenMealsChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
