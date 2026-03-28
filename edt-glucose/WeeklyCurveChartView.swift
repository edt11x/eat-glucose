//
//  WeeklyCurveChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import SwiftUI
import SwiftData
import Charts

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let hoursFromMonday: Double
    let glucose: Double
}

struct WeeklyCurveChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var calendar: Calendar { Calendar.current }

    // Monday of the current week
    private var currentWeekStart: Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    private var bgEvents: [GlucoseEvent] {
        events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
    }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    // Historical weeks: all BG readings before the current week, mapped to hours-from-Monday
    private var historicalPoints: [WeeklyDataPoint] {
        var cal = calendar
        cal.firstWeekday = 2

        let historical = bgEvents.filter { $0.timestamp < currentWeekStart }

        return historical.compactMap { event -> WeeklyDataPoint? in
            let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: event.timestamp)
            guard let weekStart = cal.date(from: weekComponents) else { return nil }
            let hoursFromMonday = event.timestamp.timeIntervalSince(weekStart) / 3600.0
            guard hoursFromMonday >= 0 && hoursFromMonday <= 168 else { return nil }
            return WeeklyDataPoint(hoursFromMonday: hoursFromMonday, glucose: Double(event.bloodGlucose!))
        }
    }

    // Smoothed historical data: bin into 1-hour buckets, average, then moving average
    private var smoothedHistorical: [WeeklyDataPoint] {
        let points = historicalPoints
        guard !points.isEmpty else { return [] }

        // Bin into 1-hour buckets
        var buckets: [Int: [Double]] = [:]
        for point in points {
            let bucket = Int(point.hoursFromMonday)
            buckets[bucket, default: []].append(point.glucose)
        }

        // Average each bucket
        var binned: [(Double, Double)] = []
        for (hour, values) in buckets.sorted(by: { $0.key < $1.key }) {
            let avg = values.reduce(0, +) / Double(values.count)
            binned.append((Double(hour) + 0.5, avg))
        }

        // Moving average (window of 5)
        let window = 5
        var smoothed: [WeeklyDataPoint] = []
        for i in 0..<binned.count {
            let start = max(0, i - window / 2)
            let end = min(binned.count - 1, i + window / 2)
            let windowValues = binned[start...end].map(\.1)
            let avg = windowValues.reduce(0, +) / Double(windowValues.count)
            smoothed.append(WeeklyDataPoint(hoursFromMonday: binned[i].0, glucose: avg))
        }

        return smoothed
    }

    // Current week raw readings
    private var currentWeekPoints: [WeeklyDataPoint] {
        let current = bgEvents.filter { $0.timestamp >= currentWeekStart }
        return current.map { event in
            let hoursFromMonday = event.timestamp.timeIntervalSince(currentWeekStart) / 3600.0
            return WeeklyDataPoint(hoursFromMonday: hoursFromMonday, glucose: Double(event.bloodGlucose!))
        }.sorted { $0.hoursFromMonday < $1.hoursFromMonday }
    }

    // Current week multi-meter estimates
    private var currentWeekMultiMeter: [WeeklyDataPoint] {
        let current = bgEvents.filter { $0.timestamp >= currentWeekStart }
        return current.compactMap { event -> WeeklyDataPoint? in
            guard let meter = event.meterType,
                  let estimate = MultiMeterEstimator.estimate(
                      reading: event.bloodGlucose!, meterType: meter, deviations: meterDeviations
                  ) else { return nil }
            let hoursFromMonday = event.timestamp.timeIntervalSince(currentWeekStart) / 3600.0
            return WeeklyDataPoint(hoursFromMonday: hoursFromMonday, glucose: estimate)
        }.sorted { $0.hoursFromMonday < $1.hoursFromMonday }
    }

    // Historical average
    private var historicalAverage: Double {
        let values = historicalPoints.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if smoothedHistorical.isEmpty && currentWeekPoints.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "waveform.path.ecg",
                        description: Text("Need at least one full week of blood glucose readings to show the weekly curve.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Historical average vs current week, anchored at Monday")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                // Historical smoothed line
                                ForEach(smoothedHistorical) { point in
                                    LineMark(
                                        x: .value("Hours", point.hoursFromMonday),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Series", "Historical")
                                    )
                                    .foregroundStyle(.blue.opacity(0.6))
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }

                                // Current week raw line
                                ForEach(currentWeekPoints) { point in
                                    LineMark(
                                        x: .value("Hours", point.hoursFromMonday),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Series", "Current Week")
                                    )
                                    .foregroundStyle(.green)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                                    PointMark(
                                        x: .value("Hours", point.hoursFromMonday),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(.green)
                                    .symbolSize(20)
                                }

                                // Multi-meter estimate line for current week
                                if !currentWeekMultiMeter.isEmpty {
                                    ForEach(currentWeekMultiMeter) { point in
                                        LineMark(
                                            x: .value("Hours", point.hoursFromMonday),
                                            y: .value("mg/dL", point.glucose),
                                            series: .value("Series", "Multi-Meter")
                                        )
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                                    }
                                }

                                // Historical average dotted line
                                if historicalAverage > 0 {
                                    RuleMark(y: .value("Hist Avg", historicalAverage))
                                        .foregroundStyle(.blue.opacity(0.4))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        .annotation(position: .top, alignment: .leading) {
                                            Text(String(format: "Hist Avg: %.0f", historicalAverage))
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: [0, 24, 48, 72, 96, 120, 144, 168]) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let hours = value.as(Double.self) {
                                            Text(dayLabel(for: hours))
                                        }
                                    }
                                }
                            }
                            .chartYAxisLabel("mg/dL")
                            .frame(height: 300)
                            .padding()

                            // Legend
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Legend")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                HStack(spacing: 16) {
                                    legendItem(color: .blue.opacity(0.6), label: "Historical (smoothed)")
                                    legendItem(color: .green, label: "Current week")
                                    legendItem(color: .orange, label: "Multi-meter est.")
                                }
                            }
                            .padding(.horizontal)

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                let currentValues = currentWeekPoints.map(\.glucose)
                                let currentAvg = currentValues.isEmpty ? 0.0 : currentValues.reduce(0, +) / Double(currentValues.count)
                                let historicalWeeks = countHistoricalWeeks()

                                HStack(spacing: 24) {
                                    StatBox(label: "Hist Avg", value: String(format: "%.0f", historicalAverage), unit: "mg/dL", theme: theme)
                                    StatBox(label: "This Week", value: String(format: "%.0f", currentAvg), unit: "mg/dL", theme: theme)
                                    StatBox(label: "Hist Weeks", value: "\(historicalWeeks)", unit: "", theme: theme)
                                    StatBox(label: "This Week", value: "\(currentValues.count)", unit: "readings", theme: theme)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Weekly Curve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func dayLabel(for hours: Double) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let index = Int(hours / 24)
        guard index >= 0 && index < days.count else { return "" }
        return days[index]
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }

    private func countHistoricalWeeks() -> Int {
        var cal = calendar
        cal.firstWeekday = 2
        let historical = bgEvents.filter { $0.timestamp < currentWeekStart }
        let weeks = Set(historical.map { event in
            cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: event.timestamp)
        })
        return weeks.count
    }
}

#Preview {
    WeeklyCurveChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
