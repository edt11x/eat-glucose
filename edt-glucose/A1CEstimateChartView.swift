//
//  A1CEstimateChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import SwiftUI
import SwiftData
import Charts

struct A1CDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let eA1C: Double
}

struct A1CEstimateChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]
    @State private var timeRange: ChartTimeRange = .month

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    // Compute rolling 90-day eA1C for each day that has BG data.
    // When useMultiMeter is true, BG readings are first converted to a multi-meter
    // estimate using each event's meter type.
    //
    // Uses a two-pointer sliding window over readings sorted by timestamp so
    // each per-day eA1C is computed in amortized O(1) rather than re-filtering
    // the full reading list. Net cost: O(N + D) where N is total BG readings
    // and D is the number of distinct days with data.
    private func computeA1CPoints(useMultiMeter: Bool) -> [A1CDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        guard !bgEvents.isEmpty else { return [] }

        let deviations = meterDeviations

        let allEstimates: [(Date, Double)] = bgEvents.compactMap { event in
            let reading = event.bloodGlucose!
            if useMultiMeter {
                guard let meter = event.meterType,
                      let estimate = MultiMeterEstimator.estimate(
                          reading: reading, meterType: meter, deviations: deviations
                      ) else { return nil }
                return (event.timestamp, estimate)
            } else {
                return (event.timestamp, Double(reading))
            }
        }

        guard !allEstimates.isEmpty else { return [] }

        let sortedEstimates = allEstimates.sorted { $0.0 < $1.0 }
        let sortedDays = Set(sortedEstimates.map { calendar.startOfDay(for: $0.0) }).sorted()

        var results: [A1CDataPoint] = []
        let windowDays = 90
        let minimumReadings = 10

        var leftIdx = 0
        var rightIdx = 0
        var sum = 0.0

        for day in sortedDays {
            let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: day)!
            let windowEnd = calendar.date(byAdding: .day, value: 1, to: day)!

            // Right pointer: include every estimate strictly before windowEnd.
            while rightIdx < sortedEstimates.count,
                  sortedEstimates[rightIdx].0 < windowEnd {
                sum += sortedEstimates[rightIdx].1
                rightIdx += 1
            }
            // Left pointer: drop estimates older than windowStart.
            while leftIdx < rightIdx,
                  sortedEstimates[leftIdx].0 < windowStart {
                sum -= sortedEstimates[leftIdx].1
                leftIdx += 1
            }

            let count = rightIdx - leftIdx
            guard count >= minimumReadings else { continue }

            let avgBG = sum / Double(count)
            let eA1C = (avgBG + 46.7) / 28.7
            results.append(A1CDataPoint(date: day, eA1C: eA1C))
        }

        return results
    }

    private var a1cDataPoints: [A1CDataPoint] {
        let cutoff = timeRange.startDate()
        return computeA1CPoints(useMultiMeter: false).filter { $0.date >= cutoff }
    }
    private var a1cMultiMeterPoints: [A1CDataPoint] {
        let cutoff = timeRange.startDate()
        return computeA1CPoints(useMultiMeter: true).filter { $0.date >= cutoff }
    }

    private func averageA1C(of points: [A1CDataPoint]) -> Double {
        let values = points.map(\.eA1C)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        // Compute the two rolling-window series once per render (each does a
        // full filter + sliding window, and the MM series also runs the
        // per-reading estimator) and reuse them for the chart, y-scale,
        // averages, and stats instead of recomputing them ~6–8× each.
        let rawPoints = a1cDataPoints
        let mmPoints = a1cMultiMeterPoints
        let avgRaw = averageA1C(of: rawPoints)
        let avgMM = averageA1C(of: mmPoints)
        let domain = yDomain(raw: rawPoints, mm: mmPoints)

        return NavigationStack {
            VStack(spacing: 0) {
                ChartTimeRangePicker(selection: $timeRange)
                    .padding(.top, 8)
                if rawPoints.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "percent",
                        description: Text("Need at least 10 blood glucose readings within a 90-day window to estimate A1C.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Rolling 90-day estimated A1C from average BG")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                // Color zones
                                RectangleMark(
                                    yStart: .value("", 0),
                                    yEnd: .value("", 5.7)
                                )
                                .foregroundStyle(.green.opacity(0.08))

                                RectangleMark(
                                    yStart: .value("", 5.7),
                                    yEnd: .value("", 6.5)
                                )
                                .foregroundStyle(.yellow.opacity(0.08))

                                RectangleMark(
                                    yStart: .value("", 6.5),
                                    yEnd: .value("", domain.upperBound)
                                )
                                .foregroundStyle(.red.opacity(0.08))

                                // A1C line (raw)
                                ForEach(rawPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("eA1C %", point.eA1C),
                                        series: .value("Series", "Raw")
                                    )
                                    .foregroundStyle(.purple)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("eA1C %", point.eA1C)
                                    )
                                    .foregroundStyle(a1cColor(for: point.eA1C))
                                    .symbolSize(20)
                                }

                                // Multi-meter A1C line
                                if !mmPoints.isEmpty {
                                    ForEach(mmPoints) { point in
                                        LineMark(
                                            x: .value("Date", point.date, unit: .day),
                                            y: .value("eA1C %", point.eA1C),
                                            series: .value("Series", "Multi-Meter")
                                        )
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                                        .interpolationMethod(.catmullRom)
                                    }
                                }

                                // Average line
                                RuleMark(y: .value("Average", avgRaw))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text(String(format: "Avg: %.1f%%", avgRaw))
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                            }
                            .chartYAxisLabel("eA1C %")
                            .chartYScale(domain: domain)
                            .frame(height: 300)
                            .padding()

                            // Legend
                            if !mmPoints.isEmpty {
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.purple)
                                            .frame(width: 16, height: 3)
                                        Text("Raw eA1C")
                                    }
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.orange)
                                            .frame(width: 16, height: 3)
                                        Text("Multi-Meter eA1C")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)
                            }

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = rawPoints.map(\.eA1C)
                                let current = values.last ?? 0
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Current", value: String(format: "%.1f%%", current), unit: "", theme: theme)
                                    StatBox(label: "Average", value: String(format: "%.1f%%", avgRaw), unit: "", theme: theme)
                                    StatBox(label: "Min", value: String(format: "%.1f%%", minVal), unit: "", theme: theme)
                                    StatBox(label: "Max", value: String(format: "%.1f%%", maxVal), unit: "", theme: theme)
                                }

                                if !mmPoints.isEmpty {
                                    let mmValues = mmPoints.map(\.eA1C)
                                    let mmCurrent = mmValues.last ?? 0
                                    let mmMin = mmValues.min() ?? 0
                                    let mmMax = mmValues.max() ?? 0

                                    HStack(spacing: 24) {
                                        StatBox(label: "Current (MM)", value: String(format: "%.1f%%", mmCurrent), unit: "", theme: theme, valueColor: .orange)
                                        StatBox(label: "Avg (MM)", value: String(format: "%.1f%%", avgMM), unit: "", theme: theme, valueColor: .orange)
                                        StatBox(label: "Min (MM)", value: String(format: "%.1f%%", mmMin), unit: "", theme: theme, valueColor: .orange)
                                        StatBox(label: "Max (MM)", value: String(format: "%.1f%%", mmMax), unit: "", theme: theme, valueColor: .orange)
                                    }
                                }
                            }
                            .padding()

                            // Color zone legend
                            VStack(alignment: .leading, spacing: 4) {
                                Text("A1C Ranges")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                HStack(spacing: 16) {
                                    legendItem(color: .green, label: "Normal (<5.7%)")
                                    legendItem(color: .yellow, label: "Prediabetes (5.7-6.4%)")
                                    legendItem(color: .red, label: "Diabetes (≥6.5%)")
                                }
                            }
                            .padding(.horizontal)

                            // Formula note
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Formula")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                Text("eA1C = (avgBG + 46.7) / 28.7")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryTextColor)
                                Text("Raw average BG over a 90-day rolling window; multi-meter line uses meter-deviation-adjusted readings")
                                    .font(.caption2)
                                    .foregroundStyle(theme.tertiaryTextColor)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("A1C Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func yDomain(raw: [A1CDataPoint], mm: [A1CDataPoint]) -> ClosedRange<Double> {
        let values = raw.map(\.eA1C) + mm.map(\.eA1C)
        let minVal = max((values.min() ?? 4.0) - 0.5, 0)
        let maxVal = (values.max() ?? 8.0) + 0.5
        return minVal...maxVal
    }

    private func a1cColor(for value: Double) -> Color {
        if value < 5.7 { return .green }
        else if value < 6.5 { return .yellow }
        else { return .red }
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
}

#Preview {
    A1CEstimateChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
