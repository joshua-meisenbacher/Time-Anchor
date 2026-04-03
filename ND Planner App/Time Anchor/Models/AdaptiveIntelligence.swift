import Foundation

enum CapacityBand: String, CaseIterable, Hashable, Codable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low:
            return "Low Capacity"
        case .medium:
            return "Medium Capacity"
        case .high:
            return "High Capacity"
        }
    }
}

enum ExecutionState: String, CaseIterable, Hashable, Codable {
    case onTrack
    case drifting
    case interrupted
    case overloaded

    var title: String {
        switch self {
        case .onTrack:
            return "On Track"
        case .drifting:
            return "Drifting"
        case .interrupted:
            return "Interrupted"
        case .overloaded:
            return "Overloaded"
        }
    }
}

struct EstimatedState: Hashable, Codable {
    let capacityBand: CapacityBand
    let overloadRisk: Double
    let transitionRisk: [UUID: Double]
    let latenessRisk: [UUID: Double]
    let executionState: ExecutionState
    let confidence: Double
    let supportingSignals: [String]

    static let empty = EstimatedState(
        capacityBand: .medium,
        overloadRisk: 0.5,
        transitionRisk: [:],
        latenessRisk: [:],
        executionState: .onTrack,
        confidence: 0.25,
        supportingSignals: []
    )
}

struct DailyHealthSnapshot: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let signals: HealthSignals

    init(id: UUID = UUID(), date: Date, signals: HealthSignals) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.signals = signals
    }
}

enum LiveHealthStatus: String, CaseIterable, Hashable, Codable {
    case stable
    case strained
    case overwhelmed

    var title: String {
        switch self {
        case .stable:
            return "Stable"
        case .strained:
            return "Strained"
        case .overwhelmed:
            return "Overwhelmed"
        }
    }
}

enum RecoveryRecommendationKind: String, CaseIterable, Hashable, Codable, Identifiable {
    case earlierBedtime
    case hydrateSoon
    case lightenEvening
    case protectRecoveryBlock
    case softenSupport
    case shrinkNextStep

    var id: String { rawValue }
}

struct RecoveryRecommendation: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: RecoveryRecommendationKind
    let title: String
    let summary: String

    init(id: UUID = UUID(), kind: RecoveryRecommendationKind, title: String, summary: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
    }
}

struct LiveHealthState: Hashable, Codable {
    let status: LiveHealthStatus
    let strainRisk: Double
    let confidence: Double
    let summary: String
    let supportingSignals: [String]
    let recoveryRecommendations: [RecoveryRecommendation]

    static let empty = LiveHealthState(
        status: .stable,
        strainRisk: 0,
        confidence: 0,
        summary: "Health support is waiting for more recent data.",
        supportingSignals: [],
        recoveryRecommendations: []
    )
}

enum ExecutionDriftSignal: String, CaseIterable, Hashable, Codable, Identifiable {
    case taskStartingLate
    case taskNotStartedAfterCue
    case routineCueNotLanding
    case repeatedRebuilds
    case routinePausedTooLong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taskStartingLate:
            return "Task Starting Late"
        case .taskNotStartedAfterCue:
            return "Task Still Not Started"
        case .routineCueNotLanding:
            return "Routine Cue Not Landing"
        case .repeatedRebuilds:
            return "Repeated Rebuilds"
        case .routinePausedTooLong:
            return "Routine Paused Too Long"
        }
    }

    var supportText: String {
        switch self {
        case .taskStartingLate:
            return "The current block is slipping past its planned start."
        case .taskNotStartedAfterCue:
            return "Support has already fired, but the task still has not cleanly started."
        case .routineCueNotLanding:
            return "Recent routine cues are not turning into forward motion."
        case .repeatedRebuilds:
            return "Today has needed several rebuilds, which usually means continuity is under strain."
        case .routinePausedTooLong:
            return "A paused routine has stayed open long enough that resume support may need to change."
        }
    }
}

struct TransitionWindowState: Hashable, Codable {
    let blockID: UUID?
    let title: String
    let minutesUntilStart: Int?
    let minutesPastStart: Int?
    let risk: Double
    let needsAttention: Bool

    static let inactive = TransitionWindowState(
        blockID: nil,
        title: "",
        minutesUntilStart: nil,
        minutesPastStart: nil,
        risk: 0,
        needsAttention: false
    )
}

struct LiveExecutionState: Hashable, Codable {
    let signals: [ExecutionDriftSignal]
    let transitionWindow: TransitionWindowState
    let summary: String
    let shouldSuggestReplan: Bool

    static let stable = LiveExecutionState(
        signals: [],
        transitionWindow: .inactive,
        summary: "Execution looks steady right now.",
        shouldSuggestReplan: false
    )
}

enum SupportAdjustment: String, CaseIterable, Hashable, Codable, Identifiable {
    case addTransitionRunway
    case dropStretchWork
    case softenCueIntensity
    case protectRecovery
    case reduceTransitions
    case shrinkFirstStep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addTransitionRunway:
            return "Add transition runway"
        case .dropStretchWork:
            return "Drop stretch work"
        case .softenCueIntensity:
            return "Soften cue intensity"
        case .protectRecovery:
            return "Protect recovery"
        case .reduceTransitions:
            return "Reduce transitions"
        case .shrinkFirstStep:
            return "Shrink the first step"
        }
    }
}

struct ReplanSuggestion: Hashable, Codable {
    let reason: ReplanReason
    let recommendedMode: PlanMode
    let title: String
    let summary: String
    let adjustments: [SupportAdjustment]
    let shouldPrompt: Bool
}

enum ReplanReason: String, CaseIterable, Identifiable, Hashable, Codable {
    case overloaded
    case stuck
    case transition
    case sensory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overloaded:
            return "Too much at once"
        case .stuck:
            return "Hard to start"
        case .transition:
            return "Trouble switching"
        case .sensory:
            return "Sensory load is high"
        }
    }

    var recommendation: String {
        switch self {
        case .overloaded:
            return "Shift to a reduced or minimum day and protect only the essentials."
        case .stuck:
            return "Shrink the first task and stay with one anchor until momentum returns."
        case .transition:
            return "Use a softer handoff and make the next anchor extremely explicit."
        case .sensory:
            return "Lower stimulation, reduce transitions, and preserve recovery."
        }
    }
}

enum InsightCategory: String, CaseIterable, Hashable, Codable, Identifiable {
    case transitions
    case cues
    case routines
    case capacity
    case planning
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transitions:
            return "Transitions"
        case .cues:
            return "Cues"
        case .routines:
            return "Routines"
        case .capacity:
            return "Capacity"
        case .planning:
            return "Planning"
        case .health:
            return "Health"
        }
    }
}

enum InsightPriority: Int, CaseIterable, Hashable, Codable {
    case low = 0
    case medium = 1
    case high = 2
}

struct InsightCard: Identifiable, Hashable, Codable {
    let id: UUID
    let category: InsightCategory
    let priority: InsightPriority
    let title: String
    let summary: String
    let supportingDetail: String

    init(
        id: UUID = UUID(),
        category: InsightCategory,
        priority: InsightPriority,
        title: String,
        summary: String,
        supportingDetail: String
    ) {
        self.id = id
        self.category = category
        self.priority = priority
        self.title = title
        self.summary = summary
        self.supportingDetail = supportingDetail
    }
}

enum CueResponseResult: String, CaseIterable, Hashable, Codable {
    case delivered
    case actedOn
    case ignored
    case dismissed
    case overstimulating
    case helpful
}

enum CueResponseContext: String, CaseIterable, Hashable, Codable {
    case routineCue
    case taskStart
    case taskCompletion
    case replan
    case routinePause
    case routineResume
    case feedback
}

enum CueFailureReason: String, CaseIterable, Hashable, Codable, Identifiable {
    case tooEarly
    case tooLate
    case tooIntense
    case notRelevant
    case alreadyMoving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooEarly:
            return "Too Early"
        case .tooLate:
            return "Too Late"
        case .tooIntense:
            return "Too Intense"
        case .notRelevant:
            return "Not Relevant"
        case .alreadyMoving:
            return "Already Moving"
        }
    }

    var supportLabel: String {
        switch self {
        case .tooEarly:
            return "The prompt came before it was useful."
        case .tooLate:
            return "The prompt came after the moment had already slipped."
        case .tooIntense:
            return "The support felt too loud or pushy."
        case .notRelevant:
            return "The cue did not fit what was actually happening."
        case .alreadyMoving:
            return "You were already in motion and did not need the prompt."
        }
    }
}

struct CueResponse: Identifiable, Hashable, Codable {
    let id: UUID
    let recordedAt: Date
    let taskID: UUID?
    let scheduleBlockID: UUID?
    let routineID: UUID?
    let routineStepID: UUID?
    let sensoryCue: TaskSensoryCue?
    let reminderProfile: ReminderProfile?
    let context: CueResponseContext
    let responseDelaySeconds: Int?
    let failureReason: CueFailureReason?
    let result: CueResponseResult
    let note: String

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        taskID: UUID? = nil,
        scheduleBlockID: UUID? = nil,
        routineID: UUID? = nil,
        routineStepID: UUID? = nil,
        sensoryCue: TaskSensoryCue? = nil,
        reminderProfile: ReminderProfile? = nil,
        context: CueResponseContext,
        responseDelaySeconds: Int? = nil,
        failureReason: CueFailureReason? = nil,
        result: CueResponseResult,
        note: String = ""
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.taskID = taskID
        self.scheduleBlockID = scheduleBlockID
        self.routineID = routineID
        self.routineStepID = routineStepID
        self.sensoryCue = sensoryCue
        self.reminderProfile = reminderProfile
        self.context = context
        self.responseDelaySeconds = responseDelaySeconds
        self.failureReason = failureReason
        self.result = result
        self.note = note
    }
}

struct RoutineExecutionSupport: Hashable {
    enum CueIntensity: String, Hashable {
        case calm
        case steady
        case elevated

        var title: String {
            switch self {
            case .calm:
                return "Calm"
            case .steady:
                return "Steady"
            case .elevated:
                return "More Structure"
            }
        }
    }

    let leadTimeMinutes: Int
    let cueIntensity: CueIntensity
    let suppressIfAlreadyMoving: Bool
    let maxCueRepeats: Int
    let resumeCueDelaySeconds: Int
    let currentStepCue: String
    let resumeSupportText: String
    let adjustmentSummary: String?
}

struct DayOutcome: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let completedTaskIDs: [UUID]
    let skippedTaskIDs: [UUID]
    let missedTransitionBlockIDs: [UUID]
    let lateStartMinutesByBlockID: [UUID: Int]
    let rebuildDayCount: Int
    let routinePauseCount: Int
    let routineResumeCount: Int
    let selectedModesSeen: [PlanMode]
    let cueResponses: [CueResponse]
    let notes: String

    init(
        id: UUID = UUID(),
        date: Date,
        completedTaskIDs: [UUID] = [],
        skippedTaskIDs: [UUID] = [],
        missedTransitionBlockIDs: [UUID] = [],
        lateStartMinutesByBlockID: [UUID: Int] = [:],
        rebuildDayCount: Int = 0,
        routinePauseCount: Int = 0,
        routineResumeCount: Int = 0,
        selectedModesSeen: [PlanMode] = [],
        cueResponses: [CueResponse] = [],
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.completedTaskIDs = completedTaskIDs
        self.skippedTaskIDs = skippedTaskIDs
        self.missedTransitionBlockIDs = missedTransitionBlockIDs
        self.lateStartMinutesByBlockID = lateStartMinutesByBlockID
        self.rebuildDayCount = rebuildDayCount
        self.routinePauseCount = routinePauseCount
        self.routineResumeCount = routineResumeCount
        self.selectedModesSeen = selectedModesSeen
        self.cueResponses = cueResponses
        self.notes = notes
    }
}

extension DayOutcome {
    func recordingCompletedTask(_ taskID: UUID) -> DayOutcome {
        var completed = completedTaskIDs
        if !completed.contains(taskID) {
            completed.append(taskID)
        }

        return DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completed,
            skippedTaskIDs: skippedTaskIDs.filter { $0 != taskID },
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingSkippedTask(_ taskID: UUID) -> DayOutcome {
        var skipped = skippedTaskIDs
        if !skipped.contains(taskID) {
            skipped.append(taskID)
        }

        return DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs.filter { $0 != taskID },
            skippedTaskIDs: skipped,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingMissedTransition(_ blockID: UUID) -> DayOutcome {
        var missed = missedTransitionBlockIDs
        if !missed.contains(blockID) {
            missed.append(blockID)
        }

        return DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missed,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingLateStart(for blockID: UUID, minutes: Int) -> DayOutcome {
        var lateStarts = lateStartMinutesByBlockID
        lateStarts[blockID] = max(lateStarts[blockID] ?? 0, minutes)

        return DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStarts,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingRebuildDay() -> DayOutcome {
        DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount + 1,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingRoutinePause() -> DayOutcome {
        DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount + 1,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingRoutineResume() -> DayOutcome {
        DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount + 1,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingMode(_ mode: PlanMode) -> DayOutcome {
        var modes = selectedModesSeen
        if !modes.contains(mode) {
            modes.append(mode)
        }

        return DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: modes,
            cueResponses: cueResponses,
            notes: notes
        )
    }

    func recordingCueResponse(_ response: CueResponse) -> DayOutcome {
        DayOutcome(
            id: id,
            date: date,
            completedTaskIDs: completedTaskIDs,
            skippedTaskIDs: skippedTaskIDs,
            missedTransitionBlockIDs: missedTransitionBlockIDs,
            lateStartMinutesByBlockID: lateStartMinutesByBlockID,
            rebuildDayCount: rebuildDayCount,
            routinePauseCount: routinePauseCount,
            routineResumeCount: routineResumeCount,
            selectedModesSeen: selectedModesSeen,
            cueResponses: cueResponses + [response],
            notes: notes
        )
    }
}

struct PersonalizedBaselines: Hashable, Codable {
    let typicalSleepHours: Double?
    let typicalHydrationLiters: Double?
    let typicalRestingHeartRate: Double?
    let typicalHeartRateVariabilityMilliseconds: Double?
    let typicalRespiratoryRate: Double?
    let typicalCueResponseDelaySeconds: Double?
    let weekdayTypicalCueResponseDelaySeconds: Double?
    let weekendTypicalCueResponseDelaySeconds: Double?
    let typicalLateStartMinutes: Double?
    let preferredLeadTimeMinutes: Double?
    let preferredRepeatIntervalMinutes: Double?
    let noReminderStartHour: Int?
    let noReminderEndHour: Int?
    let cueOverstimulationRate: Double
    let cueAlreadyMovingRate: Double
    let rebuildsPerDay: Double
    let transitionMissRate: Double
    let routineResumeRate: Double
    let typicalRecoveryScore: Double?

    static let empty = PersonalizedBaselines(
        typicalSleepHours: nil,
        typicalHydrationLiters: nil,
        typicalRestingHeartRate: nil,
        typicalHeartRateVariabilityMilliseconds: nil,
        typicalRespiratoryRate: nil,
        typicalCueResponseDelaySeconds: nil,
        weekdayTypicalCueResponseDelaySeconds: nil,
        weekendTypicalCueResponseDelaySeconds: nil,
        typicalLateStartMinutes: nil,
        preferredLeadTimeMinutes: nil,
        preferredRepeatIntervalMinutes: nil,
        noReminderStartHour: nil,
        noReminderEndHour: nil,
        cueOverstimulationRate: 0,
        cueAlreadyMovingRate: 0,
        rebuildsPerDay: 0,
        transitionMissRate: 0,
        routineResumeRate: 0,
        typicalRecoveryScore: nil
    )
}

struct IntelligenceReplaySummary: Hashable, Codable {
    let totalDays: Int
    let rebuildsPerDay: Double
    let transitionMissesPerDay: Double
    let averageLateStartMinutes: Double?
    let cueActedOnRate: Double?
    let routineResumeRate: Double?

    static let empty = IntelligenceReplaySummary(
        totalDays: 0,
        rebuildsPerDay: 0,
        transitionMissesPerDay: 0,
        averageLateStartMinutes: nil,
        cueActedOnRate: nil,
        routineResumeRate: nil
    )
}

struct IntelligenceDataQualityReport: Hashable, Codable {
    let trailingWindowDays: Int
    let missingOutcomeDays: Int
    let missingHealthSnapshotDays: Int
    let cueResponsesRecorded: Int
    let hasSufficientSignalCoverage: Bool

    static let empty = IntelligenceDataQualityReport(
        trailingWindowDays: 14,
        missingOutcomeDays: 14,
        missingHealthSnapshotDays: 14,
        cueResponsesRecorded: 0,
        hasSufficientSignalCoverage: false
    )
}
