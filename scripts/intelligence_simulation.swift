import Foundation

@main
struct IntelligenceSimulation {
    static var totalChecks = 0
    static var passedChecks = 0

    @inline(__always)
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        totalChecks += 1
        if !condition() {
            fputs("❌ \(message)\n", stderr)
            exit(1)
        }
        passedChecks += 1
        print("✅ \(message)")
    }
    
    static func main() {
        let now = Date()
        let calendar = Calendar.current

        let cueTooLate = CueResponse(
            recordedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            context: .taskStart,
            responseDelaySeconds: 420,
            failureReason: .tooLate,
            result: .ignored
        )
        let cueTooIntense = CueResponse(
            recordedAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now,
            context: .taskStart,
            responseDelaySeconds: 260,
            failureReason: .tooIntense,
            result: .overstimulating
        )
        let cueAlreadyMoving = CueResponse(
            recordedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            context: .taskStart,
            responseDelaySeconds: 80,
            failureReason: .alreadyMoving,
            result: .helpful
        )

        let outcomes: [DayOutcome] = [
            DayOutcome(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                missedTransitionBlockIDs: [UUID()],
                lateStartMinutesByBlockID: [UUID(): 12],
                rebuildDayCount: 1,
                cueResponses: [cueTooLate]
            ),
            DayOutcome(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                missedTransitionBlockIDs: [],
                lateStartMinutesByBlockID: [UUID(): 6],
                rebuildDayCount: 0,
                cueResponses: [cueTooIntense, cueAlreadyMoving]
            )
        ]

        let healthSignals: [HealthSignals] = [
            HealthSignals(restingHeartRate: 72, averageHeartRate: 80, recentHeartRate: 84, heartRateVariabilityMilliseconds: 36, respiratoryRate: 16.5, sleepDebtHours: 1.2, recoveryScore: 58, hydrationLiters: 1.2, activeEnergyKilocalories: 320, exerciseMinutes: 14, stepCount: 4800, sleepHours: 6.2),
            HealthSignals(restingHeartRate: 68, averageHeartRate: 76, recentHeartRate: 81, heartRateVariabilityMilliseconds: 40, respiratoryRate: 15.8, sleepDebtHours: 0.8, recoveryScore: 64, hydrationLiters: 1.5, activeEnergyKilocalories: 410, exerciseMinutes: 22, stepCount: 7100, sleepHours: 7.1)
        ]

        let baselineStore = BaselineAdaptiveProfileStore()
        let baselines = baselineStore.baselines(for: UUID(), recentHealthSignals: healthSignals, outcomes: outcomes)

        check(baselines.preferredLeadTimeMinutes != nil, "Expected preferred lead time to be inferred from cue history.")
        check(baselines.preferredRepeatIntervalMinutes != nil, "Expected preferred repeat interval to be inferred.")
        check(baselines.typicalCueResponseDelaySeconds != nil, "Expected cue response baseline to be computed.")

        let reminderOrchestrator = AdaptiveReminderOrchestrator()
        let reminderPlan = reminderOrchestrator.reminderPlan(
            for: Task(title: "Draft paragraph", detail: "Write a first rough paragraph.", startMinute: 9 * 60, durationMinutes: 25, isEssential: true),
            contextDate: now,
            dailyState: DailyState(energy: 2, stress: 4, sleepHours: 6.0, sensoryLoad: 4, transitionFriction: 4, priority: "finish essay", reminderProfile: .balanced),
            profileSettings: ProfileSettings(displayName: "Sim User", transitionPrepMinutes: 10, reminderProfile: .balanced),
            estimatedState: EstimatedState(
                capacityBand: .low,
                overloadRisk: 0.74,
                transitionRisk: [:],
                latenessRisk: [:],
                executionState: .drifting,
                confidence: 0.7,
                supportingSignals: []
            ),
            recentOutcomes: outcomes,
            baselines: baselines
        )

        check(reminderPlan.leadTimeMinutes >= 0, "Reminder lead time should never be negative.")
        check(reminderPlan.maxRepeats >= 1, "Reminder max repeats should be clamped to at least 1.")
        
        let coldStartPlan = reminderOrchestrator.reminderPlan(
            for: Task(title: "Inbox triage", detail: "Process the top 3 items.", startMinute: 10 * 60, durationMinutes: 20, isEssential: true),
            contextDate: now,
            dailyState: DailyState(energy: 3, stress: 3, sleepHours: 7.0, sensoryLoad: 2, transitionFriction: 2, priority: "stabilize", reminderProfile: .repetitiveSupport),
            profileSettings: ProfileSettings(displayName: "Cold Start", transitionPrepMinutes: 10, reminderProfile: .repetitiveSupport),
            estimatedState: EstimatedState(
                capacityBand: .medium,
                overloadRisk: 0.35,
                transitionRisk: [:],
                latenessRisk: [:],
                executionState: .onTrack,
                confidence: 0.4,
                supportingSignals: []
            ),
            recentOutcomes: [],
            baselines: .empty
        )
        check(coldStartPlan.repeatIntervalMinutes == 6, "Cold-start repetitive profile should use stable default repeat interval.")
        check(coldStartPlan.escalationRule.contains("Starting from"), "Cold-start reminder plan should explain stable bootstrap behavior.")

        let replanEngine = HeuristicAdaptiveReplanEngine()
        let replanSuggestion = replanEngine.suggest(
            liveExecutionState: LiveExecutionState(
                signals: [.taskStartingLate, .taskNotStartedAfterCue, .repeatedRebuilds],
                transitionWindow: TransitionWindowState(blockID: UUID(), title: "Transition", minutesUntilStart: 5, minutesPastStart: nil, risk: 0.75, needsAttention: true),
                summary: "Simulation state",
                shouldSuggestReplan: true
            ),
            liveHealthState: LiveHealthState(
                status: .overwhelmed,
                strainRisk: 0.84,
                confidence: 0.8,
                summary: "High strain",
                supportingSignals: [],
                recoveryRecommendations: []
            ),
            estimatedState: EstimatedState(
                capacityBand: .low,
                overloadRisk: 0.82,
                transitionRisk: [:],
                latenessRisk: [:],
                executionState: .overloaded,
                confidence: 0.75,
                supportingSignals: []
            ),
            currentMode: .full,
            assessment: DayAssessment(
                recommendedMode: .minimum,
                headline: "Overloaded",
                reasoning: "Simulation",
                loadScore: 9,
                supportFocus: "Reduce demands",
                capacityDrivers: []
            ),
            profileSettings: ProfileSettings()
        )

        check(replanSuggestion?.recommendedMode == .minimum, "Expected replan to recommend minimum mode under overload signals.")
        
        let replanScore = HeuristicReplanDecisionScorer().score(
            features: ReplanDecisionFeatures(
                liveExecutionState: LiveExecutionState(
                    signals: [],
                    transitionWindow: TransitionWindowState(blockID: UUID(), title: "Transition", minutesUntilStart: 35, minutesPastStart: nil, risk: 0.2, needsAttention: false),
                    summary: "Low evidence state",
                    shouldSuggestReplan: false
                ),
                liveHealthState: LiveHealthState(
                    status: .stable,
                    strainRisk: 0.22,
                    confidence: 0.2,
                    summary: "Sparse health confidence",
                    supportingSignals: [],
                    recoveryRecommendations: []
                ),
                estimatedState: EstimatedState(
                    capacityBand: .medium,
                    overloadRisk: 0.55,
                    transitionRisk: [:],
                    latenessRisk: [:],
                    executionState: .onTrack,
                    confidence: 0.35,
                    supportingSignals: []
                ),
                currentMode: .full,
                assessment: DayAssessment(
                    recommendedMode: .full,
                    headline: "Low evidence",
                    reasoning: "Sparse signal should damp aggressive replans.",
                    loadScore: 4,
                    supportFocus: "Keep stable",
                    capacityDrivers: []
                ),
                profileSettings: ProfileSettings()
            )
        )
        check(replanScore.overloadPressure < 0.62, "Low-evidence conditions should not immediately push overload pressure into aggressive replan range.")

        print("—")
        print("Intelligence simulation report: \(passedChecks)/\(totalChecks) checks passed.")
        print("✅ Intelligence simulation passed")
    }
}
