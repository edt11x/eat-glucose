//
//  ChartTimeRange.swift
//  edt-glucose
//

import Foundation
import SwiftUI

/// Time-window selector used by chart screens that don't already have their
/// own day/week/month navigation. Default is `.month` per project convention.
enum ChartTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    /// Inclusive lower bound. Events with `timestamp >= startDate()` are in range.
    /// `.all` returns `Date.distantPast`.
    func startDate(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate
        case .all:
            return .distantPast
        }
    }
}

struct ChartTimeRangePicker: View {
    @Binding var selection: ChartTimeRange

    var body: some View {
        Picker("Range", selection: $selection) {
            ForEach(ChartTimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
