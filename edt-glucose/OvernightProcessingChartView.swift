//
//  OvernightProcessingChartView.swift
//  edt-glucose
//
//  Overnight BG change vs bedtime insulin. For each "night" — defined as the
//  bedtime reading on day N to the fasting reading on day N+1 — plot
//  `morningBG - bedtimeBG` on the primary axis (negative = BG fell overnight,
//  positive = BG rose). On the same x-axis, plot total bedtime-window insulin
//  units as bars on a secondary axis. The goal is to make it easy to see how
//  well the body processes glucose overnight and how a given insulin dose
//  affects the result.
//

import SwiftUI
import SwiftData
import Charts

struct OvernightPoint: Identifiable {
    let id = UUID()
    /// The morning whose fasting reading drove this point. Used on the x-axis.
    let morningDate: Date
    let bedtimeBG: Int
    let fastingBG: Int
    let bgDelta: Int            // fasting - bedtime
    let bedtimeInsulinUnits: Double
    let bedtimeInsulinNames: [String]
}

struct OvernightProcessingChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var allEvents: [GlucoseEvent]
    @State private var timeRange: ChartTimeRange = .month

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    /// Only events inside the visible time range — used for the chart and table.
    private var events: [GlucoseEvent] {
        let cutoff = timeRange.startDate()
        return allEvents.filter { $0.timestamp >= cutoff }
    }

    /// Per the project convention used in Fasting/Bedtime charts, 5:00 AM is
    /// the dividing line: the *fasting* reading is the first BG measurement at
    /// or after 5:00 AM on a given day, and the *bedtime* reading is the last
    /// BG measurement before 5:00 AM on that same day.
    private let dayBoundaryHour = 5

    /// We treat anything between 8:00 PM the prior evening and the day's 5 AM
    /// boundary as "bedtime" for insulin-accounting purposes.
    private let bedtimeWindowStartHour = 20

    private var points: [OvernightPoint] {
        let calendar = Calendar.current
        let bgEvents = events
            .filter { $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil }
            .sorted { $0.timestamp < $1.timestamp }
        guard !bgEvents.isEmpty else { return [] }

        // Group BG events by calendar day; we'll walk forward looking for the
        // first reading after each day's 5 AM boundary.
        let bgByDay = Dictionary(grouping: bgEvents) { calendar.startOfDay(for: $0.timestamp) }

        let sortedDays = bgByDay.keys.sorted()
        var results: [OvernightPoint] = []

        for morningDay in sortedDays {
            let fiveAM = calendar.date(bySettingHour: dayBoundaryHour, minute: 0, second: 0,
                                       of: morningDay)!
            // Fasting reading: first BG at/after 5 AM on `morningDay`.
            guard let fasting = bgByDay[morningDay]?
                .first(where: { $0.timestamp >= fiveAM }),
                  let fastingBG = fasting.bloodGlucose
            else { continue }

            // Bedtime reading: last BG before 5 AM on `morningDay`. That's
            // either a pre-dawn reading on `morningDay` (00:00–05:00) or, more
            // commonly, the last reading on the previous calendar day after
            // 5 AM the prior day.
            let previousDay = calendar.date(byAdding: .day, value: -1, to: morningDay)!
            let prevFiveAM = calendar.date(bySettingHour: dayBoundaryHour, minute: 0, second: 0,
                                           of: previousDay)!
            let bedtimeCandidates = bgEvents
                .filter { $0.timestamp >= prevFiveAM && $0.timestamp < fiveAM }
                .sorted { $0.timestamp > $1.timestamp }
            guard let bedtime = bedtimeCandidates.first,
                  let bedtimeBG = bedtime.bloodGlucose
            else { continue }

            // Bedtime-window insulin: any BG event between 8 PM the prior
            // evening and 5 AM that has a medicine name + dose. Sum the doses.
            let bedtimeWindowStart = calendar.date(
                bySettingHour: bedtimeWindowStartHour, minute: 0, second: 0,
                of: previousDay
            )!
            let insulinEvents = bgEvents.filter {
                $0.timestamp >= bedtimeWindowStart
                && $0.timestamp < fiveAM
                && $0.medicineName != nil
                && $0.medicineName != "None"
                && $0.medicineDose != nil
            }
            let totalUnits = insulinEvents.reduce(0.0) { $0 + ($1.medicineDose ?? 0) }
            let medicineNames = Array(Set(insulinEvents.compactMap(\.medicineName))).sorted()

            results.append(OvernightPoint(
                morningDate: morningDay,
                bedtimeBG: bedtimeBG,
                fastingBG: fastingBG,
                bgDelta: fastingBG - bedtimeBG,
                bedtimeInsulinUnits: totalUnits,
                bedtimeInsulinNames: medicineNames
            ))
        }

        return results
    }

    private var hasInsulin: Bool {
        points.contains(where: { $0.bedtimeInsulinUnits > 0 })
    }

    private var deltaYDomain: ClosedRange<Double> {
        let values = points.map { Double($0.bgDelta) }
        let lo = (values.min() ?? -50) - 10
        let hi = (values.max() ?? 50) + 10
        return min(lo, -10)...max(hi, 10)
    }

    private var insulinMax: Double {
        max(points.map(\.bedtimeInsulinUnits).max() ?? 0, 1)
    }

    /// "Nice" integer tick values for the insulin (left) axis, e.g. 0, 2, 4, 6, 8.
    private var insulinUnitTicks: [Double] {
        let maxUnit = max(1.0, insulinMax)
        let step = max(1.0, (ceil(maxUnit) / 4).rounded())
        var ticks: [Double] = []
        var u = 0.0
        while u < maxUnit + step {
            ticks.append(u)
            u += step
        }
        return ticks
    }

    /// Top of the insulin axis — the largest tick, so the mapping and the
    /// labelled ticks share the same ceiling.
    private var insulinAxisMax: Double { insulinUnitTicks.last ?? 1 }

    /// Swift Charts uses a single y-scale per chart, so we render insulin on its
    /// own labelled left axis by linearly mapping insulin units onto the BG-delta
    /// domain (0 units → bottom of the chart, `insulinAxisMax` → top). The left
    /// axis then relabels those positions back into insulin units.
    private func insulinToDelta(_ units: Double) -> Double {
        let domain = deltaYDomain
        let frac = units / insulinAxisMax
        return domain.lowerBound + frac * (domain.upperBound - domain.lowerBound)
    }

    private func deltaColor(_ delta: Int) -> Color {
        // BG drop overnight is generally desirable; large rises are concerning.
        if delta <= -20 { return .green }
        if delta < 20   { return .yellow }
        return .red
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChartTimeRangePicker(selection: $timeRange)
                    .padding(.top, 8)
                if points.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "moon.zzz.fill",
                        description: Text("Need at least one night with both a bedtime BG reading (before 5 AM) and a fasting BG reading (after 5 AM the next morning).")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Overnight BG change (morning − bedtime, right axis) and bedtime-window insulin (left axis, units)")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            chart
                                .frame(height: 320)
                                .padding()

                            legend

                            summarySection

                            tableSection
                        }
                    }
                }
            }
            .navigationTitle("Overnight Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            // Zero line — visual reference for "no overnight change".
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(theme.tertiaryTextColor.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))

            // Bedtime insulin bars, drawn against the left insulin-units axis.
            // 0 units sits at the bottom of the chart; the bar height is the
            // dose mapped onto the shared y-domain. Orange per the project's
            // secondary-data convention.
            if hasInsulin {
                ForEach(points) { point in
                    if point.bedtimeInsulinUnits > 0 {
                        BarMark(
                            x: .value("Date", point.morningDate, unit: .day),
                            yStart: .value("Baseline", insulinToDelta(0)),
                            yEnd: .value("Insulin", insulinToDelta(point.bedtimeInsulinUnits)),
                            width: .fixed(6)
                        )
                        .foregroundStyle(.orange.opacity(0.55))
                    }
                }
            }

            // BG delta line.
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.morningDate, unit: .day),
                    y: .value("Δ mg/dL", point.bgDelta)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.morningDate, unit: .day),
                    y: .value("Δ mg/dL", point.bgDelta)
                )
                .foregroundStyle(deltaColor(point.bgDelta))
                .symbolSize(45)
            }
        }
        .chartYScale(domain: deltaYDomain)
        .chartYAxis {
            if hasInsulin {
                // Left axis: insulin units. Ticks are placed at the mapped
                // positions but relabelled back into whole units.
                AxisMarks(position: .leading, values: insulinUnitTicks.map { insulinToDelta($0) }) { value in
                    AxisTick()
                    AxisValueLabel {
                        if value.index < insulinUnitTicks.count {
                            Text("\(Int(insulinUnitTicks[value.index]))")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                // Right axis: overnight BG delta.
                AxisMarks(position: .trailing)
            } else {
                // No insulin data — show the BG-delta axis on the left as usual.
                AxisMarks(position: .leading)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: "Overnight Δ BG")
            legendItem(color: .green, label: "Δ ≤ −20")
            legendItem(color: .yellow, label: "−20 < Δ < +20")
            legendItem(color: .red, label: "Δ ≥ +20")
            if hasInsulin {
                legendItem(color: .orange.opacity(0.55), label: "Bedtime Insulin")
            }
        }
        .font(.caption2)
        .padding(.horizontal)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let deltas = points.map(\.bgDelta)
            let avgDelta = deltas.isEmpty ? 0 : deltas.reduce(0, +) / deltas.count
            let avgInsulin = points.isEmpty
                ? 0.0
                : points.map(\.bedtimeInsulinUnits).reduce(0, +) / Double(points.count)
            let nights = points.count
            let nightsWithInsulin = points.filter { $0.bedtimeInsulinUnits > 0 }.count

            Text("Summary")
                .font(.headline)
                .foregroundStyle(theme.eventTypeColor)

            HStack(spacing: 24) {
                StatBox(label: "Avg Δ", value: "\(avgDelta >= 0 ? "+" : "")\(avgDelta)",
                        unit: "mg/dL", theme: theme)
                StatBox(label: "Min Δ", value: "\(deltas.min() ?? 0)", unit: "mg/dL", theme: theme)
                StatBox(label: "Max Δ", value: "\(deltas.max() ?? 0)", unit: "mg/dL", theme: theme)
                StatBox(label: "Nights", value: "\(nights)", unit: "", theme: theme)
            }

            if hasInsulin {
                HStack(spacing: 24) {
                    StatBox(label: "Avg Insulin",
                            value: String(format: "%.1f", avgInsulin),
                            unit: "units", theme: theme, valueColor: .orange)
                    StatBox(label: "Nights w/ Insulin",
                            value: "\(nightsWithInsulin)",
                            unit: "", theme: theme, valueColor: .orange)
                    StatBox(label: "Nights w/o Insulin",
                            value: "\(nights - nightsWithInsulin)",
                            unit: "", theme: theme)
                }
            }
        }
        .padding()
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nights")
                .font(.headline)
                .foregroundStyle(theme.eventTypeColor)
                .padding(.horizontal)

            // Most-recent first per project convention.
            ForEach(points.reversed()) { point in
                HStack(alignment: .top) {
                    Text(point.morningDate, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(point.bedtimeBG) → \(point.fastingBG)")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                            Text("(\(point.bgDelta >= 0 ? "+" : "")\(point.bgDelta))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(deltaColor(point.bgDelta))
                        }
                        if point.bedtimeInsulinUnits > 0 {
                            let medsText = point.bedtimeInsulinNames.isEmpty
                                ? ""
                                : " (\(point.bedtimeInsulinNames.joined(separator: ", ")))"
                            Text(String(format: "%.1f units%@",
                                        point.bedtimeInsulinUnits, medsText))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom)
    }
}

#Preview {
    OvernightProcessingChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}
