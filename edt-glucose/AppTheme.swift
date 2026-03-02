//
//  AppTheme.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import SwiftUI

enum AppTheme: Int, CaseIterable {
    case dark = 0
    case light = 1
    case system = 2
    case obsidianite = 3

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        case .obsidianite: return "Obsidianite"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark, .obsidianite: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    // Accent color used for buttons, links, tints
    var accentColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.68, green: 0.51, blue: 1.0) // soft purple
        default: return .blue
        }
    }

    // Navigation bar / header tint
    var headerColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.55, green: 0.36, blue: 0.96) // vibrant purple
        default: return .primary
        }
    }

    // Section header text color
    var sectionHeaderColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.45, green: 0.7, blue: 1.0) // cyan-blue
        default: return .secondary
        }
    }

    // Glucose row event type text color
    var eventTypeColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.82, green: 0.68, blue: 1.0) // light lavender
        default: return .primary
        }
    }

    // Timestamp and secondary info color
    var secondaryTextColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.55, green: 0.65, blue: 0.85) // muted blue
        default: return .secondary
        }
    }

    // Background for list rows (used in list row background)
    var rowBackground: Color? {
        switch self {
        case .obsidianite: return Color(red: 0.1, green: 0.1, blue: 0.16) // deep navy
        default: return nil
        }
    }

    // Meter label color
    var meterColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.4, green: 0.75, blue: 0.85) // teal
        default: return .secondary
        }
    }

    // Notes / tertiary text
    var tertiaryTextColor: Color {
        switch self {
        case .obsidianite: return Color(red: 0.5, green: 0.45, blue: 0.65) // muted purple
        default: return .secondary.opacity(0.7)
        }
    }

    // "Add" button and toolbar icon color
    var toolbarIconColor: Color {
        switch self {
        case .obsidianite: return Color(red: 1.0, green: 0.55, blue: 0.75) // pink
        default: return .blue
        }
    }
}
