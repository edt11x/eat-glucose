//
//  DailyReadingsChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import SwiftUI
import SwiftData
import Charts

struct DailyReadingsChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var dailyReadings: [FastingDataPoint] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return events
            .filter {
                $0.eventType == "Blood Glucose Measurement"
                && $0.bloodGlucose != nil
                && $0.timestamp >= dayStart
                && $0.timestamp < dayEnd
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { FastingDataPoint(date: $0.timestamp, glucose: $0.bloodGlucose!) }
    }

    private var averageGlucose: Int {
        let values = dailyReadings.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private var daysWithData: [Date] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let days = Set(bgEvents.map { calendar.startOfDay(for: $0.timestamp) })
        return days.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Group {
                if dailyReadings.isEmpty {
                    ContentUnavailableView(
                        "No Readings",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("No blood glucose readings for this day.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Chart {
                                ForEach(dailyReadings) { point in
                                    LineMark(
                                        x: .value("Time", point.date),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Time", point.date),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(glucoseColor(for: point.glucose))
                                    .symbolSize(40)
                                }

                                RuleMark(y: .value("Average", averageGlucose))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Avg: \(averageGlucose)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = dailyReadings.map(\.glucose)
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Average", value: "\(averageGlucose)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Min", value: "\(minVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Max", value: "\(maxVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Readings", value: "\(values.count)", unit: "", theme: theme)
                                }
                            }
                            .padding()

                            // Readings table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Readings")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(dailyReadings) { point in
                                    HStack {
                                        Text(point.date, format: .dateTime.hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text("\(point.glucose) mg/dL")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(glucoseColor(for: point.glucose))
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Day", selection: $selectedDate) {
                        ForEach(daysWithData, id: \.self) { day in
                            Text(day, format: .dateTime.month().day().year())
                                .tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("Daily Readings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = dailyReadings.map(\.glucose)
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
    DailyReadingsChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
