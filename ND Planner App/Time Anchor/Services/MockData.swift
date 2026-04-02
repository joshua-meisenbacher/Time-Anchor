import Foundation

struct MockScenario: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let dailyState: DailyState
    let anchors: [Anchor]
    let events: [DayEvent]
    let healthSignals: HealthSignals

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        dailyState: DailyState,
        events: [DayEvent] = [],
        healthSignals: HealthSignals = .baseline,
        anchors: [Anchor]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.dailyState = dailyState
        self.anchors = anchors
        self.events = events
        self.healthSignals = healthSignals
    }
}

struct DemoStory: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let profileName: String
    let personaSummary: String
    let challenge: String
    let appSupportSummary: String
    let walkthroughMoments: [String]
    let scenario: MockScenario
    let userRole: UserRole
    let neurotype: Neurotype
    let pdaAwareSupport: Bool
    let supportPreset: SupportPreset
    let primarySupportFocus: SupportFocus
    let additionalSupportFocuses: [SupportFocus]
    let supportTone: SupportTone
    let communicationStyle: CommunicationStyle
    let visualSupportMode: VisualSupportMode
    let transitionPrepMinutes: Int
    let reminderProfile: ReminderProfile

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        profileName: String,
        personaSummary: String,
        challenge: String,
        appSupportSummary: String,
        walkthroughMoments: [String],
        scenario: MockScenario,
        userRole: UserRole,
        neurotype: Neurotype,
        pdaAwareSupport: Bool,
        supportPreset: SupportPreset,
        primarySupportFocus: SupportFocus,
        additionalSupportFocuses: [SupportFocus] = [],
        supportTone: SupportTone,
        communicationStyle: CommunicationStyle,
        visualSupportMode: VisualSupportMode,
        transitionPrepMinutes: Int,
        reminderProfile: ReminderProfile
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.profileName = profileName
        self.personaSummary = personaSummary
        self.challenge = challenge
        self.appSupportSummary = appSupportSummary
        self.walkthroughMoments = walkthroughMoments
        self.scenario = scenario
        self.userRole = userRole
        self.neurotype = neurotype
        self.pdaAwareSupport = pdaAwareSupport
        self.supportPreset = supportPreset
        self.primarySupportFocus = primarySupportFocus
        self.additionalSupportFocuses = additionalSupportFocuses
        self.supportTone = supportTone
        self.communicationStyle = communicationStyle
        self.visualSupportMode = visualSupportMode
        self.transitionPrepMinutes = transitionPrepMinutes
        self.reminderProfile = reminderProfile
    }

    var profileSettings: ProfileSettings {
        ProfileSettings(
            displayName: profileName,
            neurotype: neurotype,
            pdaAwareSupport: pdaAwareSupport,
            includeHolidayEvents: false,
            supportPreset: supportPreset,
            userRole: userRole,
            primarySupportFocus: primarySupportFocus,
            additionalSupportFocuses: additionalSupportFocuses,
            supportTone: supportTone,
            communicationStyle: communicationStyle,
            visualSupportMode: visualSupportMode,
            transitionPrepMinutes: transitionPrepMinutes,
            reminderProfile: reminderProfile
        )
    }
}

enum MockData {
    static let sampleAnchors: [Anchor] = openHighCapacityDay.anchors

    static let sampleDailyState = openHighCapacityDay.dailyState

    static let routines: [Routine] = [
        Routine(
            title: "Morning Routine",
            timeWindow: "Before 9:00 AM",
            summary: "A calm launch that reduces rushed transitions.",
            steps: [
                RoutineStep(title: "Drink water", cue: "Start with one grounding action before checking anything else.", estimatedMinutes: 2, isCompleted: true),
                RoutineStep(title: "Take medicine", cue: "Handle medication before the rest of the morning starts to compete.", estimatedMinutes: 2),
                RoutineStep(title: "Brush teeth", cue: "Finish one basic care step before moving on.", estimatedMinutes: 3),
                RoutineStep(title: "Get dressed", cue: "Lay out one simple outfit and keep moving.", estimatedMinutes: 5),
                RoutineStep(title: "Eat breakfast", cue: "Give yourself fuel before the first demand of the day.", estimatedMinutes: 10),
                RoutineStep(title: "Check first task", cue: "Look at the first task or event so the morning direction is clear.", estimatedMinutes: 3),
                RoutineStep(title: "Pack essentials", cue: "Reduce friction for leaving later.", estimatedMinutes: 5)
            ],
            isPinned: true
        ),
        Routine(
            title: "Study Launch",
            timeWindow: "Before focus blocks",
            summary: "Shrink the barrier to getting started.",
            steps: [
                RoutineStep(title: "Clear desk", cue: "Remove one distraction, not everything.", estimatedMinutes: 3),
                RoutineStep(title: "Open only the needed tabs", cue: "Keep the task boundary narrow.", estimatedMinutes: 4),
                RoutineStep(title: "Write the first tiny step", cue: "Starting matters more than maximizing.", estimatedMinutes: 2)
            ]
        ),
        Routine(
            title: "Evening Reset",
            timeWindow: "After the last major task",
            summary: "Close the day gently so tomorrow starts lighter.",
            steps: [
                RoutineStep(title: "Write tomorrow's first step", cue: "Give future-you a softer landing.", estimatedMinutes: 3),
                RoutineStep(title: "Put devices on charge", cue: "Reduce morning friction.", estimatedMinutes: 2),
                RoutineStep(title: "Choose one recovery activity", cue: "Make decompression intentional.", estimatedMinutes: 5)
            ],
            isPinned: true
        )
    ]

    static let scenarios: [MockScenario] = [
        openHighCapacityDay,
        lowCapacityDay,
        overloadedDay,
        splitShiftWorkday,
        schoolAndWorkDay,
        recoveryDay
    ]

    static let demoStories: [DemoStory] = [
        DemoStory(
            title: "Student Between Class and Work",
            subtitle: "Show how the app narrows focus when school and a shift compete for the same day.",
            profileName: "Jordan Carter",
            personaSummary: "A college student balancing assignments, class, and an afternoon work shift.",
            challenge: "Jordan tends to lose the best study window by bouncing between school prep and work anxiety.",
            appSupportSummary: "Time Anchor protects the morning study block, makes the work transition explicit, and lowers the pressure to keep doing school tasks right before the shift.",
            walkthroughMoments: [
                "Start in Check-In to frame the day around the reading response instead of the entire backlog.",
                "Switch to Today to show the protected study block before the commute.",
                "Call out how the work transition anchor prevents context bleed between school and the shift."
            ],
            scenario: schoolAndWorkDay,
            userRole: .selfPlanner,
            neurotype: .adhd,
            pdaAwareSupport: false,
            supportPreset: .adhdSupport,
            primarySupportFocus: .stayingOnTask,
            additionalSupportFocuses: [.timeBlindness],
            supportTone: .direct,
            communicationStyle: .literal,
            visualSupportMode: .standard,
            transitionPrepMinutes: 10,
            reminderProfile: .repetitiveSupport
        ),
        DemoStory(
            title: "Family Coordinator in Overload",
            subtitle: "Show how the app helps someone hold onto essentials when the day becomes crowded.",
            profileName: "Sara Anderson",
            personaSummary: "A family coordinator juggling deadlines, meetings, and the emotional load of keeping things moving for other people.",
            challenge: "Sara's day gets loud fast, so every request feels urgent and the true priorities disappear.",
            appSupportSummary: "Time Anchor turns the day into a sequence of anchors, surfaces the heaviest commitment first, and makes recovery and shutdown visible before burnout spills into tomorrow.",
            walkthroughMoments: [
                "Load the story and open Today to show the morning triage anchor.",
                "Point to the fixed events that add pressure without taking over the whole plan.",
                "End on the evening shutdown to show the app supporting recovery, not just productivity."
            ],
            scenario: overloadedDay,
            userRole: .familyCoordinator,
            neurotype: .audhd,
            pdaAwareSupport: true,
            supportPreset: .balanced,
            primarySupportFocus: .transitions,
            additionalSupportFocuses: [.recovery],
            supportTone: .steady,
            communicationStyle: .supportive,
            visualSupportMode: .lowerStimulation,
            transitionPrepMinutes: 20,
            reminderProfile: .gentleSupport
        ),
        DemoStory(
            title: "Recovery Without Losing the Thread",
            subtitle: "Show that the app can support a softer day instead of pushing constant output.",
            profileName: "Alex Rivera",
            personaSummary: "An adult trying to recover after an intense stretch without letting important life admin vanish entirely.",
            challenge: "Alex needs permission to reduce load, but still wants enough structure to avoid the day dissolving.",
            appSupportSummary: "Time Anchor reframes success around regulation, protects recovery anchors, and keeps just one practical task visible so the day stays kind and workable.",
            walkthroughMoments: [
                "Open Check-In first to show a low-capacity day being named honestly.",
                "Move to Today and highlight the recovery anchors instead of deep work.",
                "Close by pointing out that the app is helping Alex preserve energy, not squeeze in more demands."
            ],
            scenario: recoveryDay,
            userRole: .selfPlanner,
            neurotype: .asd,
            pdaAwareSupport: true,
            supportPreset: .asdSupport,
            primarySupportFocus: .recovery,
            additionalSupportFocuses: [.routines],
            supportTone: .gentle,
            communicationStyle: .supportive,
            visualSupportMode: .lowerStimulation,
            transitionPrepMinutes: 20,
            reminderProfile: .gentleSupport
        )
    ]

    static let openHighCapacityDay = MockScenario(
        title: "Open High-Capacity Day",
        subtitle: "Strong sleep, low stress, and spacious anchors.",
        dailyState: DailyState(energy: 5, stress: 1, sleepHours: 8.2, sensoryLoad: 2, transitionFriction: 2, priority: "draft the project proposal"),
        events: [
            DayEvent(title: "Lunch check-in", startMinute: 12 * 60, durationMinutes: 30, detail: "A light social touchpoint in the middle of the day."),
            DayEvent(title: "Walk break", startMinute: 18 * 60, durationMinutes: 20, detail: "A recovery block to keep momentum from becoming sprawl.", kind: .recovery)
        ],
        healthSignals: HealthSignals(restingHeartRate: 61, averageHeartRate: 68, heartRateVariabilityMilliseconds: 54, respiratoryRate: 14.8, sleepDebtHours: 0.2, recoveryScore: 82, hydrationLiters: 1.8, activeEnergyKilocalories: 540, exerciseMinutes: 38, stepCount: 9200, sleepHours: 8.2),
        anchors: [
            Anchor(
                title: "Morning Landing",
                timeLabel: "8:00 AM",
                type: .transition,
                prompt: "Use the open morning to set direction before the day fills up.",
                tasks: [
                    Task(
                        title: "Review weekly goals",
                        detail: "Reconnect today to the bigger arc of the week.",
                        startMinute: 8 * 60,
                        durationMinutes: 15,
                        isEssential: true,
                        sensoryCue: .rhythmicPulsingGlow,
                        completionHistory: [
                            TaskCompletionSample(actualMinutes: 12),
                            TaskCompletionSample(actualMinutes: 16)
                        ]
                    ),
                    Task(
                        title: "Set up workspace",
                        detail: "Prepare desk, water, and reference materials.",
                        startMinute: 8 * 60 + 20,
                        durationMinutes: 10,
                        isEssential: false,
                        sensoryCue: .timedVibration,
                        completionHistory: [
                            TaskCompletionSample(actualMinutes: 9),
                            TaskCompletionSample(actualMinutes: 11)
                        ]
                    )
                ]
            ),
            Anchor(
                title: "Deep Work Block",
                timeLabel: "9:30 AM",
                type: .focus,
                prompt: "This is your clearest focus window.",
                tasks: [
                    Task(
                        title: "Draft proposal sections",
                        detail: "Push the main document forward before checking messages.",
                        startMinute: 9 * 60 + 30,
                        durationMinutes: 60,
                        isEssential: true,
                        sensoryCue: .rhythmicClickingSound,
                        completionHistory: [
                            TaskCompletionSample(actualMinutes: 52),
                            TaskCompletionSample(actualMinutes: 58),
                            TaskCompletionSample(actualMinutes: 64)
                        ]
                    ),
                    Task(
                        title: "Capture follow-up questions",
                        detail: "Keep a side list instead of switching tasks.",
                        startMinute: 10 * 60 + 35,
                        durationMinutes: 10,
                        isEssential: false,
                        sensoryCue: .timedVibration,
                        completionHistory: [
                            TaskCompletionSample(actualMinutes: 8),
                            TaskCompletionSample(actualMinutes: 12)
                        ]
                    )
                ]
            ),
            Anchor(
                title: "Afternoon Momentum",
                timeLabel: "1:30 PM",
                type: .focus,
                prompt: "Return after lunch with a lighter but still meaningful block.",
                tasks: [
                    Task(title: "Refine outline", detail: "Turn rough ideas into a cleaner structure.", durationMinutes: 45, isEssential: true),
                    Task(title: "Send one progress update", detail: "Close the loop with whoever needs visibility.", durationMinutes: 10, isEssential: false)
                ]
            ),
            Anchor(
                title: "Evening Recovery",
                timeLabel: "7:00 PM",
                type: .recovery,
                prompt: "Close the day before it starts to sprawl.",
                tasks: [
                    Task(title: "Shutdown ritual", detail: "Write tomorrow's first step and log off.", durationMinutes: 15, isEssential: true)
                ]
            )
        ]
    )

    static let lowCapacityDay = MockScenario(
        title: "Low-Capacity Day",
        subtitle: "Low sleep and low energy call for a gentle plan.",
        dailyState: DailyState(energy: 2, stress: 3, sleepHours: 5.4, sensoryLoad: 4, transitionFriction: 4, priority: "answer the most important messages"),
        events: [
            DayEvent(title: "Pharmacy pickup", startMinute: 16 * 60 + 30, durationMinutes: 20, detail: "A small practical errand that still needs buffer.", kind: .travel)
        ],
        healthSignals: HealthSignals(restingHeartRate: 72, averageHeartRate: 79, heartRateVariabilityMilliseconds: 24, respiratoryRate: 18.4, sleepDebtHours: 2.4, recoveryScore: 41, hydrationLiters: 0.8, activeEnergyKilocalories: 190, exerciseMinutes: 8, stepCount: 3100, sleepHours: 5.4),
        anchors: [
            Anchor(
                title: "Slow Start",
                timeLabel: "8:30 AM",
                type: .transition,
                prompt: "Ease into the day before making promises.",
                tasks: [
                    Task(title: "Drink water and orient", detail: "Reduce friction before touching work.", durationMinutes: 10, isEssential: true)
                ]
            ),
            Anchor(
                title: "Essential Work",
                timeLabel: "10:30 AM",
                type: .focus,
                prompt: "Touch only what truly needs today's attention.",
                tasks: [
                    Task(title: "Answer priority messages", detail: "Respond only to items with real consequences today.", durationMinutes: 20, isEssential: true),
                    Task(title: "Write one next step", detail: "Leave tomorrow a simpler starting point.", durationMinutes: 5, isEssential: false)
                ]
            ),
            Anchor(
                title: "Afternoon Reset",
                timeLabel: "2:00 PM",
                type: .recovery,
                prompt: "Use recovery to prevent the day from collapsing entirely.",
                tasks: [
                    Task(title: "Take a quiet break", detail: "Step away from stimulation and reassess.", durationMinutes: 15, isEssential: true)
                ]
            )
        ]
    )

    static let overloadedDay = MockScenario(
        title: "Overloaded Day",
        subtitle: "A crowded schedule with too much anchor weight.",
        dailyState: DailyState(energy: 3, stress: 5, sleepHours: 6.3, sensoryLoad: 4, transitionFriction: 5, priority: "make it through deadlines without dropping the essentials"),
        events: [
            DayEvent(title: "Client review call", startMinute: 11 * 60, durationMinutes: 45, detail: "A fixed commitment that carries deadline pressure."),
            DayEvent(title: "Commute home", startMinute: 18 * 60 + 15, durationMinutes: 35, detail: "Travel time that needs protection.", kind: .travel)
        ],
        healthSignals: HealthSignals(restingHeartRate: 78, averageHeartRate: 84, heartRateVariabilityMilliseconds: 22, respiratoryRate: 18.8, sleepDebtHours: 1.6, recoveryScore: 39, hydrationLiters: 1.0, activeEnergyKilocalories: 320, exerciseMinutes: 12, stepCount: 4700, sleepHours: 6.3),
        anchors: [
            Anchor(
                title: "Morning Triage",
                timeLabel: "7:30 AM",
                type: .transition,
                prompt: "Decide what is actually urgent before the day starts reacting for you.",
                tasks: [
                    Task(title: "Sort deadlines", detail: "Identify what must happen today versus what just feels loud.", durationMinutes: 15, isEssential: true)
                ]
            ),
            Anchor(
                title: "Client Deliverable",
                timeLabel: "9:00 AM",
                type: .focus,
                prompt: "This anchor carries the heaviest commitment of the day.",
                tasks: [
                    Task(title: "Finish deliverable draft", detail: "Get the work to a sendable state.", durationMinutes: 75, isEssential: true),
                    Task(title: "Prepare handoff note", detail: "Clarify open risks before sending.", durationMinutes: 15, isEssential: false)
                ]
            ),
            Anchor(
                title: "Meeting Cluster",
                timeLabel: "12:00 PM",
                type: .maintenance,
                prompt: "Contain coordination work so it does not swallow the whole afternoon.",
                tasks: [
                    Task(title: "Attend required meetings", detail: "Stay present for only the meetings that move blockers.", durationMinutes: 60, isEssential: true),
                    Task(title: "Log follow-ups immediately", detail: "Prevent rework by capturing actions on the spot.", durationMinutes: 10, isEssential: true)
                ]
            ),
            Anchor(
                title: "Late Catch-Up",
                timeLabel: "4:30 PM",
                type: .focus,
                prompt: "Finish what would otherwise leak into the evening.",
                tasks: [
                    Task(title: "Close one remaining deadline", detail: "Ship one unfinished piece instead of juggling many.", durationMinutes: 45, isEssential: true)
                ]
            ),
            Anchor(
                title: "Evening Shutdown",
                timeLabel: "8:00 PM",
                type: .recovery,
                prompt: "Protect the edge where overload turns into tomorrow's problem.",
                tasks: [
                    Task(title: "Write tomorrow triage list", detail: "Offload open loops so they are not carried mentally.", durationMinutes: 15, isEssential: true)
                ]
            )
        ]
    )

    static let splitShiftWorkday = MockScenario(
        title: "Split-Shift Workday",
        subtitle: "Two work windows with a long midday gap.",
        dailyState: DailyState(energy: 3, stress: 3, sleepHours: 7.0, sensoryLoad: 3, transitionFriction: 4, priority: "stay steady across both shifts"),
        events: [
            DayEvent(title: "Commute to second shift", startMinute: 14 * 60 + 20, durationMinutes: 25, detail: "A travel block that should be visible.", kind: .travel)
        ],
        healthSignals: HealthSignals(restingHeartRate: 66, averageHeartRate: 71, heartRateVariabilityMilliseconds: 41, respiratoryRate: 15.9, sleepDebtHours: 0.8, recoveryScore: 64, hydrationLiters: 1.5, activeEnergyKilocalories: 430, exerciseMinutes: 24, stepCount: 7100, sleepHours: 7.0),
        anchors: [
            Anchor(
                title: "Opening Shift",
                timeLabel: "6:00 AM",
                type: .focus,
                prompt: "Use the early shift for high-clarity operational work.",
                tasks: [
                    Task(title: "Handle opening tasks", detail: "Complete the required startup checklist.", durationMinutes: 45, isEssential: true)
                ]
            ),
            Anchor(
                title: "Midday Reset",
                timeLabel: "11:30 AM",
                type: .recovery,
                prompt: "The gap between shifts has to restore you, not become a second job.",
                tasks: [
                    Task(title: "Eat and fully disengage", detail: "Recover before the second block begins.", durationMinutes: 30, isEssential: true)
                ]
            ),
            Anchor(
                title: "Second Shift Setup",
                timeLabel: "3:00 PM",
                type: .transition,
                prompt: "Re-enter the day on purpose instead of dropping straight into stress.",
                tasks: [
                    Task(title: "Review second-shift priorities", detail: "Decide what matters for the remaining hours.", durationMinutes: 10, isEssential: true)
                ]
            ),
            Anchor(
                title: "Closing Shift",
                timeLabel: "4:00 PM",
                type: .focus,
                prompt: "Use the final work block for the tasks that must be done before close.",
                tasks: [
                    Task(title: "Work the closing checklist", detail: "Complete the must-finish items for the shift.", durationMinutes: 50, isEssential: true),
                    Task(title: "Leave notes for tomorrow", detail: "Reduce startup friction for the next day.", durationMinutes: 10, isEssential: false)
                ]
            )
        ]
    )

    static let schoolAndWorkDay = MockScenario(
        title: "School + Work Day",
        subtitle: "Academic work layered with a scheduled shift.",
        dailyState: DailyState(energy: 3, stress: 4, sleepHours: 6.8, sensoryLoad: 3, transitionFriction: 4, priority: "finish the reading response before work"),
        events: [
            DayEvent(title: "Class seminar", startMinute: 10 * 60 + 30, durationMinutes: 50, detail: "A fixed school commitment in the middle of the day."),
            DayEvent(title: "Commute to work", startMinute: 14 * 60, durationMinutes: 25, detail: "Travel time should not compete with study.", kind: .travel)
        ],
        healthSignals: HealthSignals(restingHeartRate: 70, averageHeartRate: 76, heartRateVariabilityMilliseconds: 33, respiratoryRate: 16.8, sleepDebtHours: 0.9, recoveryScore: 52, hydrationLiters: 1.2, activeEnergyKilocalories: 360, exerciseMinutes: 18, stepCount: 6200, sleepHours: 6.8),
        anchors: [
            Anchor(
                title: "Class Prep",
                timeLabel: "8:00 AM",
                type: .transition,
                prompt: "Start by orienting to the school pieces before the work shift looms.",
                tasks: [
                    Task(title: "Review class deadlines", detail: "Confirm what actually has to move today.", durationMinutes: 15, isEssential: true)
                ]
            ),
            Anchor(
                title: "Study Block",
                timeLabel: "9:00 AM",
                type: .focus,
                prompt: "This is the best chance to make academic progress before work drains capacity.",
                tasks: [
                    Task(title: "Write reading response", detail: "Draft the assignment while your head is still fresh.", durationMinutes: 50, isEssential: true),
                    Task(title: "Upload materials", detail: "Remove last-minute friction before leaving.", durationMinutes: 10, isEssential: false)
                ]
            ),
            Anchor(
                title: "Work Transition",
                timeLabel: "1:30 PM",
                type: .transition,
                prompt: "Shift from school context to paid work without carrying everything mentally.",
                tasks: [
                    Task(title: "Pack and commute prep", detail: "Gather work items and stop trying to finish more school tasks.", durationMinutes: 20, isEssential: true)
                ]
            ),
            Anchor(
                title: "Work Shift",
                timeLabel: "3:00 PM",
                type: .maintenance,
                prompt: "Treat the work shift as a contained obligation rather than part of your study time.",
                tasks: [
                    Task(title: "Complete shift essentials", detail: "Focus on the tasks that define a solid shift.", durationMinutes: 90, isEssential: true)
                ]
            ),
            Anchor(
                title: "Late Recovery",
                timeLabel: "9:00 PM",
                type: .recovery,
                prompt: "Do not ask the night to solve what the day already used up.",
                tasks: [
                    Task(title: "Prepare tomorrow's start", detail: "Set out materials and let the rest wait.", durationMinutes: 10, isEssential: true)
                ]
            )
        ]
    )

    static let recoveryDay = MockScenario(
        title: "Recovery Day",
        subtitle: "A day designed around regulation and catching your breath.",
        dailyState: DailyState(energy: 2, stress: 2, sleepHours: 8.8, priority: "recover without losing the thread completely"),
        events: [
            DayEvent(title: "Quiet outside time", startMinute: 15 * 60 + 30, durationMinutes: 30, detail: "A restorative block that should stay protected.", kind: .recovery)
        ],
        healthSignals: HealthSignals(restingHeartRate: 64, averageHeartRate: 69, heartRateVariabilityMilliseconds: 48, respiratoryRate: 14.6, sleepDebtHours: nil, recoveryScore: 74, hydrationLiters: 2.0, activeEnergyKilocalories: 260, exerciseMinutes: 22, stepCount: 5800, sleepHours: 8.8),
        anchors: [
            Anchor(
                title: "Gentle Morning",
                timeLabel: "9:00 AM",
                type: .recovery,
                prompt: "Begin with calm inputs and a very low-friction start.",
                tasks: [
                    Task(title: "Slow breakfast", detail: "Start with food, water, and no rush.", durationMinutes: 20, isEssential: true)
                ]
            ),
            Anchor(
                title: "Light Admin",
                timeLabel: "11:30 AM",
                type: .maintenance,
                prompt: "Touch only the upkeep that makes tomorrow easier.",
                tasks: [
                    Task(title: "Handle one practical task", detail: "Pay one bill, answer one message, or tidy one loose end.", durationMinutes: 15, isEssential: true)
                ]
            ),
            Anchor(
                title: "Afternoon Reset",
                timeLabel: "2:30 PM",
                type: .recovery,
                prompt: "The middle of the day is for restoring bandwidth.",
                tasks: [
                    Task(title: "Go outside or rest", detail: "Choose the least activating way to recover.", durationMinutes: 30, isEssential: true)
                ]
            ),
            Anchor(
                title: "Evening Soft Landing",
                timeLabel: "6:30 PM",
                type: .transition,
                prompt: "Reduce tomorrow's startup friction without turning the evening into planning mode.",
                tasks: [
                    Task(title: "Set out one tomorrow item", detail: "Prepare a single visible cue for the next day.", durationMinutes: 10, isEssential: true)
                ]
            )
        ]
    )

    static let legacySampleAnchors: [Anchor] = [
        Anchor(
            title: "Morning Landing",
            timeLabel: "8:00 AM",
            type: .transition,
            prompt: "Use this anchor to orient the day before reacting to messages.",
            tasks: [
                Task(title: "Review today at a glance", detail: "Open the app and scan your three plan modes.", durationMinutes: 10, isEssential: true),
                Task(title: "Set up workspace", detail: "Clear desk, water bottle, and headphones.", durationMinutes: 10, isEssential: false)
            ]
        ),
        Anchor(
            title: "Deep Work Block",
            timeLabel: "10:00 AM",
            type: .focus,
            prompt: "Advance the highest-value work while energy is still available.",
            tasks: [
                Task(title: "Work on top priority", detail: "Push the most meaningful task forward without context switching.", durationMinutes: 45, isEssential: true),
                Task(title: "Capture loose ideas", detail: "Write down follow-ups instead of pivoting.", durationMinutes: 10, isEssential: false)
            ]
        ),
        Anchor(
            title: "Admin Reset",
            timeLabel: "1:30 PM",
            type: .maintenance,
            prompt: "Catch important maintenance work without letting it take over the day.",
            tasks: [
                Task(title: "Process urgent messages", detail: "Reply only to items that affect today.", durationMinutes: 20, isEssential: true),
                Task(title: "Tidy task list", detail: "Move stray notes into the right place.", durationMinutes: 15, isEssential: false)
            ]
        ),
        Anchor(
            title: "Evening Recovery",
            timeLabel: "7:00 PM",
            type: .recovery,
            prompt: "Close loops and make tomorrow easier.",
            tasks: [
                Task(title: "Shutdown ritual", detail: "Wrap up, prep tomorrow, and stop actively planning.", durationMinutes: 15, isEssential: true),
                Task(title: "Gentle reset", detail: "Stretch, dim lights, and lower stimulation.", durationMinutes: 15, isEssential: false)
            ]
        )
    ]
}
