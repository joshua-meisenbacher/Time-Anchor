import Foundation

protocol StateEstimator {
    func estimate(
        context: DayContext,
        anchors: [Anchor],
        assessment: DayAssessment,
        profileSettings: ProfileSettings,
        baselines: PersonalizedBaselines
    ) -> EstimatedState
}

protocol OutcomeLogger {
    func record(_ outcome: DayOutcome)
    func outcomes() -> [DayOutcome]
}

protocol ReminderOrchestrator {
    func reminderPlan(
        for task: Task,
        dailyState: DailyState,
        profileSettings: ProfileSettings,
        estimatedState: EstimatedState,
        recentOutcomes: [DayOutcome],
        baselines: PersonalizedBaselines
    ) -> ReminderPlan
}

protocol AdaptiveProfileStore {
    func baselines(for profileID: UUID, recentHealthSignals: [HealthSignals], outcomes: [DayOutcome]) -> PersonalizedBaselines
}

protocol HealthSupportEvaluator {
    func evaluate(
        context: DayContext,
        baselines: PersonalizedBaselines,
        recentOutcomes: [DayOutcome]
    ) -> LiveHealthState
}

protocol LiveExecutionMonitor {
    func evaluate(
        now: Date,
        currentBlock: ScheduleBlock?,
        currentTask: Task?,
        activeTaskStartedAt: Date?,
        currentDayOutcome: DayOutcome,
        recentOutcomes: [DayOutcome],
        routinePauseStartedAt: Date?,
        estimatedState: EstimatedState
    ) -> LiveExecutionState
}

protocol AdaptiveReplanEngine {
    func suggest(
        liveExecutionState: LiveExecutionState,
        liveHealthState: LiveHealthState,
        estimatedState: EstimatedState,
        currentMode: PlanMode,
        assessment: DayAssessment
    ) -> ReplanSuggestion?
}

protocol InsightsEngine {
    func generateInsights(
        outcomes: [DayOutcome],
        baselines: PersonalizedBaselines,
        estimatedState: EstimatedState,
        liveHealthState: LiveHealthState
    ) -> [InsightCard]
}

struct HeuristicStateEstimator: StateEstimator {
    func estimate(
        context: DayContext,
        anchors: [Anchor],
        assessment: DayAssessment,
        profileSettings: ProfileSettings,
        baselines: PersonalizedBaselines
    ) -> EstimatedState {
        var overloadRisk = min(max(Double(assessment.loadScore) / 10.0, 0.0), 1.0)
        let capacityBand: CapacityBand

        switch assessment.recommendedMode {
        case .minimum:
            capacityBand = .low
        case .reduced:
            capacityBand = .medium
        case .full:
            capacityBand = .high
        }

        var transitionRisk: [UUID: Double] = [:]
        var latenessRisk: [UUID: Double] = [:]

        let transitionBase = min(max((Double(context.dailyState.transitionFriction) - 1) / 4.0, 0.0), 1.0)
        let latenessBase = min(max(Double(context.events.count) / 4.0, 0.0), 1.0)

        for anchor in anchors {
            let taskDensity = min(Double(anchor.tasks.count) / 4.0, 1.0)
            transitionRisk[anchor.id] = min(1.0, transitionBase + (taskDensity * 0.25))
        }

        for event in context.events {
            let prepMinutes = Double(event.supportMetadata.transitionPrepMinutes)
            let estimatedDriveMinutes = Double(event.supportMetadata.estimatedDriveMinutes ?? 0)
            let travelPressure = min((prepMinutes + estimatedDriveMinutes) / 60.0, 1.0)
            latenessRisk[event.id] = min(1.0, latenessBase + (travelPressure * 0.35))
        }

        let executionState: ExecutionState
        if context.dailyState.sensoryLoad >= 5 || context.dailyState.stress >= 5 {
            executionState = .overloaded
        } else if context.dailyState.transitionFriction >= 4 {
            executionState = .drifting
        } else if context.dailyState.energy <= 2 {
            executionState = .interrupted
        } else {
            executionState = .onTrack
        }

        let healthSignalCount = [
            context.healthSignals.sleepHours,
            context.healthSignals.hydrationLiters,
            context.healthSignals.restingHeartRate.map(Double.init),
            context.healthSignals.recentHeartRate.map(Double.init),
            context.healthSignals.heartRateVariabilityMilliseconds,
            context.healthSignals.respiratoryRate
        ]
        .compactMap { $0 }
        .count

        let confidence = min(1.0, 0.25 + (Double(healthSignalCount) * 0.1) + (context.events.isEmpty ? 0.0 : 0.15))
        if baselines.rebuildsPerDay >= 1.25 {
            overloadRisk = min(1.0, overloadRisk + 0.1)
        }
        if baselines.transitionMissRate >= 0.2 {
            for key in transitionRisk.keys {
                transitionRisk[key] = min(1.0, transitionRisk[key, default: 0] + 0.1)
            }
        }

        var supportingSignals = assessment.capacityDrivers
        if let baselineSleep = baselines.typicalSleepHours, let sleepHours = context.healthSignals.sleepHours {
            let sleepDelta = sleepHours - baselineSleep
            if abs(sleepDelta) >= 0.75 {
                supportingSignals.append(
                    sleepDelta < 0
                    ? String(format: "Sleep is running about %.1f hours below your recent baseline.", abs(sleepDelta))
                    : String(format: "Sleep is running about %.1f hours above your recent baseline.", sleepDelta)
                )
            }
        }
        if profileSettings.primarySupportFocus == .transitions {
            supportingSignals.append("Your profile prioritizes transition support, so switching risk is weighted more heavily.")
        }
        if let typicalCueResponseDelaySeconds = baselines.typicalCueResponseDelaySeconds, typicalCueResponseDelaySeconds >= 240 {
            supportingSignals.append("You usually need a little more runway before cues turn into action, so support should arrive earlier.")
        }
        if baselines.rebuildsPerDay >= 1.25 {
            supportingSignals.append("Recent days often needed rebuilding, so the app is leaning toward extra continuity and buffer.")
        }
        if baselines.transitionMissRate >= 0.2 {
            supportingSignals.append("Transitions have been a common friction point recently, so handoff risk is being weighted more heavily.")
        }

        return EstimatedState(
            capacityBand: capacityBand,
            overloadRisk: overloadRisk,
            transitionRisk: transitionRisk,
            latenessRisk: latenessRisk,
            executionState: executionState,
            confidence: confidence,
            supportingSignals: Array(supportingSignals.prefix(6))
        )
    }
}

final class InMemoryOutcomeLogger: OutcomeLogger {
    private var storedOutcomes: [DayOutcome] = []

    func record(_ outcome: DayOutcome) {
        let calendar = Calendar.current
        storedOutcomes.removeAll { calendar.isDate($0.date, inSameDayAs: outcome.date) }
        storedOutcomes.append(outcome)
        storedOutcomes.sort { $0.date < $1.date }
    }

    func outcomes() -> [DayOutcome] {
        storedOutcomes
    }
}

struct AdaptiveReminderOrchestrator: ReminderOrchestrator {
    func reminderPlan(
        for task: Task,
        dailyState: DailyState,
        profileSettings: ProfileSettings,
        estimatedState: EstimatedState,
        recentOutcomes: [DayOutcome],
        baselines: PersonalizedBaselines
    ) -> ReminderPlan {
        let outcomeWindow = Array(recentOutcomes.suffix(5))
        let rebuildPressure = outcomeWindow.reduce(0) { $0 + $1.rebuildDayCount }
        let missedTransitions = outcomeWindow.reduce(0) { $0 + $1.missedTransitionBlockIDs.count }
        let dismissedCueCount = outcomeWindow
            .flatMap(\.cueResponses)
            .filter { $0.result == .dismissed || $0.result == .overstimulating }
            .count
        let actedOnCueCount = outcomeWindow
            .flatMap(\.cueResponses)
            .filter { $0.result == .actedOn || $0.result == .helpful }
            .count
        let failureReasons = outcomeWindow.flatMap(\.cueResponses).compactMap(\.failureReason)
        let tooEarlyCount = failureReasons.filter { $0 == .tooEarly }.count
        let tooLateCount = failureReasons.filter { $0 == .tooLate }.count
        let tooIntenseCount = failureReasons.filter { $0 == .tooIntense }.count
        let alreadyMovingCount = failureReasons.filter { $0 == .alreadyMoving }.count

        let highFriction = dailyState.transitionFriction >= 4 || estimatedState.executionState == .drifting || estimatedState.executionState == .interrupted
        let overloadRisk = estimatedState.overloadRisk >= 0.7
        let behaviorPressure = rebuildPressure >= 2 || missedTransitions >= 2
        let overstimulationRisk = tooIntenseCount >= 2 || (dismissedCueCount > actedOnCueCount && dismissedCueCount >= 2)
        let baselineLeadBias = (baselines.typicalCueResponseDelaySeconds ?? 0) >= 240 ? 3 : 0
        let baselineLateStartBias = (baselines.typicalLateStartMinutes ?? 0) >= 8 ? 4 : 0
        let transitionLead = max(profileSettings.transitionPrepMinutes, 0)
            + baselineLeadBias
            + baselineLateStartBias
            + (tooLateCount >= 2 ? 5 : (tooEarlyCount >= 2 ? -3 : 0))
        let boundedTransitionLead = max(0, transitionLead)
        let alreadyInMotion = alreadyMovingCount >= 2
        let highBaselineRebuildPattern = baselines.rebuildsPerDay >= 1.25
        let lowRoutineRecovery = baselines.routineResumeRate < 0.6

        switch dailyState.reminderProfile {
        case .balanced:
            return ReminderPlan(
                profile: .balanced,
                leadTimeMinutes: task.startMinute == nil ? 0 : boundedTransitionLead,
                repeatIntervalMinutes: overstimulationRisk ? 14 : (behaviorPressure || highFriction || highBaselineRebuildPattern ? 8 : 12),
                maxRepeats: alreadyInMotion ? 1 : (overloadRisk ? 2 : ((behaviorPressure || highFriction || lowRoutineRecovery) ? 3 : 2)),
                tone: "Clear and supportive",
                escalationRule: overstimulationRisk
                    ? "Reduce repetition because recent cues look easy to bounce off when the day feels loud."
                    : (tooLateCount >= 2
                        ? "Shift the prompts earlier because support has been arriving after the useful moment."
                        : "Escalate when friction or rebuild pressure is high, but stay predictable and avoid stacking reminders too tightly."),
                sampleCopy: overstimulationRisk
                    ? "A calm check-in: \(task.title) is still here when it feels workable to return."
                    : (alreadyInMotion
                        ? "A light check-in: keep going with \(task.title) and stay in the same lane."
                        : "Your next task is ready when you are. Start with one small step: \(task.title).")
            )
        case .repetitiveSupport:
            return ReminderPlan(
                profile: .repetitiveSupport,
                leadTimeMinutes: task.startMinute == nil ? 0 : max(boundedTransitionLead, 12),
                repeatIntervalMinutes: overstimulationRisk ? 10 : (overloadRisk ? 8 : ((behaviorPressure || highBaselineRebuildPattern) ? 5 : 6)),
                maxRepeats: alreadyInMotion ? 2 : (overloadRisk ? 3 : ((behaviorPressure || lowRoutineRecovery) ? 5 : 4)),
                tone: "Brief, repeatable, momentum-focused",
                escalationRule: overstimulationRisk
                    ? "Keep the prompts present but slightly farther apart because recent support looks easy to tune out."
                    : (tooLateCount >= 2
                        ? "Start prompts earlier and keep them compact because late support has not been enough."
                        : "Use repeat prompts when execution drift, missed transitions, or rebuild usage are showing up."),
                sampleCopy: behaviorPressure
                    ? "Time Anchor check-in: \(task.title) is the lane to come back to. Open it and do the first visible step."
                    : "Time Anchor check-in: \(task.title) is next. Open it and start the first step now."
            )
        case .gentleSupport:
            return ReminderPlan(
                profile: .gentleSupport,
                leadTimeMinutes: task.startMinute == nil ? 0 : max(boundedTransitionLead, 15),
                repeatIntervalMinutes: overloadRisk || overstimulationRisk ? nil : ((behaviorPressure || highBaselineRebuildPattern) ? 12 : 15),
                maxRepeats: alreadyInMotion ? 1 : (overloadRisk ? 1 : ((behaviorPressure || lowRoutineRecovery) && !overstimulationRisk ? 3 : 2)),
                tone: "Low-pressure and invitational",
                escalationRule: "Prioritize continuity over urgency, especially when recent cues looked easy to dismiss or the day needed rebuilding.",
                sampleCopy: behaviorPressure
                    ? "A gentle reminder: \(task.title) is still the next lane. Re-enter it when you can with one small step."
                    : "A gentle reminder: \(task.title) is coming up. You can prepare when it feels doable."
            )
        }
    }
}

struct BaselineAdaptiveProfileStore: AdaptiveProfileStore {
    func baselines(for profileID: UUID, recentHealthSignals: [HealthSignals], outcomes: [DayOutcome]) -> PersonalizedBaselines {
        let cueDelays = outcomes
            .flatMap(\.cueResponses)
            .compactMap(\.responseDelaySeconds)
            .map(Double.init)
        let lateStartMinutes = outcomes
            .flatMap(\.lateStartMinutesByBlockID.values)
            .map(Double.init)
        let rebuildsPerDay = average(outcomes.map { Double($0.rebuildDayCount) }) ?? 0
        let transitionAttempts = outcomes.reduce(0.0) { partial, outcome in
            partial + Double(max(outcome.missedTransitionBlockIDs.count + outcome.lateStartMinutesByBlockID.count, 1))
        }
        let transitionMisses = Double(outcomes.reduce(0) { $0 + $1.missedTransitionBlockIDs.count })
        let pauseCount = Double(outcomes.reduce(0) { $0 + $1.routinePauseCount })
        let resumeCount = Double(outcomes.reduce(0) { $0 + $1.routineResumeCount })

        return PersonalizedBaselines(
            typicalSleepHours: average(recentHealthSignals.compactMap(\.sleepHours)),
            typicalHydrationLiters: average(recentHealthSignals.compactMap(\.hydrationLiters)),
            typicalRestingHeartRate: average(recentHealthSignals.compactMap { $0.restingHeartRate.map(Double.init) }),
            typicalHeartRateVariabilityMilliseconds: average(recentHealthSignals.compactMap(\.heartRateVariabilityMilliseconds)),
            typicalRespiratoryRate: average(recentHealthSignals.compactMap(\.respiratoryRate)),
            typicalCueResponseDelaySeconds: average(cueDelays),
            typicalLateStartMinutes: average(lateStartMinutes),
            rebuildsPerDay: rebuildsPerDay,
            transitionMissRate: transitionAttempts > 0 ? (transitionMisses / transitionAttempts) : 0,
            routineResumeRate: pauseCount > 0 ? min(max(resumeCount / pauseCount, 0), 1) : 1,
            typicalRecoveryScore: average(recentHealthSignals.compactMap { $0.recoveryScore.map(Double.init) })
        )
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

struct HeuristicHealthSupportEvaluator: HealthSupportEvaluator {
    func evaluate(
        context: DayContext,
        baselines: PersonalizedBaselines,
        recentOutcomes: [DayOutcome]
    ) -> LiveHealthState {
        let health = context.healthSignals
        var strainRisk = 0.0
        var confidence = 0.15
        var signals: [String] = []
        var recommendations: [RecoveryRecommendation] = []

        if let sleepHours = health.sleepHours {
            confidence += 0.15
            if sleepHours < 6 {
                strainRisk += 0.18
                let bedtimeHour = sleepHours < 5 ? "9:00 PM" : "9:30 PM"
                signals.append(String(format: "Sleep was light at %.1f hours.", sleepHours))
                recommendations.append(
                    RecoveryRecommendation(
                        kind: .earlierBedtime,
                        title: "Aim for an earlier bedtime tonight",
                        summary: "Last night was short, so a quieter evening and a \(bedtimeHour) wind-down target would likely help tomorrow land better."
                    )
                )
            }
        }

        if let hydrationLiters = health.hydrationLiters,
           let baselineHydration = baselines.typicalHydrationLiters,
           hydrationLiters < max(1.0, baselineHydration * 0.7) {
            confidence += 0.1
            strainRisk += 0.12
            signals.append(String(format: "Hydration is behind your recent baseline at %.1f liters so far.", hydrationLiters))
            recommendations.append(
                RecoveryRecommendation(
                    kind: .hydrateSoon,
                    title: "Hydrate before the next transition",
                    summary: "A water reset now may make the next block and the next switch cost less."
                )
            )
        }

        if let recentHeartRate = health.recentHeartRate,
           let baselineRestingHeartRate = baselines.typicalRestingHeartRate {
            confidence += 0.2
            let heartRateDelta = Double(recentHeartRate) - baselineRestingHeartRate
            let likelyActivityDriven = (health.exerciseMinutes ?? 0) >= 20 || (health.activeEnergyKilocalories ?? 0) >= 350
            if heartRateDelta >= 18 && !likelyActivityDriven {
                strainRisk += 0.2
                signals.append("Recent heart rate is running well above your usual baseline without a clear activity explanation.")
            } else if heartRateDelta >= 10 && !likelyActivityDriven {
                strainRisk += 0.12
                signals.append("Recent heart rate is somewhat elevated relative to baseline.")
            }
        }

        if let hrv = health.heartRateVariabilityMilliseconds,
           let baselineHRV = baselines.typicalHeartRateVariabilityMilliseconds,
           hrv < baselineHRV * 0.75 {
            confidence += 0.15
            strainRisk += 0.15
            signals.append(String(format: "HRV is below your recent baseline at %.0f ms.", hrv))
        }

        if let respiratoryRate = health.respiratoryRate,
           let baselineRespiratoryRate = baselines.typicalRespiratoryRate,
           respiratoryRate > baselineRespiratoryRate + 1.5 {
            confidence += 0.1
            strainRisk += 0.1
            signals.append(String(format: "Respiratory rate is running above your recent baseline at %.1f.", respiratoryRate))
        }

        if context.dailyState.stress >= 4 || context.dailyState.sensoryLoad >= 4 {
            strainRisk += 0.12
            signals.append("Self-reported stress or sensory load is already elevated.")
        }

        let recentRebuilds = recentOutcomes.suffix(3).reduce(0) { $0 + $1.rebuildDayCount }
        if recentRebuilds >= 2 {
            strainRisk += 0.08
            signals.append("Recent days have needed rebuilding, so the app is assuming less reserve than the calendar alone suggests.")
        }

        strainRisk = min(max(strainRisk, 0), 1)
        confidence = min(max(confidence, 0), 1)

        if strainRisk >= 0.7 {
            recommendations.append(
                RecoveryRecommendation(
                    kind: .protectRecoveryBlock,
                    title: "Protect recovery before the next demanding block",
                    summary: "The signals suggest the day may be tipping into overwhelm. A lower-demand bridge or decompression block would likely help."
                )
            )
            recommendations.append(
                RecoveryRecommendation(
                    kind: .softenSupport,
                    title: "Use gentler support for a bit",
                    summary: "Reducing cue intensity and lowering friction may work better than pushing harder right now."
                )
            )
        } else if strainRisk >= 0.45 {
            recommendations.append(
                RecoveryRecommendation(
                    kind: .shrinkNextStep,
                    title: "Shrink the next step",
                    summary: "Keeping the next block smaller would likely preserve continuity better than trying to hold the original scope."
                )
            )
        }

        if let sleepDebtHours = health.sleepDebtHours, sleepDebtHours >= 1.5 {
            recommendations.append(
                RecoveryRecommendation(
                    kind: .lightenEvening,
                    title: "Lighten the evening load",
                    summary: "Sleep debt is building, so tonight should probably protect shutdown and avoid extra commitments."
                )
            )
        }

        let status: LiveHealthStatus
        let summary: String
        switch strainRisk {
        case 0.7...:
            status = .overwhelmed
            summary = "Health signals suggest overwhelm is likely right now, so the schedule should get gentler."
        case 0.45...:
            status = .strained
            summary = "Health signals suggest the day is getting heavier, so the next steps should stay smaller and more protected."
        default:
            status = .stable
            summary = health.hasAnyData
                ? "Health signals look stable enough to support the current plan."
                : "There is not enough live health data yet to adjust support from physiology."
        }

        return LiveHealthState(
            status: status,
            strainRisk: strainRisk,
            confidence: confidence,
            summary: summary,
            supportingSignals: Array(signals.prefix(4)),
            recoveryRecommendations: Array(recommendations.prefix(3))
        )
    }
}

struct HeuristicLiveExecutionMonitor: LiveExecutionMonitor {
    func evaluate(
        now: Date,
        currentBlock: ScheduleBlock?,
        currentTask: Task?,
        activeTaskStartedAt: Date?,
        currentDayOutcome: DayOutcome,
        recentOutcomes: [DayOutcome],
        routinePauseStartedAt: Date?,
        estimatedState: EstimatedState
    ) -> LiveExecutionState {
        var signals: [ExecutionDriftSignal] = []
        let currentMinute = Self.minuteOfDay(for: now)

        let transitionWindow: TransitionWindowState
        if let currentBlock {
            let startDelta = currentBlock.startMinute - currentMinute
            let minutesUntilStart = startDelta >= 0 ? startDelta : nil
            let minutesPastStart = startDelta < 0 ? abs(startDelta) : nil
            let riskBase: Double = {
                if let anchorID = currentBlock.anchorID {
                    return estimatedState.transitionRisk[anchorID, default: 0]
                }
                return currentBlock.kind == .event ? estimatedState.latenessRisk.values.max() ?? 0 : estimatedState.overloadRisk
            }()

            transitionWindow = TransitionWindowState(
                blockID: currentBlock.id,
                title: currentBlock.title,
                minutesUntilStart: minutesUntilStart,
                minutesPastStart: minutesPastStart,
                risk: riskBase,
                needsAttention: (minutesUntilStart != nil && minutesUntilStart! <= 10 && riskBase >= 0.65) || (minutesPastStart != nil && minutesPastStart! >= 5)
            )

            if activeTaskStartedAt == nil, currentTask != nil, let minutesPastStart, minutesPastStart >= 5 {
                signals.append(.taskStartingLate)
                if minutesPastStart >= 10 {
                    signals.append(.taskNotStartedAfterCue)
                }
            }
        } else {
            transitionWindow = .inactive
        }

        let recentCueResponses = Array(currentDayOutcome.cueResponses.suffix(8))
        let deliveredTaskCueWithoutStart = recentCueResponses.contains { response in
            response.context == .routineCue ? false : response.result == .delivered
        } && activeTaskStartedAt == nil
        if deliveredTaskCueWithoutStart {
            signals.append(.taskNotStartedAfterCue)
        }

        let recentRoutineCueMisses = recentCueResponses.filter {
            $0.context == .routineCue && $0.result == .ignored
        }.count
        if recentRoutineCueMisses >= 1 {
            signals.append(.routineCueNotLanding)
        }

        if currentDayOutcome.rebuildDayCount >= 2 {
            signals.append(.repeatedRebuilds)
        }

        if let routinePauseStartedAt {
            let pausedSeconds = max(Int(now.timeIntervalSince(routinePauseStartedAt)), 0)
            if pausedSeconds >= 600 {
                signals.append(.routinePausedTooLong)
            }
        }

        signals = Array(NSOrderedSet(array: signals)) as? [ExecutionDriftSignal] ?? signals

        let shouldSuggestReplan = signals.contains(.repeatedRebuilds)
            || signals.contains(.routinePausedTooLong)
            || (signals.contains(.taskNotStartedAfterCue) && signals.contains(.taskStartingLate))

        let summary: String
        if let strongest = signals.first {
            summary = strongest.supportText
        } else if transitionWindow.needsAttention {
            summary = "A transition window is approaching and may need a little more support."
        } else {
            summary = "Execution looks steady right now."
        }

        return LiveExecutionState(
            signals: signals,
            transitionWindow: transitionWindow,
            summary: summary,
            shouldSuggestReplan: shouldSuggestReplan
        )
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}

struct HeuristicAdaptiveReplanEngine: AdaptiveReplanEngine {
    func suggest(
        liveExecutionState: LiveExecutionState,
        liveHealthState: LiveHealthState,
        estimatedState: EstimatedState,
        currentMode: PlanMode,
        assessment: DayAssessment
    ) -> ReplanSuggestion? {
        if liveHealthState.status == .overwhelmed {
            return ReplanSuggestion(
                reason: .overloaded,
                recommendedMode: .minimum,
                title: "Shift into recovery-first support",
                summary: "Live health signals suggest overwhelm is likely right now. A gentler plan is more likely to hold than pushing through.",
                adjustments: [.protectRecovery, .softenCueIntensity, .shrinkFirstStep],
                shouldPrompt: true
            )
        }

        if liveHealthState.status == .strained, currentMode == .full {
            return ReplanSuggestion(
                reason: .overloaded,
                recommendedMode: .reduced,
                title: "Protect the next few blocks",
                summary: "Health signals suggest the day is getting heavier than the current plan assumes.",
                adjustments: [.dropStretchWork, .addTransitionRunway, .shrinkFirstStep],
                shouldPrompt: true
            )
        }

        let signals = Set(liveExecutionState.signals)
        guard !signals.isEmpty || liveExecutionState.shouldSuggestReplan else { return nil }

        if signals.contains(.routinePausedTooLong) || signals.contains(.repeatedRebuilds) {
            return ReplanSuggestion(
                reason: .overloaded,
                recommendedMode: .minimum,
                title: "Protect the next stretch",
                summary: "Recent drift suggests the current version of the day is asking too much. Tighten the plan around continuity and essentials.",
                adjustments: [.dropStretchWork, .protectRecovery, .reduceTransitions],
                shouldPrompt: true
            )
        }

        if signals.contains(.taskStartingLate) && signals.contains(.taskNotStartedAfterCue) {
            return ReplanSuggestion(
                reason: .stuck,
                recommendedMode: currentMode == .full ? .reduced : currentMode,
                title: "Make the start smaller",
                summary: "The current task is not landing cleanly. Shrinking the first move and removing extra switching should help momentum return.",
                adjustments: [.shrinkFirstStep, .dropStretchWork],
                shouldPrompt: true
            )
        }

        if signals.contains(.routineCueNotLanding) || liveExecutionState.transitionWindow.needsAttention {
            return ReplanSuggestion(
                reason: .transition,
                recommendedMode: currentMode == .full ? .reduced : currentMode,
                title: "Support the handoff",
                summary: "A transition is absorbing more effort than expected. Give the next handoff more runway and reduce avoidable switching.",
                adjustments: [.addTransitionRunway, .reduceTransitions, .softenCueIntensity],
                shouldPrompt: liveExecutionState.transitionWindow.risk >= 0.65 || estimatedState.executionState != .onTrack
            )
        }

        if estimatedState.executionState == .overloaded || estimatedState.overloadRisk >= 0.75 {
            return ReplanSuggestion(
                reason: .sensory,
                recommendedMode: .minimum,
                title: "Lower the pressure",
                summary: "Signals suggest the day has become heavier than planned. A calmer, lower-demand version is more likely to hold.",
                adjustments: [.softenCueIntensity, .protectRecovery, .reduceTransitions],
                shouldPrompt: true
            )
        }

        if assessment.recommendedMode != currentMode {
            return ReplanSuggestion(
                reason: .overloaded,
                recommendedMode: assessment.recommendedMode,
                title: "Return to the steadier plan",
                summary: "The current live state looks closer to the app's steadier recommendation than the active mode.",
                adjustments: [.dropStretchWork],
                shouldPrompt: false
            )
        }

        return nil
    }
}

struct HeuristicInsightsEngine: InsightsEngine {
    func generateInsights(
        outcomes: [DayOutcome],
        baselines: PersonalizedBaselines,
        estimatedState: EstimatedState,
        liveHealthState: LiveHealthState
    ) -> [InsightCard] {
        let recent = Array(outcomes.suffix(14))
        let cueResponses = recent.flatMap(\.cueResponses)
        let failureReasons = cueResponses.compactMap(\.failureReason)
        let tooLateCount = failureReasons.filter { $0 == .tooLate }.count
        let tooIntenseCount = failureReasons.filter { $0 == .tooIntense }.count
        let alreadyMovingCount = failureReasons.filter { $0 == .alreadyMoving }.count
        let lateStartValues = recent.flatMap { $0.lateStartMinutesByBlockID.values }
        let averageLateStart = lateStartValues.isEmpty ? nil : Double(lateStartValues.reduce(0, +)) / Double(lateStartValues.count)
        let totalRoutinePauses = recent.reduce(0) { $0 + $1.routinePauseCount }
        let totalRoutineResumes = recent.reduce(0) { $0 + $1.routineResumeCount }
        var insights: [InsightCard] = []

        if baselines.transitionMissRate >= 0.2 {
            insights.append(
                InsightCard(
                    category: .transitions,
                    priority: .high,
                    title: "Transitions need extra support",
                    summary: "Handoffs have been the most common friction point lately.",
                    supportingDetail: "Recent transition misses are high enough that earlier prep and lower switching demand are likely to help."
                )
            )
        }

        if tooLateCount >= 3 {
            insights.append(
                InsightCard(
                    category: .transitions,
                    priority: .high,
                    title: "Support is landing after the moment",
                    summary: "Recent feedback says prompts have often come too late to help the handoff.",
                    supportingDetail: "That usually means prep windows or leave-by support should start earlier than feels necessary."
                )
            )
        }

        if let typicalCueResponseDelaySeconds = baselines.typicalCueResponseDelaySeconds, typicalCueResponseDelaySeconds >= 240 {
            insights.append(
                InsightCard(
                    category: .cues,
                    priority: .medium,
                    title: "Earlier cues tend to land better",
                    summary: "You usually take a few minutes to respond after support appears.",
                    supportingDetail: "Typical response delay is about \(Int(typicalCueResponseDelaySeconds.rounded())) seconds, so earlier prompts may fit better than last-minute cues."
                )
            )
        }

        if tooIntenseCount >= 3 {
            insights.append(
                InsightCard(
                    category: .cues,
                    priority: .medium,
                    title: "Softer support may work better",
                    summary: "Recent cue feedback suggests current support intensity can feel like too much.",
                    supportingDetail: "Lower stimulation, fewer repeats, or calmer language may help cues stay usable instead of becoming another source of friction."
                )
            )
        }

        if alreadyMovingCount >= 3 {
            insights.append(
                InsightCard(
                    category: .cues,
                    priority: .low,
                    title: "Some cues are arriving after momentum starts",
                    summary: "You are sometimes already moving by the time support appears.",
                    supportingDetail: "That pattern usually means redundant escalation can back off without losing continuity."
                )
            )
        }

        if baselines.routineResumeRate < 0.6 {
            insights.append(
                InsightCard(
                    category: .routines,
                    priority: .medium,
                    title: "Paused routines often stay paused",
                    summary: "Once a routine breaks, it has been harder to resume cleanly.",
                    supportingDetail: "Keeping the current step very small and obvious is likely more helpful than showing the whole routine after an interruption."
                )
            )
        }

        if totalRoutinePauses >= 3, totalRoutineResumes < totalRoutinePauses {
            insights.append(
                InsightCard(
                    category: .routines,
                    priority: .medium,
                    title: "Routine interruptions are costing momentum",
                    summary: "Pauses have been happening more often than clean resumptions lately.",
                    supportingDetail: "Resume support works best when the next step stays small and visible instead of reopening the whole routine."
                )
            )
        }

        if baselines.rebuildsPerDay >= 1.25 {
            insights.append(
                InsightCard(
                    category: .planning,
                    priority: .high,
                    title: "The day often needs rebuilding",
                    summary: "Plans have been drifting enough to require frequent restructuring.",
                    supportingDetail: "That usually means the plan needs more buffer, fewer switches, or a smaller first version by default."
                )
            )
        }

        if let averageLateStart, averageLateStart >= 8 {
            insights.append(
                InsightCard(
                    category: .planning,
                    priority: .medium,
                    title: "Starts are slipping later than planned",
                    summary: "Recent blocks have often started after the intended handoff time.",
                    supportingDetail: "Average late start is about \(Int(averageLateStart.rounded())) minutes, so earlier runway or a smaller opening step may help the day hold together."
                )
            )
        }

        if estimatedState.overloadRisk >= 0.75 {
            insights.append(
                InsightCard(
                    category: .capacity,
                    priority: .high,
                    title: "Capacity looks more fragile today",
                    summary: "Current signals suggest the day may tip more easily than usual.",
                    supportingDetail: "Treat continuity and recovery as first-class work if the day starts slipping."
                )
            )
        }

        if liveHealthState.status != .stable {
            insights.append(
                InsightCard(
                    category: .health,
                    priority: liveHealthState.status == .overwhelmed ? .high : .medium,
                    title: liveHealthState.status == .overwhelmed ? "Health signals suggest overload right now" : "Health signals suggest rising strain",
                    summary: liveHealthState.summary,
                    supportingDetail: liveHealthState.supportingSignals.first ?? "The app is using current recovery and physiology signals to decide whether support should get gentler."
                )
            )
        }

        if insights.isEmpty, let lateStartAverage = baselines.typicalLateStartMinutes, lateStartAverage >= 5 {
            insights.append(
                InsightCard(
                    category: .planning,
                    priority: .low,
                    title: "Starts tend to run later than planned",
                    summary: "First actions are regularly landing a bit after their intended time.",
                    supportingDetail: "Typical late start is about \(Int(lateStartAverage.rounded())) minutes, so extra runway before the first block may help."
                )
            )
        }

        return insights
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                return lhs.title < rhs.title
            }
    }
}
