import Foundation

struct DayAssessment: Equatable {
    let recommendedMode: PlanMode
    let headline: String
    let reasoning: String
    let loadScore: Int
    let supportFocus: String
    let capacityDrivers: [String]
}
