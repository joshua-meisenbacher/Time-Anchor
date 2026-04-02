import Foundation

struct CapacityEngine {
    func assessDay(context: DayContext, anchors: [Anchor]) -> DayAssessment {
        PlanningEngine().assessDay(context: context, anchors: anchors)
    }
}

struct GuidanceEngine {
    func makeGuidance(currentBlock: ScheduleBlock?, nextBlock: ScheduleBlock?, dailyState: DailyState, mode: PlanMode) -> String {
        guard let currentBlock else {
            return "Start with a gentle orientation step so the day has a clear beginning."
        }

        let priorityText = dailyState.priority.isEmpty ? "today's main priority" : dailyState.priority
        let nextText = nextBlock.map { "Next: \($0.title) at \($0.timeRangeText)." } ?? "There is no next block after this one, so let recovery count."

        switch mode {
        case .minimum:
            return "Stay with \(currentBlock.title), narrow the scope, and let success mean continuity. \(nextText)"
        case .reduced:
            return "Use \(currentBlock.title) to protect momentum around \(priorityText) without opening extra loops. \(nextText)"
        case .full:
            return "Keep \(currentBlock.title) as the main lane for \(priorityText) and avoid unnecessary context switches. \(nextText)"
        }
    }
}

final class PlanningEngine {
    func assessDay(context: DayContext, anchors: [Anchor]) -> DayAssessment {
        let anchors = filteredAnchors(anchors, for: context.planningDayOffset)
        let dailyState = context.dailyState
        let loadScore = anchorLoadScore(for: anchors)
        let eventLoad = min(context.events.count, 3)
        let routinePressure = context.routines.filter(\.isPinned).count >= 3 ? 1 : 0
        let projectPressure = min(context.projects.filter { $0.remainingMinutes > 0 && $0.daysUntilDue(from: context.date) <= 3 }.count, 2)
        let healthPenalty = (context.healthSignals.sleepDebtHours ?? 0) >= 2 ? 1 : 0
        let hydrationPenalty = (context.healthSignals.hydrationLiters ?? 1.5) < 1 ? 1 : 0
        let recoveryPenalty = (context.healthSignals.recoveryScore ?? 60) < 45 ? 1 : 0
        let hrvPenalty = {
            guard let hrv = context.healthSignals.heartRateVariabilityMilliseconds else { return 0 }
            return hrv < 28 ? 1 : 0
        }()
        let respiratoryPenalty = {
            guard let respiratoryRate = context.healthSignals.respiratoryRate else { return 0 }
            return respiratoryRate > 18 ? 1 : 0
        }()
        let adjustedLoad = loadScore + eventLoad + routinePressure + projectPressure + healthPenalty + hydrationPenalty + recoveryPenalty + hrvPenalty + respiratoryPenalty
        let drivers = capacityDrivers(
            context: context,
            loadScore: loadScore,
            eventLoad: eventLoad,
            routinePressure: routinePressure,
            projectPressure: projectPressure,
            healthPenalty: healthPenalty,
            hydrationPenalty: hydrationPenalty,
            recoveryPenalty: recoveryPenalty,
            hrvPenalty: hrvPenalty,
            respiratoryPenalty: respiratoryPenalty
        )

        // These rules intentionally stay interpretable: sleep, energy, stress,
        // and anchor load each contribute visible pressure on the day.
        if dailyState.sleepHours < 5.5 || (dailyState.energy <= 2 && dailyState.stress >= 4) || dailyState.sensoryLoad >= 5 {
            return DayAssessment(
                recommendedMode: .minimum,
                headline: "Protect the essentials",
                reasoning: "Low recovery combined with stress or low energy means the day should center on continuity, not expansion.",
                loadScore: adjustedLoad,
                supportFocus: "Lower demands, reduce switching, and keep the next step obvious.",
                capacityDrivers: drivers
            )
        }

        if adjustedLoad >= 8 && (dailyState.stress >= 4 || dailyState.energy <= 3 || dailyState.transitionFriction >= 4) {
            return DayAssessment(
                recommendedMode: .minimum,
                headline: "Too much load for current capacity",
                reasoning: "A heavy anchor load paired with strain means the safest plan is the minimum viable day.",
                loadScore: adjustedLoad,
                supportFocus: "Preserve recovery and cut the number of moving pieces.",
                capacityDrivers: drivers
            )
        }

        if dailyState.sleepHours >= 7, dailyState.energy >= 4, dailyState.stress <= 2, adjustedLoad <= 6, dailyState.transitionFriction <= 3 {
            return DayAssessment(
                recommendedMode: .full,
                headline: "Capacity and load are aligned",
                reasoning: "Rest, energy, and a manageable anchor load support a fuller plan with deeper work.",
                loadScore: adjustedLoad,
                supportFocus: "Use structure to create progress while keeping transitions intentional.",
                capacityDrivers: drivers
            )
        }

        if dailyState.stress >= 4 || dailyState.sleepHours < 6.5 || adjustedLoad >= 7 || dailyState.transitionFriction >= 4 {
            return DayAssessment(
                recommendedMode: .reduced,
                headline: "Use a protected middle path",
                reasoning: "Some strain is present, so the day should preserve momentum while trimming overhead and transitions.",
                loadScore: adjustedLoad,
                supportFocus: "Keep one clear lane of progress and make transitions gentler.",
                capacityDrivers: drivers
            )
        }

        return DayAssessment(
            recommendedMode: .full,
            headline: "A workable full day",
            reasoning: "Capacity is stable enough for a fuller plan, with anchors still doing the work of pacing the day.",
            loadScore: adjustedLoad,
            supportFocus: "Keep what matters visible so effort turns into forward motion.",
            capacityDrivers: drivers
        )
    }

    private func capacityDrivers(
        context: DayContext,
        loadScore: Int,
        eventLoad: Int,
        routinePressure: Int,
        projectPressure: Int,
        healthPenalty: Int,
        hydrationPenalty: Int,
        recoveryPenalty: Int,
        hrvPenalty: Int,
        respiratoryPenalty: Int
    ) -> [String] {
        var drivers: [String] = []
        let dailyState = context.dailyState

        if dailyState.sleepHours < 6.5 {
            drivers.append(String(format: "Sleep looks light at %.1f hours.", dailyState.sleepHours))
        } else if dailyState.sleepHours >= 7.5 {
            drivers.append(String(format: "Sleep looks steadier at %.1f hours.", dailyState.sleepHours))
        }

        if dailyState.energy <= 2 {
            drivers.append("Self-reported energy is low, so starting and switching may take more effort.")
        } else if dailyState.energy >= 4 {
            drivers.append("Energy is showing up as workable for a fuller day.")
        }

        if dailyState.stress >= 4 {
            drivers.append("Stress is elevated, which raises the cost of interruptions and extra decisions.")
        }

        if dailyState.sensoryLoad >= 4 {
            drivers.append("Sensory load is high, so cues and transitions should stay gentle and clear.")
        }

        if dailyState.transitionFriction >= 4 {
            drivers.append("Transitions are likely to be sticky today, so buffers and handoffs matter more.")
        }

        if eventLoad >= 2 {
            drivers.append("Calendar commitments add time pressure and reduce flexible space.")
        }

        if routinePressure > 0 {
            drivers.append("Pinned routines are taking a meaningful share of the day.")
        }

        if projectPressure > 0 {
            drivers.append("A due-soon project is adding background pressure, even if it is not the loudest thing on the calendar.")
        }

        if loadScore >= 5 {
            drivers.append("The anchor load is already fairly dense before extra friction is added.")
        }

        if healthPenalty > 0, let sleepDebtHours = context.healthSignals.sleepDebtHours {
            drivers.append(String(format: "Apple Health suggests a sleep debt of about %.1f hours.", sleepDebtHours))
        }

        if hydrationPenalty > 0, let hydrationLiters = context.healthSignals.hydrationLiters {
            drivers.append(String(format: "Hydration looks low at %.1f liters so far.", hydrationLiters))
        }

        if recoveryPenalty > 0, let recoveryScore = context.healthSignals.recoveryScore {
            drivers.append("Recovery is trending low at \(recoveryScore), which can make the day feel heavier than it looks.")
        }

        if hrvPenalty > 0, let hrv = context.healthSignals.heartRateVariabilityMilliseconds {
            drivers.append(String(format: "HRV is lower than usual-looking at %.0f ms, which can signal strain or low recovery.", hrv))
        }

        if respiratoryPenalty > 0, let respiratoryRate = context.healthSignals.respiratoryRate {
            drivers.append(String(format: "Respiratory rate is elevated at %.1f breaths per minute.", respiratoryRate))
        }

        if drivers.isEmpty {
            drivers.append("Current signals are fairly balanced, so the plan can stay more expansive.")
        }

        return Array(drivers.prefix(5))
    }

    func generatePlans(
        for context: DayContext,
        anchors: [Anchor],
        profileSettings: ProfileSettings,
        estimatedState: EstimatedState = .empty,
        recentOutcomes: [DayOutcome] = [],
        preserving existingPlans: [PlanVersion] = []
    ) -> [PlanVersion] {
        let anchors = filteredAnchors(anchors, for: context.planningDayOffset)
        let assessment = assessDay(context: context, anchors: anchors)
        let planningFeedback = makePlanningFeedback(from: recentOutcomes)

        return PlanMode.allCases.map { mode in
            let sourceAnchors = existingPlans.first(where: { $0.mode == mode })?.anchors ?? anchors
            let completedTaskIDs = Set(sourceAnchors.flatMap(\.tasks).filter(\.isCompleted).map(\.id))
            let plannedAnchors = sourceAnchors.map {
                makeAnchor(
                    $0,
                    context: context,
                    for: mode,
                    dailyState: context.dailyState,
                    profileSettings: profileSettings,
                    assessment: assessment,
                estimatedState: estimatedState,
                planningFeedback: planningFeedback,
                    completedTaskIDs: completedTaskIDs
                )
            }
            let dailyPlan = buildDailyPlan(
                for: mode,
                context: context,
                anchors: plannedAnchors,
                assessment: assessment,
                estimatedState: estimatedState,
                planningFeedback: planningFeedback
            )
            let focus = makeFocusSummary(for: mode, context: context, assessment: assessment, estimatedState: estimatedState)
            let modeSummary = makeModeSummary(for: mode, assessment: assessment, estimatedState: estimatedState)
            let existingPlanID = existingPlans.first(where: { $0.mode == mode })?.id ?? UUID()
            return PlanVersion(
                id: existingPlanID,
                mode: mode,
                context: context,
                anchors: plannedAnchors,
                dailyPlan: dailyPlan,
                whatMattersNow: focus,
                modeSummary: modeSummary
            )
        }
    }

    private func makeAnchor(
        _ anchor: Anchor,
        context: DayContext,
        for mode: PlanMode,
        dailyState: DailyState,
        profileSettings: ProfileSettings,
        assessment: DayAssessment,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback,
        completedTaskIDs: Set<UUID>
    ) -> Anchor {
        let adaptedIdentity = adaptAnchorIdentity(anchor, context: context)
        let rebuiltTasks = plannedTasks(
            for: anchor,
            mode: mode,
            dailyState: dailyState,
            assessment: assessment,
            estimatedState: estimatedState,
            planningFeedback: planningFeedback
        )
            .map { task in
                completedTaskIDs.contains(task.id) ? task.updatingCompletion(true) : task
            }
        let preservedCompletedTasks = anchor.tasks.filter { $0.isCompleted && !rebuiltTasks.map(\.id).contains($0.id) }
        let mergedTasks = preservedCompletedTasks + rebuiltTasks
        let adaptivePrompt = adaptPrompt(
            anchor: adaptedIdentity,
            dailyState: dailyState,
            profileSettings: profileSettings,
            mode: mode,
            assessment: assessment,
            estimatedState: estimatedState,
            planningFeedback: planningFeedback
        )

        return adaptedIdentity.updating(prompt: adaptivePrompt, tasks: mergedTasks)
    }

    private func plannedTasks(
        for anchor: Anchor,
        mode: PlanMode,
        dailyState: DailyState,
        assessment: DayAssessment,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> [Task] {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)

        switch mode {
        case .full:
            // Full plans preserve the original anchor intent and only add stretch work
            // when the assessment says capacity clearly exceeds load.
            if assessment.recommendedMode == .full,
               confidenceProfile.allowStretchWork,
               estimatedState.executionState == .onTrack,
               planningFeedback.rebuildPressure == 0,
               anchor.type == .focus,
               let coreTask = anchor.tasks.first(where: \.isEssential) {
                return anchor.tasks + [
                    Task(
                        title: "Stretch the same work",
                        detail: "If momentum is good, continue the same priority instead of switching contexts.",
                        durationMinutes: min(coreTask.durationMinutes, 30),
                        isEssential: false
                    )
                ]
            }

            return anchor.tasks

        case .reduced:
            return reducedTasks(for: anchor)

        case .minimum:
            return minimumTasks(for: anchor, priority: dailyState.priority)
        }
    }

    private func reducedTasks(for anchor: Anchor) -> [Task] {
        // Reduced plans are not "full but shorter". They change the posture of the
        // day by converting anchors into protected versions with less overhead.
        switch anchor.type {
        case .focus:
            let essential = anchor.tasks.first(where: \.isEssential)
            return compactTasks([
                essential,
                Task(
                    title: "Capture stopping point",
                    detail: "Leave a short note so the next work block can restart cleanly.",
                    durationMinutes: 5,
                    isEssential: true
                )
            ])

        case .maintenance:
            return [
                Task(
                    title: "Triage only",
                    detail: "Handle only the items that affect today or tomorrow.",
                    durationMinutes: 15,
                    isEssential: true
                )
            ]

        case .transition:
            return [
                Task(
                    title: "Orient quickly",
                    detail: "Check the next anchor and remove one source of friction.",
                    durationMinutes: 10,
                    isEssential: true
                )
            ]

        case .recovery:
            return compactTasks([
                anchor.tasks.first(where: \.isEssential),
                Task(
                    title: "Protect decompression",
                    detail: "Avoid reopening the day after shutdown starts.",
                    durationMinutes: 10,
                    isEssential: true
                )
            ])
        }
    }

    private func minimumTasks(for anchor: Anchor, priority: String) -> [Task] {
        let priorityText = priority.isEmpty ? "today's main commitment" : priority

        // Minimum plans keep every anchor as a continuity checkpoint, but each one
        // shrinks to the smallest action that still keeps the day coherent.
        switch anchor.type {
        case .focus:
            return [
                Task(
                    title: "Do one tiny step",
                    detail: "Touch \(priorityText) for 10 minutes or define the next action.",
                    durationMinutes: 10,
                    isEssential: true
                )
            ]

        case .maintenance:
            return [
                Task(
                    title: "Keep the day from slipping",
                    detail: "Handle one urgent admin item and defer the rest.",
                    durationMinutes: 10,
                    isEssential: true
                )
            ]

        case .transition:
            return [
                Task(
                    title: "Reset and re-enter",
                    detail: "Pause, hydrate, and decide only what comes next.",
                    durationMinutes: 10,
                    isEssential: true
                )
            ]

        case .recovery:
            return [
                Task(
                    title: "Recover on purpose",
                    detail: "Close the day gently and lower demands wherever possible.",
                    durationMinutes: 15,
                    isEssential: true
                )
            ]
        }
    }

    private func adaptPrompt(
        anchor: Anchor,
        dailyState: DailyState,
        profileSettings: ProfileSettings,
        mode: PlanMode,
        assessment: DayAssessment,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> String {
        let basePrompt = canonicalAnchorPrompt(from: anchor.prompt)
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let supportLine: String
        if confidenceProfile.isLowConfidence, let confidenceLine = confidenceProfile.supportLine {
            supportLine = confidenceLine
        } else if planningFeedback.rebuildPressure >= 2 {
            supportLine = "Keep this step narrow and easy to restart."
        } else if planningFeedback.tooIntensePressure >= 2 {
            supportLine = "Keep this step softer and lower pressure."
        } else if planningFeedback.missedTransitionPressure >= 2 || estimatedState.transitionRisk[anchor.id, default: 0] >= 0.65 {
            supportLine = "Give the handoff extra support."
        } else {
            switch mode {
            case .full:
                supportLine = "Keep one clear lane of progress here."
            case .reduced:
                supportLine = "Trim extras and keep only the useful work."
            case .minimum:
                supportLine = "Use this as a gentle continuity point."
            }
        }

        return [basePrompt, supportLine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func adaptAnchorIdentity(_ anchor: Anchor, context: DayContext) -> Anchor {
        let todayEvents = context.events
            .filter { $0.dayOffset == context.planningDayOffset && $0.shouldAppearInPlanning }
            .sorted { lhs, rhs in
                if lhs.startMinute == rhs.startMinute {
                    return lhs.title < rhs.title
                }
                return lhs.startMinute < rhs.startMinute
            }

        guard !todayEvents.isEmpty else {
            return anchor.updating(title: genericAnchorTitle(for: anchor, anchorMinute: clockMinutes(from: anchor.timeLabel)))
        }

        let anchorMinute = clockMinutes(from: anchor.timeLabel)
        let upcomingEvent = todayEvents.first(where: { $0.startMinute >= anchorMinute && ($0.startMinute - anchorMinute) <= 120 })
        let recentEvent = todayEvents.last(where: { $0.endMinute <= anchorMinute && (anchorMinute - $0.endMinute) <= 120 })
        let currentEvent = todayEvents.first(where: { $0.startMinute <= anchorMinute && anchorMinute < $0.endMinute })

        switch anchor.type {
        case .transition:
            if let upcomingEvent {
                return anchor.updating(
                    title: "Before \(shortEventTitle(upcomingEvent.title))",
                    timeLabel: anchor.timeLabel
                )
            }

            if let recentEvent {
                return anchor.updating(
                    title: "After \(shortEventTitle(recentEvent.title))",
                    timeLabel: anchor.timeLabel
                )
            }

            return anchor.updating(title: genericAnchorTitle(for: anchor, anchorMinute: anchorMinute))

        case .focus:
            if let upcomingEvent, (upcomingEvent.startMinute - anchorMinute) <= 90 {
                return anchor.updating(
                    title: "Prep For \(shortEventTitle(upcomingEvent.title))",
                    timeLabel: anchor.timeLabel
                )
            }

            if let currentEvent {
                return anchor.updating(
                    title: shortEventTitle(currentEvent.title),
                    timeLabel: eventTimeLabel(for: currentEvent)
                )
            }

            return anchor.updating(title: genericAnchorTitle(for: anchor, anchorMinute: anchorMinute))

        case .maintenance:
            if let upcomingEvent {
                return anchor.updating(
                    title: "Get Ready For \(shortEventTitle(upcomingEvent.title))",
                    timeLabel: anchor.timeLabel
                )
            }

            return anchor.updating(title: genericAnchorTitle(for: anchor, anchorMinute: anchorMinute))

        case .recovery:
            if let recentEvent {
                return anchor.updating(
                    title: "Recover After \(shortEventTitle(recentEvent.title))",
                    timeLabel: anchor.timeLabel
                )
            }

            return anchor.updating(title: genericAnchorTitle(for: anchor, anchorMinute: anchorMinute))
        }
    }

    private func genericAnchorTitle(for anchor: Anchor, anchorMinute: Int) -> String {
        switch anchor.type {
        case .focus:
            if anchorMinute < 12 * 60 { return "Morning Focus Window" }
            if anchorMinute < 17 * 60 { return "Daytime Focus Window" }
            return "Evening Focus Window"
        case .maintenance:
            if anchorMinute < 12 * 60 { return "Morning Upkeep" }
            if anchorMinute < 17 * 60 { return "Daytime Upkeep" }
            return "Evening Upkeep"
        case .transition:
            if anchorMinute < 12 * 60 { return "Morning Transition" }
            if anchorMinute < 17 * 60 { return "Midday Transition" }
            return "Evening Transition"
        case .recovery:
            if anchorMinute < 15 * 60 { return "Recovery Window" }
            return "Evening Recovery"
        }
    }

    private func shortEventTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 28 {
            return trimmed
        }
        return String(trimmed.prefix(25)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func clockMinutes(from label: String) -> Int {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        if let date = formatter.date(from: label) {
            return Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
        }
        return 8 * 60
    }

    private func eventTimeLabel(for event: DayEvent) -> String {
        "\(clockString(for: event.startMinute)) - \(clockString(for: event.endMinute))"
    }

    private func anchorRoleLine(for anchor: Anchor, profileSettings: ProfileSettings) -> String {
        let pdaAware = profileSettings.pdaAwareSupport

        switch anchor.type {
        case .focus:
            return pdaAware
            ? "Let this anchor hold a small, clear lane so you do not have to renegotiate the whole day here."
            : "Let this anchor make time easier to read and the next move easier to start."
        case .maintenance:
            return pdaAware
            ? "Use this anchor to keep essential upkeep visible without turning it into a pile of demands."
            : "Use this anchor to keep maintenance from scattering across the whole day."
        case .transition:
            return "Use this anchor as a predictable handoff so the switch into the next part of the day stays clearer."
        case .recovery:
            return "Use this anchor to protect recovery and keep the day from spilling past what is workable."
        }
    }

    private func profileAnchorLine(for anchor: Anchor, profileSettings: ProfileSettings) -> String {
        if profileSettings.pdaAwareSupport {
            return "This anchor should feel like an option, not an order. Use it as a gentle place to restart when it helps."
        }

        switch profileSettings.neurotype {
        case .adhd:
            return "Keep this anchor very explicit so the next step is visible without extra interpretation."
        case .asd:
            return "Keep this anchor low-pressure and literal so it reduces uncertainty instead of adding more."
        case .audhd:
            return "Use this anchor to keep both time and transitions concrete without making the step feel too loud."
        case .neurotypical, .other:
            switch profileSettings.primarySupportFocus {
            case .timeBlindness:
                return "Use this anchor to make the shape of the day easier to read at a glance."
            case .transitions:
                return anchor.type == .transition ? "Use this anchor to make the handoff between contexts feel more intentional." : ""
            case .stayingOnTask:
                return anchor.type == .focus ? "Use this anchor to keep one lane active long enough for momentum to form." : ""
            case .routines:
                return "Use this anchor as a stable part of the day that linked routines can hang onto."
            case .recovery:
                return anchor.type == .recovery ? "Use this anchor to protect recovery before the day starts asking for more." : ""
            }
        }
    }

    private func dailyAnchorLine(
        for anchor: Anchor,
        dailyState: DailyState,
        assessment: DayAssessment,
        profileSettings: ProfileSettings
    ) -> String {
        if dailyState.transitionFriction >= 4, anchor.type == .transition {
            return profileSettings.pdaAwareSupport
            ? "A softer, clearer handoff will probably help more than pushing speed here."
            : "Transitions look sticky today, so keep this handoff especially explicit."
        }

        if dailyState.sensoryLoad >= 4 {
            return profileSettings.pdaAwareSupport
            ? "Keep this part of the day quieter and more optional if sensory load rises."
            : "Sensory load is high today, so keep this anchor quieter and easier to scan."
        }

        if dailyState.energy <= 2, anchor.type == .focus || anchor.type == .maintenance {
            return profileSettings.pdaAwareSupport
            ? "A smaller version of this anchor may be the more workable choice today."
            : "Energy is low today, so keep this anchor narrower than usual."
        }

        if assessment.recommendedMode == .full, dailyState.energy >= 4, anchor.type == .focus {
            return "This looks like one of your clearer windows today, so it can carry meaningful progress."
        }

        return ""
    }

    private func makeFocusSummary(
        for mode: PlanMode,
        context: DayContext,
        assessment: DayAssessment,
        estimatedState: EstimatedState
    ) -> String {
        let priorityText = context.dailyState.priority.isEmpty ? "staying grounded" : context.dailyState.priority
        let urgentProject = context.projects
            .filter { $0.remainingMinutes > 0 && $0.daysUntilDue(from: context.date) <= 3 }
            .sorted { $0.daysUntilDue(from: context.date) < $1.daysUntilDue(from: context.date) }
            .first
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)

        switch mode {
        case .full:
            if let urgentProject {
                return "Keep \(priorityText) moving while protecting real progress on \(urgentProject.title) before the due date turns into pressure."
            }
            if confidenceProfile.isLowConfidence {
                return "Work toward \(priorityText), but keep a fallback posture so the day can stay steady if the signals shift."
            }
            return "Use your available capacity to make real progress on \(priorityText), while letting anchors pace the day."
        case .reduced:
            if let urgentProject {
                return "Protect \(priorityText), contain transitions, and keep a small but visible step open for \(urgentProject.title)."
            }
            if confidenceProfile.isLowConfidence {
                return "Protect \(priorityText), contain transitions, and let the first version of each step be enough until the day feels clearer."
            }
            return "Protect \(priorityText), contain transitions, and let non-essential effort stay optional."
        case .minimum:
            if let urgentProject {
                return "Preserve only the smallest meaningful version of \(priorityText) and one survivable step for \(urgentProject.title)."
            }
            return "Preserve only the smallest meaningful version of \(priorityText); success is continuity, not volume."
        }
    }

    private func makeModeSummary(for mode: PlanMode, assessment: DayAssessment, estimatedState: EstimatedState) -> String {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)

        switch mode {
        case .full:
            if confidenceProfile.isLowConfidence {
                return "Keeps the full anchor structure, but with a more conservative posture because current signals are less certain."
            }
            return "Keeps the full anchor structure and allows depth when capacity and load are aligned."
        case .reduced:
            if confidenceProfile.isLowConfidence {
                return "Converts the day into a protected version with extra margin because the current state is not fully clear yet."
            }
            return "Converts the day into a protected, lower-overhead version with buffer-friendly anchors."
        case .minimum:
            return "Turns anchors into continuity checkpoints so the day remains survivable and coherent."
        }
    }

    private func anchorLoadScore(for anchors: [Anchor]) -> Int {
        let totalMinutes = anchors.flatMap(\.tasks).reduce(0) { $0 + $1.durationMinutes }
        let focusAnchors = anchors.filter { $0.type == .focus }.count
        let anchorCount = anchors.count

        var score = 0

        if totalMinutes >= 240 { score += 3 }
        else if totalMinutes >= 150 { score += 2 }
        else if totalMinutes >= 90 { score += 1 }

        if focusAnchors >= 3 { score += 2 }
        else if focusAnchors == 2 { score += 1 }

        if anchorCount >= 6 { score += 3 }
        else if anchorCount >= 5 { score += 2 }
        else if anchorCount >= 4 { score += 1 }

        return score
    }

    private func compactTasks(_ tasks: [Task?]) -> [Task] {
        tasks.compactMap { $0 }
    }

    private func filteredAnchors(_ anchors: [Anchor], for dayOffset: Int) -> [Anchor] {
        anchors.map { anchor in
            anchor.updating(tasks: anchor.tasks.filter { $0.dayOffset == dayOffset })
        }
    }

    private func buildDailyPlan(
        for mode: PlanMode,
        context: DayContext,
        anchors: [Anchor],
        assessment: DayAssessment,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> DailyPlan {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let routineBlocks = context.routines
            .filter(\.isPinned)
            .enumerated()
            .map { index, routine in
                let startMinute = inferredStartMinute(for: routine, fallbackIndex: index)
                let duration = max(routine.steps.reduce(0) { $0 + $1.estimatedMinutes }, 10)
                return ScheduleBlock(
                    kind: .routine,
                    title: routine.title,
                    detail: routine.summary,
                    startMinute: startMinute,
                    endMinute: startMinute + duration,
                    cue: ScheduleCue(
                        title: "Routine support",
                        detail: routine.steps.first?.cue ?? "Use the routine to lower startup friction.",
                        style: .calm
                    )
                )
            }

        let projectBlocks = suggestedProjectBlocks(
            for: context,
            mode: mode,
            estimatedState: estimatedState,
            planningFeedback: planningFeedback
        )

        let eventBlocks = context.events.compactMap { event -> [ScheduleBlock]? in
            guard event.dayOffset == 0 else { return nil }
            guard event.shouldAppearInPlanning else { return nil }

            return eventSupportBlocks(for: event) + [
                ScheduleBlock(
                    kind: event.kind == .recovery ? .recovery : .event,
                    title: event.title,
                    detail: eventDetail(for: event),
                    startMinute: event.startMinute,
                    endMinute: event.endMinute,
                    cue: ScheduleCue(
                        title: "Event cue",
                        detail: eventCueDetail(for: event),
                        style: event.kind == .travel ? .alert : .supportive
                    )
                )
            ]
        }
        .flatMap { $0 }

        let anchorBlocks = anchors.map { anchor in
            let startMinute = parseTimeLabel(anchor.timeLabel) ?? 9 * 60
            let endMinute = startMinute + max(anchor.totalMinutes, 15)
            return ScheduleBlock(
                kind: anchor.type == .recovery ? .recovery : .anchor,
                title: anchor.title,
                detail: anchor.prompt,
                startMinute: startMinute,
                endMinute: endMinute,
                anchorID: anchor.id,
                cue: cue(
                    for: anchor,
                    mode: mode,
                    assessment: assessment,
                    estimatedState: estimatedState,
                    planningFeedback: planningFeedback
                )
            )
        }

        let primaryBlocks = (routineBlocks + projectBlocks + eventBlocks + anchorBlocks)
            .sorted { lhs, rhs in
                if lhs.startMinute == rhs.startMinute {
                    let lhsPriority = blockPriority(lhs)
                    let rhsPriority = blockPriority(rhs)
                    if lhsPriority == rhsPriority {
                        return lhs.endMinute < rhs.endMinute
                    }
                    return lhsPriority < rhsPriority
                }
                return lhs.startMinute < rhs.startMinute
            }

        var blocks: [ScheduleBlock] = []
        var previousEnd: Int?

        for block in primaryBlocks {
            if let previousEnd {
                let feedbackBufferBoost = planningFeedback.rebuildPressure >= 2 ? 5 : 0
                let overloadBufferBoost = estimatedState.executionState == .overloaded ? 5 : 0
                let maxBuffer = (mode == .full ? 10 : 15) + feedbackBufferBoost + overloadBufferBoost + confidenceProfile.bufferBoost
                let bufferDuration = min(max(block.startMinute - previousEnd, 0), maxBuffer)
                if bufferDuration >= 10 {
                    blocks.append(
                        ScheduleBlock(
                            kind: .buffer,
                            title: "Buffer",
                            detail: "Use this space to breathe, reset, or prepare the next move.",
                            startMinute: block.startMinute - bufferDuration,
                            endMinute: block.startMinute,
                            cue: ScheduleCue(
                                title: "Protect the gap",
                                detail: "Let this be transition time instead of accidental overflow.",
                                style: .calm
                            )
                        )
                    )
                }

                if shouldInsertTransition(before: block, previousEnd: previousEnd) {
                    let transitionWindow = transitionLeadMinutes(
                        before: block,
                        estimatedState: estimatedState,
                        planningFeedback: planningFeedback
                    )
                    let transitionStart = max(previousEnd, block.startMinute - transitionWindow)
                    if transitionStart < block.startMinute {
                        blocks.append(
                            ScheduleBlock(
                                kind: .transition,
                                title: "Transition into \(block.title)",
                                detail: "Make the next step visible and remove one source of friction.",
                                startMinute: transitionStart,
                                endMinute: block.startMinute,
                                anchorID: block.anchorID,
                                cue: ScheduleCue(
                                    title: "Switch gently",
                                    detail: "Gather what you need before the block begins.",
                                    style: .supportive
                                )
                            )
                        )
                    }
                }
            }

            blocks.append(block)
            previousEnd = max(previousEnd ?? block.endMinute, block.endMinute)
        }

        return DailyPlan(
            blocks: blocks.sorted { $0.startMinute < $1.startMinute },
            supportSummary: confidenceProfile.isLowConfidence
                ? "\(assessment.supportFocus) Keep extra margin because the current signals are less certain than usual."
                : assessment.supportFocus
        )
    }

    private func cue(
        for anchor: Anchor,
        mode: PlanMode,
        assessment: DayAssessment,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> ScheduleCue {
        let highTransitionRisk = estimatedState.transitionRisk[anchor.id, default: 0] >= 0.65 || planningFeedback.missedTransitionPressure >= 2

        switch anchor.type {
        case .focus:
            return ScheduleCue(
                title: "Stay with one lane",
                detail: mode == .minimum
                    ? "Keep the task tiny and visible."
                    : (planningFeedback.rebuildPressure >= 2
                        ? "Protect attention by staying with the same work and leaving a clean stopping point."
                        : (planningFeedback.tooIntensePressure >= 2
                            ? "Keep the task present with softer support and less pressure."
                            : "Protect attention by staying with the same work.")),
                style: mode == .full ? .supportive : .calm
            )
        case .maintenance:
            return ScheduleCue(
                title: "Contain overhead",
                detail: "Only do the coordination that protects today and tomorrow.",
                style: .supportive
            )
        case .transition:
            return ScheduleCue(
                title: "Prepare the switch",
                detail: highTransitionRisk
                    ? "Transitions deserve extra support here. Slow down the handoff and make departure steps explicit."
                    : "Transitions deserve their own support, especially on high-friction days.",
                style: highTransitionRisk ? .alert : (assessment.recommendedMode == .minimum ? .calm : .supportive)
            )
        case .recovery:
            return ScheduleCue(
                title: "Recovery counts",
                detail: planningFeedback.rebuildPressure >= 2
                    ? "Protect decompression so the day can reset cleanly if it slips."
                    : "Protect decompression so the day does not sprawl.",
                style: .calm
            )
        }
    }

    private func suggestedProjectBlocks(
        for context: DayContext,
        mode: PlanMode,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> [ScheduleBlock] {
        let incompleteProjects = context.projects
            .filter { $0.remainingMinutes > 0 }
            .sorted { lhs, rhs in
                if lhs.daysUntilDue(from: context.date) == rhs.daysUntilDue(from: context.date) {
                    return lhs.dailyMinutesNeeded(from: context.date) > rhs.dailyMinutesNeeded(from: context.date)
                }
                return lhs.daysUntilDue(from: context.date) < rhs.daysUntilDue(from: context.date)
            }

        guard !incompleteProjects.isEmpty else { return [] }

        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let modeBlockLimit: Int = {
            switch mode {
            case .full: return confidenceProfile.isLowConfidence ? 1 : 2
            case .reduced: return 1
            case .minimum: return 1
            }
        }()

        let urgentProjects = incompleteProjects.filter { project in
            let daysUntilDue = project.daysUntilDue(from: context.date)
            if mode == .minimum {
                return daysUntilDue <= 1
            }
            return daysUntilDue <= 3 || project.dailyMinutesNeeded(from: context.date) >= 45
        }

        let candidates = (urgentProjects.isEmpty ? Array(incompleteProjects.prefix(1)) : Array(urgentProjects.prefix(modeBlockLimit)))

        return candidates.compactMap { project in
            guard let subtask = project.remainingSubtasks.first else { return nil }

            let blockMinutes = suggestedProjectMinutes(
                for: project,
                subtask: subtask,
                mode: mode,
                estimatedState: estimatedState,
                planningFeedback: planningFeedback
            )
            let startMinute = suggestedProjectStartMinute(
                for: project,
                mode: mode,
                estimatedState: estimatedState,
                planningFeedback: planningFeedback
            )
            let detail = projectBlockDetail(for: project, subtask: subtask)
            return ScheduleBlock(
                kind: .project,
                title: subtask.title,
                detail: detail,
                startMinute: startMinute,
                endMinute: startMinute + blockMinutes,
                cue: ScheduleCue(
                    title: "Project progress",
                    detail: projectCueDetail(for: project, mode: mode, planningFeedback: planningFeedback),
                    style: projectCueStyle(for: project, mode: mode, planningFeedback: planningFeedback)
                )
            )
        }
    }

    private func eventSupportBlocks(for event: DayEvent) -> [ScheduleBlock] {
        guard event.shouldGenerateTransitionSupport else { return [] }
        var blocks: [ScheduleBlock] = []

        if let feltDeadlineOffset = event.supportMetadata.feltDeadlineOffsetMinutes, feltDeadlineOffset > 0 {
            let feltDeadlineMinute = max(event.startMinute - feltDeadlineOffset, 0)
            let feltDeadlineEnd = min(feltDeadlineMinute + 10, event.startMinute)
            if feltDeadlineMinute < feltDeadlineEnd {
                blocks.append(
                    ScheduleBlock(
                        kind: .transition,
                        title: "Felt deadline for \(event.title)",
                        detail: "Treat this as the wrap-up point so the event does not become a last-minute sprint.",
                        startMinute: feltDeadlineMinute,
                        endMinute: feltDeadlineEnd,
                        cue: ScheduleCue(
                            title: "Start moving early",
                            detail: "Use the felt deadline to shift attention before the real start time arrives.",
                            style: .alert
                        )
                    )
                )
            }
        }

        let prepMinutes = event.supportMetadata.transitionPrepMinutes
        let prepStart = event.prepStartMinute
        let prepEnd = event.leaveByMinute ?? event.startMinute
        if prepMinutes > 0, prepStart < prepEnd {
            blocks.append(
                ScheduleBlock(
                    kind: .transition,
                    title: event.leaveByMinute == nil ? "Prep for \(event.title)" : "Get ready to leave for \(event.title)",
                    detail: prepDetail(for: event),
                    startMinute: prepStart,
                    endMinute: prepEnd,
                    cue: ScheduleCue(
                        title: "Transition support",
                        detail: "Gather what you need before the event begins.",
                        style: event.kind == .travel ? .alert : .supportive
                    )
                )
            )
        }

        if let leaveByMinute = event.leaveByMinute, leaveByMinute < event.startMinute {
            blocks.append(
                ScheduleBlock(
                    kind: .transition,
                    title: "Leave for \(event.title)",
                    detail: travelDetail(for: event),
                    startMinute: leaveByMinute,
                    endMinute: event.startMinute,
                    cue: ScheduleCue(
                        title: "Leave by \(clockString(for: leaveByMinute))",
                        detail: "Use the estimated drive time so arrival does not turn into a last-minute rush.",
                        style: .alert
                    )
                )
            )
        }

        return blocks
    }

    private func prepDetail(for event: DayEvent) -> String {
        if !event.supportMetadata.sensoryNote.isEmpty {
            return "Prep note: \(event.supportMetadata.sensoryNote)"
        }

        if let leaveByMinute = event.leaveByMinute {
            let locationText = event.supportMetadata.locationName.isEmpty ? "the destination" : event.supportMetadata.locationName
            return "Get departure items ready so you can leave by \(clockString(for: leaveByMinute)) for \(locationText)."
        }

        switch event.kind {
        case .travel:
            return "Leave with more buffer than feels necessary and get departure items ready first."
        case .recovery:
            return "Protect the handoff into recovery so it does not get eaten by spillover."
        case .commitment:
            return "Close open loops, gather materials, and reduce friction before this starts."
        }
    }

    private func eventDetail(for event: DayEvent) -> String {
        var parts = [event.detail]

        if !event.supportMetadata.locationName.isEmpty {
            parts.append("Location: \(event.supportMetadata.locationName)")
        }

        if let estimatedDriveMinutes = event.supportMetadata.estimatedDriveMinutes {
            parts.append("Drive \(estimatedDriveMinutes)m")
        }

        if let leaveByMinute = event.leaveByMinute {
            parts.append("Leave by \(clockString(for: leaveByMinute))")
        }

        if let feltDeadlineOffset = event.supportMetadata.feltDeadlineOffsetMinutes, feltDeadlineOffset > 0 {
            parts.append("Felt deadline \(clockString(for: max(event.startMinute - feltDeadlineOffset, 0)))")
        }

        if !event.supportMetadata.sensoryNote.isEmpty {
            parts.append("Sensory note: \(event.supportMetadata.sensoryNote)")
        }

        var seen = Set<String>()
        let dedupedParts = parts.filter { part in
            let normalized = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }

        return dedupedParts.joined(separator: " • ")
    }

    private func eventCueDetail(for event: DayEvent) -> String {
        if let leaveByMinute = event.leaveByMinute {
            return "Leave by \(clockString(for: leaveByMinute)) so travel and transition time stay protected."
        }

        if let feltDeadlineOffset = event.supportMetadata.feltDeadlineOffsetMinutes, feltDeadlineOffset > 0 {
            return "Treat \(clockString(for: max(event.startMinute - feltDeadlineOffset, 0))) like the time this really starts."
        }

        if !event.supportMetadata.sensoryNote.isEmpty {
            return event.supportMetadata.sensoryNote
        }

        return event.kind == .travel
            ? "Leave with more buffer than feels necessary."
            : "Keep this commitment visible so it does not sneak up on you."
    }

    private func travelDetail(for event: DayEvent) -> String {
        let locationText = event.supportMetadata.locationName.isEmpty ? "the event" : event.supportMetadata.locationName
        if let estimatedDriveMinutes = event.supportMetadata.estimatedDriveMinutes {
            return "Estimated drive time is \(estimatedDriveMinutes) minutes to \(locationText)."
        }
        return "Leave with enough margin to get to \(locationText) without compressing the transition."
    }

    private func shouldInsertTransition(before block: ScheduleBlock, previousEnd: Int) -> Bool {
        block.kind == .anchor || block.kind == .event || block.kind == .project
            ? block.startMinute > previousEnd
            : false
    }

    private func blockPriority(_ block: ScheduleBlock) -> Int {
        switch block.kind {
        case .event, .recovery:
            return 0
        case .routine:
            return 1
        case .project:
            return 2
        case .anchor:
            return 3
        case .transition:
            return 4
        case .buffer:
            return 5
        }
    }

    private func suggestedProjectMinutes(
        for project: Project,
        subtask: ProjectSubtask,
        mode: PlanMode,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> Int {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let duePressure = project.daysUntilDue() <= 1 ? 15 : (project.daysUntilDue() <= 3 ? 5 : 0)
        let rebuildAdjustment = planningFeedback.rebuildPressure >= 2 ? -10 : 0
        let modeBase: Int = {
            switch mode {
            case .full: return 50
            case .reduced: return 35
            case .minimum: return 20
            }
        }()
        let confidenceAdjustment = confidenceProfile.isLowConfidence ? -10 : 0
        let target = modeBase + duePressure + rebuildAdjustment + confidenceAdjustment
        return min(max(target, 15), max(subtask.estimatedMinutes, 15))
    }

    private func suggestedProjectStartMinute(
        for project: Project,
        mode: PlanMode,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> Int {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let dueSoon = project.daysUntilDue() <= 1
        let base: Int = {
            switch mode {
            case .full: return dueSoon ? 10 * 60 : 14 * 60
            case .reduced: return dueSoon ? 9 * 60 + 30 : 13 * 60
            case .minimum: return 15 * 60
            }
        }()
        let earlierForLatePressure = planningFeedback.tooLatePressure >= 2 ? -30 : 0
        let laterForIntensity = planningFeedback.tooIntensePressure >= 2 ? 30 : 0
        let confidenceShift = confidenceProfile.isLowConfidence ? -15 : 0
        return min(max(base + earlierForLatePressure + laterForIntensity + confidenceShift, 8 * 60), 18 * 60)
    }

    private func projectBlockDetail(for project: Project, subtask: ProjectSubtask) -> String {
        let urgency = project.urgencySummary
        return "\(project.title) • \(subtask.estimatedMinutes)m • \(urgency)"
    }

    private func projectCueDetail(for project: Project, mode: PlanMode, planningFeedback: PlanningFeedback) -> String {
        if project.daysUntilDue() == 0 {
            return "Keep this block concrete so the project moves before end-of-day pressure takes over."
        }
        if planningFeedback.rebuildPressure >= 2 {
            return "Protect a small project step here so long-term work survives a wobbly day."
        }
        switch mode {
        case .full:
            return "Use this block to make visible project progress without letting it disappear behind urgent tasks."
        case .reduced:
            return "Keep the project step small and finishable so it builds continuity instead of pressure."
        case .minimum:
            return "A very small step here keeps the project from going fully invisible."
        }
    }

    private func projectCueStyle(for project: Project, mode: PlanMode, planningFeedback: PlanningFeedback) -> CueStyle {
        if project.daysUntilDue() == 0 {
            return .alert
        }
        if planningFeedback.tooIntensePressure >= 2 || mode == .minimum {
            return .calm
        }
        return .supportive
    }

    private func transitionLeadMinutes(
        before block: ScheduleBlock,
        estimatedState: EstimatedState,
        planningFeedback: PlanningFeedback
    ) -> Int {
        let confidenceProfile = confidencePlanningProfile(for: estimatedState)
        let base = 10
        let riskBoost = {
            if let anchorID = block.anchorID, estimatedState.transitionRisk[anchorID, default: 0] >= 0.65 {
                return 5
            }
            return block.kind == .event && estimatedState.latenessRisk.values.contains(where: { $0 >= 0.65 }) ? 5 : 0
        }()
        let feedbackBoost = planningFeedback.missedTransitionPressure >= 2 || planningFeedback.tooLatePressure >= 2 ? 5 : 0
        let tooEarlyAdjustment = planningFeedback.tooEarlyPressure >= 2 ? -3 : 0
        return max(base + riskBoost + feedbackBoost + tooEarlyAdjustment + confidenceProfile.transitionLeadBoost, 5)
    }

    private func makePlanningFeedback(from outcomes: [DayOutcome]) -> PlanningFeedback {
        let recent = Array(outcomes.suffix(5))
        let rebuildPressure = recent.reduce(0) { $0 + $1.rebuildDayCount }
        let missedTransitionPressure = recent.reduce(0) { $0 + $1.missedTransitionBlockIDs.count }
        let dismissedCuePressure = recent
            .flatMap(\.cueResponses)
            .filter { $0.result == .dismissed || $0.result == .overstimulating }
            .count
        let failureReasons = recent.flatMap(\.cueResponses).compactMap(\.failureReason)
        let tooLatePressure = failureReasons.filter { $0 == .tooLate }.count
        let tooEarlyPressure = failureReasons.filter { $0 == .tooEarly }.count
        let tooIntensePressure = failureReasons.filter { $0 == .tooIntense }.count
        return PlanningFeedback(
            rebuildPressure: rebuildPressure,
            missedTransitionPressure: missedTransitionPressure,
            dismissedCuePressure: dismissedCuePressure,
            tooLatePressure: tooLatePressure,
            tooEarlyPressure: tooEarlyPressure,
            tooIntensePressure: tooIntensePressure
        )
    }

    private func confidencePlanningProfile(for estimatedState: EstimatedState) -> ConfidencePlanningProfile {
        let isVeryLowConfidence = estimatedState.confidence < 0.35
        let isLowConfidence = estimatedState.confidence < 0.55
        let supportLine: String?

        if isVeryLowConfidence {
            supportLine = "Signals are mixed right now, so keep this step lighter than usual and protect a fallback path."
        } else if isLowConfidence {
            supportLine = "The picture for today is a little uncertain, so leave extra room around this step."
        } else {
            supportLine = nil
        }

        return ConfidencePlanningProfile(
            isLowConfidence: isLowConfidence,
            isVeryLowConfidence: isVeryLowConfidence,
            allowStretchWork: !isLowConfidence,
            bufferBoost: isVeryLowConfidence ? 10 : (isLowConfidence ? 5 : 0),
            transitionLeadBoost: isVeryLowConfidence ? 8 : (isLowConfidence ? 4 : 0),
            supportLine: supportLine
        )
    }

    private struct PlanningFeedback {
        let rebuildPressure: Int
        let missedTransitionPressure: Int
        let dismissedCuePressure: Int
        let tooLatePressure: Int
        let tooEarlyPressure: Int
        let tooIntensePressure: Int
    }

    private struct ConfidencePlanningProfile {
        let isLowConfidence: Bool
        let isVeryLowConfidence: Bool
        let allowStretchWork: Bool
        let bufferBoost: Int
        let transitionLeadBoost: Int
        let supportLine: String?
    }

    private func inferredStartMinute(for routine: Routine, fallbackIndex: Int) -> Int {
        let lowercased = routine.timeWindow.lowercased()
        if lowercased.contains("before 9") { return 8 * 60 }
        if lowercased.contains("evening") || lowercased.contains("after the last") { return 20 * 60 }
        if lowercased.contains("focus") { return 9 * 60 }
        return (7 + fallbackIndex) * 60
    }

    private func parseTimeLabel(_ label: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: label) else { return nil }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return (hour * 60) + minute
    }

    private func clockString(for minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }
}
