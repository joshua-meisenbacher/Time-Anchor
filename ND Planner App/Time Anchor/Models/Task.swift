import Foundation

struct TaskCompletionSample: Identifiable, Hashable, Codable {
    let id: UUID
    let completedAt: Date
    let actualMinutes: Int

    init(id: UUID = UUID(), completedAt: Date = Date(), actualMinutes: Int) {
        self.id = id
        self.completedAt = completedAt
        self.actualMinutes = actualMinutes
    }
}

enum TaskSensoryCue: String, CaseIterable, Identifiable, Hashable, Codable {
    case rhythmicPulsingGlow
    case timedVibration
    case rhythmicClickingSound

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rhythmicPulsingGlow:
            return "Rhythmic Pulsing Glow"
        case .timedVibration:
            return "Timed Vibration"
        case .rhythmicClickingSound:
            return "Rhythmic Clicking Sound"
        }
    }

    var categoryTitle: String {
        switch self {
        case .rhythmicPulsingGlow:
            return "Visual Cue"
        case .timedVibration:
            return "Vibration Cue"
        case .rhythmicClickingSound:
            return "Sound Cue"
        }
    }

    var detail: String {
        switch self {
        case .rhythmicPulsingGlow:
            return "A repeating visual pulse to keep the task present without demanding constant re-reading."
        case .timedVibration:
            return "A timed vibration to bring attention back when momentum slips."
        case .rhythmicClickingSound:
            return "A gentle rhythmic click to support pacing and task persistence."
        }
    }
}

struct Task: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let detail: String
    let dayOffset: Int
    let startMinute: Int?
    let durationMinutes: Int
    let isEssential: Bool
    let projectID: UUID?
    let sensoryCue: TaskSensoryCue?
    let completionHistory: [TaskCompletionSample]
    let isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        dayOffset: Int = 0,
        startMinute: Int? = nil,
        durationMinutes: Int,
        isEssential: Bool,
        projectID: UUID? = nil,
        sensoryCue: TaskSensoryCue? = nil,
        completionHistory: [TaskCompletionSample] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.dayOffset = dayOffset
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.isEssential = isEssential
        self.projectID = projectID
        self.sensoryCue = sensoryCue
        self.completionHistory = completionHistory
        self.isCompleted = isCompleted
    }

    var suggestedDurationMinutes: Int? {
        guard !completionHistory.isEmpty else { return nil }
        let total = completionHistory.reduce(0) { $0 + $1.actualMinutes }
        return Int((Double(total) / Double(completionHistory.count)).rounded())
    }

    var estimateSummary: String {
        if let suggestedDurationMinutes {
            return "Est. \(durationMinutes)m, suggested \(suggestedDurationMinutes)m from past completions"
        }
        return "Est. \(durationMinutes)m"
    }

    var startTimeText: String? {
        guard let startMinute else { return nil }
        return Self.clockString(for: startMinute)
    }

    func updatingCompletion(_ isCompleted: Bool, recordedMinutes: Int? = nil) -> Task {
        let updatedHistory: [TaskCompletionSample]
        if isCompleted, let recordedMinutes {
            updatedHistory = completionHistory + [TaskCompletionSample(actualMinutes: recordedMinutes)]
        } else {
            updatedHistory = completionHistory
        }

        return Task(
            id: id,
            title: title,
            detail: detail,
            dayOffset: dayOffset,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            isEssential: isEssential,
            projectID: projectID,
            sensoryCue: sensoryCue,
            completionHistory: updatedHistory,
            isCompleted: isCompleted
        )
    }

    func updatingSchedule(dayOffset: Int? = nil, startMinute: Int? = nil, durationMinutes: Int? = nil) -> Task {
        Task(
            id: id,
            title: title,
            detail: detail,
            dayOffset: dayOffset ?? self.dayOffset,
            startMinute: startMinute ?? self.startMinute,
            durationMinutes: durationMinutes ?? self.durationMinutes,
            isEssential: isEssential,
            projectID: projectID,
            sensoryCue: sensoryCue,
            completionHistory: completionHistory,
            isCompleted: isCompleted
        )
    }

    private static func clockString(for minutes: Int) -> String {
        let normalized = max(minutes, 0)
        let hour24 = (normalized / 60) % 24
        let minute = normalized % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }
}

struct ProjectSubtask: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let estimatedMinutes: Int
    let isCompleted: Bool

    init(id: UUID = UUID(), title: String, estimatedMinutes: Int, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
    }

    func updatingCompletion(_ isCompleted: Bool) -> ProjectSubtask {
        ProjectSubtask(id: id, title: title, estimatedMinutes: estimatedMinutes, isCompleted: isCompleted)
    }
}

struct ProjectWorkBlock: Identifiable, Hashable, Codable {
    let id: UUID
    let projectID: UUID
    let subtaskID: UUID?
    let title: String
    let detail: String
    let dayOffset: Int
    let startMinute: Int
    let durationMinutes: Int
    let isSuggested: Bool

    init(
        id: UUID = UUID(),
        projectID: UUID,
        subtaskID: UUID? = nil,
        title: String,
        detail: String,
        dayOffset: Int,
        startMinute: Int,
        durationMinutes: Int,
        isSuggested: Bool = true
    ) {
        self.id = id
        self.projectID = projectID
        self.subtaskID = subtaskID
        self.title = title
        self.detail = detail
        self.dayOffset = dayOffset
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.isSuggested = isSuggested
    }
}

struct Project: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let detail: String
    let dueDate: Date
    let estimatedTotalMinutes: Int
    let subtasks: [ProjectSubtask]

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        dueDate: Date,
        estimatedTotalMinutes: Int,
        subtasks: [ProjectSubtask]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.estimatedTotalMinutes = estimatedTotalMinutes
        self.subtasks = subtasks
    }

    var completedSubtaskCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    var progressSummary: String {
        "\(completedSubtaskCount)/\(max(subtasks.count, 1)) subtasks complete"
    }

    var remainingSubtasks: [ProjectSubtask] {
        subtasks.filter { !$0.isCompleted }
    }

    var remainingMinutes: Int {
        max(remainingSubtasks.reduce(0) { $0 + max($1.estimatedMinutes, 15) }, 0)
    }

    var suggestedWorkBlockMinutes: Int {
        if estimatedTotalMinutes <= 60 { return 30 }
        if estimatedTotalMinutes <= 180 { return 45 }
        return 60
    }

    var suggestedWorkBlockCount: Int {
        max(Int(ceil(Double(max(estimatedTotalMinutes, 1)) / Double(suggestedWorkBlockMinutes))), 1)
    }

    var dueDateSummary: String {
        DateFormatter.localizedString(from: dueDate, dateStyle: .medium, timeStyle: .none)
    }

    func daysUntilDue(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let due = calendar.startOfDay(for: dueDate)
        return max(calendar.dateComponents([.day], from: start, to: due).day ?? 0, 0)
    }

    func dailyMinutesNeeded(from referenceDate: Date = Date()) -> Int {
        let daysRemaining = max(daysUntilDue(from: referenceDate) + 1, 1)
        return Int(ceil(Double(max(remainingMinutes, 0)) / Double(daysRemaining)))
    }

    var urgencySummary: String {
        let daysRemaining = daysUntilDue()
        if remainingMinutes == 0 {
            return "Ready to close"
        }
        if daysRemaining == 0 {
            return "Due today"
        }
        if daysRemaining == 1 {
            return "Due tomorrow"
        }
        return "\(daysRemaining) days left"
    }

    func updating(subtasks: [ProjectSubtask]) -> Project {
        Project(
            id: id,
            title: title,
            detail: detail,
            dueDate: dueDate,
            estimatedTotalMinutes: estimatedTotalMinutes,
            subtasks: subtasks
        )
    }

    static func suggestedSubtasks(
        title: String,
        estimatedTotalMinutes: Int,
        manualTitles: [String]
    ) -> [ProjectSubtask] {
        let cleanedManual = manualTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !cleanedManual.isEmpty {
            let minutesPerTask = max(Int(round(Double(max(estimatedTotalMinutes, cleanedManual.count * 15)) / Double(cleanedManual.count))), 15)
            return cleanedManual.map { ProjectSubtask(title: $0, estimatedMinutes: minutesPerTask) }
        }

        let blockMinutes: Int
        if estimatedTotalMinutes <= 60 {
            blockMinutes = 30
        } else if estimatedTotalMinutes <= 180 {
            blockMinutes = 45
        } else {
            blockMinutes = 60
        }

        let blockCount = max(Int(ceil(Double(max(estimatedTotalMinutes, blockMinutes)) / Double(blockMinutes))), 1)
        return (1...blockCount).map { index in
            ProjectSubtask(
                title: "\(title) work block \(index)",
                estimatedMinutes: blockMinutes
            )
        }
    }
}

enum GoalCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case hydration
    case sleep
    case movement
    case hygiene
    case focus
    case recovery
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hydration:
            return "Hydration"
        case .sleep:
            return "Sleep"
        case .movement:
            return "Movement"
        case .hygiene:
            return "Hygiene"
        case .focus:
            return "Focus"
        case .recovery:
            return "Recovery"
        case .custom:
            return "Custom"
        }
    }
}

struct Goal: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let detail: String
    let category: GoalCategory
    let targetSummary: String
    let linkedTaskIDs: [UUID]
    let linkedRoutineIDs: [UUID]
    let linkedProjectIDs: [UUID]
    let linkedAnchorIDs: [UUID]

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        category: GoalCategory,
        targetSummary: String,
        linkedTaskIDs: [UUID] = [],
        linkedRoutineIDs: [UUID] = [],
        linkedProjectIDs: [UUID] = [],
        linkedAnchorIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.targetSummary = targetSummary
        self.linkedTaskIDs = linkedTaskIDs
        self.linkedRoutineIDs = linkedRoutineIDs
        self.linkedProjectIDs = linkedProjectIDs
        self.linkedAnchorIDs = linkedAnchorIDs
    }

    var relationshipSummary: String {
        let counts = [
            linkedTaskIDs.isEmpty ? nil : "\(linkedTaskIDs.count) task\(linkedTaskIDs.count == 1 ? "" : "s")",
            linkedRoutineIDs.isEmpty ? nil : "\(linkedRoutineIDs.count) routine\(linkedRoutineIDs.count == 1 ? "" : "s")",
            linkedProjectIDs.isEmpty ? nil : "\(linkedProjectIDs.count) project\(linkedProjectIDs.count == 1 ? "" : "s")",
            linkedAnchorIDs.isEmpty ? nil : "\(linkedAnchorIDs.count) anchor\(linkedAnchorIDs.count == 1 ? "" : "s")"
        ].compactMap { $0 }

        if counts.isEmpty {
            return "No linked supports yet"
        }

        return counts.joined(separator: " • ")
    }
}
