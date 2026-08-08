//
//  RollingAveragesChartView.swift
//  edt-glucose
//

import SwiftUI
import SwiftData
import Charts

struct RollingAveragePoint: Identifiable {
    let id = UUID()
    let date: Date
    let glucose: Double
    let windowDays: Int
}

struct RollingAveragesChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]
    @State private var timeRange: ChartTimeRange = .month

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private let windows = [7, 14, 30, 90]

    private func color(for window: Int) -> Color {
        switch window {
        case 7:  return .green
        case 14: return .yellow
        case 30: return .blue
        case 90: return .purple
        default: return .gray
        }
    }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    // (date, BG) for each BG reading
    private var bgReadings: [(Date, Double)] {
        events
            .filter { $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil }
            .map { ($0.timestamp, Double($0.bloodGlucose!)) }
    }

    // (date, multi-meter-adjusted BG) for each BG reading that has a meter type with deviation data
    private var bgMultiMeterReadings: [(Date, Double)] {
        let deviations = meterDeviations
        return events.compactMap { event in
            guard event.eventType == "Blood Glucose Measurement",
                  let bg = event.bloodGlucose,
                  let meter = event.meterType,
                  let estimate = MultiMeterEstimator.estimate(
                      reading: bg, meterType: meter, deviations: deviations
                  ) else { return nil }
            return (event.timestamp, estimate)
        }
    }

    private func rollingPoints(from source: [(Date, Double)]) -> [RollingAveragePoint] {
        let calendar = Calendar.current
        guard !source.isEmpty else { return [] }

        // Two-pointer sliding window. Sort the source once, then for every
        // visible day advance a `right` pointer to include readings before
        // `dayEnd` and a per-window `left` pointer to drop readings older than
        // `windowStart`. Maintaining a running sum gives O(N) per window
        // instead of the previous O(N×D) full filter-per-day.
        let sorted = source.sorted { $0.0 < $1.0 }
        let cutoff = timeRange.startDate()
        let dayStarts = Set(sorted.map { calendar.startOfDay(for: $0.0) })
            .filter { $0 >= cutoff }
            .sorted()
        guard !dayStarts.isEmpty else { return [] }

        var results: [RollingAveragePoint] = []
        results.reserveCapacity(dayStarts.count * windows.count)

        // Maintain one sliding window per N-day window size, advancing as we
        // walk forward through `dayStarts`.
        var rightIdxByWindow = [Int: Int]()
        var leftIdxByWindow = [Int: Int]()
        var sumByWindow = [Int: Double]()
        for w in windows {
            rightIdxByWindow[w] = 0
            leftIdxByWindow[w] = 0
            sumByWindow[w] = 0
        }

        for day in dayStarts {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            for window in windows {
                let windowStart = calendar.date(byAdding: .day, value: -window, to: day)!

                // Advance right pointer to include every reading before dayEnd.
                var right = rightIdxByWindow[window]!
                var sum = sumByWindow[window]!
                while right < sorted.count, sorted[right].0 < dayEnd {
                    sum += sorted[right].1
                    right += 1
                }
                rightIdxByWindow[window] = right

                // Advance left pointer to drop readings before windowStart.
                var left = leftIdxByWindow[window]!
                while left < right, sorted[left].0 < windowStart {
                    sum -= sorted[left].1
                    left += 1
                }
                leftIdxByWindow[window] = left
                sumByWindow[window] = sum

                let count = right - left
                guard count >= 3 else { continue }
                let avg = sum / Double(count)
                results.append(RollingAveragePoint(date: day, glucose: avg, windowDays: window))
            }
        }
        return results
    }

    private var rollingPoints: [RollingAveragePoint] { rollingPoints(from: bgReadings) }

    private var rollingMultiMeterPoints: [RollingAveragePoint] {
        rollingPoints(from: bgMultiMeterReadings)
    }

    private func yDomain(points: [RollingAveragePoint], mmPoints: [RollingAveragePoint]) -> ClosedRange<Double> {
        let values = points.map(\.glucose) + mmPoints.map(\.glucose)
        let minVal = max((values.min() ?? 60) - 10, 0)
        let maxVal = (values.max() ?? 200) + 10
        return minVal...maxVal
    }

    private func latestAverage(in points: [RollingAveragePoint], window: Int) -> Double? {
        points.filter { $0.windowDays == window }.last?.glucose
    }

    var body: some View {
        // Compute the expensive rolling-window collections once per render and
        // reuse them everywhere below (chart, y-scale, and the latest-value
        // stats), instead of recomputing each ~7× via computed properties.
        let points = rollingPoints
        let mmPoints = rollingMultiMeterPoints
        let domain = yDomain(points: points, mmPoints: mmPoints)

        return NavigationStack {
            VStack(spacing: 0) {
                ChartTimeRangePicker(selection: $timeRange)
                    .padding(.top, 8)
                if points.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.line.uptrend.xyaxis.circle.fill",
                        description: Text("Need at least 3 blood glucose readings to compute rolling averages.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trailing 7, 14, 30, and 90-day average BG, computed per day.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(points) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Window", "\(point.windowDays)d")
                                    )
                                    .foregroundStyle(color(for: point.windowDays))
                                    .interpolationMethod(.catmullRom)
                                }

                                // Multi-meter-adjusted overlay (dashed orange per window)
                                ForEach(mmPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Window", "MM-\(point.windowDays)d")
                                    )
                                    .foregroundStyle(.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 2]))
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: domain)
                            .frame(height: 320)
                            .padding()

                            // Legend
                            HStack(spacing: 16) {
                                ForEach(windows, id: \.self) { w in
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color(for: w))
                                            .frame(width: 16, height: 3)
                                        Text("\(w)d")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryTextColor)
                                    }
                                }
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.orange)
                                        .frame(width: 16, height: 3)
                                    Text("MM Est.")
                                        .font(.caption2)
                                        .foregroundStyle(theme.secondaryTextColor)
                                }
                            }
                            .padding(.horizontal)

                            // Latest values
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Latest")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                HStack(spacing: 24) {
                                    ForEach(windows, id: \.self) { w in
                                        StatBox(
                                            label: "\(w)-day",
                                            value: latestAverage(in: points, window: w).map { String(format: "%.0f", $0) } ?? "—",
                                            unit: "mg/dL",
                                            theme: theme,
                                            valueColor: color(for: w)
                                        )
                                    }
                                }

                                if !mmPoints.isEmpty {
                                    HStack(spacing: 24) {
                                        ForEach(windows, id: \.self) { w in
                                            StatBox(
                                                label: "\(w)d (MM)",
                                                value: latestAverage(in: mmPoints, window: w)
                                                    .map { String(format: "%.0f", $0) } ?? "—",
                                                unit: "mg/dL",
                                                theme: theme,
                                                valueColor: .orange
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Rolling Averages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RollingAveragesChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
