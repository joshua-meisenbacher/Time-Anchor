import Foundation

enum ReminderProfile: String, CaseIterable, Identifiable, Hashable, Codable {
    case balanced
    case repetitiveSupport
    case gentleSupport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .repetitiveSupport:
            return "Repetitive Support"
        case .gentleSupport:
            return "Gentle Support"
        }
    }

    var summary: String {
        switch self {
        case .balanced:
            return "Uses a moderate reminder rhythm with room to adjust up or down."
        case .repetitiveSupport:
            return "Uses more repeated prompts for users who benefit from stronger task-return support."
        case .gentleSupport:
            return "Uses softer reminders with more space between prompts to reduce pressure."
        }
    }
}

enum SupportPreset: String, CaseIterable, Identifiable, Hashable, Codable {
    case balanced
    case adhdSupport
    case asdSupport
    case simplePlanning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            return "Balanced Support"
        case .adhdSupport:
            return "ADHD Support"
        case .asdSupport:
            return "ASD Support"
        case .simplePlanning:
            return "Simple Planning"
        }
    }

    var summary: String {
        switch self {
        case .balanced:
            return "Keeps support visible without pushing too hard in any one direction."
        case .adhdSupport:
            return "Prioritizes immediacy, stronger task-return support, and clearer urgency."
        case .asdSupport:
            return "Prioritizes predictability, gentler transitions, and lower ambiguity."
        case .simplePlanning:
            return "Keeps the planner lighter and less intervention-heavy."
        }
    }
}

enum CommunicationStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    case supportive
    case literal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .supportive:
            return "Supportive"
        case .literal:
            return "Literal"
        }
    }

    var summary: String {
        switch self {
        case .supportive:
            return "Uses warmer, more encouraging phrasing."
        case .literal:
            return "Uses direct, explicit wording with less interpretation."
        }
    }
}

enum VisualSupportMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case standard
    case lowerStimulation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .lowerStimulation:
            return "Lower Stimulation"
        }
    }

    var summary: String {
        switch self {
        case .standard:
            return "Uses the normal visual emphasis and motion."
        case .lowerStimulation:
            return "Reduces motion and visual intensity so the interface feels calmer."
        }
    }
}

struct ReminderPlan: Hashable, Codable {
    let profile: ReminderProfile
    let leadTimeMinutes: Int
    let repeatIntervalMinutes: Int?
    let maxRepeats: Int
    let tone: String
    let escalationRule: String
    let sampleCopy: String

    var cadenceSummary: String {
        if let repeatIntervalMinutes {
            return "Starts \(leadTimeMinutes) min before, then repeats every \(repeatIntervalMinutes) min up to \(maxRepeats) times."
        }
        return "Starts \(leadTimeMinutes) min before with a single follow-up if needed."
    }
}

enum UserRole: String, CaseIterable, Identifiable, Hashable, Codable {
    case selfPlanner
    case caregiver
    case familyCoordinator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfPlanner:
            return "Planning For Myself"
        case .caregiver:
            return "Caregiver Support"
        case .familyCoordinator:
            return "Family Coordination"
        }
    }

    var summary: String {
        switch self {
        case .selfPlanner:
            return "Keeps the app centered on personal routines, tasks, and direct support."
        case .caregiver:
            return "Frames planning around helping another person move through the day."
        case .familyCoordinator:
            return "Supports managing routines and events across more than one person."
        }
    }
}

enum SupportFocus: String, CaseIterable, Identifiable, Hashable, Codable {
    case timeBlindness
    case transitions
    case stayingOnTask
    case routines
    case recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeBlindness:
            return "Time Blindness"
        case .transitions:
            return "Transitions"
        case .stayingOnTask:
            return "Staying On Task"
        case .routines:
            return "Routines"
        case .recovery:
            return "Recovery"
        }
    }
}

enum SupportTone: String, CaseIterable, Identifiable, Hashable, Codable {
    case gentle
    case steady
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle:
            return "Gentle"
        case .steady:
            return "Steady"
        case .direct:
            return "Direct"
        }
    }

    var summary: String {
        switch self {
        case .gentle:
            return "Uses soft, invitational wording with less pressure."
        case .steady:
            return "Uses calm, practical prompts that stay predictable."
        case .direct:
            return "Uses clearer, more pointed task-return prompts."
        }
    }
}

enum Neurotype: String, CaseIterable, Identifiable, Hashable, Codable {
    case adhd
    case asd
    case audhd
    case neurotypical
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adhd:
            return "ADHD"
        case .asd:
            return "ASD"
        case .audhd:
            return "AuDHD"
        case .neurotypical:
            return "Neurotypical"
        case .other:
            return "Other / Prefer Not To Say"
        }
    }
}

struct ProfileSettings: Equatable, Hashable, Codable {
    var displayName: String
    var neurotype: Neurotype
    var pdaAwareSupport: Bool
    var includeHolidayEvents: Bool
    var supportPreset: SupportPreset
    var userRole: UserRole
    var primarySupportFocus: SupportFocus
    var additionalSupportFocuses: [SupportFocus]
    var supportTone: SupportTone
    var communicationStyle: CommunicationStyle
    var visualSupportMode: VisualSupportMode
    var transitionPrepMinutes: Int
    var reminderProfile: ReminderProfile
    var defaultSensoryCue: TaskSensoryCue?
    var quietHoursEnabled: Bool
    var quietHoursStartHour: Int
    var quietHoursEndHour: Int

    init(
        displayName: String = "",
        neurotype: Neurotype = .adhd,
        pdaAwareSupport: Bool = false,
        includeHolidayEvents: Bool = false,
        supportPreset: SupportPreset = .balanced,
        userRole: UserRole = .selfPlanner,
        primarySupportFocus: SupportFocus = .transitions,
        additionalSupportFocuses: [SupportFocus] = [],
        supportTone: SupportTone = .steady,
        communicationStyle: CommunicationStyle = .supportive,
        visualSupportMode: VisualSupportMode = .standard,
        transitionPrepMinutes: Int = 10,
        reminderProfile: ReminderProfile = .balanced,
        defaultSensoryCue: TaskSensoryCue? = nil,
        quietHoursEnabled: Bool = false,
        quietHoursStartHour: Int = 21,
        quietHoursEndHour: Int = 8
    ) {
        self.displayName = displayName
        self.neurotype = neurotype
        self.pdaAwareSupport = pdaAwareSupport
        self.includeHolidayEvents = includeHolidayEvents
        self.supportPreset = supportPreset
        self.userRole = userRole
        self.primarySupportFocus = primarySupportFocus
        self.additionalSupportFocuses = additionalSupportFocuses
        self.supportTone = supportTone
        self.communicationStyle = communicationStyle
        self.visualSupportMode = visualSupportMode
        self.transitionPrepMinutes = transitionPrepMinutes
        self.reminderProfile = reminderProfile
        self.defaultSensoryCue = defaultSensoryCue
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursEndHour = quietHoursEndHour
    }

    var supportName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "you" : trimmed
    }

    var profileSummary: String {
        let focusSummary: String
        if additionalSupportFocuses.isEmpty {
            focusSummary = primarySupportFocus.title.lowercased()
        } else {
            let extras = additionalSupportFocuses.map { $0.title.lowercased() }.joined(separator: ", ")
            focusSummary = "\(primarySupportFocus.title.lowercased()) with extra support around \(extras)"
        }
        return "\(supportPreset.title) for \(userRole.title.lowercased()) with primary support around \(focusSummary), a \(neurotype.title) profile, \(pdaAwareSupport ? "PDA-aware wording enabled" : "standard support wording"), and \(includeHolidayEvents ? "holiday reminders included" : "holiday reminders reduced")."
    }

    var quietHoursSummary: String {
        guard quietHoursEnabled else { return "Notifications can arrive at any time while a task is active." }
        return "Quiet hours run from \(Self.hourLabel(for: quietHoursStartHour)) to \(Self.hourLabel(for: quietHoursEndHour)). Task reminders wait until that window ends."
    }

    private static func hourLabel(for hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        let suffix = normalized >= 12 ? "PM" : "AM"
        let hour12 = normalized == 0 ? 12 : (normalized > 12 ? normalized - 12 : normalized)
        return "\(hour12):00 \(suffix)"
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case neurotype
        case pdaAwareSupport
        case includeHolidayEvents
        case supportPreset
        case userRole
        case primarySupportFocus
        case additionalSupportFocuses
        case supportTone
        case communicationStyle
        case visualSupportMode
        case transitionPrepMinutes
        case reminderProfile
        case defaultSensoryCue
        case quietHoursEnabled
        case quietHoursStartHour
        case quietHoursEndHour
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        neurotype = try container.decodeIfPresent(Neurotype.self, forKey: .neurotype) ?? .adhd
        pdaAwareSupport = try container.decodeIfPresent(Bool.self, forKey: .pdaAwareSupport) ?? false
        includeHolidayEvents = try container.decodeIfPresent(Bool.self, forKey: .includeHolidayEvents) ?? false
        supportPreset = try container.decodeIfPresent(SupportPreset.self, forKey: .supportPreset) ?? .balanced
        userRole = try container.decodeIfPresent(UserRole.self, forKey: .userRole) ?? .selfPlanner
        primarySupportFocus = try container.decodeIfPresent(SupportFocus.self, forKey: .primarySupportFocus) ?? .transitions
        additionalSupportFocuses = try container.decodeIfPresent([SupportFocus].self, forKey: .additionalSupportFocuses) ?? []
        supportTone = try container.decodeIfPresent(SupportTone.self, forKey: .supportTone) ?? .steady
        communicationStyle = try container.decodeIfPresent(CommunicationStyle.self, forKey: .communicationStyle) ?? .supportive
        visualSupportMode = try container.decodeIfPresent(VisualSupportMode.self, forKey: .visualSupportMode) ?? .standard
        transitionPrepMinutes = try container.decodeIfPresent(Int.self, forKey: .transitionPrepMinutes) ?? 10
        reminderProfile = try container.decodeIfPresent(ReminderProfile.self, forKey: .reminderProfile) ?? .balanced
        defaultSensoryCue = try container.decodeIfPresent(TaskSensoryCue.self, forKey: .defaultSensoryCue)
        quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietHoursStartHour = try container.decodeIfPresent(Int.self, forKey: .quietHoursStartHour) ?? 21
        quietHoursEndHour = try container.decodeIfPresent(Int.self, forKey: .quietHoursEndHour) ?? 8
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(neurotype, forKey: .neurotype)
        try container.encode(pdaAwareSupport, forKey: .pdaAwareSupport)
        try container.encode(includeHolidayEvents, forKey: .includeHolidayEvents)
        try container.encode(supportPreset, forKey: .supportPreset)
        try container.encode(userRole, forKey: .userRole)
        try container.encode(primarySupportFocus, forKey: .primarySupportFocus)
        try container.encode(additionalSupportFocuses, forKey: .additionalSupportFocuses)
        try container.encode(supportTone, forKey: .supportTone)
        try container.encode(communicationStyle, forKey: .communicationStyle)
        try container.encode(visualSupportMode, forKey: .visualSupportMode)
        try container.encode(transitionPrepMinutes, forKey: .transitionPrepMinutes)
        try container.encode(reminderProfile, forKey: .reminderProfile)
        try container.encodeIfPresent(defaultSensoryCue, forKey: .defaultSensoryCue)
        try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
        try container.encode(quietHoursStartHour, forKey: .quietHoursStartHour)
        try container.encode(quietHoursEndHour, forKey: .quietHoursEndHour)
    }
}

struct UserProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var displayName: String
    var settings: ProfileSettings
    var dailyState: DailyState
    var selectedScenarioID: UUID?
    var anchors: [Anchor]
    var routines: [Routine]
    var projects: [Project]
    var goals: [Goal]
    var customEvents: [DayEvent]
    var googleCalendarAccount: GoogleCalendarAccount?
    var externalCalendarSubscriptions: [ExternalCalendarSubscription]
    var outcomes: [DayOutcome]
    var healthSnapshots: [DailyHealthSnapshot]

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case settings
        case dailyState
        case selectedScenarioID
        case anchors
        case routines
        case projects
        case goals
        case customEvents
        case googleCalendarAccount
        case externalCalendarSubscriptions
        case outcomes
        case healthSnapshots
    }

    init(
        id: UUID = UUID(),
        displayName: String = "",
        settings: ProfileSettings,
        dailyState: DailyState,
        selectedScenarioID: UUID? = nil,
        anchors: [Anchor] = [],
        routines: [Routine] = [],
        projects: [Project] = [],
        goals: [Goal] = [],
        customEvents: [DayEvent] = [],
        googleCalendarAccount: GoogleCalendarAccount? = nil,
        externalCalendarSubscriptions: [ExternalCalendarSubscription] = [],
        outcomes: [DayOutcome] = [],
        healthSnapshots: [DailyHealthSnapshot] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.settings = settings
        self.dailyState = dailyState
        self.selectedScenarioID = selectedScenarioID
        self.anchors = anchors
        self.routines = routines
        self.projects = projects
        self.goals = goals
        self.customEvents = customEvents
        self.googleCalendarAccount = googleCalendarAccount
        self.externalCalendarSubscriptions = externalCalendarSubscriptions
        self.outcomes = outcomes
        self.healthSnapshots = healthSnapshots
    }

    var title: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Profile" : trimmed
    }

    var summary: String {
        "\(settings.userRole.title) • \(settings.primarySupportFocus.title)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        settings = try container.decode(ProfileSettings.self, forKey: .settings)
        dailyState = try container.decode(DailyState.self, forKey: .dailyState)
        selectedScenarioID = try container.decodeIfPresent(UUID.self, forKey: .selectedScenarioID)
        anchors = try container.decodeIfPresent([Anchor].self, forKey: .anchors) ?? []
        routines = try container.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        customEvents = try container.decodeIfPresent([DayEvent].self, forKey: .customEvents) ?? []
        googleCalendarAccount = try container.decodeIfPresent(GoogleCalendarAccount.self, forKey: .googleCalendarAccount)
        externalCalendarSubscriptions = try container.decodeIfPresent([ExternalCalendarSubscription].self, forKey: .externalCalendarSubscriptions) ?? []
        outcomes = try container.decodeIfPresent([DayOutcome].self, forKey: .outcomes) ?? []
        healthSnapshots = try container.decodeIfPresent([DailyHealthSnapshot].self, forKey: .healthSnapshots) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(settings, forKey: .settings)
        try container.encode(dailyState, forKey: .dailyState)
        try container.encodeIfPresent(selectedScenarioID, forKey: .selectedScenarioID)
        try container.encode(anchors, forKey: .anchors)
        try container.encode(routines, forKey: .routines)
        try container.encode(projects, forKey: .projects)
        try container.encode(goals, forKey: .goals)
        try container.encode(customEvents, forKey: .customEvents)
        try container.encodeIfPresent(googleCalendarAccount, forKey: .googleCalendarAccount)
        try container.encode(externalCalendarSubscriptions, forKey: .externalCalendarSubscriptions)
        try container.encode(outcomes, forKey: .outcomes)
        try container.encode(healthSnapshots, forKey: .healthSnapshots)
    }
}

struct DailyState: Equatable, Hashable, Codable {
    var energy: Int
    var stress: Int
    var sleepHours: Double
    var sensoryLoad: Int
    var transitionFriction: Int
    var priority: String
    var reminderProfile: ReminderProfile

    init(
        energy: Int,
        stress: Int,
        sleepHours: Double,
        sensoryLoad: Int = 3,
        transitionFriction: Int = 3,
        priority: String,
        reminderProfile: ReminderProfile = .balanced
    ) {
        self.energy = energy
        self.stress = stress
        self.sleepHours = sleepHours
        self.sensoryLoad = sensoryLoad
        self.transitionFriction = transitionFriction
        self.priority = priority
        self.reminderProfile = reminderProfile
    }

    static let empty = DailyState(
        energy: 3,
        stress: 3,
        sleepHours: 7.0,
        sensoryLoad: 3,
        transitionFriction: 3,
        priority: "",
        reminderProfile: .balanced
    )
}
