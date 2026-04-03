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
    @State private var navigationStep: NavigationStep = .day
    @State private var hasInitialized = false

    enum NavigationStep: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    private var daysWithData: [Date] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let days = Set(bgEvents.map { calendar.startOfDay(for: $0.timestamp) })
        return days.sorted(by: >)
    }

    // MARK: - Date Range for current view mode

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        switch navigationStep {
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .week:
            // Week containing selectedDate (Monday start)
            var cal = calendar
            cal.firstWeekday = 2 // Monday
            let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)!.start
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            return (weekStart, weekEnd)
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: selectedDate)!.start
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return (monthStart, monthEnd)
        }
    }

    private var rangeReadings: [FastingDataPoint] {
        let range = dateRange
        return events
            .filter {
                $0.eventType == "Blood Glucose Measurement"
                && $0.bloodGlucose != nil
                && $0.timestamp >= range.start
                && $0.timestamp < range.end
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { FastingDataPoint(date: $0.timestamp, glucose: $0.bloodGlucose!) }
    }

    // For day mode: readings normalized to time-of-day for overlay
    private var dailyReadings: [FastingDataPoint] {
        readingsForDayNormalized(offset: 0)
    }

    private func readingsForDayNormalized(offset: Int) -> [FastingDataPoint] {
        let calendar = Calendar.current
        let targetDay = calendar.date(byAdding: .day, value: -offset, to: selectedDate)!
        let dayStart = calendar.startOfDay(for: targetDay)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return events
            .filter {
                $0.eventType == "Blood Glucose Measurement"
                && $0.bloodGlucose != nil
                && $0.timestamp >= dayStart
                && $0.timestamp < dayEnd
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { event in
                let components = calendar.dateComponents([.hour, .minute, .second], from: event.timestamp)
                let normalizedDate = calendar.date(bySettingHour: components.hour!, minute: components.minute!, second: components.second!, of: selectedDate)!
                return FastingDataPoint(date: normalizedDate, glucose: event.bloodGlucose!)
            }
    }

    private var currentReadings: [FastingDataPoint] {
        navigationStep == .day ? dailyReadings : rangeReadings
    }

    private var averageGlucose: Int {
        let values = currentReadings.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private var allVisibleValues: [Int] {
        if navigationStep == .day {
            var values = dailyReadings.map(\.glucose)
            for offset in 1...5 {
                values.append(contentsOf: readingsForDayNormalized(offset: offset).map(\.glucose))
            }
            return values
        } else {
            return rangeReadings.map(\.glucose)
        }
    }

    // MARK: - Title text

    private var headerTitle: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        switch navigationStep {
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: selectedDate)
        case .week:
            let range = dateRange
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: range.start)
            let endDate = calendar.date(byAdding: .day, value: -1, to: range.end)!
            formatter.dateFormat = "MMM d, yyyy"
            let endStr = formatter.string(from: endDate)
            return "\(startStr) – \(endStr)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentReadings.isEmpty {
                    ContentUnavailableView(
                        "No Readings",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("No blood glucose readings for this period.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if navigationStep == .day {
                                dayChart
                            } else {
                                rangeChart
                            }

                            // Legend (day mode only)
                            if navigationStep == .day {
                                HStack(spacing: 12) {
                                    legendItem(color: .blue, label: "Selected Day")
                                    legendItem(color: .blue.opacity(0.63), label: "1d ago")
                                    legendItem(color: .blue.opacity(0.27), label: "3d ago")
                                    legendItem(color: .blue.opacity(0.15), label: "5d ago")
                                }
                                .font(.caption2)
                                .padding(.horizontal)
                            }

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = currentReadings.map(\.glucose)
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

                                ForEach(currentReadings) { point in
                                    HStack {
                                        if navigationStep == .day {
                                            Text(point.date, format: .dateTime.hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryTextColor)
                                        } else {
                                            Text(point.date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryTextColor)
                                        }
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
                    HStack(spacing: 8) {
                        Button { stepBackward() } label: {
                            Image(systemName: "chevron.left")
                        }
                        Text(headerTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Button { stepForward() } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("View", selection: $navigationStep) {
                        ForEach(NavigationStep.allCases, id: \.self) { step in
                            Text(step.rawValue).tag(step)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("Daily Readings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !hasInitialized, let mostRecent = daysWithData.first {
                    selectedDate = mostRecent
                    hasInitialized = true
                }
            }
        }
    }

    // MARK: - Day chart with 5-day overlay

    private var dayChart: some View {
        Chart {
            // Previous 5 days overlay (dimmer colors)
            ForEach(Array(stride(from: 5, through: 1, by: -1)), id: \.self) { daysBack in
                let prevReadings = readingsForDayNormalized(offset: daysBack)
                let opacity = 0.15 + (0.12 * Double(5 - daysBack))
                ForEach(prevReadings) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("mg/dL", point.glucose),
                        series: .value("Series", "Day-\(daysBack)")
                    )
                    .foregroundStyle(Color.blue.opacity(opacity))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }

            // Current day (full opacity)
            ForEach(dailyReadings) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("mg/dL", point.glucose),
                    series: .value("Series", "Today")
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
    }

    // MARK: - Week/Month chart with actual timestamps

    private var rangeChart: some View {
        Chart {
            ForEach(rangeReadings) { point in
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
                .symbolSize(30)
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
    }

    // MARK: - Navigation

    private func stepBackward() {
        let calendar = Calendar.current
        switch navigationStep {
        case .day:   selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
        case .week:  selectedDate = calendar.date(byAdding: .day, value: -7, to: selectedDate)!
        case .month: selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)!
        }
    }

    private func stepForward() {
        let calendar = Calendar.current
        switch navigationStep {
        case .day:   selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
        case .week:  selectedDate = calendar.date(byAdding: .day, value: 7, to: selectedDate)!
        case .month: selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)!
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = allVisibleValues
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

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}

#Preview {
    DailyReadingsChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
