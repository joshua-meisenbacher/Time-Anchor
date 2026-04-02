import Combine
import Foundation

enum CheckInPreset: String, CaseIterable, Identifiable {
    case lowDemand
    case averageDay
    case overloaded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowDemand:
            return "Low Demand"
        case .averageDay:
            return "Average Day"
        case .overloaded:
            return "Overloaded"
        }
    }

    var summary: String {
        switch self {
        case .lowDemand:
            return "Build a gentler day with extra recovery and less pressure."
        case .averageDay:
            return "Use a steady default check-in for a workable day."
        case .overloaded:
            return "Assume transitions and sensory load will cost more today."
        }
    }
}

final class CheckInStore: ObservableObject {
    @Published var energy: Double
    @Published var stress: Double
    @Published var sleepHours: Double
    @Published var sensoryLoad: Double
    @Published var transitionFriction: Double
    @Published var priority: String
    @Published var reminderProfile: ReminderProfile
    @Published private(set) var healthAutofillSummary: String?

    init(dailyState: DailyState) {
        energy = Double(dailyState.energy)
        stress = Double(dailyState.stress)
        sleepHours = dailyState.sleepHours
        sensoryLoad = Double(dailyState.sensoryLoad)
        transitionFriction = Double(dailyState.transitionFriction)
        priority = ""
        reminderProfile = dailyState.reminderProfile
        healthAutofillSummary = nil
    }

    var snapshot: DailyState {
        DailyState(
            energy: Int(energy.rounded()),
            stress: Int(stress.rounded()),
            sleepHours: sleepHours,
            sensoryLoad: Int(sensoryLoad.rounded()),
            transitionFriction: Int(transitionFriction.rounded()),
            priority: priority.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderProfile: reminderProfile
        )
    }

    func update(with state: DailyState) {
        energy = Double(state.energy)
        stress = Double(state.stress)
        sleepHours = state.sleepHours
        sensoryLoad = Double(state.sensoryLoad)
        transitionFriction = Double(state.transitionFriction)
        priority = ""
        reminderProfile = state.reminderProfile
    }

    func applyQuickPreset(_ preset: CheckInPreset) {
        switch preset {
        case .lowDemand:
            energy = min(energy, 2)
            stress = max(stress, 3)
            sensoryLoad = max(sensoryLoad, 3)
            transitionFriction = max(transitionFriction, 3)
            reminderProfile = .gentleSupport
        case .averageDay:
            energy = 3
            stress = 3
            sensoryLoad = 3
            transitionFriction = 3
            reminderProfile = .balanced
        case .overloaded:
            energy = min(energy, 2)
            stress = 5
            sensoryLoad = 5
            transitionFriction = 5
            reminderProfile = .gentleSupport
        }
    }

    func applyHealthSignals(_ healthSignals: HealthSignals) {
        var summaryParts: [String] = []

        if let sleepHours = healthSignals.sleepHours {
            self.sleepHours = sleepHours
            summaryParts.append(String(format: "Sleep %.1fh", sleepHours))
        }

        let suggestedEnergy = Self.suggestedEnergy(from: healthSignals)
        energy = Double(suggestedEnergy)
        summaryParts.append("Energy \(suggestedEnergy)/5")

        let suggestedStress = Self.suggestedStress(from: healthSignals)
        stress = Double(suggestedStress)
        summaryParts.append("Stress \(suggestedStress)/5")

        healthAutofillSummary = summaryParts.isEmpty
            ? "Health data is connected, but there was not enough recent data to shorten today’s check-in."
            : "Prefilled from Health: " + summaryParts.joined(separator: " • ")
    }

    private static func suggestedEnergy(from healthSignals: HealthSignals) -> Int {
        var score = 3.0

        if let sleepHours = healthSignals.sleepHours {
            if sleepHours >= 8 {
                score += 1
            } else if sleepHours < 6 {
                score -= 1
            }
            if sleepHours < 4.5 {
                score -= 1
            }
        }

        if let recoveryScore = healthSignals.recoveryScore {
            if recoveryScore >= 75 {
                score += 1
            } else if recoveryScore <= 40 {
                score -= 1
            }
        }

        if let sleepDebtHours = healthSignals.sleepDebtHours, sleepDebtHours > 1.5 {
            score -= 1
        }

        return max(1, min(5, Int(score.rounded())))
    }

    private static func suggestedStress(from healthSignals: HealthSignals) -> Int {
        var score = 3.0

        if let restingHeartRate = healthSignals.restingHeartRate, restingHeartRate >= 80 {
            score += 1
        }

        if let heartRateVariabilityMilliseconds = healthSignals.heartRateVariabilityMilliseconds {
            if heartRateVariabilityMilliseconds < 35 {
                score += 1
            } else if heartRateVariabilityMilliseconds > 60 {
                score -= 1
            }
        }

        if let respiratoryRate = healthSignals.respiratoryRate, respiratoryRate > 18 {
            score += 1
        }

        if let recoveryScore = healthSignals.recoveryScore, recoveryScore < 45 {
            score += 1
        }

        return max(1, min(5, Int(score.rounded())))
    }
}
