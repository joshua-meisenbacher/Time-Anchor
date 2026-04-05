import Combine
import EventKit
import Foundation
import HealthKit
import AVFoundation
import AudioToolbox
import AuthenticationServices
import CoreLocation
import CryptoKit
import MapKit
import UIKit
@preconcurrency import UserNotifications

struct PlannerDaySummary: Identifiable, Hashable {
    let id = UUID()
    let dayOffset: Int
    let title: String
    let subtitle: String
    let itemCount: Int
    let commitmentCount: Int
    let projectBlockCount: Int
    let pressureSummary: String
    let focusSummary: String
}

struct PlannerAgendaItem: Identifiable, Hashable {
    enum SourceKind: String, Hashable {
        case event
        case task
        case projectBlock
        case routine
        case transition
        case recovery
    }

    let id: UUID
    let dayOffset: Int
    let title: String
    let detail: String
    let startMinute: Int
    let durationMinutes: Int
    let sourceKind: SourceKind
    let accentLabel: String
    let isSuggested: Bool

    var endMinute: Int { startMinute + durationMinutes }
}

@MainActor
final class AppStore: ObservableObject {
    private static let profilesStorageKey = "TimeAnchor.userProfiles"
    private static let selectedProfileStorageKey = "TimeAnchor.selectedProfileID"
    private static let onboardingCompletedStorageKey = "TimeAnchor.hasCompletedOnboarding"
    private static let planningEventHorizonDays = 14

    let planningEngine: PlanningEngine
    let capacityEngine: CapacityEngine
    let guidanceEngine: GuidanceEngine
    let stateEstimator: StateEstimator
    let outcomeLogger: OutcomeLogger
    let reminderOrchestrator: ReminderOrchestrator
    let adaptiveProfileStore: AdaptiveProfileStore
    let healthSupportEvaluator: HealthSupportEvaluator
    let liveExecutionMonitor: LiveExecutionMonitor
    let adaptiveReplanEngine: AdaptiveReplanEngine
    let insightsEngine: InsightsEngine
    let replayEvaluator: IntelligenceReplayEvaluator
    let dataQualityChecker: IntelligenceDataQualityChecking
    let healthService: AppleHealthService
    let calendarService: AppleCalendarService
    let googleCalendarService: GoogleCalendarService
    let externalCalendarFeedService: ExternalCalendarFeedService
    @Published private(set) var baseAnchors: [Anchor]
    @Published private(set) var scenarios: [MockScenario]
    @Published private(set) var routines: [Routine]
    @Published private(set) var projects: [Project]
    @Published private(set) var goals: [Goal]
    @Published private(set) var customEvents: [DayEvent]
    @Published private(set) var googleCalendarAccount: GoogleCalendarAccount?
    @Published private(set) var googleImportedEvents: [DayEvent]
    @Published private(set) var externalCalendarSubscriptions: [ExternalCalendarSubscription]
    @Published private(set) var externalImportedEvents: [DayEvent]
    @Published private(set) var dayContext: DayContext
    @Published var selectedScenarioID: UUID
    @Published var userProfiles: [UserProfile]
    @Published var selectedProfileID: UUID
    @Published var hasCompletedOnboarding: Bool
    @Published private(set) var assessment: DayAssessment
    @Published private(set) var estimatedState: EstimatedState
    @Published var integrationStore: IntegrationStore
    @Published private(set) var eventOverrides: [String: DayEvent] = [:]
    @Published var profileSettings: ProfileSettings
    @Published private(set) var activeTaskStartedAt: Date?
    @Published private(set) var activeTaskElapsedSeconds: Int = 0
    @Published private(set) var activeSensoryCue: TaskSensoryCue?
    @Published private(set) var currentDayOutcome: DayOutcome
    @Published private(set) var pendingFeedbackPrompt: FeedbackPrompt?
    @Published private(set) var liveHealthState: LiveHealthState
    @Published private(set) var liveExecutionState: LiveExecutionState
    @Published private(set) var adaptiveReplanSuggestion: ReplanSuggestion?
    @Published private(set) var insights: [InsightCard]
    @Published private(set) var intelligenceReplaySummary: IntelligenceReplaySummary
    @Published private(set) var intelligenceDataQuality: IntelligenceDataQualityReport
    @Published var intelligenceFeatureFlags: IntelligenceFeatureFlags
    @Published private(set) var adaptiveDecisionTelemetry: [AdaptiveDecisionTelemetry]

    @Published var dailyState: DailyState
    @Published var plans: [PlanVersion]
    @Published var selectedMode: PlanMode
    @Published var checkInStore: CheckInStore
    @Published var todayStore: TodayStore
    @Published var replanStore: ReplanStore

    private var taskTimerCancellable: AnyCancellable?
    private var executionMonitorCancellable: AnyCancellable?
    private var healthRefreshCancellable: AnyCancellable?
    private var lastRoutineCueDeliveryByStepID: [UUID: Date] = [:]
    private var routineCueMissLoggedForStepIDs: Set<UUID> = []
    private var routinePauseStartedAt: Date?
    private var lastReplanPromptAt: Date?
    private let sensoryCueController = SensoryCueController()
    private let notificationCenter = UNUserNotificationCenter.current()

    init(
        planningEngine: PlanningEngine = PlanningEngine(),
        capacityEngine: CapacityEngine = CapacityEngine(),
        guidanceEngine: GuidanceEngine = GuidanceEngine(),
        stateEstimator: StateEstimator = HeuristicStateEstimator(),
        outcomeLogger: OutcomeLogger = PersistentOutcomeLogger(),
        reminderOrchestrator: ReminderOrchestrator = AdaptiveReminderOrchestrator(),
        adaptiveProfileStore: AdaptiveProfileStore = BaselineAdaptiveProfileStore(),
        healthSupportEvaluator: HealthSupportEvaluator = HeuristicHealthSupportEvaluator(),
        liveExecutionMonitor: LiveExecutionMonitor = HeuristicLiveExecutionMonitor(),
        adaptiveReplanEngine: AdaptiveReplanEngine = HeuristicAdaptiveReplanEngine(),
        insightsEngine: InsightsEngine = HeuristicInsightsEngine(),
        replayEvaluator: IntelligenceReplayEvaluator = HeuristicIntelligenceReplayEvaluator(),
        dataQualityChecker: IntelligenceDataQualityChecking = HeuristicIntelligenceDataQualityChecker(),
        healthService: AppleHealthService = AppleHealthService(),
        calendarService: AppleCalendarService = AppleCalendarService(),
        googleCalendarService: GoogleCalendarService = GoogleCalendarService(),
        externalCalendarFeedService: ExternalCalendarFeedService = ExternalCalendarFeedService(),
        baseAnchors: [Anchor] = MockData.sampleAnchors,
        dailyState: DailyState = MockData.sampleDailyState,
        profileSettings: ProfileSettings = ProfileSettings(reminderProfile: MockData.sampleDailyState.reminderProfile),
        userProfiles: [UserProfile]? = nil,
        scenarios: [MockScenario] = MockData.scenarios,
        routines: [Routine] = MockData.routines,
        projects: [Project] = [],
        goals: [Goal] = []
    ) {
        self.planningEngine = planningEngine
        self.capacityEngine = capacityEngine
        self.guidanceEngine = guidanceEngine
        self.stateEstimator = stateEstimator
        self.outcomeLogger = outcomeLogger
        self.reminderOrchestrator = reminderOrchestrator
        self.adaptiveProfileStore = adaptiveProfileStore
        self.healthSupportEvaluator = healthSupportEvaluator
        self.liveExecutionMonitor = liveExecutionMonitor
        self.adaptiveReplanEngine = adaptiveReplanEngine
        self.insightsEngine = insightsEngine
        self.replayEvaluator = replayEvaluator
        self.dataQualityChecker = dataQualityChecker
        self.healthService = healthService
        self.calendarService = calendarService
        self.googleCalendarService = googleCalendarService
        self.externalCalendarFeedService = externalCalendarFeedService
        self.baseAnchors = baseAnchors
        self.scenarios = scenarios
        self.routines = routines
        self.projects = projects
        self.goals = goals
        self.customEvents = []
        self.googleCalendarAccount = nil
        self.googleImportedEvents = []
        self.externalCalendarSubscriptions = []
        self.externalImportedEvents = []
        let configuredProfiles = Self.loadPersistedProfiles()
        let initialProfiles = userProfiles
        ?? configuredProfiles
        ?? [
            UserProfile(
                displayName: profileSettings.displayName,
                settings: profileSettings,
                dailyState: dailyState,
                selectedScenarioID: scenarios.first?.id,
                anchors: baseAnchors,
                routines: routines,
                projects: projects,
                goals: goals,
                customEvents: [],
                googleCalendarAccount: nil,
                externalCalendarSubscriptions: []
            )
        ]
        self.userProfiles = initialProfiles
        self.hasCompletedOnboarding = Self.loadOnboardingCompletedFlag(defaultingTo: configuredProfiles != nil || userProfiles != nil)
        let persistedSelectedProfileID = Self.loadPersistedSelectedProfileID()
        let resolvedSelectedProfileID = initialProfiles.first(where: { $0.id == persistedSelectedProfileID })?.id ?? initialProfiles.first?.id ?? UUID()
        self.selectedProfileID = resolvedSelectedProfileID
        self.integrationStore = IntegrationStore(
            healthStatus: healthService.authorizationState,
            calendarStatus: calendarService.authorizationState,
            calendarSourceNames: calendarService.availableSourceNames
        )
        let selectedProfile = initialProfiles.first(where: { $0.id == resolvedSelectedProfileID }) ?? initialProfiles[0]
        var configuredProfileSettings = selectedProfile.settings
        configuredProfileSettings.displayName = selectedProfile.displayName
        var configuredDailyState = selectedProfile.dailyState
        configuredDailyState.reminderProfile = configuredProfileSettings.reminderProfile
        self.profileSettings = configuredProfileSettings
        self.dailyState = configuredDailyState
        let resolvedAnchors = selectedProfile.anchors.isEmpty ? baseAnchors : selectedProfile.anchors
        let resolvedRoutines = selectedProfile.routines.isEmpty ? routines : selectedProfile.routines
        let resolvedProjects = selectedProfile.projects
        let resolvedGoals = selectedProfile.goals
        let resolvedCustomEvents = selectedProfile.customEvents
        let resolvedGoogleCalendarAccount = selectedProfile.googleCalendarAccount
        let resolvedExternalSubscriptions = selectedProfile.externalCalendarSubscriptions
        let resolvedScenarioID = selectedProfile.selectedScenarioID ?? scenarios.first(where: { $0.dailyState == dailyState && $0.anchors == baseAnchors })?.id ?? scenarios.first?.id ?? UUID()
        self.baseAnchors = resolvedAnchors
        self.routines = resolvedRoutines
        self.projects = resolvedProjects
        self.goals = resolvedGoals
        self.customEvents = resolvedCustomEvents
        self.googleCalendarAccount = resolvedGoogleCalendarAccount
        self.externalCalendarSubscriptions = resolvedExternalSubscriptions
        self.selectedScenarioID = resolvedScenarioID
        let initialContext = AppStore.makeDayContext(
            for: scenarios.first(where: { $0.id == resolvedScenarioID }) ?? scenarios.first(where: { $0.dailyState == configuredDailyState && $0.anchors == resolvedAnchors }) ?? scenarios.first,
            dailyState: configuredDailyState,
            routines: resolvedRoutines,
            customEvents: resolvedCustomEvents
        )
        self.dayContext = initialContext

        let initialAssessment = capacityEngine.assessDay(context: initialContext, anchors: resolvedAnchors)
        assessment = initialAssessment
        currentDayOutcome = AppStore.currentOutcome(
            for: Date(),
            from: selectedProfile.outcomes,
            startingMode: initialAssessment.recommendedMode
        )
        pendingFeedbackPrompt = nil
        liveHealthState = .empty
        liveExecutionState = .stable
        adaptiveReplanSuggestion = nil
        insights = []
        intelligenceReplaySummary = .empty
        intelligenceDataQuality = .empty
        intelligenceFeatureFlags = IntelligenceFeatureFlags()
        adaptiveDecisionTelemetry = []
        lastReplanPromptAt = nil
        let initialEstimatedState = stateEstimator.estimate(
            context: initialContext,
            anchors: resolvedAnchors,
            assessment: initialAssessment,
            profileSettings: configuredProfileSettings,
            baselines: adaptiveProfileStore.baselines(
                for: resolvedSelectedProfileID,
                recentHealthSignals: selectedProfile.healthSnapshots.map(\.signals).isEmpty ? [initialContext.healthSignals] : selectedProfile.healthSnapshots.map(\.signals),
                outcomes: selectedProfile.outcomes
            )
        )
        let initialLiveHealthState = healthSupportEvaluator.evaluate(
            context: initialContext,
            baselines: adaptiveProfileStore.baselines(
                for: resolvedSelectedProfileID,
                recentHealthSignals: selectedProfile.healthSnapshots.map(\.signals).isEmpty ? [initialContext.healthSignals] : selectedProfile.healthSnapshots.map(\.signals),
                outcomes: selectedProfile.outcomes
            ),
            recentOutcomes: selectedProfile.outcomes
        )
        let adjustedInitialEstimatedState = Self.applyingHealthInfluence(to: initialEstimatedState, with: initialLiveHealthState)
        liveHealthState = initialLiveHealthState
        estimatedState = adjustedInitialEstimatedState
        intelligenceReplaySummary = replayEvaluator.evaluate(outcomes: selectedProfile.outcomes)
        intelligenceDataQuality = dataQualityChecker.assess(
            outcomes: selectedProfile.outcomes,
            healthSnapshots: selectedProfile.healthSnapshots,
            asOf: Date()
        )
        let generatedPlans = planningEngine.generatePlans(
            for: initialContext,
            anchors: resolvedAnchors,
            profileSettings: configuredProfileSettings,
            estimatedState: adjustedInitialEstimatedState,
            recentOutcomes: selectedProfile.outcomes
        )
        plans = generatedPlans
        selectedMode = initialAssessment.recommendedMode
        checkInStore = CheckInStore(dailyState: configuredDailyState)
        todayStore = TodayStore(availablePlans: generatedPlans, selectedMode: initialAssessment.recommendedMode, assessment: initialAssessment)
        replanStore = ReplanStore()
        requestNotificationAuthorization()
        startExecutionMonitor()
        startHealthRefreshTimer()
        refreshLiveExecutionState()
        persistProfiles()

        _Concurrency.Task {
            await refreshIntegrations()
        }
    }

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    var currentPlan: PlanVersion? {
        plans.first(where: { $0.mode == selectedMode })
    }

    var plannerDaySummaries: [PlannerDaySummary] {
        (0...29).map { offset in
            let items = plannerAgenda(for: offset)
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = offset == 0 ? "'Today'" : (offset == 1 ? "'Tomorrow'" : "EEE")
            let title = formatter.string(from: date)
            let subtitle = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
            let commitmentCount = items.filter { $0.sourceKind == .event || $0.sourceKind == .task }.count
            let projectBlockCount = items.filter { $0.sourceKind == .projectBlock }.count
            let pressure = pressureSummary(for: items, dayOffset: offset)
            let focus = planningFocusSummary(for: items, dayOffset: offset)
            return PlannerDaySummary(
                dayOffset: offset,
                title: title,
                subtitle: subtitle,
                itemCount: items.count,
                commitmentCount: commitmentCount,
                projectBlockCount: projectBlockCount,
                pressureSummary: pressure,
                focusSummary: focus
            )
        }
    }

    var allKnownEvents: [DayEvent] {
        deduplicatedKnownEvents(from: integrationStore.importedEvents + googleImportedEvents + externalImportedEvents + customEvents).sorted {
            if $0.dayOffset == $1.dayOffset {
                return $0.startMinute < $1.startMinute
            }
            return $0.dayOffset < $1.dayOffset
        }
    }

    var allTasks: [(anchor: Anchor, task: Task)] {
        baseAnchors.flatMap { anchor in
            anchor.tasks.map { (anchor: anchor, task: $0) }
        }
        .sorted { lhs, rhs in
            if lhs.task.dayOffset == rhs.task.dayOffset {
                return (lhs.task.startMinute ?? 0) < (rhs.task.startMinute ?? 0)
            }
            return lhs.task.dayOffset < rhs.task.dayOffset
        }
    }

    func plannerAgenda(for dayOffset: Int) -> [PlannerAgendaItem] {
        let projectItems = suggestedProjectWorkItems(for: dayOffset)
        if dayOffset == 0, let currentPlan {
            return currentPlan.dailyPlan.blocks.map { block in
                PlannerAgendaItem(
                    id: block.id,
                    dayOffset: 0,
                    title: block.title,
                    detail: block.detail,
                    startMinute: block.startMinute,
                    durationMinutes: block.durationMinutes,
                    sourceKind: plannerSourceKind(for: block.kind),
                    accentLabel: block.kindLabel,
                    isSuggested: false
                )
            }.sorted(by: plannerAgendaSort)
        }

        let dayEvents = allKnownEvents
            .filter { $0.dayOffset == dayOffset && $0.shouldAppearInPlanning }
            .map {
                PlannerAgendaItem(
                    id: $0.id,
                    dayOffset: dayOffset,
                    title: $0.title,
                    detail: $0.detail,
                    startMinute: $0.startMinute,
                    durationMinutes: $0.durationMinutes,
                    sourceKind: .event,
                    accentLabel: "Event",
                    isSuggested: false
                )
            }

        let taskItems = baseAnchors.enumerated().flatMap { index, anchor in
            anchor.tasks
                .filter { $0.dayOffset == dayOffset }
                .map { task in
                    PlannerAgendaItem(
                        id: task.id,
                        dayOffset: dayOffset,
                        title: task.title,
                        detail: task.detail,
                        startMinute: task.startMinute ?? defaultStartMinute(for: anchor.timeLabel, fallbackIndex: index),
                        durationMinutes: task.durationMinutes,
                        sourceKind: .task,
                        accentLabel: anchor.title,
                        isSuggested: false
                    )
                }
        }

        let routineItems: [PlannerAgendaItem] = Array(routines.enumerated()).compactMap { entry in
            let (index, routine) = entry
            guard routine.isPinned else { return nil }
            let minutes = max(routine.steps.reduce(0) { $0 + $1.estimatedMinutes }, 10)
            return PlannerAgendaItem(
                id: routine.id,
                dayOffset: dayOffset,
                title: routine.title,
                detail: routine.summary,
                startMinute: defaultStartMinute(for: routine.timeWindow, fallbackIndex: index),
                durationMinutes: minutes,
                sourceKind: .routine,
                accentLabel: "Routine",
                isSuggested: false
            )
        }

        let goalItems: [PlannerAgendaItem] = goals.enumerated().compactMap { index, goal in
            guard dayOffset == 0 else { return nil }
            let linkedAnchorTitle = baseAnchors.first(where: { goal.linkedAnchorIDs.contains($0.id) })?.title
            return PlannerAgendaItem(
                id: goal.id,
                dayOffset: dayOffset,
                title: goal.title,
                detail: goal.targetSummary,
                startMinute: defaultStartMinute(for: linkedAnchorTitle ?? "Daily Goal", fallbackIndex: index + routineItems.count + taskItems.count),
                durationMinutes: 10,
                sourceKind: .task,
                accentLabel: "Goal",
                isSuggested: true
            )
        }

        return (routineItems + taskItems + dayEvents + goalItems + projectItems).sorted(by: plannerAgendaSort)
    }

    var planningIntelligenceSummary: String {
        let todayProjectMinutes = currentPlan?.dailyPlan.blocks
            .filter { $0.kind == .project }
            .reduce(0) { $0 + $1.durationMinutes } ?? suggestedProjectWorkItems(for: 0).reduce(0) { $0 + $1.durationMinutes }
        let urgentProjects = projects.filter { $0.remainingMinutes > 0 && $0.daysUntilDue() <= 3 }

        if !urgentProjects.isEmpty {
            let names = urgentProjects.prefix(2).map(\.title).joined(separator: " and ")
            return "Project planning is protecting work for \(names) before the due date turns into a crunch."
        }

        if todayProjectMinutes > 0 {
            return "The planner is reserving \(todayProjectMinutes) minutes for project progress so larger work does not disappear behind today-only tasks."
        }

        return "The planner is keeping future days lighter until due dates or unfinished work create real pressure."
    }

    func projectPlanningSummary(for project: Project) -> String {
        let daysRemaining = project.daysUntilDue()
        let minutesPerDay = project.dailyMinutesNeeded()
        if project.remainingMinutes == 0 {
            return "This project's planned work is complete."
        }
        if daysRemaining == 0 {
            return "This is due today, so the planner will protect \(project.remainingMinutes)m of work immediately."
        }
        return "About \(minutesPerDay)m per day keeps this on track across the next \(daysRemaining + 1) days."
    }

    func suggestedProjectWorkItems(for dayOffset: Int) -> [PlannerAgendaItem] {
        suggestedProjectBlocks(for: dayOffset).map { block in
            PlannerAgendaItem(
                id: block.id,
                dayOffset: block.dayOffset,
                title: block.title,
                detail: block.detail,
                startMinute: block.startMinute,
                durationMinutes: block.durationMinutes,
                sourceKind: .projectBlock,
                accentLabel: "Project Block",
                isSuggested: block.isSuggested
            )
        }
    }

    func suggestedProjectBlocks(for dayOffset: Int) -> [ProjectWorkBlock] {
        let referenceDate = Date()

        let scheduled = projects.flatMap { project -> [ProjectWorkBlock] in
            let remaining = project.remainingSubtasks
            guard !remaining.isEmpty else { return [] }

            let daysAvailable = max(project.daysUntilDue(from: referenceDate), 0) + 1
            let dailyCapacity = suggestedProjectCapacity(dayOffset: dayOffset)
            let defaultMinute = suggestedProjectStartMinute(dayOffset: dayOffset)

            return remaining.enumerated().compactMap { index, subtask in
                let totalBlocks = max(remaining.count, 1)
                let compression = project.dailyMinutesNeeded(from: referenceDate) >= 90 ? 0.7 : 1.0
                let normalizedPosition = Double(index) / Double(totalBlocks)
                let rawOffset = Int(floor(Double(daysAvailable - 1) * normalizedPosition * compression))
                let assignedOffset = min(max(rawOffset, 0), max(daysAvailable - 1, 0))
                guard assignedOffset == dayOffset else { return nil }

                let minute = min(max(defaultMinute + (index % 2) * 75, 8 * 60), 20 * 60)
                let detail = "\(project.title) • \(subtask.estimatedMinutes)m • \(project.urgencySummary)"
                return ProjectWorkBlock(
                    projectID: project.id,
                    subtaskID: subtask.id,
                    title: subtask.title,
                    detail: detail,
                    dayOffset: assignedOffset,
                    startMinute: minute,
                    durationMinutes: min(subtask.estimatedMinutes, dailyCapacity),
                    isSuggested: true
                )
            }
        }

        return scheduled.sorted {
            if $0.startMinute == $1.startMinute {
                return $0.title < $1.title
            }
            return $0.startMinute < $1.startMinute
        }
    }

    private func plannerAgendaSort(_ lhs: PlannerAgendaItem, _ rhs: PlannerAgendaItem) -> Bool {
        if lhs.startMinute == rhs.startMinute {
            return lhs.title < rhs.title
        }
        return lhs.startMinute < rhs.startMinute
    }

    private func pressureSummary(for items: [PlannerAgendaItem], dayOffset: Int) -> String {
        let eventMinutes = items.filter { $0.sourceKind == .event }.reduce(0) { $0 + $1.durationMinutes }
        let taskMinutes = items.filter { $0.sourceKind == .task || $0.sourceKind == .projectBlock }.reduce(0) { $0 + $1.durationMinutes }
        let totalMinutes = eventMinutes + taskMinutes

        if totalMinutes >= 420 {
            return dayOffset == 0 ? "Heavy today" : "Heavy day"
        }
        if totalMinutes >= 240 {
            return dayOffset == 0 ? "Moderate today" : "Moderate day"
        }
        if totalMinutes > 0 {
            return dayOffset == 0 ? "Light today" : "Light day"
        }
        return "Open space"
    }

    private func planningFocusSummary(for items: [PlannerAgendaItem], dayOffset: Int) -> String {
        if let projectBlock = items.first(where: { $0.sourceKind == .projectBlock }) {
            return dayOffset == 0 ? "Protect \(projectBlock.title)" : "Make room for \(projectBlock.title)"
        }
        if let event = items.first(where: { $0.sourceKind == .event }) {
            return dayOffset == 0 ? "Plan around \(event.title)" : "Commitment-led day"
        }
        if let task = items.first(where: { $0.sourceKind == .task }) {
            return dayOffset == 0 ? "Keep \(task.title) moving" : "Task-led planning"
        }
        return "Flexible day"
    }

    private func suggestedProjectCapacity(dayOffset: Int) -> Int {
        switch dayOffset {
        case 0: return 60
        case 1...2: return 75
        default: return 90
        }
    }

    private func suggestedProjectStartMinute(dayOffset: Int) -> Int {
        switch dayOffset {
        case 0: return 14 * 60
        case 1...2: return 10 * 60
        default: return 9 * 60 + 30
        }
    }

    var currentGuidance: String {
        guidanceEngine.makeGuidance(
            currentBlock: todayStore.currentBlock,
            nextBlock: todayStore.nextTimelineBlock,
            dailyState: dailyState,
            mode: selectedMode
        )
    }

    var currentTaskTimingSummary: String {
        guard let task = todayStore.currentTask else { return "Choose a task to see timing support." }

        var parts: [String] = []
        if let startTimeText = task.startTimeText {
            parts.append("Start \(startTimeText)")
        }
        parts.append(task.estimateSummary)
        if activeTaskStartedAt != nil {
            parts.append("Timer \(elapsedMinutes)m")
        }
        return parts.joined(separator: " • ")
    }

    var currentTaskCueSummary: String? {
        resolvedSensoryCue(for: todayStore.currentTask).map { "\($0.categoryTitle): \($0.title)" }
    }

    var currentTaskCueDetail: String? {
        resolvedSensoryCue(for: todayStore.currentTask)?.detail
    }

    var currentReminderPlan: ReminderPlan? {
        guard let task = todayStore.currentTask else { return nil }
        return reminderPlan(for: task, dailyState: dailyState)
    }

    var activeRoutineForToday: Routine? {
        todayStore.activeRoutine(from: routines)
    }

    var activeRoutineSupportForToday: RoutineExecutionSupport? {
        activeRoutineForToday.map(routineExecutionSupport(for:))
    }

    var isRoutinePausedForToday: Bool {
        routinePauseStartedAt != nil
    }

    var liveExecutionSignals: [ExecutionDriftSignal] {
        liveExecutionState.signals
    }

    var suggestedReplanMode: PlanMode? {
        adaptiveReplanSuggestion?.recommendedMode
    }

    var adaptationSummary: String? {
        let recent = Array((selectedUserProfile?.outcomes ?? []).suffix(5))
        let reasons = recent.flatMap(\.cueResponses).compactMap(\.failureReason)
        let baselines = currentPersonalizedBaselines
        let tooLateCount = reasons.filter { $0 == .tooLate }.count
        let tooEarlyCount = reasons.filter { $0 == .tooEarly }.count
        let tooIntenseCount = reasons.filter { $0 == .tooIntense }.count
        let alreadyMovingCount = reasons.filter { $0 == .alreadyMoving }.count
        let rebuildPressure = recent.reduce(0) { $0 + $1.rebuildDayCount }
        let missedTransitions = recent.reduce(0) { $0 + $1.missedTransitionBlockIDs.count }

        if tooLateCount >= 2 || missedTransitions >= 2 {
            return "Adding more transition runway based on recent late starts and missed handoffs."
        }

        if tooIntenseCount >= 2 {
            return "Softening reminder intensity because recent cues looked too intense."
        }

        if tooEarlyCount >= 2 {
            return "Moving prompts closer to the moment because earlier reminders were not landing."
        }

        if alreadyMovingCount >= 2 {
            return "Reducing repeat prompts when you are already getting underway."
        }

        if rebuildPressure >= 2 {
            return "Protecting more buffer because recent days have needed more rebuilding."
        }

        if let typicalCueResponseDelaySeconds = baselines.typicalCueResponseDelaySeconds, typicalCueResponseDelaySeconds >= 240 {
            return "Starting support a little earlier because you usually need more runway before cues turn into action."
        }

        if baselines.transitionMissRate >= 0.2 {
            return "Biasing support toward gentler handoffs because transitions have been the most common friction point."
        }

        if let preferredLeadTime = baselines.preferredLeadTimeMinutes {
            return "Adapting reminder timing toward your recent response pattern (about \(Int(preferredLeadTime.rounded())) minutes of runway)."
        }

        if liveHealthState.status == .overwhelmed {
            return "Lowering demands because live health signals suggest overwhelm is likely right now."
        }

        if liveHealthState.status == .strained {
            return "Protecting the next few blocks because live health signals suggest the day is getting heavier."
        }

        return nil
    }

    var adaptationReasonDetails: [String] {
        let recent = Array((selectedUserProfile?.outcomes ?? []).suffix(5))
        let reasons = recent.flatMap(\.cueResponses).compactMap(\.failureReason)
        let baselines = currentPersonalizedBaselines
        let tooLateCount = reasons.filter { $0 == .tooLate }.count
        let tooEarlyCount = reasons.filter { $0 == .tooEarly }.count
        let tooIntenseCount = reasons.filter { $0 == .tooIntense }.count
        let alreadyMovingCount = reasons.filter { $0 == .alreadyMoving }.count
        let rebuildPressure = recent.reduce(0) { $0 + $1.rebuildDayCount }
        let missedTransitions = recent.reduce(0) { $0 + $1.missedTransitionBlockIDs.count }

        var details: [String] = []

        if tooLateCount >= 2 {
            details.append("\(tooLateCount) recent cue responses said support arrived too late.")
        }

        if missedTransitions >= 2 {
            details.append("\(missedTransitions) recent transition blocks were missed or slipped.")
        }

        if tooIntenseCount >= 2 {
            details.append("\(tooIntenseCount) recent cue responses marked support as too intense.")
        }

        if tooEarlyCount >= 2 {
            details.append("\(tooEarlyCount) recent cue responses said prompts came too early.")
        }

        if alreadyMovingCount >= 2 {
            details.append("\(alreadyMovingCount) recent cue responses showed prompts arriving after momentum had already started.")
        }

        if rebuildPressure >= 2 {
            details.append("Recent days needed \(rebuildPressure) rebuilds, which usually means the plan needs more margin.")
        }

        if let typicalCueResponseDelaySeconds = baselines.typicalCueResponseDelaySeconds, typicalCueResponseDelaySeconds >= 240 {
            details.append("Typical cue response delay is about \(Int(typicalCueResponseDelaySeconds.rounded())) seconds.")
        }

        if baselines.transitionMissRate >= 0.2 {
            details.append("Transition miss rate is about \(Int((baselines.transitionMissRate * 100).rounded()))% lately.")
        }

        if let weekdayDelay = baselines.weekdayTypicalCueResponseDelaySeconds, let weekendDelay = baselines.weekendTypicalCueResponseDelaySeconds {
            details.append("Cue response is about \(Int(weekdayDelay.rounded()))s on weekdays vs \(Int(weekendDelay.rounded()))s on weekends.")
        }

        if let noReminderStartHour = baselines.noReminderStartHour, let noReminderEndHour = baselines.noReminderEndHour {
            details.append("Quiet support window inferred around \(noReminderStartHour):00-\(noReminderEndHour):00 based on overstimulation feedback.")
        }

        if liveHealthState.status != .stable {
            details.append(liveHealthState.supportingSignals.first ?? liveHealthState.summary)
        }

        if estimatedState.confidence < 0.55 {
            details.append("Today's confidence is \(Int((estimatedState.confidence * 100).rounded()))%, so the app is biasing toward extra runway.")
        }

        return Array(details.prefix(3))
    }

    var healthContextSummary: String {
        let health = integrationStore.importedHealthSignals ?? dayContext.healthSignals
        var parts: [String] = []

        if let sleepHours = health.sleepHours {
            parts.append(String(format: "Sleep %.1fh", sleepHours))
        }
        if let recoveryScore = health.recoveryScore {
            parts.append("Recovery \(recoveryScore)")
        }
        if let recentHeartRate = health.recentHeartRate {
            parts.append("Recent HR \(recentHeartRate)")
        }
        if let hydrationLiters = health.hydrationLiters {
            parts.append(String(format: "Water %.1fL", hydrationLiters))
        }
        if let heartRateVariabilityMilliseconds = health.heartRateVariabilityMilliseconds {
            parts.append(String(format: "HRV %.0fms", heartRateVariabilityMilliseconds))
        }
        if let respiratoryRate = health.respiratoryRate {
            parts.append(String(format: "Resp %.1f", respiratoryRate))
        }

        if parts.isEmpty {
            return integrationStore.healthStatus == .connected
                ? "Apple Health is connected, but there is not enough recent data to shape today yet."
                : "Connect Apple Health to blend sleep, hydration, activity, and recovery into the daily plan."
        }

        return parts.joined(separator: " • ")
    }

    var healthSupportSummary: String? {
        guard liveHealthState.status != .stable || !liveHealthState.recoveryRecommendations.isEmpty else { return nil }
        let recommendation = liveHealthState.recoveryRecommendations.first?.title
        return [liveHealthState.summary, recommendation].compactMap { $0 }.joined(separator: " ")
    }

    var checkInHealthAutofillSummary: String? {
        checkInStore.healthAutofillSummary
    }

    var calendarContextSummary: String {
        let sourceNames = integrationStore.selectedCalendarSourceNames
        let sourceLabel = sourceNames.isEmpty ? "No calendar sources selected" : sourceNames.joined(separator: ", ")
        let eventCount = integrationStore.importedEvents.count

        if integrationStore.calendarStatus != .connected {
            return "Connect Apple Calendar to pull today's commitments and any synced Google calendars on this device."
        }

        if eventCount == 0 {
            return "\(sourceLabel) • No imported events for today."
        }

        let sampleTitles = integrationStore.importedEvents.prefix(2).map(\.title)
        let preview = sampleTitles.isEmpty ? nil : sampleTitles.joined(separator: " • ")
        let base = "\(sourceLabel) • \(eventCount) imported event\(eventCount == 1 ? "" : "s")"
        return [base, preview].compactMap { $0 }.joined(separator: " • ")
    }

    var estimatedStateSummary: String {
        let overloadPercent = Int((estimatedState.overloadRisk * 100).rounded())
        return "\(estimatedState.capacityBand.title) • overload risk \(overloadPercent)% • confidence \(Int((estimatedState.confidence * 100).rounded()))%"
    }

    var personalizedBaselineSummary: String? {
        let baselines = currentPersonalizedBaselines
        var parts: [String] = []
        if let typicalCueResponseDelaySeconds = baselines.typicalCueResponseDelaySeconds {
            parts.append("Typical cue response \(Int(typicalCueResponseDelaySeconds.rounded()))s")
        }
        if let typicalLateStartMinutes = baselines.typicalLateStartMinutes {
            parts.append("Typical late start \(Int(typicalLateStartMinutes.rounded()))m")
        }
        if let preferredLeadTimeMinutes = baselines.preferredLeadTimeMinutes {
            parts.append("Preferred cue lead \(Int(preferredLeadTimeMinutes.rounded()))m")
        }
        if let preferredRepeatIntervalMinutes = baselines.preferredRepeatIntervalMinutes {
            parts.append("Preferred repeat \(Int(preferredRepeatIntervalMinutes.rounded()))m")
        }
        if baselines.rebuildsPerDay >= 1 {
            parts.append(String(format: "Rebuild tendency %.1f/day", baselines.rebuildsPerDay))
        }
        if baselines.transitionMissRate >= 0.1 {
            parts.append("Transition misses \(Int((baselines.transitionMissRate * 100).rounded()))%")
        }
        if let typicalRecoveryScore = baselines.typicalRecoveryScore {
            parts.append("Typical recovery \(Int(typicalRecoveryScore.rounded()))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var featuredInsight: InsightCard? {
        insights.first
    }

    var reminderPreviewPlan: ReminderPlan {
        if let currentTask = todayStore.currentTask {
            return reminderPlan(for: currentTask, dailyState: dailyState)
        }

        let previewTask = baseAnchors
            .flatMap(\.tasks)
            .first ?? Task(
                title: "Preview task",
                detail: "Use this to preview reminder support.",
                durationMinutes: 20,
                isEssential: true
            )
        return reminderPlan(for: previewTask, dailyState: dailyState)
    }

    var selectedUserProfile: UserProfile? {
        userProfiles.first(where: { $0.id == selectedProfileID })
    }

    private var currentPersonalizedBaselines: PersonalizedBaselines {
        adaptiveProfileStore.baselines(
            for: selectedProfileID,
            recentHealthSignals: currentHealthSignalHistory,
            outcomes: selectedUserProfile?.outcomes ?? []
        )
    }

    private var currentHealthSignalHistory: [HealthSignals] {
        let history = (selectedUserProfile?.healthSnapshots ?? []).map(\.signals)
        if history.isEmpty {
            return [dayContext.healthSignals]
        }
        return history
    }

    private static func applyingHealthInfluence(to estimatedState: EstimatedState, with liveHealthState: LiveHealthState) -> EstimatedState {
        let overloadRisk = min(1.0, estimatedState.overloadRisk + (liveHealthState.status == .overwhelmed ? 0.2 : (liveHealthState.status == .strained ? 0.1 : 0)))
        let executionState: ExecutionState = {
            switch liveHealthState.status {
            case .stable:
                return estimatedState.executionState
            case .strained:
                return estimatedState.executionState == .overloaded ? .overloaded : .drifting
            case .overwhelmed:
                return .overloaded
            }
        }()
        let supportingSignals = Array((estimatedState.supportingSignals + liveHealthState.supportingSignals).prefix(6))
        return EstimatedState(
            capacityBand: estimatedState.capacityBand,
            overloadRisk: overloadRisk,
            transitionRisk: estimatedState.transitionRisk,
            latenessRisk: estimatedState.latenessRisk,
            executionState: executionState,
            confidence: max(estimatedState.confidence, liveHealthState.confidence),
            supportingSignals: supportingSignals
        )
    }

    func setProfileDisplayName(_ name: String) {
        profileSettings.displayName = name
        persistCurrentProfile()
    }

    func setUserRole(_ role: UserRole) {
        profileSettings.userRole = role
        persistCurrentProfile()
    }

    func setNeurotype(_ neurotype: Neurotype) {
        profileSettings.neurotype = neurotype
        persistCurrentProfile()
    }

    func setPDAAwareSupport(_ isEnabled: Bool) {
        profileSettings.pdaAwareSupport = isEnabled
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func setIncludeHolidayEvents(_ isEnabled: Bool) {
        profileSettings.includeHolidayEvents = isEnabled
        if integrationStore.calendarStatus == .connected {
            integrationStore.setImportedEvents(applyingSupportOverrides(to: integrationStore.allImportedEvents))
        }
        persistCurrentProfile()
        regeneratePlans()
    }

    func setPrimarySupportFocus(_ focus: SupportFocus) {
        profileSettings.primarySupportFocus = focus
        persistCurrentProfile()
        regeneratePlans()
    }

    func applySupportPreset(_ preset: SupportPreset) {
        profileSettings.supportPreset = preset

        switch preset {
        case .balanced:
            profileSettings.primarySupportFocus = .transitions
            profileSettings.supportTone = .steady
            profileSettings.communicationStyle = .supportive
            profileSettings.visualSupportMode = .standard
            profileSettings.transitionPrepMinutes = 10
            profileSettings.reminderProfile = .balanced
        case .adhdSupport:
            profileSettings.primarySupportFocus = .stayingOnTask
            profileSettings.supportTone = .direct
            profileSettings.communicationStyle = .literal
            profileSettings.visualSupportMode = .standard
            profileSettings.transitionPrepMinutes = 10
            profileSettings.reminderProfile = .repetitiveSupport
        case .asdSupport:
            profileSettings.primarySupportFocus = .transitions
            profileSettings.supportTone = .steady
            profileSettings.communicationStyle = .literal
            profileSettings.visualSupportMode = .lowerStimulation
            profileSettings.transitionPrepMinutes = 20
            profileSettings.reminderProfile = .gentleSupport
        case .simplePlanning:
            profileSettings.primarySupportFocus = .timeBlindness
            profileSettings.supportTone = .steady
            profileSettings.communicationStyle = .literal
            profileSettings.visualSupportMode = .standard
            profileSettings.transitionPrepMinutes = 5
            profileSettings.reminderProfile = .balanced
        }

        dailyState.reminderProfile = profileSettings.reminderProfile
        checkInStore.reminderProfile = profileSettings.reminderProfile
        persistCurrentProfile()
        regeneratePlans()
        rescheduleActiveTaskSupport()
    }

    func setSupportTone(_ tone: SupportTone) {
        profileSettings.supportTone = tone
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func setCommunicationStyle(_ style: CommunicationStyle) {
        profileSettings.communicationStyle = style
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func setVisualSupportMode(_ mode: VisualSupportMode) {
        profileSettings.visualSupportMode = mode
        persistCurrentProfile()
    }

    func setTransitionPrepMinutes(_ minutes: Int) {
        profileSettings.transitionPrepMinutes = minutes
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func setReminderProfile(_ profile: ReminderProfile) {
        profileSettings.reminderProfile = profile
        dailyState.reminderProfile = profile
        checkInStore.reminderProfile = profile
        persistCurrentProfile()
        regeneratePlans()
        rescheduleActiveTaskSupport()
    }

    func setDefaultSensoryCue(_ cue: TaskSensoryCue?) {
        profileSettings.defaultSensoryCue = cue
        persistCurrentProfile()
        if activeTaskStartedAt != nil {
            activeSensoryCue = resolvedSensoryCue(for: todayStore.currentTask)
            sensoryCueController.start(activeSensoryCue)
        }
    }

    func setQuietHoursEnabled(_ isEnabled: Bool) {
        profileSettings.quietHoursEnabled = isEnabled
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func setQuietHours(startHour: Int? = nil, endHour: Int? = nil) {
        if let startHour {
            profileSettings.quietHoursStartHour = startHour
        }
        if let endHour {
            profileSettings.quietHoursEndHour = endHour
        }
        persistCurrentProfile()
        rescheduleActiveTaskSupport()
    }

    func addUserProfile() {
        let nextIndex = userProfiles.count + 1
        let newName = "Profile \(nextIndex)"
        let newSettings = ProfileSettings(displayName: newName, reminderProfile: profileSettings.reminderProfile)
        let newProfile = UserProfile(
            displayName: newName,
            settings: newSettings,
            dailyState: dailyState,
            selectedScenarioID: selectedScenarioID,
            anchors: MockData.sampleAnchors,
            routines: MockData.routines,
            projects: [],
            goals: [],
            customEvents: []
        )
        userProfiles.append(newProfile)
        persistProfiles()
        switchToProfile(newProfile.id)
    }

    func activateDemoStory(_ story: DemoStory) {
        let profileID = userProfiles.first(where: { $0.displayName == story.profileName })?.id ?? UUID()
        var storyDailyState = story.scenario.dailyState
        storyDailyState.reminderProfile = story.reminderProfile

        let storyProfile = UserProfile(
            id: profileID,
            displayName: story.profileName,
            settings: story.profileSettings,
            dailyState: storyDailyState,
            selectedScenarioID: story.scenario.id,
            anchors: story.scenario.anchors,
            routines: MockData.routines,
            projects: [],
            goals: [],
            customEvents: [],
            googleCalendarAccount: nil,
            externalCalendarSubscriptions: [],
            outcomes: userProfiles.first(where: { $0.id == profileID })?.outcomes ?? [],
            healthSnapshots: userProfiles.first(where: { $0.id == profileID })?.healthSnapshots ?? []
        )

        if let existingIndex = userProfiles.firstIndex(where: { $0.id == profileID }) {
            userProfiles[existingIndex] = storyProfile
        } else {
            userProfiles.append(storyProfile)
        }

        selectedProfileID = storyProfile.id
        hasCompletedOnboarding = true
        applyProfile(storyProfile)
        persistProfiles()
    }

    func completeOnboarding(
        displayName: String,
        userRole: UserRole,
        neurotype: Neurotype,
        pdaAwareSupport: Bool,
        supportPreset: SupportPreset,
        primarySupportFocus: SupportFocus,
        additionalSupportFocuses: [SupportFocus],
        communicationStyle: CommunicationStyle,
        visualSupportMode: VisualSupportMode,
        reminderProfile: ReminderProfile
    ) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "My Profile" : trimmedName
        profileSettings.displayName = resolvedName
        profileSettings.userRole = userRole
        profileSettings.neurotype = neurotype
        profileSettings.pdaAwareSupport = pdaAwareSupport
        profileSettings.supportPreset = supportPreset
        profileSettings.primarySupportFocus = primarySupportFocus
        profileSettings.additionalSupportFocuses = additionalSupportFocuses
        profileSettings.communicationStyle = communicationStyle
        profileSettings.visualSupportMode = visualSupportMode
        profileSettings.reminderProfile = reminderProfile
        dailyState.reminderProfile = reminderProfile
        checkInStore.reminderProfile = reminderProfile
        checkInStore.priority = dailyState.priority

        if let index = userProfiles.firstIndex(where: { $0.id == selectedProfileID }) {
            userProfiles[index].displayName = resolvedName
        }

        hasCompletedOnboarding = true
        persistCurrentProfile()
        regeneratePlans()
    }

    func skipOnboardingForNow() {
        hasCompletedOnboarding = true
        persistProfiles()
    }

    func switchToProfile(_ profileID: UUID) {
        guard let profile = userProfiles.first(where: { $0.id == profileID }) else { return }
        selectedProfileID = profileID
        applyProfile(profile)
        persistProfiles()
    }

    func deleteSelectedProfile() {
        guard userProfiles.count > 1, let currentIndex = userProfiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let fallbackIndex = currentIndex == 0 ? 1 : currentIndex - 1
        let fallbackProfileID = userProfiles[fallbackIndex].id
        userProfiles.remove(at: currentIndex)
        selectedProfileID = fallbackProfileID
        if let fallbackProfile = userProfiles.first(where: { $0.id == fallbackProfileID }) {
            applyProfile(fallbackProfile)
        }
        persistProfiles()
    }

    func applyCheckIn() {
        dailyState = checkInStore.snapshot
        profileSettings.reminderProfile = dailyState.reminderProfile
        persistCurrentProfile()
        regeneratePlans()
    }

    func applyHealthAutofillToCheckIn() {
        guard let importedHealthSignals = integrationStore.importedHealthSignals else { return }
        checkInStore.applyHealthSignals(importedHealthSignals)
    }

    func selectMode(_ mode: PlanMode) {
        selectedMode = mode
        todayStore.selectedMode = mode
        recordCurrentDayOutcome { $0.recordingMode(mode) }
        refreshLiveExecutionState()
    }

    func rebuildDay() {
        recordCurrentDayOutcome { $0.recordingRebuildDay().recordingMode(selectedMode) }
        presentFeedbackPrompt(
            kind: .rebuild,
            title: "What felt off about the support?",
            detail: "A quick note helps the app adjust how it replans and cues the next stretch."
        )
        dayContext = makeDayContext()
        assessment = capacityEngine.assessDay(context: dayContext, anchors: baseAnchors)
        estimatedState = stateEstimator.estimate(
            context: dayContext,
            anchors: baseAnchors,
            assessment: assessment,
            profileSettings: profileSettings,
            baselines: adaptiveProfileStore.baselines(
                for: selectedProfileID,
                recentHealthSignals: currentHealthSignalHistory,
                outcomes: selectedUserProfile?.outcomes ?? []
            )
        )
        estimatedState = Self.applyingHealthInfluence(
            to: estimatedState,
            with: healthSupportEvaluator.evaluate(
                context: dayContext,
                baselines: currentPersonalizedBaselines,
                recentOutcomes: selectedUserProfile?.outcomes ?? []
            )
        )
        plans = planningEngine.generatePlans(
            for: dayContext,
            anchors: baseAnchors,
            profileSettings: profileSettings,
            estimatedState: estimatedState,
            recentOutcomes: selectedUserProfile?.outcomes ?? [],
            preserving: plans
        )
        if plans.contains(where: { $0.mode == assessment.recommendedMode }) {
            selectedMode = assessment.recommendedMode
        }
        todayStore.updatePlans(plans, selectedMode: selectedMode, assessment: assessment)
        refreshLiveExecutionState()
    }

    func toggleTask(_ taskID: UUID, in anchorID: UUID, mode: PlanMode) {
        guard let currentTask = plans
            .first(where: { $0.mode == mode })?
            .anchors.first(where: { $0.id == anchorID })?
            .tasks.first(where: { $0.id == taskID }) else { return }

        let willComplete = !currentTask.isCompleted
        let recordedMinutes = willComplete && todayStore.activeTaskID == taskID ? max(elapsedMinutes, 1) : nil

        baseAnchors = updateTasks(in: baseAnchors, anchorID: anchorID, taskID: taskID, isCompleted: willComplete, recordedMinutes: recordedMinutes)

        plans = plans.map { plan in
            let updatedAnchors = updateTasks(in: plan.anchors, anchorID: anchorID, taskID: taskID, isCompleted: willComplete, recordedMinutes: recordedMinutes)
            return plan.updating(anchors: updatedAnchors)
        }

        dayContext = makeDayContext()
        todayStore.updatePlans(plans, selectedMode: selectedMode, assessment: assessment)
        todayStore.setActiveAnchor(anchorID)
        if willComplete {
            var updatedOutcome = currentDayOutcome.recordingCompletedTask(taskID)
            if todayStore.activeTaskID == taskID {
                let response = CueResponse(
                    taskID: taskID,
                    scheduleBlockID: blockID(for: anchorID, taskID: taskID),
                    sensoryCue: resolvedSensoryCue(for: currentTask),
                    reminderProfile: dailyState.reminderProfile,
                    context: .taskCompletion,
                    responseDelaySeconds: activeTaskElapsedSeconds > 0 ? activeTaskElapsedSeconds : nil,
                    result: .actedOn,
                    note: "Completed the active task."
                )
                updatedOutcome = updatedOutcome.recordingCueResponse(response)
            }
            replaceCurrentDayOutcome(with: updatedOutcome)
        } else {
            recordCurrentDayOutcome { $0.recordingSkippedTask(taskID) }
        }
        persistCurrentProfile()

        if willComplete && todayStore.activeTaskID == taskID {
            todayStore.clearActiveTask(taskID)
            stopTaskTimer()
        }
        refreshLiveExecutionState()
    }

    func startCurrentTask() {
        todayStore.startCurrentTask()
        guard let currentTask = todayStore.currentTask else { return }
        beginTask(currentTask)
    }

    func startTask(_ taskID: UUID, in anchorID: UUID) {
        todayStore.startTask(taskID, in: anchorID)
        guard let anchor = baseAnchors.first(where: { $0.id == anchorID }),
              let task = anchor.tasks.first(where: { $0.id == taskID }) else { return }
        beginTask(task)
    }

    func deleteTask(_ taskID: UUID, from anchorID: UUID) {
        if todayStore.activeTaskID == taskID {
            todayStore.clearActiveTask(taskID)
            stopTaskTimer()
        }

        baseAnchors = baseAnchors.map { anchor in
            guard anchor.id == anchorID else { return anchor }
            return anchor.updating(tasks: anchor.tasks.filter { $0.id != taskID })
        }
        persistCurrentProfile()
        regeneratePlans()
    }

    private func beginTask(_ currentTask: Task) {
        activeTaskStartedAt = Date()
        activeTaskElapsedSeconds = 0
        activeSensoryCue = resolvedSensoryCue(for: currentTask)
        recordTaskStart(for: currentTask)
        startTaskTimer()
        sensoryCueController.start(activeSensoryCue)
        scheduleNotifications(for: currentTask, reminderPlan: reminderPlan(for: currentTask, dailyState: dailyState))
        refreshLiveExecutionState()
    }

    func loadScenario(_ scenarioID: UUID) {
        guard let scenario = scenarios.first(where: { $0.id == scenarioID }) else {
            return
        }

        selectedScenarioID = scenarioID
        baseAnchors = scenario.anchors
        dailyState = scenario.dailyState
        dailyState.reminderProfile = profileSettings.reminderProfile
        customEvents = []
        dayContext = makeDayContext(for: scenario, dailyState: dailyState, routines: routines)
        checkInStore.update(with: dailyState)
        persistCurrentProfile()
        stopTaskTimer()
        regeneratePlans()
    }

    func selectSupportReason(_ reason: ReplanReason) {
        replanStore.selectedReason = reason
    }

    func applyReplanChoice(_ mode: PlanMode) {
        selectedMode = mode
        todayStore.selectedMode = mode
        replanStore.lastAppliedMode = mode
        adaptiveReplanSuggestion = nil
        lastReplanPromptAt = Date()
        let response = CueResponse(
            taskID: todayStore.currentTask?.id,
            scheduleBlockID: todayStore.currentBlock?.id,
            sensoryCue: resolvedSensoryCue(for: todayStore.currentTask),
            reminderProfile: dailyState.reminderProfile,
            context: .replan,
            result: .helpful,
            note: "Used replan support to switch the day into \(mode.title.lowercased())."
        )
        recordCurrentDayOutcome { $0.recordingMode(mode).recordingCueResponse(response) }
        presentFeedbackPrompt(
            kind: .rebuild,
            title: "What made the original support miss?",
            detail: "One quick label helps the next version of the day fit better."
        )
    }

    func toggleRoutineStep(_ stepID: UUID, in routineID: UUID) {
        let wasCompleted = routines
            .first(where: { $0.id == routineID })?
            .steps.first(where: { $0.id == stepID })?
            .isCompleted ?? false
        routines = routines.map { routine in
            guard routine.id == routineID else { return routine }
            let updatedSteps = routine.steps.map { step in
                guard step.id == stepID else { return step }
                return step.updatingCompletion(!step.isCompleted)
            }
            return routine.updating(steps: updatedSteps)
        }
        if !wasCompleted {
            let responseDelaySeconds = lastRoutineCueDeliveryByStepID[stepID].map { max(Int(Date().timeIntervalSince($0)), 0) }
            let response = CueResponse(
                routineID: routineID,
                routineStepID: stepID,
                reminderProfile: dailyState.reminderProfile,
                context: .taskCompletion,
                responseDelaySeconds: responseDelaySeconds,
                result: .actedOn,
                note: "Completed a routine step."
            )
            recordCurrentDayOutcome { $0.recordingCueResponse(response) }
            lastRoutineCueDeliveryByStepID.removeValue(forKey: stepID)
            routineCueMissLoggedForStepIDs.remove(stepID)
        }
        persistCurrentProfile()
        regeneratePlans()
        refreshLiveExecutionState()
    }

    func pauseRoutine(_ routineID: UUID) {
        let currentStepID = routines.first(where: { $0.id == routineID })?.steps.first(where: { !$0.isCompleted })?.id
        let response = CueResponse(
            scheduleBlockID: nil,
            routineID: routineID,
            routineStepID: currentStepID,
            sensoryCue: nil,
            reminderProfile: dailyState.reminderProfile,
            context: .routinePause,
            result: .dismissed,
            note: "Paused routine \(routineTitle(for: routineID))."
        )
        recordCurrentDayOutcome { $0.recordingRoutinePause().recordingCueResponse(response) }
        routinePauseStartedAt = Date()
        presentFeedbackPrompt(
            kind: .routineStep(routineID: routineID, stepID: currentStepID),
            title: "What made that cue unhelpful?",
            detail: "This helps the app learn whether to change timing, intensity, or repetition."
        )
        refreshLiveExecutionState()
    }

    func resumeRoutine(_ routineID: UUID) {
        let currentStepID = routines.first(where: { $0.id == routineID })?.steps.first(where: { !$0.isCompleted })?.id
        let response = CueResponse(
            scheduleBlockID: nil,
            routineID: routineID,
            routineStepID: currentStepID,
            sensoryCue: nil,
            reminderProfile: dailyState.reminderProfile,
            context: .routineResume,
            result: .helpful,
            note: "Resumed routine \(routineTitle(for: routineID))."
        )
        recordCurrentDayOutcome { $0.recordingRoutineResume().recordingCueResponse(response) }
        routinePauseStartedAt = nil
        refreshLiveExecutionState()
    }

    func recordRoutineCueDelivery(
        routineID: UUID,
        stepID: UUID,
        cueIntensity: RoutineExecutionSupport.CueIntensity
    ) {
        lastRoutineCueDeliveryByStepID[stepID] = Date()
        routineCueMissLoggedForStepIDs.remove(stepID)

        let response = CueResponse(
            routineID: routineID,
            routineStepID: stepID,
            reminderProfile: dailyState.reminderProfile,
            context: .routineCue,
            result: .delivered,
            note: "Delivered a \(cueIntensity.title.lowercased()) routine cue."
        )
        recordCurrentDayOutcome { $0.recordingCueResponse(response) }
        refreshLiveExecutionState()
    }

    func recordRoutineCueMiss(routineID: UUID, stepID: UUID) {
        guard !routineCueMissLoggedForStepIDs.contains(stepID) else { return }
        routineCueMissLoggedForStepIDs.insert(stepID)

        let response = CueResponse(
            routineID: routineID,
            routineStepID: stepID,
            reminderProfile: dailyState.reminderProfile,
            context: .routineCue,
            result: .ignored,
            note: "Routine cue sequence ended without the step being completed."
        )
        recordCurrentDayOutcome { $0.recordingCueResponse(response) }

        presentFeedbackPrompt(
            kind: .routineStep(routineID: routineID, stepID: stepID),
            title: "What made that routine cue miss?",
            detail: "A quick label helps the app time and shape the next step more accurately."
        )
        refreshLiveExecutionState()
    }

    func addEvent(_ event: DayEvent) {
        customEvents.append(contentsOf: expandedEvents(from: event))
        persistCurrentProfile()
        regeneratePlans()
    }

    func addTask(
        title: String,
        detail: String,
        anchorID: UUID,
        dayOffset: Int,
        startMinute: Int?,
        durationMinutes: Int,
        isEssential: Bool,
        projectID: UUID? = nil,
        sensoryCue: TaskSensoryCue?
    ) {
        let newTask = Task(
            title: title,
            detail: detail,
            dayOffset: dayOffset,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            isEssential: isEssential,
            projectID: projectID,
            sensoryCue: sensoryCue
        )

        baseAnchors = baseAnchors.map { anchor in
            guard anchor.id == anchorID else { return anchor }
            return anchor.updating(tasks: anchor.tasks + [newTask])
        }

        persistCurrentProfile()
        regeneratePlans()
    }

    func addProject(
        title: String,
        detail: String,
        dueDate: Date,
        estimatedTotalMinutes: Int,
        subtaskTitles: [String]
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let subtasks = Project.suggestedSubtasks(
            title: trimmedTitle,
            estimatedTotalMinutes: estimatedTotalMinutes,
            manualTitles: subtaskTitles
        )

        projects.append(
            Project(
                title: trimmedTitle,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: dueDate,
                estimatedTotalMinutes: estimatedTotalMinutes,
                subtasks: subtasks
            )
        )
        persistCurrentProfile()
    }

    func addGoal(
        title: String,
        detail: String,
        category: GoalCategory,
        targetSummary: String,
        linkedTaskIDs: [UUID],
        linkedRoutineIDs: [UUID],
        linkedProjectIDs: [UUID],
        linkedAnchorIDs: [UUID]
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedTarget.isEmpty else { return }

        goals.append(
            Goal(
                title: trimmedTitle,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                targetSummary: trimmedTarget,
                linkedTaskIDs: linkedTaskIDs,
                linkedRoutineIDs: linkedRoutineIDs,
                linkedProjectIDs: linkedProjectIDs,
                linkedAnchorIDs: linkedAnchorIDs
            )
        )
        persistCurrentProfile()
    }

    func toggleProjectSubtask(projectID: UUID, subtaskID: UUID) {
        projects = projects.map { project in
            guard project.id == projectID else { return project }
            let updatedSubtasks = project.subtasks.map { subtask in
                guard subtask.id == subtaskID else { return subtask }
                return subtask.updatingCompletion(!subtask.isCompleted)
            }
            return project.updating(subtasks: updatedSubtasks)
        }
        persistCurrentProfile()
    }

    func addAnchor(title: String, timeLabel: String, type: Anchor.AnchorType, prompt: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let canonicalPrompt = canonicalAnchorPrompt(from: prompt)
        baseAnchors.append(
            Anchor(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                timeLabel: timeLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                prompt: canonicalPrompt,
                tasks: []
            )
        )
        persistCurrentProfile()
        regeneratePlans()
    }

    func updateAnchor(_ anchorID: UUID, title: String, timeLabel: String, type: Anchor.AnchorType, prompt: String) {
        let canonicalPrompt = canonicalAnchorPrompt(from: prompt)
        baseAnchors = baseAnchors.map { anchor in
            guard anchor.id == anchorID else { return anchor }
            return Anchor(
                id: anchor.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                timeLabel: timeLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                prompt: canonicalPrompt,
                tasks: anchor.tasks
            )
        }
        persistCurrentProfile()
        regeneratePlans()
    }

    func deleteAnchor(_ anchorID: UUID) {
        baseAnchors.removeAll { $0.id == anchorID }
        persistCurrentProfile()
        regeneratePlans()
    }

    func shrinkCurrentTaskBlock() {
        guard let anchorID = todayStore.currentAnchor?.id, let task = todayStore.currentTask else { return }
        updateTaskSchedule(taskID: task.id, from: anchorID) { existing in
            existing.updatingSchedule(durationMinutes: max(existing.durationMinutes - 10, 5))
        }
    }

    func moveCurrentTaskToNextAnchor() {
        guard let currentAnchor = todayStore.currentAnchor,
              let nextAnchor = todayStore.nextAnchor,
              let task = todayStore.currentTask else { return }
        moveTask(taskID: task.id, from: currentAnchor.id, to: nextAnchor.id) { existing in
            existing.updatingSchedule(startMinute: nil)
        }
    }

    func deferCurrentTaskToTomorrow() {
        guard let anchorID = todayStore.currentAnchor?.id, let task = todayStore.currentTask else { return }
        updateTaskSchedule(taskID: task.id, from: anchorID) { existing in
            existing.updatingSchedule(dayOffset: min(existing.dayOffset + 1, Self.planningEventHorizonDays))
        }
    }

    func dropCurrentTaskFromToday() {
        guard let anchorID = todayStore.currentAnchor?.id, let task = todayStore.currentTask else { return }
        if task.isEssential {
            updateTaskSchedule(taskID: task.id, from: anchorID) { existing in
                existing.updatingSchedule(dayOffset: min(existing.dayOffset + 1, Self.planningEventHorizonDays))
            }
        } else {
            baseAnchors = baseAnchors.map { anchor in
                guard anchor.id == anchorID else { return anchor }
                return anchor.updating(tasks: anchor.tasks.filter { $0.id != task.id })
            }
            persistCurrentProfile()
            regeneratePlans()
        }
    }

    func previewSensoryCue(_ cue: TaskSensoryCue?) {
        activeSensoryCue = cue
        sensoryCueController.start(cue)
        guard cue != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.activeTaskStartedAt == nil else { return }
            self.activeSensoryCue = nil
            self.sensoryCueController.stop()
        }
    }

    func stopSensoryCuePreview() {
        if activeTaskStartedAt == nil {
            activeSensoryCue = nil
            sensoryCueController.stop()
        }
    }

    func replayCurrentTaskCue() {
        guard let cue = resolvedSensoryCue(for: todayStore.currentTask) else { return }
        activeSensoryCue = cue
        sensoryCueController.start(cue)
    }

    func addRoutine(title: String, timeWindow: String, summary: String, stepTitles: [String], isPinned: Bool) {
        let steps = stepTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { title in
                RoutineStep(
                    title: title,
                    cue: "Keep this step visible and low-pressure.",
                    estimatedMinutes: 5
                )
            }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !steps.isEmpty else { return }

        routines.append(
            Routine(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                timeWindow: timeWindow.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                steps: steps,
                isPinned: isPinned
            )
        )
        persistCurrentProfile()
        regeneratePlans()
    }

    func updateRoutine(_ routineID: UUID, title: String, timeWindow: String, summary: String, stepTitles: [String], isPinned: Bool) {
        let steps = stepTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { title in
                RoutineStep(
                    title: title,
                    cue: "Keep this step visible and low-pressure.",
                    estimatedMinutes: 5
                )
            }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !steps.isEmpty else { return }

        routines = routines.map { routine in
            guard routine.id == routineID else { return routine }
            return Routine(
                id: routine.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                timeWindow: timeWindow.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                steps: steps,
                isPinned: isPinned
            )
        }
        persistCurrentProfile()
        regeneratePlans()
    }

    func updateEventSupport(_ event: DayEvent) {
        eventOverrides[event.supportKey] = event

        if customEvents.contains(where: { $0.id == event.id }) {
            customEvents = customEvents.map { existingEvent in
                existingEvent.id == event.id ? event : existingEvent
            }
        }

        integrationStore.setImportedEvents(
            integrationStore.allImportedEvents.map { importedEvent in
                importedEvent.supportKey == event.supportKey ? event : applyingSupportOverride(to: importedEvent)
            }
        )
        regeneratePlans()
    }

    func connectAppleHealth() async {
        let granted = await healthService.requestAuthorization()
        integrationStore.healthStatus = healthService.authorizationState
        guard granted else { return }
        integrationStore.importedHealthSignals = await healthService.fetchSignals()
        if let importedHealthSignals = integrationStore.importedHealthSignals {
            checkInStore.applyHealthSignals(importedHealthSignals)
            recordHealthSnapshotIfNeeded(importedHealthSignals)
        }
        regeneratePlans()
    }

    func removeEvent(_ event: DayEvent) {
        customEvents.removeAll { $0.id == event.id }
        eventOverrides.removeValue(forKey: event.supportKey)
        persistCurrentProfile()
        regeneratePlans()
    }

    func setEventPlanningVisibility(_ event: DayEvent, isVisible: Bool) {
        let updatedMetadata = DayEvent.SupportMetadata(
            planningRelevance: isVisible ? .fullSupport : .ignoreForPlanning,
            transitionPrepMinutes: event.supportMetadata.transitionPrepMinutes,
            feltDeadlineOffsetMinutes: event.supportMetadata.feltDeadlineOffsetMinutes,
            sensoryNote: event.supportMetadata.sensoryNote,
            locationName: event.supportMetadata.locationName,
            estimatedDriveMinutes: event.supportMetadata.estimatedDriveMinutes
        )
        updateEventSupport(event.applyingSupportMetadata(updatedMetadata))
    }

    func connectCalendar() async {
        let granted = await calendarService.requestAccess()
        integrationStore.calendarStatus = calendarService.authorizationState
        integrationStore.setCalendarSources(calendarService.availableSourceNames)
        guard granted else { return }
        integrationStore.setImportedEvents(
            applyingSupportOverrides(
                to: await calendarService.fetchEvents(
                    for: Date(),
                    daysAhead: 365,
                    selectedCalendarNames: integrationStore.selectedCalendarSourceNames
                )
            )
        )
        regeneratePlans()
    }

    func refreshIntegrations() async {
        integrationStore.healthStatus = healthService.authorizationState
        integrationStore.calendarStatus = calendarService.authorizationState
        integrationStore.setCalendarSources(calendarService.availableSourceNames)

        if integrationStore.healthStatus == .connected {
            await refreshHealthSignalsIfConnected()
        }

        if integrationStore.calendarStatus == .connected {
            integrationStore.setImportedEvents(
                applyingSupportOverrides(
                    to: await calendarService.fetchEvents(
                        for: Date(),
                        daysAhead: 365,
                        selectedCalendarNames: integrationStore.selectedCalendarSourceNames
                    )
                )
            )
            integrationStore.setCalendarSources(calendarService.availableSourceNames)
        }

        await refreshGoogleCalendar()
        await refreshExternalCalendarFeeds()

        regeneratePlans()
    }

    func connectGoogleCalendar(clientID: String) async {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else { return }

        if let account = try? await googleCalendarService.connect(clientID: trimmedClientID) {
            googleCalendarAccount = account
            persistCurrentProfile()
            await refreshGoogleCalendar()
            regeneratePlans()
        }
    }

    func disconnectGoogleCalendar() {
        googleCalendarAccount = nil
        googleImportedEvents = []
        persistCurrentProfile()
        regeneratePlans()
    }

    func refreshGoogleCalendar() async {
        guard let account = googleCalendarAccount else {
            googleImportedEvents = []
            return
        }

        if let result = try? await googleCalendarService.refresh(account: account, startingAt: Date(), daysAhead: 365) {
            googleCalendarAccount = result.account
            googleImportedEvents = result.events
            persistCurrentProfile()
        }
    }

    func toggleGoogleCalendarSelection(_ calendarID: String) async {
        guard var account = googleCalendarAccount else { return }
        var selectedIDs = account.selectedCalendarIDs
        if selectedIDs.contains(calendarID) {
            selectedIDs.removeAll { $0 == calendarID }
        } else {
            selectedIDs.append(calendarID)
        }
        account = GoogleCalendarAccount(
            clientID: account.clientID,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            accessTokenExpiration: account.accessTokenExpiration,
            availableCalendars: account.availableCalendars,
            selectedCalendarIDs: selectedIDs.sorted()
        )
        googleCalendarAccount = account
        persistCurrentProfile()
        await refreshGoogleCalendar()
        regeneratePlans()
    }

    func addExternalCalendarSubscription(title: String, provider: ExternalCalendarSubscription.Provider, feedURL: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedURL.isEmpty else { return }

        externalCalendarSubscriptions.append(
            ExternalCalendarSubscription(
                title: trimmedTitle,
                provider: provider,
                feedURL: trimmedURL
            )
        )
        persistCurrentProfile()
        await refreshExternalCalendarFeeds()
        regeneratePlans()
    }

    func removeExternalCalendarSubscription(_ subscriptionID: UUID) async {
        externalCalendarSubscriptions.removeAll { $0.id == subscriptionID }
        persistCurrentProfile()
        await refreshExternalCalendarFeeds()
        regeneratePlans()
    }

    func refreshExternalCalendarFeeds() async {
        externalImportedEvents = await externalCalendarFeedService.fetchEvents(
            for: externalCalendarSubscriptions,
            startingAt: Date(),
            daysAhead: 365
        )
    }

    func refreshHealthSignalsIfConnected() async {
        guard integrationStore.healthStatus == .connected else { return }
        let signals = await healthService.fetchSignals()
        integrationStore.importedHealthSignals = signals
        if signals.hasAnyData {
            checkInStore.applyHealthSignals(signals)
            recordHealthSnapshotIfNeeded(signals)
        }
        regeneratePlans()
    }

    func toggleCalendarSourceSelection(_ sourceName: String) {
        integrationStore.toggleCalendarSourceSelection(sourceName)
        _Concurrency.Task {
            if integrationStore.calendarStatus == .connected {
                integrationStore.setImportedEvents(
                    applyingSupportOverrides(
                        to: await calendarService.fetchEvents(
                            for: Date(),
                            daysAhead: 365,
                            selectedCalendarNames: integrationStore.selectedCalendarSourceNames
                        )
                    )
                )
            }
            regeneratePlans()
        }
    }

    func regeneratePlans() {
        dayContext = makeDayContext()
        assessment = capacityEngine.assessDay(context: dayContext, anchors: baseAnchors)
        ensureCurrentDayOutcomeIsCurrent(startingMode: assessment.recommendedMode)
        estimatedState = stateEstimator.estimate(
            context: dayContext,
            anchors: baseAnchors,
            assessment: assessment,
            profileSettings: profileSettings,
            baselines: adaptiveProfileStore.baselines(
                for: selectedProfileID,
                recentHealthSignals: currentHealthSignalHistory,
                outcomes: selectedUserProfile?.outcomes ?? []
            )
        )
        estimatedState = Self.applyingHealthInfluence(
            to: estimatedState,
            with: healthSupportEvaluator.evaluate(
                context: dayContext,
                baselines: currentPersonalizedBaselines,
                recentOutcomes: selectedUserProfile?.outcomes ?? []
            )
        )
        selectedMode = assessment.recommendedMode
        plans = planningEngine.generatePlans(
            for: dayContext,
            anchors: baseAnchors,
            profileSettings: profileSettings,
            estimatedState: estimatedState,
            recentOutcomes: selectedUserProfile?.outcomes ?? [],
            preserving: plans
        )
        todayStore.updatePlans(plans, selectedMode: selectedMode, assessment: assessment)
        syncExecutionWithCurrentTime()
        replanStore.lastAppliedMode = selectedMode
        scheduleLeaveByNotifications()
        if todayStore.currentTask == nil || todayStore.currentTask?.isCompleted == true {
            stopTaskTimer()
        }
        refreshLiveExecutionState()
        persistCurrentProfile()
    }

    private func makeDayContext() -> DayContext {
        makeDayContext(
            for: scenarios.first(where: { $0.id == selectedScenarioID }),
            dailyState: dailyState,
            routines: routines,
            customEvents: customEvents
        )
    }

    private func makeDayContext(for scenario: MockScenario?, dailyState: DailyState, routines: [Routine], customEvents: [DayEvent] = []) -> DayContext {
        let importedEvents = integrationStore.importedEvents
        let visibleEvents = (importedEvents.isEmpty ? (scenario?.events ?? []) : importedEvents) + customEvents
        let mergedEvents = visibleEvents.filter { $0.dayOffset <= Self.planningEventHorizonDays }
        let healthSignals = integrationStore.importedHealthSignals ?? scenario?.healthSignals ?? .baseline

        return DayContext(
            date: Date(),
            planningDayOffset: 0,
            dailyState: dailyState,
            events: mergedEvents,
            routines: routines,
            projects: projects,
            healthSignals: healthSignals
        )
    }

    private static func makeDayContext(for scenario: MockScenario?, dailyState: DailyState, routines: [Routine], customEvents: [DayEvent] = []) -> DayContext {
        DayContext(
            date: Date(),
            planningDayOffset: 0,
            dailyState: dailyState,
            events: ((scenario?.events ?? []) + customEvents).filter { $0.dayOffset <= planningEventHorizonDays },
            routines: routines,
            projects: [],
            healthSignals: scenario?.healthSignals ?? .baseline
        )
    }

    private func applyingSupportOverrides(to events: [DayEvent]) -> [DayEvent] {
        events.map(applyingSupportOverride)
    }

    private func applyingSupportOverride(to event: DayEvent) -> DayEvent {
        if let override = eventOverrides[event.supportKey] {
            return override
        }

        if event.isLikelyHoliday {
            return event.applyingSupportMetadata(
                DayEvent.SupportMetadata(
                    planningRelevance: profileSettings.includeHolidayEvents ? .lightweightReminder : .ignoreForPlanning,
                    transitionPrepMinutes: 0,
                    feltDeadlineOffsetMinutes: nil,
                    sensoryNote: "",
                    locationName: event.supportMetadata.locationName,
                    estimatedDriveMinutes: event.supportMetadata.estimatedDriveMinutes
                )
            )
        }

        return event
    }

    private func expandedEvents(from event: DayEvent) -> [DayEvent] {
        switch event.repeatRule {
        case .none:
            return [event]
        case .daily:
            return (0..<5).map { offset in
                DayEvent(
                    id: UUID(),
                    title: event.title,
                    dayOffset: offset,
                    startMinute: event.startMinute,
                    durationMinutes: event.durationMinutes,
                    detail: event.detail,
                    kind: event.kind,
                    familyMember: event.familyMember,
                    repeatRule: event.repeatRule,
                    sensoryLevel: event.sensoryLevel,
                    sourceName: event.sourceName,
                    externalIdentifier: event.externalIdentifier,
                    supportMetadata: event.supportMetadata
                )
            }
        case .weekdays:
            return (0..<5).map { offset in
                DayEvent(
                    id: UUID(),
                    title: event.title,
                    dayOffset: offset,
                    startMinute: event.startMinute,
                    durationMinutes: event.durationMinutes,
                    detail: event.detail,
                    kind: event.kind,
                    familyMember: event.familyMember,
                    repeatRule: event.repeatRule,
                    sensoryLevel: event.sensoryLevel,
                    sourceName: event.sourceName,
                    externalIdentifier: event.externalIdentifier,
                    supportMetadata: event.supportMetadata
                )
            }
        case .weekly:
            return [event]
        }
    }

    private var elapsedMinutes: Int {
        max(Int(ceil(Double(activeTaskElapsedSeconds) / 60.0)), 0)
    }

    private func updateTasks(in anchors: [Anchor], anchorID: UUID, taskID: UUID, isCompleted: Bool, recordedMinutes: Int?) -> [Anchor] {
        anchors.map { anchor in
            guard anchor.id == anchorID else { return anchor }

            let updatedTasks = anchor.tasks.map { task in
                guard task.id == taskID else { return task }
                return task.updatingCompletion(isCompleted, recordedMinutes: recordedMinutes)
            }

            return anchor.updating(tasks: updatedTasks)
        }
    }

    private func updateTaskSchedule(taskID: UUID, from anchorID: UUID, transform: (Task) -> Task) {
        baseAnchors = baseAnchors.map { anchor in
            guard anchor.id == anchorID else { return anchor }
            return anchor.updating(tasks: anchor.tasks.map { $0.id == taskID ? transform($0) : $0 })
        }
        persistCurrentProfile()
        regeneratePlans()
    }

    private func moveTask(taskID: UUID, from sourceAnchorID: UUID, to destinationAnchorID: UUID, transform: (Task) -> Task) {
        var movedTask: Task?

        baseAnchors = baseAnchors.map { anchor in
            guard anchor.id == sourceAnchorID else { return anchor }
            let remainingTasks = anchor.tasks.filter { task in
                if task.id == taskID {
                    movedTask = transform(task)
                    return false
                }
                return true
            }
            return anchor.updating(tasks: remainingTasks)
        }

        if let movedTask {
            baseAnchors = baseAnchors.map { anchor in
                guard anchor.id == destinationAnchorID else { return anchor }
                return anchor.updating(tasks: anchor.tasks + [movedTask])
            }
        }

        persistCurrentProfile()
        regeneratePlans()
    }

    private func defaultStartMinute(for label: String, fallbackIndex: Int) -> Int {
        let normalized = label.lowercased()
        if normalized.contains("morning") { return 8 * 60 }
        if normalized.contains("midday") || normalized.contains("afternoon") { return 13 * 60 }
        if normalized.contains("evening") { return 18 * 60 }
        if normalized.contains("night") { return 20 * 60 }
        return (8 + fallbackIndex * 2) * 60
    }

    private func plannerSourceKind(for kind: ScheduleBlock.BlockKind) -> PlannerAgendaItem.SourceKind {
        switch kind {
        case .event:
            return .event
        case .routine:
            return .routine
        case .transition, .buffer:
            return .transition
        case .recovery:
            return .recovery
        case .project:
            return .projectBlock
        case .anchor:
            return .task
        }
    }

    private func startTaskTimer() {
        taskTimerCancellable?.cancel()
        taskTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let activeTaskStartedAt else { return }
                self.activeTaskElapsedSeconds = max(Int(Date().timeIntervalSince(activeTaskStartedAt)), 0)
                self.refreshLiveExecutionState()
            }
    }

    private func startExecutionMonitor() {
        executionMonitorCancellable?.cancel()
        executionMonitorCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshLiveExecutionState()
            }
    }

    private func startHealthRefreshTimer() {
        healthRefreshCancellable?.cancel()
        healthRefreshCancellable = Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.integrationStore.healthStatus == .connected else { return }
                _Concurrency.Task {
                    await self.refreshHealthSignalsIfConnected()
                }
            }
    }

    private func refreshLiveExecutionState() {
        syncExecutionWithCurrentTime()
        let profileOutcomes = selectedUserProfile?.outcomes ?? []
        let healthSnapshots = selectedUserProfile?.healthSnapshots ?? []
        let baselines = currentPersonalizedBaselines
        liveHealthState = healthSupportEvaluator.evaluate(
            context: dayContext,
            baselines: baselines,
            recentOutcomes: profileOutcomes
        )
        liveExecutionState = liveExecutionMonitor.evaluate(
            now: Date(),
            currentBlock: todayStore.currentBlock,
            currentTask: todayStore.currentTask,
            activeTaskStartedAt: activeTaskStartedAt,
            currentDayOutcome: currentDayOutcome,
            recentOutcomes: profileOutcomes,
            routinePauseStartedAt: routinePauseStartedAt,
            estimatedState: estimatedState
        )
        if intelligenceFeatureFlags.adaptiveReplanEnabled {
            adaptiveReplanSuggestion = adaptiveReplanEngine.suggest(
                liveExecutionState: liveExecutionState,
                liveHealthState: liveHealthState,
                estimatedState: estimatedState,
                currentMode: selectedMode,
                assessment: assessment,
                profileSettings: profileSettings
            )
        } else {
            adaptiveReplanSuggestion = nil
        }
        insights = insightsEngine.generateInsights(
            outcomes: profileOutcomes,
            baselines: baselines,
            estimatedState: estimatedState,
            liveHealthState: liveHealthState
        )
        intelligenceReplaySummary = replayEvaluator.evaluate(outcomes: profileOutcomes)
        intelligenceDataQuality = dataQualityChecker.assess(
            outcomes: profileOutcomes,
            healthSnapshots: healthSnapshots,
            asOf: Date()
        )
        adaptiveReplanSuggestion = gatedReplanSuggestion(adaptiveReplanSuggestion)
        if let adaptiveReplanSuggestion {
            appendTelemetry(
                kind: .replan,
                title: adaptiveReplanSuggestion.title,
                detail: "Reason: \(adaptiveReplanSuggestion.reason.title) • Mode: \(adaptiveReplanSuggestion.recommendedMode.title)"
            )
        }
        if let suggestion = adaptiveReplanSuggestion, suggestion.shouldPrompt, shouldPromptReplan(now: Date()) {
            replanStore.selectedReason = suggestion.reason
            lastReplanPromptAt = Date()
        }
    }

    private func shouldPromptReplan(now: Date) -> Bool {
        guard let lastReplanPromptAt else { return true }
        return now.timeIntervalSince(lastReplanPromptAt) >= 20 * 60
    }

    private func stopTaskTimer() {
        taskTimerCancellable?.cancel()
        taskTimerCancellable = nil
        activeTaskStartedAt = nil
        activeTaskElapsedSeconds = 0
        activeSensoryCue = nil
        sensoryCueController.stop()
        cancelTaskNotifications()
        refreshLiveExecutionState()
    }

    private func syncExecutionWithCurrentTime() {
        if let activeTaskID = todayStore.activeTaskID {
            if let activeTaskStartedAt, Date().timeIntervalSince(activeTaskStartedAt) < 90 {
                return
            }
            let activeTaskAnchorID = baseAnchors.first(where: { anchor in
                anchor.tasks.contains(where: { $0.id == activeTaskID })
            })?.id
            let currentAnchorID = todayStore.currentAnchor?.id
            let currentTaskID = todayStore.currentTask?.id

            if activeTaskAnchorID != currentAnchorID || currentTaskID != activeTaskID {
                recordCurrentDayOutcome { $0.recordingSkippedTask(activeTaskID) }
                todayStore.clearActiveTask(activeTaskID)
                taskTimerCancellable?.cancel()
                taskTimerCancellable = nil
                activeTaskStartedAt = nil
                activeTaskElapsedSeconds = 0
                activeSensoryCue = nil
                sensoryCueController.stop()
                cancelTaskNotifications()
            }
        }

        if todayStore.currentBlock?.kind != .routine, routinePauseStartedAt != nil {
            routinePauseStartedAt = nil
        }
    }

    private func resolvedSensoryCue(for task: Task?) -> TaskSensoryCue? {
        guard let task else { return nil }
        return task.sensoryCue ?? profileSettings.defaultSensoryCue
    }

    private func persistCurrentProfile() {
        guard let index = userProfiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        var updatedSettings = profileSettings
        updatedSettings.displayName = profileSettings.displayName
        userProfiles[index].displayName = profileSettings.displayName
        userProfiles[index].settings = updatedSettings
        userProfiles[index].dailyState = dailyState
        userProfiles[index].selectedScenarioID = selectedScenarioID
        userProfiles[index].anchors = baseAnchors
        userProfiles[index].routines = routines
        userProfiles[index].projects = projects
        userProfiles[index].goals = goals
        userProfiles[index].customEvents = customEvents
        userProfiles[index].googleCalendarAccount = googleCalendarAccount
        userProfiles[index].externalCalendarSubscriptions = externalCalendarSubscriptions
        userProfiles[index].outcomes = replacingOutcome(currentDayOutcome, in: userProfiles[index].outcomes)
        userProfiles[index].healthSnapshots = trimmedHealthSnapshots(userProfiles[index].healthSnapshots)
        persistProfiles()
    }

    private func applyProfile(_ profile: UserProfile) {
        stopTaskTimer()
        var updatedSettings = profile.settings
        updatedSettings.displayName = profile.displayName
        profileSettings = updatedSettings
        dailyState = profile.dailyState
        dailyState.reminderProfile = updatedSettings.reminderProfile
        baseAnchors = profile.anchors.isEmpty ? MockData.sampleAnchors : profile.anchors
        routines = profile.routines.isEmpty ? MockData.routines : profile.routines
        projects = profile.projects
        goals = profile.goals
        customEvents = profile.customEvents
        googleCalendarAccount = profile.googleCalendarAccount
        googleImportedEvents = []
        externalCalendarSubscriptions = profile.externalCalendarSubscriptions
        externalImportedEvents = []
        if let selectedScenarioID = profile.selectedScenarioID {
            self.selectedScenarioID = selectedScenarioID
        }
        currentDayOutcome = Self.currentOutcome(
            for: Date(),
            from: profile.outcomes,
            startingMode: assessment.recommendedMode
        )
        pendingFeedbackPrompt = nil
        routinePauseStartedAt = nil
        checkInStore.update(with: dailyState)
        regeneratePlans()
        refreshLiveExecutionState()
        _Concurrency.Task {
            await self.refreshIntegrations()
        }
    }

    private func deduplicatedKnownEvents(from events: [DayEvent]) -> [DayEvent] {
        func priority(for event: DayEvent) -> Int {
            if let sourceName = event.sourceName?.lowercased() {
                if sourceName.contains("google calendar") { return 3 }
                if sourceName.contains("feed") || sourceName.contains("skylight") { return 2 }
                if sourceName.contains("•") { return 1 }
            }
            return 0
        }

        func normalizedKey(for event: DayEvent) -> String {
            [
                event.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                String(event.dayOffset),
                String(event.startMinute),
                String(event.durationMinutes)
            ].joined(separator: "|")
        }

        var preferredByKey: [String: DayEvent] = [:]
        for event in events {
            let key = normalizedKey(for: event)
            if let existing = preferredByKey[key] {
                preferredByKey[key] = priority(for: event) >= priority(for: existing) ? event : existing
            } else {
                preferredByKey[key] = event
            }
        }
        return Array(preferredByKey.values)
    }

    private func recordHealthSnapshotIfNeeded(_ signals: HealthSignals) {
        guard signals.hasAnyData, let index = userProfiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let snapshot = DailyHealthSnapshot(date: Date(), signals: signals)
        var snapshots = userProfiles[index].healthSnapshots.filter { !Calendar.current.isDate($0.date, inSameDayAs: snapshot.date) }
        snapshots.append(snapshot)
        userProfiles[index].healthSnapshots = trimmedHealthSnapshots(snapshots)
        persistProfiles()
    }

    private func trimmedHealthSnapshots(_ snapshots: [DailyHealthSnapshot]) -> [DailyHealthSnapshot] {
        Array(snapshots.sorted { $0.date < $1.date }.suffix(21))
    }

    private func ensureCurrentDayOutcomeIsCurrent(startingMode: PlanMode) {
        currentDayOutcome = Self.currentOutcome(
            for: Date(),
            from: replacingOutcome(currentDayOutcome, in: selectedUserProfile?.outcomes ?? []),
            startingMode: startingMode
        )
    }

    private static func currentOutcome(for date: Date, from outcomes: [DayOutcome], startingMode: PlanMode) -> DayOutcome {
        let calendar = Calendar.current
        if let existing = outcomes.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return existing.recordingMode(startingMode)
        }
        return DayOutcome(date: calendar.startOfDay(for: date), selectedModesSeen: [startingMode])
    }

    private func replacingOutcome(_ outcome: DayOutcome, in outcomes: [DayOutcome]) -> [DayOutcome] {
        let calendar = Calendar.current
        var updated = outcomes.filter { !calendar.isDate($0.date, inSameDayAs: outcome.date) }
        updated.append(outcome)
        updated.sort { $0.date < $1.date }
        return updated
    }

    private func replaceCurrentDayOutcome(with outcome: DayOutcome) {
        currentDayOutcome = outcome
        outcomeLogger.record(outcome)
        refreshLiveExecutionState()
        persistCurrentProfile()
    }

    private func recordCurrentDayOutcome(_ transform: (DayOutcome) -> DayOutcome) {
        ensureCurrentDayOutcomeIsCurrent(startingMode: selectedMode)
        replaceCurrentDayOutcome(with: transform(currentDayOutcome))
    }

    private func recordTaskStart(for task: Task) {
        let currentMinute = AppStore.minuteOfDay(for: Date())
        var updatedOutcome = currentDayOutcome.recordingMode(selectedMode)
        if let activeBlock = todayStore.currentBlock {
            let lateStart = max(currentMinute - activeBlock.startMinute, 0)
            if lateStart >= 5 {
                updatedOutcome = updatedOutcome.recordingLateStart(for: activeBlock.id, minutes: lateStart)
                if activeBlock.kind == .transition || activeBlock.kind == .event {
                    updatedOutcome = updatedOutcome.recordingMissedTransition(activeBlock.id)
                    presentFeedbackPrompt(
                        kind: .missedTransition(blockID: activeBlock.id),
                        title: "What made that handoff miss?",
                        detail: "A fast label helps the app shape transition support more accurately."
                    )
                }
            }
        }

        let response = CueResponse(
            taskID: task.id,
            scheduleBlockID: todayStore.currentBlock?.id,
            sensoryCue: resolvedSensoryCue(for: task),
            reminderProfile: dailyState.reminderProfile,
            context: .taskStart,
            result: .actedOn,
            note: "Started the current task from Today."
        )
        replaceCurrentDayOutcome(with: updatedOutcome.recordingCueResponse(response))
    }

    private func blockID(for anchorID: UUID, taskID: UUID) -> UUID? {
        if let block = todayStore.timelineBlocks.first(where: { $0.anchorID == anchorID }) {
            return block.id
        }
        return todayStore.currentBlock?.id
    }

    private func routineTitle(for routineID: UUID) -> String {
        routines.first(where: { $0.id == routineID })?.title ?? "routine"
    }

    func routineExecutionSupport(for routine: Routine) -> RoutineExecutionSupport {
        let recent = Array((selectedUserProfile?.outcomes ?? []).suffix(6))
        let baselines = currentPersonalizedBaselines
        let currentStep = routine.steps.first(where: { !$0.isCompleted })
        let routineResponses = recent
            .flatMap(\.cueResponses)
            .filter { response in
                response.routineID == routine.id ||
                (currentStep != nil && response.routineStepID == currentStep?.id)
            }
        let globalReasons = recent.flatMap(\.cueResponses).compactMap(\.failureReason)
        let localReasons = routineResponses.compactMap(\.failureReason)
        let reasonPool = localReasons.isEmpty ? globalReasons : localReasons

        let tooLateCount = reasonPool.filter { $0 == .tooLate }.count
        let tooEarlyCount = reasonPool.filter { $0 == .tooEarly }.count
        let tooIntenseCount = reasonPool.filter { $0 == .tooIntense }.count
        let alreadyMovingCount = reasonPool.filter { $0 == .alreadyMoving }.count
        let pausePressure = recent.reduce(0) { $0 + $1.routinePauseCount }

        let baselineLeadBias = (baselines.typicalCueResponseDelaySeconds ?? 0) >= 240 ? 2 : 0
        let leadTime = max(3, 5 + baselineLeadBias + (tooLateCount >= 2 ? 4 : 0) - (tooEarlyCount >= 2 ? 2 : 0))
        let cueIntensity: RoutineExecutionSupport.CueIntensity
        if tooIntenseCount >= 2 {
            cueIntensity = .calm
        } else if tooLateCount >= 2 || pausePressure >= 2 || baselines.transitionMissRate >= 0.2 {
            cueIntensity = .elevated
        } else {
            cueIntensity = .steady
        }

        let suppressIfAlreadyMoving = alreadyMovingCount >= 2
        let maxCueRepeats = suppressIfAlreadyMoving ? 1 : (cueIntensity == .elevated ? 2 : 1)
        let resumeCueDelaySeconds = cueIntensity == .calm ? 90 : (cueIntensity == .elevated ? 30 : (baselines.routineResumeRate < 0.6 ? 45 : 60))
        let currentStepCue = adaptedRoutineCue(
            for: currentStep,
            cueIntensity: cueIntensity,
            suppressIfAlreadyMoving: suppressIfAlreadyMoving
        )
        let resumeSupportText: String
        if profileSettings.pdaAwareSupport {
            if pausePressure >= 2 {
                resumeSupportText = "If you want an easier re-entry, the smallest visible action is enough. There is no need to recover the whole routine at once."
            } else {
                resumeSupportText = "If you come back to this, picking up from the current step is enough."
            }
        } else if pausePressure >= 2 {
            resumeSupportText = "When you come back, restart with the smallest visible action instead of trying to recover the whole routine at once."
        } else {
            resumeSupportText = "If the routine pauses, come back to the current step rather than restarting everything."
        }

        let adjustmentSummary: String?
        if tooLateCount >= 2 || (baselines.typicalLateStartMinutes ?? 0) >= 8 {
            adjustmentSummary = "Adding a little more runway before the next step."
        } else if tooIntenseCount >= 2 {
            adjustmentSummary = "Keeping the cue softer because stronger prompts have been too much."
        } else if suppressIfAlreadyMoving {
            adjustmentSummary = "Backing off repeated prompts once you're already in motion."
        } else {
            adjustmentSummary = nil
        }

        return RoutineExecutionSupport(
            leadTimeMinutes: leadTime,
            cueIntensity: cueIntensity,
            suppressIfAlreadyMoving: suppressIfAlreadyMoving,
            maxCueRepeats: maxCueRepeats,
            resumeCueDelaySeconds: resumeCueDelaySeconds,
            currentStepCue: currentStepCue,
            resumeSupportText: resumeSupportText,
            adjustmentSummary: adjustmentSummary
        )
    }

    func submitFeedbackReason(_ reason: CueFailureReason) {
        guard let pendingFeedbackPrompt else { return }

        let response = CueResponse(
            taskID: todayStore.currentTask?.id,
            scheduleBlockID: pendingFeedbackPrompt.associatedBlockID,
            routineID: pendingFeedbackPrompt.associatedRoutineID,
            routineStepID: pendingFeedbackPrompt.associatedRoutineStepID,
            sensoryCue: resolvedSensoryCue(for: todayStore.currentTask),
            reminderProfile: dailyState.reminderProfile,
            context: .feedback,
            failureReason: reason,
            result: reason == .tooIntense ? .overstimulating : .dismissed,
            note: pendingFeedbackPrompt.kind.feedbackNote(reason: reason)
        )
        recordCurrentDayOutcome { $0.recordingCueResponse(response) }
        self.pendingFeedbackPrompt = nil
    }

    func dismissFeedbackPrompt() {
        pendingFeedbackPrompt = nil
    }

    private func presentFeedbackPrompt(kind: FeedbackPrompt.Kind, title: String, detail: String) {
        if let existing = pendingFeedbackPrompt, existing.kind == kind {
            return
        }
        pendingFeedbackPrompt = FeedbackPrompt(kind: kind, title: title, detail: detail)
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    struct FeedbackPrompt: Equatable {
        enum Kind: Equatable {
            case rebuild
            case cueMismatch
            case missedTransition(blockID: UUID)
            case routineStep(routineID: UUID, stepID: UUID?)

            var associatedBlockID: UUID? {
                switch self {
                case .missedTransition(let blockID):
                    return blockID
                case .rebuild, .cueMismatch, .routineStep:
                    return nil
                }
            }

            var associatedRoutineID: UUID? {
                switch self {
                case .routineStep(let routineID, _):
                    return routineID
                case .rebuild, .cueMismatch, .missedTransition:
                    return nil
                }
            }

            var associatedRoutineStepID: UUID? {
                switch self {
                case .routineStep(_, let stepID):
                    return stepID
                case .rebuild, .cueMismatch, .missedTransition:
                    return nil
                }
            }

            func feedbackNote(reason: CueFailureReason) -> String {
                switch self {
                case .rebuild:
                    return "Rebuild feedback: \(reason.supportLabel)"
                case .cueMismatch:
                    return "Cue mismatch feedback: \(reason.supportLabel)"
                case .missedTransition:
                    return "Missed transition feedback: \(reason.supportLabel)"
                case .routineStep:
                    return "Routine step feedback: \(reason.supportLabel)"
                }
            }
        }

        let kind: Kind
        let title: String
        let detail: String

        var associatedBlockID: UUID? {
            kind.associatedBlockID
        }

        var associatedRoutineID: UUID? {
            kind.associatedRoutineID
        }

        var associatedRoutineStepID: UUID? {
            kind.associatedRoutineStepID
        }
    }

    private func adaptedRoutineCue(
        for step: RoutineStep?,
        cueIntensity: RoutineExecutionSupport.CueIntensity,
        suppressIfAlreadyMoving: Bool
    ) -> String {
        let baseCue = step?.cue ?? "Keep the next step simple and visible."
        switch cueIntensity {
        case .calm:
            return "\(baseCue) Let the support stay quiet and low-pressure."
        case .steady:
            return baseCue
        case .elevated:
            return suppressIfAlreadyMoving
                ? "\(baseCue) Keep going once you start; the app should avoid piling on."
                : "\(baseCue) Give yourself a slightly earlier handoff into this step."
        }
    }

    private func persistProfiles() {
        let encoder = JSONEncoder()
        guard let profilesData = try? encoder.encode(userProfiles) else { return }
        UserDefaults.standard.set(profilesData, forKey: Self.profilesStorageKey)
        UserDefaults.standard.set(selectedProfileID.uuidString, forKey: Self.selectedProfileStorageKey)
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingCompletedStorageKey)
    }

    private static func loadPersistedProfiles() -> [UserProfile]? {
        guard let data = UserDefaults.standard.data(forKey: profilesStorageKey) else { return nil }
        return try? JSONDecoder().decode([UserProfile].self, from: data)
    }

    private static func loadPersistedSelectedProfileID() -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedProfileStorageKey) else { return nil }
        return UUID(uuidString: rawValue)
    }

    private static func loadOnboardingCompletedFlag(defaultingTo fallback: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: onboardingCompletedStorageKey) == nil {
            return fallback
        }
        return UserDefaults.standard.bool(forKey: onboardingCompletedStorageKey)
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotifications(for task: Task, reminderPlan: ReminderPlan) {
        cancelTaskNotifications()

        let repeatCount = max(reminderPlan.maxRepeats, 1)
        let intervalMinutes = reminderPlan.repeatIntervalMinutes ?? max(task.durationMinutes / 2, 15)
        let baseDate = Date()
        var lastScheduledDate: Date?

        for index in 1...repeatCount {
            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: reminderPlan, reminderIndex: index)
            content.body = notificationBody(for: task, reminderPlan: reminderPlan, reminderIndex: index)
            content.sound = .default
            var scheduledDate = baseDate.addingTimeInterval(TimeInterval(intervalMinutes * 60 * index))
            scheduledDate = nextAllowedNotificationDate(after: scheduledDate)
            if let lastScheduledDate, scheduledDate <= lastScheduledDate {
                let spacing = TimeInterval(max(intervalMinutes, 5) * 60)
                scheduledDate = nextAllowedNotificationDate(after: lastScheduledDate.addingTimeInterval(spacing))
            }
            lastScheduledDate = scheduledDate

            let request = UNNotificationRequest(
                identifier: taskNotificationIdentifier(taskID: task.id, index: index),
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second],
                        from: scheduledDate
                    ),
                    repeats: false
                )
            )

            notificationCenter.add(request)
        }
    }

    private func scheduleLeaveByNotifications() {
        cancelLeaveByNotifications()

        guard let currentPlan = plans.first(where: { $0.mode == selectedMode }) else { return }
        let leaveBlocks = currentPlan.dailyPlan.blocks.filter {
            $0.kind == .transition && $0.title.hasPrefix("Leave for ")
        }
        guard !leaveBlocks.isEmpty else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        for block in leaveBlocks {
            guard let leaveDate = calendar.date(byAdding: .minute, value: block.startMinute, to: startOfDay),
                  leaveDate > Date() else {
                continue
            }

            let prepDate = leaveDate.addingTimeInterval(-10 * 60)
            if prepDate > Date() {
                addLeaveByNotification(
                    identifier: leaveByNotificationIdentifier(blockID: block.id, phase: "prep"),
                    title: "Leaving Soon",
                    body: "In about 10 minutes, it will be time to leave. \(block.detail)",
                    scheduledDate: nextAllowedNotificationDate(after: prepDate)
                )
            }

            addLeaveByNotification(
                identifier: leaveByNotificationIdentifier(blockID: block.id, phase: "leave"),
                title: "Time To Leave",
                body: block.detail,
                scheduledDate: nextAllowedNotificationDate(after: leaveDate)
            )
        }
    }

    private func cancelTaskNotifications() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter] requests in
            let matchingIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("time-anchor.active-task.") }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
        }
    }

    private func cancelLeaveByNotifications() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter] requests in
            let matchingIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("time-anchor.leave-by.") }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
        }
    }

    private func taskNotificationIdentifier(taskID: UUID, index: Int) -> String {
        "time-anchor.active-task.\(taskID.uuidString).\(index)"
    }

    private func leaveByNotificationIdentifier(blockID: UUID, phase: String) -> String {
        "time-anchor.leave-by.\(blockID.uuidString).\(phase)"
    }

    private func addLeaveByNotification(identifier: String, title: String, body: String, scheduledDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: scheduledDate
                ),
                repeats: false
            )
        )

        notificationCenter.add(request)
    }

    private func nextAllowedNotificationDate(after proposedDate: Date) -> Date {
        guard profileSettings.quietHoursEnabled else { return proposedDate }

        let startHour = profileSettings.quietHoursStartHour
        let endHour = profileSettings.quietHoursEndHour
        guard startHour != endHour else { return proposedDate }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: proposedDate)
        let isInQuietHours: Bool

        if startHour < endHour {
            isInQuietHours = hour >= startHour && hour < endHour
        } else {
            isInQuietHours = hour >= startHour || hour < endHour
        }

        guard isInQuietHours else { return proposedDate }

        var components = calendar.dateComponents([.year, .month, .day], from: proposedDate)
        components.hour = endHour
        components.minute = 0
        components.second = 0

        guard let baseWakeDate = calendar.date(from: components) else { return proposedDate }

        if startHour < endHour {
            return proposedDate < baseWakeDate ? baseWakeDate : calendar.date(byAdding: .day, value: 1, to: baseWakeDate) ?? proposedDate
        }

        if hour >= startHour {
            return calendar.date(byAdding: .day, value: 1, to: baseWakeDate) ?? proposedDate
        }

        return baseWakeDate
    }

    private func rescheduleActiveTaskSupport() {
        guard let currentTask = todayStore.currentTask, activeTaskStartedAt != nil else { return }
        activeSensoryCue = resolvedSensoryCue(for: currentTask)
        sensoryCueController.start(activeSensoryCue)
        scheduleNotifications(for: currentTask, reminderPlan: reminderPlan(for: currentTask, dailyState: dailyState))
    }

    private func notificationTitle(for reminderPlan: ReminderPlan, reminderIndex: Int) -> String {
        if profileSettings.pdaAwareSupport {
            switch reminderPlan.profile {
            case .balanced:
                return reminderIndex == 1 ? "Time Anchor Option" : "A Next Step Is Available"
            case .repetitiveSupport:
                return "A Gentle Return Option"
            case .gentleSupport:
                return "A Soft Check-In"
            }
        }
        switch reminderPlan.profile {
        case .balanced:
            return reminderIndex == 1 ? "Time Anchor Check-In" : "Stay With The Task"
        case .repetitiveSupport:
            return "Task Return Prompt"
        case .gentleSupport:
            return "Gentle Reminder"
        }
    }

    private func notificationBody(for task: Task, reminderPlan: ReminderPlan, reminderIndex: Int) -> String {
        let supportName = profileSettings.supportName
        if profileSettings.pdaAwareSupport {
            switch reminderPlan.profile {
            case .balanced:
                if reminderIndex == 1 {
                    return "\(task.title) is available if this is a workable moment, \(supportName). The next visible step is ready."
                }
                return "If it helps, \(task.title) is still here, \(supportName). You could pick it back up with one small step."
            case .repetitiveSupport:
                return "\(task.title) is still open, \(supportName). If now works, the next step is ready without needing to do the whole thing at once."
            case .gentleSupport:
                return "If it feels workable, \(task.title) is available to come back to, \(supportName). It can stay gentle and unhurried."
            }
        }
        switch reminderPlan.profile {
        case .balanced:
            switch profileSettings.supportTone {
            case .gentle:
                if reminderIndex == 1 {
                    return "When it feels workable, come back to \(task.title), \(supportName), and take the next visible step."
                }
                return "A soft check-in for \(supportName): \(task.title) is still here when you are ready to return."
            case .steady:
                if reminderIndex == 1 {
                    return "Keep going with \(task.title), \(supportName). Return to the next visible step."
                }
                return "If you drifted, come back to \(task.title), \(supportName), and restart with one small action."
            case .direct:
                if reminderIndex == 1 {
                    return "\(supportName.capitalized), return to \(task.title) and continue the next step now."
                }
                return "\(task.title) is still active. Re-open it and keep moving."
            }
        case .repetitiveSupport:
            switch profileSettings.supportTone {
            case .gentle:
                return "\(task.title) is still the current task, \(supportName). Come back to it when you can and continue the next step."
            case .steady:
                return "\(supportName.capitalized), \(task.title) is still the current task. Open it again and continue the next step."
            case .direct:
                return "\(supportName.capitalized), return to \(task.title) now and continue the next step."
            }
        case .gentleSupport:
            switch profileSettings.supportTone {
            case .gentle:
                return "When it feels workable, ease back into \(task.title), \(supportName). There is no need to rush."
            case .steady:
                return "\(task.title) is ready when you are, \(supportName). Come back to the next step without rushing."
            case .direct:
                return "\(supportName.capitalized), \(task.title) is the next thing to return to when you are ready."
            }
        }
    }

    private func reminderPlan(for task: Task, dailyState: DailyState) -> ReminderPlan {
        guard intelligenceFeatureFlags.adaptiveReminderEnabled else {
            let fallback = conservativeReminderPlan(for: task, profile: dailyState.reminderProfile)
            appendTelemetry(kind: .reminder, title: "Reminder defaults applied", detail: "Adaptive reminders disabled by feature flag.")
            return fallback
        }
        let computedPlan = reminderOrchestrator.reminderPlan(
            for: task,
            contextDate: dayContext.date,
            dailyState: dailyState,
            profileSettings: profileSettings,
            estimatedState: estimatedState,
            recentOutcomes: selectedUserProfile?.outcomes ?? [],
            baselines: currentPersonalizedBaselines
        )
        guard !intelligenceFeatureFlags.dataQualityGatingEnabled || intelligenceDataQuality.hasSufficientSignalCoverage else {
            let fallback = conservativeReminderPlan(for: task, profile: dailyState.reminderProfile)
            appendTelemetry(kind: .reminder, title: "Reminder fallback", detail: "Insufficient signal coverage, using conservative defaults.")
            return fallback
        }
        appendTelemetry(kind: .reminder, title: "Adaptive reminder plan", detail: computedPlan.cadenceSummary)
        return computedPlan
    }

    private func conservativeReminderPlan(for task: Task, profile: ReminderProfile) -> ReminderPlan {
        switch profile {
        case .balanced:
            return ReminderPlan(
                profile: .balanced,
                leadTimeMinutes: task.startMinute == nil ? 0 : max(profileSettings.transitionPrepMinutes, 8),
                repeatIntervalMinutes: 12,
                maxRepeats: 2,
                tone: "Clear and supportive",
                escalationRule: "Using conservative defaults until enough data quality signal is available.",
                sampleCopy: "Your next task is ready when you are. Start with one small step: \(task.title)."
            )
        case .repetitiveSupport:
            return ReminderPlan(
                profile: .repetitiveSupport,
                leadTimeMinutes: task.startMinute == nil ? 0 : max(profileSettings.transitionPrepMinutes, 12),
                repeatIntervalMinutes: 7,
                maxRepeats: 3,
                tone: "Brief, repeatable, momentum-focused",
                escalationRule: "Using conservative defaults until enough data quality signal is available.",
                sampleCopy: "Time Anchor check-in: \(task.title) is next. Open it and start the first step now."
            )
        case .gentleSupport:
            return ReminderPlan(
                profile: .gentleSupport,
                leadTimeMinutes: task.startMinute == nil ? 0 : max(profileSettings.transitionPrepMinutes, 15),
                repeatIntervalMinutes: 15,
                maxRepeats: 2,
                tone: "Low-pressure and invitational",
                escalationRule: "Using conservative defaults until enough data quality signal is available.",
                sampleCopy: "A gentle reminder: \(task.title) is coming up. You can prepare when it feels doable."
            )
        }
    }

    private func gatedReplanSuggestion(_ suggestion: ReplanSuggestion?) -> ReplanSuggestion? {
        guard let suggestion else { return nil }
        guard intelligenceFeatureFlags.dataQualityGatingEnabled,
              !intelligenceDataQuality.hasSufficientSignalCoverage,
              suggestion.shouldPrompt else { return suggestion }
        return ReplanSuggestion(
            reason: suggestion.reason,
            recommendedMode: suggestion.recommendedMode,
            title: suggestion.title,
            summary: suggestion.summary,
            adjustments: suggestion.adjustments,
            shouldPrompt: false
        )
    }

    private func appendTelemetry(kind: AdaptiveDecisionTelemetry.Kind, title: String, detail: String) {
        guard intelligenceFeatureFlags.decisionTelemetryEnabled else { return }
        adaptiveDecisionTelemetry.insert(
            AdaptiveDecisionTelemetry(kind: kind, title: title, detail: detail),
            at: 0
        )
        if adaptiveDecisionTelemetry.count > 40 {
            adaptiveDecisionTelemetry.removeLast(adaptiveDecisionTelemetry.count - 40)
        }
    }
}

private final class SensoryCueController {
    private var vibrationTimer: Timer?
    private var clickingCycleTimer: Timer?
    private var clickWorkItems: [DispatchWorkItem] = []
    private let softFeedback = UIImpactFeedbackGenerator(style: .soft)
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var metronomeBuffer: AVAudioPCMBuffer?

    init() {
        configureAudio()
    }

    func start(_ cue: TaskSensoryCue?) {
        stop()

        guard let cue else { return }

        switch cue {
        case .rhythmicPulsingGlow:
            break
        case .timedVibration:
            softFeedback.prepare()
            softFeedback.impactOccurred(intensity: 0.95)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.softFeedback.impactOccurred(intensity: 0.8)
                self?.softFeedback.prepare()
            }
            vibrationTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
                self?.softFeedback.impactOccurred(intensity: 0.9)
                self?.softFeedback.prepare()
            }
        case .rhythmicClickingSound:
            playClickPattern()
            clickingCycleTimer = Timer.scheduledTimer(withTimeInterval: 2.1, repeats: true) { [weak self] _ in
                self?.playClickPattern()
            }
        }
    }

    func stop() {
        vibrationTimer?.invalidate()
        clickingCycleTimer?.invalidate()
        vibrationTimer = nil
        clickingCycleTimer = nil
        clickWorkItems.forEach { $0.cancel() }
        clickWorkItems.removeAll()
        playerNode.stop()
        audioEngine.pause()
    }

    private func playClickPattern() {
        clickWorkItems.forEach { $0.cancel() }
        clickWorkItems.removeAll()

        let offsets: [TimeInterval] = [0, 0.35, 0.7, 1.25]
        for offset in offsets {
            let workItem = DispatchWorkItem {
                self.playMetronomeClick()
            }
            clickWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + offset, execute: workItem)
        }
    }

    private func configureAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        metronomeBuffer = makeMetronomeBuffer(format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Keep cues graceful even if audio session setup is unavailable.
        }
    }

    private func playMetronomeClick() {
        guard let metronomeBuffer else { return }

        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                return
            }
        }

        if !playerNode.isPlaying {
            playerNode.play()
        }

        playerNode.scheduleBuffer(metronomeBuffer, at: nil, options: .interrupts)
    }

    private func makeMetronomeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double = 0.07
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let frequency = 1_420.0
        let amplitude: Float = 0.38
        let sampleRate = format.sampleRate

        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        for frame in 0..<Int(frameCount) {
            let progress = Double(frame) / Double(frameCount)
            let envelope = exp(-14 * progress)
            let sample = sin((2 * Double.pi * frequency * Double(frame)) / sampleRate) * envelope
            channelData[frame] = Float(sample) * amplitude
        }

        return buffer
    }
}

enum IntegrationAuthorizationState: String {
    case unavailable
    case notDetermined
    case denied
    case connected

    var title: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .notDetermined:
            return "Not Connected"
        case .denied:
            return "Permission Needed"
        case .connected:
            return "Connected"
        }
    }
}

final class IntegrationStore: ObservableObject {
    @Published var healthStatus: IntegrationAuthorizationState
    @Published var calendarStatus: IntegrationAuthorizationState
    @Published var importedHealthSignals: HealthSignals?
    @Published var allImportedEvents: [DayEvent]
    @Published var importedEvents: [DayEvent]
    @Published var calendarSourceNames: [String]
    @Published var selectedCalendarSourceNames: [String]

    init(
        healthStatus: IntegrationAuthorizationState,
        calendarStatus: IntegrationAuthorizationState,
        importedHealthSignals: HealthSignals? = nil,
        importedEvents: [DayEvent] = [],
        calendarSourceNames: [String],
        selectedCalendarSourceNames: [String] = []
    ) {
        self.healthStatus = healthStatus
        self.calendarStatus = calendarStatus
        self.importedHealthSignals = importedHealthSignals
        self.allImportedEvents = importedEvents
        self.importedEvents = importedEvents
        self.calendarSourceNames = calendarSourceNames
        self.selectedCalendarSourceNames = selectedCalendarSourceNames.isEmpty ? calendarSourceNames : selectedCalendarSourceNames
        applyCalendarSelection()
    }

    func setCalendarSources(_ sourceNames: [String]) {
        calendarSourceNames = sourceNames.sorted()
        selectedCalendarSourceNames = selectedCalendarSourceNames.filter(calendarSourceNames.contains)
        if selectedCalendarSourceNames.isEmpty {
            selectedCalendarSourceNames = calendarSourceNames
        }
        applyCalendarSelection()
    }

    func setImportedEvents(_ events: [DayEvent]) {
        allImportedEvents = events
        if selectedCalendarSourceNames.isEmpty {
            let discoveredSources = Array(Set(events.compactMap(\.sourceName))).sorted()
            selectedCalendarSourceNames = discoveredSources.isEmpty ? calendarSourceNames : discoveredSources
        }
        applyCalendarSelection()
    }

    func toggleCalendarSourceSelection(_ sourceName: String) {
        if selectedCalendarSourceNames.contains(sourceName) {
            selectedCalendarSourceNames.removeAll { $0 == sourceName }
        } else {
            selectedCalendarSourceNames.append(sourceName)
            selectedCalendarSourceNames.sort()
        }
        applyCalendarSelection()
    }

    private func applyCalendarSelection() {
        guard !selectedCalendarSourceNames.isEmpty else {
            importedEvents = []
            return
        }

        importedEvents = allImportedEvents.filter { event in
            guard let sourceName = event.sourceName else { return true }
            return selectedCalendarSourceNames.contains(sourceName)
        }
    }
}

final class AppleCalendarService {
    private let store = EKEventStore()
    private let locationProvider = CurrentLocationProvider()
    private let travelTimeEstimator = TravelTimeEstimator()

    var authorizationState: IntegrationAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .restricted, .denied, .writeOnly:
            return .denied
        case .fullAccess:
            return .connected
        @unknown default:
            return .notDetermined
        }
    }

    var availableSourceNames: [String] {
        guard authorizationState == .connected else { return [] }
        return store.calendars(for: .event)
            .map(Self.calendarDisplayName(for:))
            .sorted()
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func fetchEvents(for date: Date, daysAhead: Int = 365, selectedCalendarNames: [String]? = nil) async -> [DayEvent] {
        guard authorizationState == .connected else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: max(daysAhead, 1), to: start) else { return [] }
        let allowedCalendars = selectedCalendars(named: selectedCalendarNames)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: allowedCalendars)
        let originCoordinate = await locationProvider.currentCoordinate()

        var importedEvents: [DayEvent] = []

        for event in store.events(matching: predicate)
            .sorted(by: { $0.startDate < $1.startDate })
        {
            let dayOffset = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: event.startDate)).day ?? 0
            let startComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
            guard let hour = startComponents.hour, let minute = startComponents.minute else { continue }
            let startMinute = hour * 60 + minute
            let duration = max(Int(event.endDate.timeIntervalSince(event.startDate) / 60), 15)
            let detail = [event.calendar.title, event.notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
            let kind: DayEvent.EventKind = event.title.lowercased().contains("commute") || event.calendar.title.lowercased().contains("travel")
                ? .travel
                : .commitment
            let locationName = event.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let estimatedDriveMinutes = locationName.isEmpty ? nil : await travelTimeEstimator.estimateDriveMinutes(from: originCoordinate, to: locationName)

            importedEvents.append(
                DayEvent(
                    title: event.title,
                    dayOffset: dayOffset,
                    startMinute: startMinute,
                    durationMinutes: duration,
                    detail: detail.isEmpty ? "Imported from Calendar" : detail,
                    kind: kind,
                    sourceName: Self.calendarDisplayName(for: event.calendar),
                    externalIdentifier: event.calendarItemIdentifier,
                    supportMetadata: DayEvent.SupportMetadata(
                        planningRelevance: .fullSupport,
                        transitionPrepMinutes: kind == .travel ? 15 : 10,
                        feltDeadlineOffsetMinutes: kind == .commitment ? 20 : nil,
                        sensoryNote: "",
                        locationName: locationName,
                        estimatedDriveMinutes: estimatedDriveMinutes
                    )
                )
            )
        }

        var seenKeys: Set<String> = []
        return importedEvents.filter { event in
            let key = event.externalIdentifier
            ?? [
                event.sourceName ?? "",
                event.title.lowercased(),
                String(event.dayOffset),
                String(event.startMinute),
                String(event.durationMinutes)
            ].joined(separator: "|")

            guard !seenKeys.contains(key) else { return false }
            seenKeys.insert(key)
            return true
        }
    }

    private func selectedCalendars(named selectedCalendarNames: [String]?) -> [EKCalendar]? {
        guard let selectedCalendarNames, !selectedCalendarNames.isEmpty else { return nil }
        let calendars = store.calendars(for: .event)
        let matching = calendars.filter { selectedCalendarNames.contains(Self.calendarDisplayName(for: $0)) }
        return matching.isEmpty ? nil : matching
    }

    private static func calendarDisplayName(for calendar: EKCalendar) -> String {
        "\(calendar.source.title) • \(calendar.title)"
    }
}

final class GoogleCalendarService: NSObject {
    struct RefreshResult {
        let account: GoogleCalendarAccount
        let events: [DayEvent]
    }

    private let callbackScheme = "timeanchorgoogle"
    private var authenticationSession: ASWebAuthenticationSession?

    func connect(clientID: String) async throws -> GoogleCalendarAccount {
        let codeVerifier = Self.randomCodeVerifier()
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        let redirectURI = "\(callbackScheme):/oauth2redirect"
        let scope = "https://www.googleapis.com/auth/calendar.readonly"
        let queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = queryItems
        let authURL = components.url!
        let callbackURL = try await authorize(at: authURL)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            throw URLError(.badServerResponse)
        }

        let tokenResponse = try await exchangeCode(
            clientID: clientID,
            code: code,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI
        )
        let calendars = try await fetchCalendars(accessToken: tokenResponse.accessToken)
        return GoogleCalendarAccount(
            clientID: clientID,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            accessTokenExpiration: tokenResponse.expirationDate,
            availableCalendars: calendars,
            selectedCalendarIDs: calendars.map(\.id)
        )
    }

    func refresh(account: GoogleCalendarAccount, startingAt date: Date, daysAhead: Int) async throws -> RefreshResult {
        let validToken = try await refreshedAccountIfNeeded(account).accessToken
        let updatedAccount = try await refreshedAccountIfNeeded(account)
        let calendars = try await fetchCalendars(accessToken: validToken)
        let mergedSelection = updatedAccount.selectedCalendarIDs.filter { id in calendars.contains(where: { $0.id == id }) }
        let normalizedAccount = GoogleCalendarAccount(
            clientID: updatedAccount.clientID,
            accessToken: updatedAccount.accessToken,
            refreshToken: updatedAccount.refreshToken,
            accessTokenExpiration: updatedAccount.accessTokenExpiration,
            availableCalendars: calendars,
            selectedCalendarIDs: mergedSelection.isEmpty ? calendars.map(\.id) : mergedSelection
        )
        let selectedCalendars = calendars.filter { normalizedAccount.selectedCalendarIDs.contains($0.id) }
        let events = try await fetchEvents(
            accessToken: normalizedAccount.accessToken,
            calendars: selectedCalendars,
            startingAt: date,
            daysAhead: daysAhead
        )
        return RefreshResult(account: normalizedAccount, events: events)
    }

    private func authorize(at url: URL) async throws -> URL {
        let presentationProvider = await MainActor.run { WebAuthenticationPresentationContextProvider.shared }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? URLError(.userAuthenticationRequired))
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = presentationProvider
            self.authenticationSession = session
            if !session.start() {
                continuation.resume(throwing: URLError(.cannotLoadFromNetwork))
            }
        }
    }

    private func exchangeCode(clientID: String, code: String, codeVerifier: String, redirectURI: String) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id=\(Self.percentEncoded(clientID))",
            "code=\(Self.percentEncoded(code))",
            "code_verifier=\(Self.percentEncoded(codeVerifier))",
            "grant_type=authorization_code",
            "redirect_uri=\(Self.percentEncoded(redirectURI))"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    private func refreshedAccountIfNeeded(_ account: GoogleCalendarAccount) async throws -> GoogleCalendarAccount {
        guard let expiration = account.accessTokenExpiration, expiration <= Date().addingTimeInterval(60) else {
            return account
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id=\(Self.percentEncoded(account.clientID))",
            "refresh_token=\(Self.percentEncoded(account.refreshToken))",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let refreshed = try JSONDecoder().decode(GoogleRefreshTokenResponse.self, from: data)
        return GoogleCalendarAccount(
            clientID: account.clientID,
            accessToken: refreshed.accessToken,
            refreshToken: account.refreshToken,
            accessTokenExpiration: refreshed.expirationDate,
            availableCalendars: account.availableCalendars,
            selectedCalendarIDs: account.selectedCalendarIDs
        )
    }

    private func fetchCalendars(accessToken: String) async throws -> [GoogleCalendarDescriptor] {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
        return response.items.map {
            GoogleCalendarDescriptor(
                id: $0.id,
                title: $0.summary,
                subtitle: $0.description ?? ($0.primary == true ? "Primary calendar" : "Google Calendar")
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func fetchEvents(accessToken: String, calendars: [GoogleCalendarDescriptor], startingAt date: Date, daysAhead: Int) async throws -> [DayEvent] {
        try await withThrowingTaskGroup(of: [DayEvent].self) { group in
            for calendarDescriptor in calendars {
                group.addTask {
                    try await self.fetchEvents(
                        accessToken: accessToken,
                        calendar: calendarDescriptor,
                        startingAt: date,
                        daysAhead: daysAhead
                    )
                }
            }

            var merged: [DayEvent] = []
            for try await events in group {
                merged.append(contentsOf: events)
            }
            return merged
        }
    }

    private func fetchEvents(accessToken: String, calendar: GoogleCalendarDescriptor, startingAt date: Date, daysAhead: Int) async throws -> [DayEvent] {
        let start = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        let endDate = Calendar.current.date(byAdding: .day, value: max(daysAhead, 1), to: Calendar.current.startOfDay(for: date)) ?? date
        let end = ISO8601DateFormatter().string(from: endDate)

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(Self.percentEncoded(calendar.id))/events")!
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: start),
            URLQueryItem(name: "timeMax", value: end)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
        let startOfWindow = Calendar.current.startOfDay(for: date)

        return response.items.compactMap { item in
            guard let startDate = item.start.resolvedDate else { return nil }
            let endDate = item.end?.resolvedDate ?? startDate.addingTimeInterval(3600)
            let dayOffset = Calendar.current.dateComponents([.day], from: startOfWindow, to: Calendar.current.startOfDay(for: startDate)).day ?? 0
            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: startDate)
            let startMinute = ((startComponents.hour ?? 0) * 60) + (startComponents.minute ?? 0)
            let durationMinutes = max(Int(endDate.timeIntervalSince(startDate) / 60), item.start.date != nil ? 60 * 24 : 15)
            let detail = [calendar.title, item.description, item.location]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")

            return DayEvent(
                title: item.summary ?? "Google Calendar Event",
                dayOffset: dayOffset,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                detail: detail.isEmpty ? "Imported from Google Calendar" : detail,
                kind: .commitment,
                sourceName: "Google Calendar • \(calendar.title)",
                externalIdentifier: item.id,
                supportMetadata: DayEvent.SupportMetadata(
                    planningRelevance: .fullSupport,
                    transitionPrepMinutes: 10,
                    feltDeadlineOffsetMinutes: 20,
                    sensoryNote: "",
                    locationName: item.location ?? "",
                    estimatedDriveMinutes: nil
                )
            )
        }
    }

    private static func randomCodeVerifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).compactMap { _ in chars.randomElement() })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func percentEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}

private final class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthenticationPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct GoogleRefreshTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct GoogleCalendarListResponse: Decodable {
    struct Item: Decodable {
        let id: String
        let summary: String
        let description: String?
        let primary: Bool?
    }

    let items: [Item]
}

private struct GoogleEventsResponse: Decodable {
    struct EventDateTime: Decodable {
        let date: String?
        let dateTime: String?

        var resolvedDate: Date? {
            if let dateTime {
                return ISO8601DateFormatter().date(from: dateTime)
            }
            if let date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: date)
            }
            return nil
        }
    }

    struct Item: Decodable {
        let id: String
        let summary: String?
        let description: String?
        let location: String?
        let start: EventDateTime
        let end: EventDateTime?
    }

    let items: [Item]
}

final class ExternalCalendarFeedService {
    func fetchEvents(
        for subscriptions: [ExternalCalendarSubscription],
        startingAt date: Date,
        daysAhead: Int
    ) async -> [DayEvent] {
        await withTaskGroup(of: [DayEvent].self) { group in
            for subscription in subscriptions where subscription.isEnabled {
                group.addTask {
                    await self.fetchEvents(for: subscription, startingAt: date, daysAhead: daysAhead)
                }
            }

            var merged: [DayEvent] = []
            for await events in group {
                merged.append(contentsOf: events)
            }
            return merged.sorted {
                if $0.dayOffset == $1.dayOffset {
                    return $0.startMinute < $1.startMinute
                }
                return $0.dayOffset < $1.dayOffset
            }
        }
    }

    private func fetchEvents(
        for subscription: ExternalCalendarSubscription,
        startingAt date: Date,
        daysAhead: Int
    ) async -> [DayEvent] {
        guard let url = URL(string: subscription.feedURL) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseICS(data: data, subscription: subscription, startingAt: date, daysAhead: daysAhead)
        } catch {
            return []
        }
    }

    private func parseICS(
        data: Data,
        subscription: ExternalCalendarSubscription,
        startingAt date: Date,
        daysAhead: Int
    ) -> [DayEvent] {
        guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }

        let unfolded = raw
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
        let lines = unfolded.components(separatedBy: .newlines)
        let calendar = Calendar.current
        let startOfWindow = calendar.startOfDay(for: date)
        let endOfWindow = calendar.date(byAdding: .day, value: max(daysAhead, 1), to: startOfWindow) ?? date

        var events: [DayEvent] = []
        var currentFields: [String: String] = [:]
        var insideEvent = false

        for line in lines {
            if line == "BEGIN:VEVENT" {
                insideEvent = true
                currentFields = [:]
                continue
            }

            if line == "END:VEVENT" {
                insideEvent = false
                if let event = makeEvent(from: currentFields, subscription: subscription, startOfWindow: startOfWindow, endOfWindow: endOfWindow) {
                    events.append(event)
                }
                currentFields = [:]
                continue
            }

            guard insideEvent, let separatorIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separatorIndex])
            let value = String(line[line.index(after: separatorIndex)...])
            currentFields[key] = value
        }

        return events
    }

    private func makeEvent(
        from fields: [String: String],
        subscription: ExternalCalendarSubscription,
        startOfWindow: Date,
        endOfWindow: Date
    ) -> DayEvent? {
        let startEntry = fields.first { $0.key.hasPrefix("DTSTART") }
        let endEntry = fields.first { $0.key.hasPrefix("DTEND") }
        guard let startText = startEntry?.value,
              let startDate = parseICSDate(startText, isDateOnly: startEntry?.key.contains("VALUE=DATE") == true) else {
            return nil
        }

        let endDate = endEntry.flatMap { parseICSDate($0.value, isDateOnly: $0.key.contains("VALUE=DATE")) }
        guard startDate >= startOfWindow, startDate < endOfWindow else { return nil }

        let durationMinutes = max(Int((endDate ?? startDate.addingTimeInterval(3600)).timeIntervalSince(startDate) / 60), 15)
        let dayOffset = Calendar.current.dateComponents([.day], from: startOfWindow, to: Calendar.current.startOfDay(for: startDate)).day ?? 0
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        let startMinute = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)
        let title = decodeICSValue(fields["SUMMARY"] ?? subscription.title)
        let detail = [fields["DESCRIPTION"], fields["LOCATION"]]
            .compactMap { $0 }
            .map(decodeICSValue)
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        let externalID = fields["UID"] ?? "\(subscription.id.uuidString)-\(title)-\(dayOffset)-\(startMinute)"
        return DayEvent(
            title: title,
            dayOffset: dayOffset,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            detail: detail.isEmpty ? "Imported from \(subscription.title)" : detail,
            kind: .commitment,
            sourceName: subscription.title,
            externalIdentifier: externalID,
            supportMetadata: DayEvent.SupportMetadata(
                planningRelevance: .fullSupport,
                transitionPrepMinutes: 10,
                feltDeadlineOffsetMinutes: 20,
                sensoryNote: "",
                locationName: decodeICSValue(fields["LOCATION"] ?? ""),
                estimatedDriveMinutes: nil
            )
        )
    }

    private func parseICSDate(_ value: String, isDateOnly: Bool) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if isDateOnly {
            formatter.dateFormat = "yyyyMMdd"
            return formatter.date(from: value)
        }

        if value.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return formatter.date(from: value)
        }

        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter.date(from: value)
    }

    private func decodeICSValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
    }
}

private final class CurrentLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentCoordinate() async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let coordinate = manager.location?.coordinate {
                return coordinate
            }

            return await requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return await requestLocation()
        case .denied, .restricted:
            return nil
        @unknown default:
            return nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    private func requestLocation() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }
}

private struct TravelTimeEstimator {
    func estimateDriveMinutes(from origin: CLLocationCoordinate2D?, to destinationQuery: String) async -> Int? {
        guard let origin else { return nil }

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = destinationQuery

        let search = MKLocalSearch(request: searchRequest)
        guard let searchResponse = try? await search.start(),
              let destinationItem = searchResponse.mapItems.first else {
            return nil
        }

        let directionsRequest = MKDirections.Request()
        directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        directionsRequest.destination = destinationItem
        directionsRequest.transportType = .automobile

        guard let response = try? await MKDirections(request: directionsRequest).calculate(),
              let route = response.routes.first else {
            return nil
        }

        return max(Int((route.expectedTravelTime / 60).rounded()), 1)
    }
}

final class AppleHealthService {
    private static let authorizationRequestedKey = "TimeAnchor.healthAuthorizationRequested"
    private let store = HKHealthStore()

    private var readTypes: [HKObjectType] {
        [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .stepCount),
        ]
        .compactMap { $0 }
    }

    var authorizationState: IntegrationAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        return Self.authorizationRequested ? .connected : .notDetermined
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        do {
            try await store.requestAuthorization(toShare: [], read: Set(readTypes))
            Self.authorizationRequested = true
            return true
        } catch {
            return false
        }
    }

    func fetchSignals() async -> HealthSignals {
        async let sleepHours = fetchSleepHours()
        async let averageHeartRate = averageQuantity(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            daysBack: 1
        )
        async let recentHeartRate = recentAverageQuantity(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            minutesBack: 15
        )
        async let restingHeartRate = averageQuantity(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            daysBack: 7
        )
        async let heartRateVariability = averageQuantity(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            daysBack: 7
        )
        async let respiratoryRate = averageQuantity(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            daysBack: 7
        )
        async let hydration = cumulativeQuantity(
            for: .dietaryWater,
            unit: .liter(),
            fallbackDaysBack: 2
        )
        async let activeEnergy = cumulativeQuantity(
            for: .activeEnergyBurned,
            unit: .kilocalorie(),
            fallbackDaysBack: 2
        )
        async let exerciseMinutes = cumulativeQuantity(
            for: .appleExerciseTime,
            unit: .minute(),
            fallbackDaysBack: 2
        )
        async let stepCount = cumulativeQuantity(
            for: .stepCount,
            unit: .count(),
            fallbackDaysBack: 2
        )

        let resolvedSleepHours = await sleepHours
        let resolvedAverageHeartRate = await averageHeartRate
        let resolvedRecentHeartRate = await recentHeartRate
        let resolvedRestingHeartRate = await restingHeartRate
        let resolvedHeartRateVariability = await heartRateVariability
        let resolvedRespiratoryRate = await respiratoryRate
        let resolvedHydration = await hydration
        let resolvedActiveEnergy = await activeEnergy
        let resolvedExerciseMinutes = await exerciseMinutes
        let resolvedStepCount = await stepCount

        let sleepDebt = resolvedSleepHours.map { max(8 - $0, 0) }
        let recoveryScore = Self.recoveryScore(
            sleepHours: resolvedSleepHours,
            restingHeartRate: resolvedRestingHeartRate,
            heartRateVariabilityMilliseconds: resolvedHeartRateVariability,
            respiratoryRate: resolvedRespiratoryRate,
            hydrationLiters: resolvedHydration,
            exerciseMinutes: resolvedExerciseMinutes
        )

        return HealthSignals(
            restingHeartRate: resolvedRestingHeartRate.map(Int.init),
            averageHeartRate: resolvedAverageHeartRate.map(Int.init),
            recentHeartRate: resolvedRecentHeartRate.map(Int.init),
            heartRateVariabilityMilliseconds: resolvedHeartRateVariability,
            respiratoryRate: resolvedRespiratoryRate,
            sleepDebtHours: sleepDebt,
            recoveryScore: recoveryScore,
            hydrationLiters: resolvedHydration,
            activeEnergyKilocalories: resolvedActiveEnergy,
            exerciseMinutes: resolvedExerciseMinutes,
            stepCount: resolvedStepCount.map(Int.init),
            sleepHours: resolvedSleepHours
        )
    }

    private func averageQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = predicate(daysBack: daysBack)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func recentAverageQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, minutesBack: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let end = Date()
        let start = Calendar.current.date(byAdding: .minute, value: -minutesBack, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func cumulativeQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, fallbackDaysBack: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let todayOnlyPredicate = todayPredicate()
        let fallbackWindow = predicateWindow(daysBack: fallbackDaysBack)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: todayOnlyPredicate, options: .cumulativeSum) { [store] _, result, _ in
                let todayValue = result?.sumQuantity()?.doubleValue(for: unit)
                if let todayValue, todayValue > 0 {
                    continuation.resume(returning: todayValue)
                    return
                }

                let fallbackPredicate = HKQuery.predicateForSamples(
                    withStart: fallbackWindow.start,
                    end: fallbackWindow.end,
                    options: .strictStartDate
                )
                let fallbackQuery = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: fallbackPredicate, options: .cumulativeSum) { _, fallbackResult, _ in
                    let fallbackValue = fallbackResult?.sumQuantity()?.doubleValue(for: unit)
                    continuation.resume(returning: fallbackValue)
                }
                store.execute(fallbackQuery)
            }
            store.execute(query)
        }
    }

    private func fetchSleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .hour, value: -36, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let sleepSamples = (samples as? [HKCategorySample])?
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    .sorted { $0.startDate < $1.startDate } ?? []

                let mergedIntervals = sleepSamples.reduce(into: [(start: Date, end: Date)]()) { result, sample in
                    if let last = result.last,
                       sample.startDate <= last.end.addingTimeInterval(30 * 60) {
                        result[result.count - 1].end = max(last.end, sample.endDate)
                    } else {
                        result.append((sample.startDate, sample.endDate))
                    }
                }

                let sleepWindows = mergedIntervals
                    .map { interval in
                        (
                            start: interval.start,
                            end: interval.end,
                            hours: interval.end.timeIntervalSince(interval.start) / 3600
                        )
                    }
                    .filter { $0.hours >= 2 && $0.hours <= 14 }
                    .sorted {
                        if abs($0.end.timeIntervalSince(end)) == abs($1.end.timeIntervalSince(end)) {
                            return $0.hours > $1.hours
                        }
                        return abs($0.end.timeIntervalSince(end)) < abs($1.end.timeIntervalSince(end))
                    }

                guard let bestWindow = sleepWindows.first else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: bestWindow.hours)
            }
            store.execute(query)
        }
    }

    static func canonicalAnchorPrompt(from prompt: String) -> String {
        let supportSentences = [
            "Use this anchor to make deliberate progress without skipping transitions.",
            "Trim extras here and preserve only the work that keeps the day moving.",
            "Treat this anchor as continuity support: lower friction, narrow scope, and protect recovery.",
            "The day has needed more rebuilding lately, so keep this step especially narrow and restart-friendly.",
            "Keep support softer here so the task stays present without adding extra pressure.",
            "Give the handoff extra support here so the next switch does not turn into a scramble."
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

    private func todayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
    }

    private func predicate(daysBack: Int) -> NSPredicate {
        let window = predicateWindow(daysBack: daysBack)
        return HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)
    }

    private func predicateWindow(daysBack: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .day, value: -max(daysBack - 1, 0), to: calendar.startOfDay(for: end)) else {
            return (calendar.startOfDay(for: end), end)
        }
        return (start, end)
    }

    private static func recoveryScore(
        sleepHours: Double?,
        restingHeartRate: Double?,
        heartRateVariabilityMilliseconds: Double?,
        respiratoryRate: Double?,
        hydrationLiters: Double?,
        exerciseMinutes: Double?
    ) -> Int? {
        var score = 50.0

        if let sleepHours {
            score += min(max((sleepHours - 6) * 10, -20), 20)
        }

        if let restingHeartRate {
            score += restingHeartRate <= 62 ? 12 : (restingHeartRate <= 70 ? 4 : -8)
        }

        if let heartRateVariabilityMilliseconds {
            score += heartRateVariabilityMilliseconds >= 45 ? 12 : (heartRateVariabilityMilliseconds >= 30 ? 4 : -8)
        }

        if let respiratoryRate {
            score += respiratoryRate <= 15 ? 8 : (respiratoryRate <= 18 ? 3 : -6)
        }

        if let hydrationLiters {
            score += hydrationLiters >= 1.5 ? 10 : (hydrationLiters >= 1 ? 4 : -8)
        }

        if let exerciseMinutes {
            score += exerciseMinutes >= 20 ? 8 : (exerciseMinutes >= 10 ? 4 : 0)
        }

        return Int(min(max(score, 0), 100))
    }

    private static var authorizationRequested: Bool {
        get { UserDefaults.standard.bool(forKey: authorizationRequestedKey) }
        set { UserDefaults.standard.set(newValue, forKey: authorizationRequestedKey) }
    }
}

final class ReplanStore: ObservableObject {
    @Published var selectedReason: ReplanReason = .overloaded
    @Published var lastAppliedMode: PlanMode = .reduced
}
