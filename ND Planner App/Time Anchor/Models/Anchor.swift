import Foundation

func canonicalAnchorPrompt(from prompt: String) -> String {
    let supportSentences = [
        "Use this anchor to make deliberate progress without skipping transitions.",
        "Trim extras here and preserve only the work that keeps the day moving.",
        "Treat this anchor as continuity support: lower friction, narrow scope, and protect recovery.",
        "The day has needed more rebuilding lately, so keep this step especially narrow and restart-friendly.",
        "Keep support softer here so the task stays present without adding extra pressure.",
        "Give the handoff extra support here so the next switch does not turn into a scramble.",
        "Let this anchor make time easier to read and the next move easier to start.",
        "Use this anchor as a predictable handoff so the switch into the next part of the day stays clearer.",
        "Let this anchor hold a small, clear lane so you do not have to renegotiate the whole day here.",
        "Use this anchor to protect recovery and keep the day from spilling past what is workable.",
        "This anchor should feel like an option, not an order. Use it as a gentle place to restart when it helps.",
        "Keep this anchor very explicit so the next step is visible without extra interpretation.",
        "Keep this anchor low-pressure and literal so it reduces uncertainty instead of adding more."
    ]

    var cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    for sentence in supportSentences {
        cleaned = cleaned.replacingOccurrences(of: sentence, with: "")
    }

    let sentences = cleaned
        .components(separatedBy: ".")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    var seen = Set<String>()
    let deduplicated = sentences.filter { sentence in
        let key = sentence.lowercased()
        guard !seen.contains(key) else { return false }
        seen.insert(key)
        return true
    }

    cleaned = deduplicated.joined(separator: ". ")
    if !cleaned.isEmpty && !cleaned.hasSuffix(".") {
        cleaned += "."
    }

    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }

    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct Anchor: Identifiable, Hashable, Codable {
    enum AnchorType: String, Codable {
        case focus
        case maintenance
        case transition
        case recovery
    }

    let id: UUID
    let title: String
    let timeLabel: String
    let type: AnchorType
    let prompt: String
    let tasks: [Task]

    init(
        id: UUID = UUID(),
        title: String,
        timeLabel: String,
        type: AnchorType,
        prompt: String,
        tasks: [Task]
    ) {
        self.id = id
        self.title = title
        self.timeLabel = timeLabel
        self.type = type
        self.prompt = prompt
        self.tasks = tasks
    }

    var completedTaskCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var totalTaskCount: Int {
        tasks.count
    }

    var completionSummary: String {
        "\(completedTaskCount) of \(max(totalTaskCount, 1)) done"
    }

    var totalMinutes: Int {
        tasks.reduce(0) { $0 + $1.durationMinutes }
    }

    func updating(
        title: String? = nil,
        timeLabel: String? = nil,
        type: AnchorType? = nil,
        prompt: String? = nil,
        tasks: [Task]? = nil
    ) -> Anchor {
        Anchor(
            id: id,
            title: title ?? self.title,
            timeLabel: timeLabel ?? self.timeLabel,
            type: type ?? self.type,
            prompt: prompt ?? self.prompt,
            tasks: tasks ?? self.tasks
        )
    }
}

struct Routine: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let timeWindow: String
    let summary: String
    let steps: [RoutineStep]
    let isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        timeWindow: String,
        summary: String,
        steps: [RoutineStep],
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.timeWindow = timeWindow
        self.summary = summary
        self.steps = steps
        self.isPinned = isPinned
    }

    var progressText: String {
        let completed = steps.filter(\.isCompleted).count
        return "\(completed)/\(max(steps.count, 1)) steps"
    }

    func updating(steps: [RoutineStep]) -> Routine {
        Routine(
            id: id,
            title: title,
            timeWindow: timeWindow,
            summary: summary,
            steps: steps,
            isPinned: isPinned
        )
    }
}

struct RoutineStep: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let cue: String
    let estimatedMinutes: Int
    let isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        cue: String,
        estimatedMinutes: Int,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.cue = cue
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
    }

    func updatingCompletion(_ isCompleted: Bool) -> RoutineStep {
        RoutineStep(
            id: id,
            title: title,
            cue: cue,
            estimatedMinutes: estimatedMinutes,
            isCompleted: isCompleted
        )
    }
}
