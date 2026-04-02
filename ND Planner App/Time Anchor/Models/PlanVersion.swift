import Foundation

struct GoogleCalendarDescriptor: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
}

struct GoogleCalendarAccount: Hashable, Codable {
    let clientID: String
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiration: Date?
    let availableCalendars: [GoogleCalendarDescriptor]
    let selectedCalendarIDs: [String]

    var isConnected: Bool {
        !accessToken.isEmpty && !refreshToken.isEmpty
    }
}

struct ExternalCalendarSubscription: Identifiable, Hashable, Codable {
    enum Provider: String, CaseIterable, Identifiable, Hashable, Codable {
        case googleCalendar
        case skylight
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .googleCalendar:
                return "Google Calendar Feed"
            case .skylight:
                return "Skylight Feed"
            case .other:
                return "Other Calendar Feed"
            }
        }
    }

    let id: UUID
    let title: String
    let provider: Provider
    let feedURL: String
    let isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        provider: Provider,
        feedURL: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.feedURL = feedURL
        self.isEnabled = isEnabled
    }
}

struct HealthSignals: Hashable, Codable {
    let restingHeartRate: Int?
    let averageHeartRate: Int?
    let recentHeartRate: Int?
    let heartRateVariabilityMilliseconds: Double?
    let respiratoryRate: Double?
    let sleepDebtHours: Double?
    let recoveryScore: Int?
    let hydrationLiters: Double?
    let activeEnergyKilocalories: Double?
    let exerciseMinutes: Double?
    let stepCount: Int?
    let sleepHours: Double?

    init(
        restingHeartRate: Int?,
        averageHeartRate: Int?,
        recentHeartRate: Int? = nil,
        heartRateVariabilityMilliseconds: Double?,
        respiratoryRate: Double?,
        sleepDebtHours: Double?,
        recoveryScore: Int?,
        hydrationLiters: Double?,
        activeEnergyKilocalories: Double?,
        exerciseMinutes: Double?,
        stepCount: Int?,
        sleepHours: Double?
    ) {
        self.restingHeartRate = restingHeartRate
        self.averageHeartRate = averageHeartRate
        self.recentHeartRate = recentHeartRate
        self.heartRateVariabilityMilliseconds = heartRateVariabilityMilliseconds
        self.respiratoryRate = respiratoryRate
        self.sleepDebtHours = sleepDebtHours
        self.recoveryScore = recoveryScore
        self.hydrationLiters = hydrationLiters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.stepCount = stepCount
        self.sleepHours = sleepHours
    }

    static let baseline = HealthSignals(
        restingHeartRate: nil,
        averageHeartRate: nil,
        recentHeartRate: nil,
        heartRateVariabilityMilliseconds: nil,
        respiratoryRate: nil,
        sleepDebtHours: nil,
        recoveryScore: nil,
        hydrationLiters: nil,
        activeEnergyKilocalories: nil,
        exerciseMinutes: nil,
        stepCount: nil,
        sleepHours: nil
    )

    var hasAnyData: Bool {
        restingHeartRate != nil
        || averageHeartRate != nil
        || recentHeartRate != nil
        || heartRateVariabilityMilliseconds != nil
        || respiratoryRate != nil
        || sleepDebtHours != nil
        || recoveryScore != nil
        || hydrationLiters != nil
        || activeEnergyKilocalories != nil
        || exerciseMinutes != nil
        || stepCount != nil
        || sleepHours != nil
    }
}

struct DayEvent: Identifiable, Hashable, Codable {
    struct SupportMetadata: Hashable, Codable {
        enum PlanningRelevance: String, CaseIterable, Identifiable, Hashable, Codable {
            case fullSupport
            case lightweightReminder
            case ignoreForPlanning

            var id: String { rawValue }

            var title: String {
                switch self {
                case .fullSupport:
                    return "Full Schedule Support"
                case .lightweightReminder:
                    return "Lightweight Reminder"
                case .ignoreForPlanning:
                    return "Ignore For Planning"
                }
            }

            var summary: String {
                switch self {
                case .fullSupport:
                    return "Use prep, leave-by, and full transition support."
                case .lightweightReminder:
                    return "Keep the event visible, but do not build extra transition scaffolding around it."
                case .ignoreForPlanning:
                    return "Do not let this event shape the day plan."
                }
            }
        }

        let planningRelevance: PlanningRelevance
        let transitionPrepMinutes: Int
        let feltDeadlineOffsetMinutes: Int?
        let sensoryNote: String
        let locationName: String
        let estimatedDriveMinutes: Int?

        static let `default` = SupportMetadata(
            planningRelevance: .fullSupport,
            transitionPrepMinutes: 0,
            feltDeadlineOffsetMinutes: nil,
            sensoryNote: "",
            locationName: "",
            estimatedDriveMinutes: nil
        )
    }

    enum EventKind: String, Codable {
        case commitment
        case travel
        case recovery
    }

    enum FamilyMember: String, CaseIterable, Identifiable, Codable {
        case me
        case alex
        case mary
        case ella

        var id: String { rawValue }

        var title: String {
            switch self {
            case .me:
                return "Me"
            case .alex:
                return "Alex"
            case .mary:
                return "Mary"
            case .ella:
                return "Ella"
            }
        }
    }

    enum RepeatRule: String, CaseIterable, Identifiable, Codable {
        case none
        case daily
        case weekdays
        case weekly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none:
                return "Does not repeat"
            case .daily:
                return "Daily"
            case .weekdays:
                return "Weekdays"
            case .weekly:
                return "Weekly"
            }
        }
    }

    let id: UUID
    let title: String
    let dayOffset: Int
    let startMinute: Int
    let durationMinutes: Int
    let detail: String
    let kind: EventKind
    let familyMember: FamilyMember
    let repeatRule: RepeatRule
    let sensoryLevel: Int
    let sourceName: String?
    let externalIdentifier: String?
    let supportMetadata: SupportMetadata

    init(
        id: UUID = UUID(),
        title: String,
        dayOffset: Int = 0,
        startMinute: Int,
        durationMinutes: Int,
        detail: String,
        kind: EventKind = .commitment,
        familyMember: FamilyMember = .me,
        repeatRule: RepeatRule = .none,
        sensoryLevel: Int = 3,
        sourceName: String? = nil,
        externalIdentifier: String? = nil,
        supportMetadata: SupportMetadata = .default
    ) {
        self.id = id
        self.title = title
        self.dayOffset = dayOffset
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.detail = detail
        self.kind = kind
        self.familyMember = familyMember
        self.repeatRule = repeatRule
        self.sensoryLevel = sensoryLevel
        self.sourceName = sourceName
        self.externalIdentifier = externalIdentifier
        self.supportMetadata = supportMetadata
    }

    var endMinute: Int {
        startMinute + durationMinutes
    }

    var supportKey: String {
        externalIdentifier ?? id.uuidString
    }

    var shouldAppearInPlanning: Bool {
        supportMetadata.planningRelevance != .ignoreForPlanning
    }

    var shouldGenerateTransitionSupport: Bool {
        supportMetadata.planningRelevance == .fullSupport
    }

    var isLikelyHoliday: Bool {
        let normalizedTitle = title.lowercased()
        let normalizedSource = (sourceName ?? "").lowercased()
        let normalizedDetail = detail.lowercased()

        let commonHolidayTitles = [
            "new year's day",
            "martin luther king jr. day",
            "presidents' day",
            "memorial day",
            "juneteenth",
            "independence day",
            "labor day",
            "columbus day",
            "veterans day",
            "thanksgiving",
            "christmas",
            "christmas day",
            "new year's eve",
            "tax day"
        ]

        return normalizedSource.contains("holiday")
            || normalizedDetail.contains("holiday")
            || commonHolidayTitles.contains(where: { normalizedTitle == $0 || normalizedTitle.contains($0) })
    }

    var leaveByMinute: Int? {
        guard let estimatedDriveMinutes = supportMetadata.estimatedDriveMinutes, estimatedDriveMinutes > 0 else { return nil }
        return max(startMinute - estimatedDriveMinutes, 0)
    }

    var prepStartMinute: Int {
        let prepEnd = leaveByMinute ?? startMinute
        return max(prepEnd - supportMetadata.transitionPrepMinutes, 0)
    }

    func applyingSupportMetadata(_ supportMetadata: SupportMetadata) -> DayEvent {
        DayEvent(
            id: id,
            title: title,
            dayOffset: dayOffset,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            detail: detail,
            kind: kind,
            familyMember: familyMember,
            repeatRule: repeatRule,
            sensoryLevel: sensoryLevel,
            sourceName: sourceName,
            externalIdentifier: externalIdentifier,
            supportMetadata: supportMetadata
        )
    }
}

struct DayContext: Hashable, Codable {
    let date: Date
    let planningDayOffset: Int
    let dailyState: DailyState
    let events: [DayEvent]
    let routines: [Routine]
    let projects: [Project]
    let healthSignals: HealthSignals
}

enum CueStyle: String, Hashable, Codable {
    case calm
    case supportive
    case alert
}

struct ScheduleCue: Hashable, Codable {
    let title: String
    let detail: String
    let style: CueStyle
}

struct ScheduleBlock: Identifiable, Hashable, Codable {
    enum BlockKind: String, Hashable, Codable {
        case routine
        case anchor
        case project
        case transition
        case event
        case buffer
        case recovery
    }

    let id: UUID
    let kind: BlockKind
    let title: String
    let detail: String
    let startMinute: Int
    let endMinute: Int
    let anchorID: UUID?
    let cue: ScheduleCue

    init(
        id: UUID = UUID(),
        kind: BlockKind,
        title: String,
        detail: String,
        startMinute: Int,
        endMinute: Int,
        anchorID: UUID? = nil,
        cue: ScheduleCue
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.anchorID = anchorID
        self.cue = cue
    }

    var durationMinutes: Int {
        max(endMinute - startMinute, 0)
    }

    var timeRangeText: String {
        "\(Self.clockString(for: startMinute)) - \(Self.clockString(for: endMinute))"
    }

    var kindLabel: String {
        switch kind {
        case .routine:
            return "Routine"
        case .anchor:
            return "Task Block"
        case .project:
            return "Project Block"
        case .transition:
            return "Transition"
        case .event:
            return "Event"
        case .buffer:
            return "Buffer"
        case .recovery:
            return "Recovery"
        }
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

struct DailyPlan: Hashable, Codable {
    let blocks: [ScheduleBlock]
    let supportSummary: String

    var actionableBlocks: [ScheduleBlock] {
        blocks.filter { $0.kind != .buffer }
    }
}

struct PlanVersion: Identifiable, Hashable, Codable {
    let id: UUID
    let mode: PlanMode
    let context: DayContext
    let anchors: [Anchor]
    let dailyPlan: DailyPlan
    let whatMattersNow: String
    let modeSummary: String

    init(
        id: UUID = UUID(),
        mode: PlanMode,
        context: DayContext,
        anchors: [Anchor],
        dailyPlan: DailyPlan,
        whatMattersNow: String,
        modeSummary: String
    ) {
        self.id = id
        self.mode = mode
        self.context = context
        self.anchors = anchors
        self.dailyPlan = dailyPlan
        self.whatMattersNow = whatMattersNow
        self.modeSummary = modeSummary
    }

    func updating(
        context: DayContext? = nil,
        anchors: [Anchor],
        dailyPlan: DailyPlan? = nil,
        whatMattersNow: String? = nil,
        modeSummary: String? = nil
    ) -> PlanVersion {
        PlanVersion(
            id: id,
            mode: mode,
            context: context ?? self.context,
            anchors: anchors,
            dailyPlan: dailyPlan ?? self.dailyPlan,
            whatMattersNow: whatMattersNow ?? self.whatMattersNow,
            modeSummary: modeSummary ?? self.modeSummary
        )
    }
}
