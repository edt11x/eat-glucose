//
//  InsulinEstimator.swift
//  edt-glucose
//
//  Core of the Insulin Tracking & Estimation feature (SPEC 3.1).
//
//  ⚠️ This is a personal estimation aid, NOT medical advice. All suggested
//  doses must be reviewed against a clinician's guidance.
//
//  Design goals (per SPEC):
//   • Protocol-first so the algorithm is swappable (PK-curve now, Kalman later).
//   • Pharmacokinetic dose-response curve per agent, from editable parameters.
//   • An "effective ISF" (mg/dL drop per unit by the target time) that a later
//     empirical fit will learn from the user's own overnight data.
//   • A "liver reservoir" / dawn-effect drift term for the no-insulin baseline.
//
//  This file is pure logic (no SwiftUI / SwiftData) so it is fully unit-testable.
//

import Foundation

// MARK: - Kinetic class

/// Broad kinetic class for a doseable agent.
enum InsulinClass: String, Codable, CaseIterable {
    case rapid        // e.g. Lispro — pronounced peak
    case longActing   // e.g. Lantus, Toujeo — flat/basal
    case supplement   // e.g. Berberine, Inositol — chronic, NOT per-dose acute
}

// MARK: - Pharmacokinetic profile

/// Editable pharmacokinetic parameters for one agent. Values are **literature
/// starting points** the user should verify/tune. All times in hours.
struct InsulinProfile: Identifiable, Equatable, Codable {
    var id: String { name }
    var name: String
    var kind: InsulinClass
    var onsetHours: Double
    var peakHours: Double
    var durationHours: Double

    /// Whether the agent has a pronounced peak (rapid insulin) vs. a flat
    /// basal profile (Lantus/Toujeo). Flat profiles use a uniform activity ramp.
    var hasPronouncedPeak: Bool

    /// Fraction (0...1) of the dose's *total* glucose-lowering effect delivered
    /// by `hours` after the dose — a monotonically non-decreasing cumulative
    /// activity curve. Supplements act chronically, so their acute per-dose
    /// fraction is treated as 0 over the prediction window.
    func fractionActive(at hours: Double) -> Double {
        guard kind != .supplement else { return 0 }
        let a = onsetHours
        let d = durationHours
        if hours <= a { return 0 }
        if hours >= d { return 1 }

        if hasPronouncedPeak {
            // Triangular activity rate: rises 0→peak over [a, p], falls peak→0
            // over [p, d]. Area normalized to 1, so the cumulative integral is
            // piecewise-quadratic. p is clamped into (a, d).
            let p = min(max(peakHours, a + 1e-6), d - 1e-6)
            let rise = p - a
            let fall = d - p
            if hours <= p {
                // Cumulative area of the rising triangle up to `hours`.
                let x = hours - a
                return (x * x) / (rise * (d - a))
            } else {
                // Full rising triangle + partial falling triangle.
                let riseArea = rise / (d - a)
                let y = hours - p
                let fallArea = (2 * fall - y) * y / (fall * (d - a))
                return min(1, riseArea + fallArea)
            }
        } else {
            // Flat basal: uniform activity between onset and duration → linear
            // cumulative ramp.
            return (hours - a) / (d - a)
        }
    }

    /// Effect shape normalized so that `shape(hoursToTarget) == 1`. Used to
    /// distribute the total expected drop across the prediction window for the
    /// graph. Returns 0 everywhere if the agent isn't active by the target.
    func effectShape(at hours: Double, targetHours: Double) -> Double {
        let denom = fractionActive(at: targetHours)
        guard denom > 1e-9 else { return 0 }
        return fractionActive(at: hours) / denom
    }
}

extension InsulinProfile {
    /// Literature starting profiles. The user should verify and can edit these.
    /// Berberine/Inositol are supplements (chronic) — included for completeness
    /// but excluded from acute per-dose math via the `.supplement` class.
    static let defaults: [InsulinProfile] = [
        InsulinProfile(name: "Lispro (Humalog)", kind: .rapid,
                       onsetHours: 0.25, peakHours: 1.5, durationHours: 4.5,
                       hasPronouncedPeak: true),
        InsulinProfile(name: "Lantus (glargine U-100)", kind: .longActing,
                       onsetHours: 1.5, peakHours: 12, durationHours: 24,
                       hasPronouncedPeak: false),
        InsulinProfile(name: "Toujeo (glargine U-300)", kind: .longActing,
                       onsetHours: 6, peakHours: 18, durationHours: 30,
                       hasPronouncedPeak: false),
        InsulinProfile(name: "Berberine", kind: .supplement,
                       onsetHours: 1, peakHours: 2, durationHours: 6,
                       hasPronouncedPeak: false),
        InsulinProfile(name: "Inositol", kind: .supplement,
                       onsetHours: 1, peakHours: 2, durationHours: 6,
                       hasPronouncedPeak: false),
    ]
}

// MARK: - Estimator I/O

struct InsulinEstimateInput {
    /// Blood glucose right now (mg/dL).
    var currentBG: Double
    /// Blood glucose we want to reach (mg/dL).
    var targetBG: Double
    /// Hours from now until we want to be at `targetBG`.
    var hoursToTarget: Double
    /// Pharmacokinetic profile of the chosen agent.
    var profile: InsulinProfile
    /// Maximum dose the user is willing to take (units).
    var maxDose: Int
    /// Expected mg/dL drop per unit realized **by the target time**. This is the
    /// value a later empirical fit learns from the user's overnight deltas.
    var effectiveISFPerUnit: Double
    /// Endogenous glucose drift with NO insulin (mg/dL per hour). Models the
    /// liver reservoir / dawn effect; may be positive (BG rises) or negative.
    var endogenousDriftPerHour: Double
}

struct DoseRecommendation: Equatable {
    /// Rounded, clamped dose to take (units).
    let units: Int
    /// Pre-rounding, pre-clamp dose (for transparency/debugging).
    let rawUnits: Double
    /// Predicted BG at the target time if the rounded dose is taken.
    let projectedBGAtTarget: Double
    /// Predicted BG at the target time with NO insulin.
    let projectedBGNoInsulin: Double
    /// Human-readable explanation of the recommendation.
    let rationale: String
}

struct BGPredictionPoint: Identifiable, Equatable {
    var id: Double { hour }
    let hour: Double
    let bg: Double
}

/// Swappable estimation strategy. The concrete implementation can be replaced
/// (e.g. with a Kalman/alpha-beta filter) without changing callers.
protocol InsulinEstimator {
    func recommend(_ input: InsulinEstimateInput) -> DoseRecommendation
    func predictedCurve(units: Double, input: InsulinEstimateInput, step: Double) -> [BGPredictionPoint]
}

// MARK: - PK-curve estimator (v1)

/// First concrete estimator. Recommendation is driven by the effective ISF
/// (empirically fittable); the PK profile only shapes the intermediate BG
/// trajectory for display. Deliberately simple and replaceable.
struct PKCurveEstimator: InsulinEstimator {

    func recommend(_ input: InsulinEstimateInput) -> DoseRecommendation {
        let noInsulin = input.currentBG + input.endogenousDriftPerHour * input.hoursToTarget
        let gap = noInsulin - input.targetBG

        // Can't (or needn't) help: already at/below target, non-positive ISF,
        // or the agent isn't active by the target time.
        let activeByTarget = input.profile.fractionActive(at: input.hoursToTarget) > 1e-9
        guard gap > 0, input.effectiveISFPerUnit > 0, activeByTarget else {
            let rationale = gap <= 0
                ? "No insulin needed — projected BG (\(Int(noInsulin.rounded()))) is already at or below target."
                : (activeByTarget
                    ? "Cannot compute — effective ISF must be positive."
                    : "\(input.profile.name) is not active by the target time, so it can't reach target in \(fmt(input.hoursToTarget))h.")
            return DoseRecommendation(units: 0, rawUnits: 0,
                                      projectedBGAtTarget: noInsulin,
                                      projectedBGNoInsulin: noInsulin,
                                      rationale: rationale)
        }

        let raw = gap / input.effectiveISFPerUnit
        let clamped = min(max(raw, 0), Double(input.maxDose))
        let units = Int(clamped.rounded())
        let projected = noInsulin - Double(units) * input.effectiveISFPerUnit

        var rationale = "Projected \(Int(noInsulin.rounded())) mg/dL without insulin; "
        rationale += "\(units) unit\(units == 1 ? "" : "s") of \(input.profile.name) "
        rationale += "(≈\(fmt(input.effectiveISFPerUnit)) mg/dL per unit) → ~\(Int(projected.rounded())) mg/dL at target."
        if raw > Double(input.maxDose) {
            rationale += " Capped at your \(input.maxDose)-unit max."
        }

        return DoseRecommendation(units: units, rawUnits: raw,
                                  projectedBGAtTarget: projected,
                                  projectedBGNoInsulin: noInsulin,
                                  rationale: rationale)
    }

    func predictedCurve(units: Double, input: InsulinEstimateInput, step: Double = 0.5) -> [BGPredictionPoint] {
        guard input.hoursToTarget > 0, step > 0 else { return [] }
        var points: [BGPredictionPoint] = []
        var t = 0.0
        while t <= input.hoursToTarget + 1e-9 {
            let baseline = input.currentBG + input.endogenousDriftPerHour * t
            let drop = units * input.effectiveISFPerUnit
                * input.profile.effectShape(at: t, targetHours: input.hoursToTarget)
            points.append(BGPredictionPoint(hour: t, bg: baseline - drop))
            t += step
        }
        return points
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }
}
