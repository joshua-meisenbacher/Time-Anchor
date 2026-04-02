import Foundation

enum PlanMode: String, CaseIterable, Identifiable, Codable {
    case minimum
    case reduced
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimum:
            return "Minimum"
        case .reduced:
            return "Reduced"
        case .full:
            return "Full"
        }
    }

    var description: String {
        switch self {
        case .minimum:
            return "Protect the essentials and reduce friction."
        case .reduced:
            return "Keep momentum with fewer transitions and less overhead."
        case .full:
            return "Use a steadier, fuller plan when capacity is available."
        }
    }

    var supportiveLabel: String {
        switch self {
        case .minimum:
            return "Gentle mode"
        case .reduced:
            return "Protected mode"
        case .full:
            return "Stretch mode"
        }
    }
}
