import SwiftUI

struct TodayView: View {
    private enum TodayDominantState {
        case urgentTransition
        case replan
        case pausedRoutine
        case activeRoutine
        case task
    }

    private enum DayVisualStyle: String, CaseIterable, Identifiable {
        case timeline
        case pie

        var id: String { rawValue }

        var title: String {
            switch self {
            case .timeline:
                return "Timeline"
            case .pie:
                return "Pie"
            }
        }
    }

    @ObservedObject var viewModel: TodayStore
    let guidance: String
    let healthContextSummary: String
    let calendarContextSummary: String
    let personalizedBaselineSummary: String?
    let featuredInsight: InsightCard?
    let capacityDrivers: [String]
    let communicationStyle: CommunicationStyle
    let pdaAwareSupport: Bool
    let visualSupportMode: VisualSupportMode
    let adaptationSummary: String?
    let adaptationReasons: [String]
    let feedbackPromptTitle: String?
    let feedbackPromptDetail: String?
    let liveExecutionSummary: String
    let liveExecutionSignals: [ExecutionDriftSignal]
    let shouldSuggestReplan: Bool
    let suggestedReplan: ReplanSuggestion?
    let taskTimingSummary: String
    let taskCueSummary: String?
    let taskCueDetail: String?
    let reminderPlan: ReminderPlan?
    let activeRoutine: Routine?
    let activeRoutineSupport: RoutineExecutionSupport?
    let isRoutinePaused: Bool
    let onModeChange: (PlanMode) -> Void
    let onTaskToggle: (UUID, UUID, PlanMode) -> Void
    let onStartCurrentTask: () -> Void
    let onShrinkCurrentTask: () -> Void
    let onMoveCurrentTaskLater: () -> Void
    let onDeferCurrentTask: () -> Void
    let onDropCurrentTask: () -> Void
    let onReplayCurrentTaskCue: () -> Void
    let onFocusAnchor: (UUID) -> Void
    let onToggleRoutineStep: (UUID, UUID) -> Void
    let onPauseRoutine: (UUID) -> Void
    let onResumeRoutine: (UUID) -> Void
    let onRebuildDay: () -> Void
    let onApplySuggestedReplan: (PlanMode) -> Void
    let onFeedbackReason: (CueFailureReason) -> Void
    let onDismissFeedback: () -> Void
    let onOpenCurrentContext: () -> Void

    @State private var isReasoningExpanded = false
    @State private var isContextExpanded = false
    @State private var dayVisualStyle: DayVisualStyle = .timeline

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topSummaryCard
                    dayVisualCard
                    primaryExecutionSection
                    if shouldShowModePicker {
                        modePicker
                    }
                    if shouldShowCurrentAnchorCard {
                        currentAnchorCard
                    }
                    if shouldShowNextAnchorCard {
                        nextAnchorCard
                    }
                    if feedbackPromptTitle != nil {
                        feedbackCard
                    }
                    if adaptationSummary != nil, shouldShowCommentary {
                        adaptationCard
                    }
                    if personalizedBaselineSummary != nil, shouldShowCommentary {
                        baselineCard
                    }
                    if featuredInsight != nil, shouldShowCommentary {
                        insightCard
                    }
                    if shouldShowLaterToday {
                        laterTodayCard
                    }
                    if shouldShowCommentary {
                        whatMattersNowCard
                        supportContextSection
                    }
                    if shouldShowTimeline {
                        timelineCard
                    }
                    rebuildButton
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Today")
            .onAppear {
                if visualSupportMode == .lowerStimulation {
                    dayVisualStyle = .timeline
                }
            }
        }
    }

    private var dominantState: TodayDominantState {
        if let transition = viewModel.transitionFocusBlock, transitionNeedsDominance(transition) {
            return .urgentTransition
        }
        if shouldSuggestReplan && suggestedReplan != nil {
            return .replan
        }
        if viewModel.currentTask != nil {
            return .task
        }
        if activeRoutine != nil, isRoutinePaused {
            return .pausedRoutine
        }
        if activeRoutine != nil, activeRoutineSupport != nil {
            return .activeRoutine
        }
        return .task
    }

    @ViewBuilder
    private var primaryExecutionSection: some View {
        switch dominantState {
        case .urgentTransition:
            transitionCard
        case .replan:
            liveExecutionCard
        case .pausedRoutine, .activeRoutine:
            activeRoutineCard
        case .task:
            currentAnchorCard
            if !liveExecutionSignals.isEmpty || shouldSuggestReplan || suggestedReplan != nil {
                liveExecutionCard
            }
        }
    }

    private var shouldShowModePicker: Bool {
        dominantState != .urgentTransition
    }

    private var shouldShowCurrentAnchorCard: Bool {
        dominantState == .replan || dominantState == .pausedRoutine || dominantState == .activeRoutine
    }

    private var shouldShowNextAnchorCard: Bool {
        dominantState == .task
    }

    private var shouldShowLaterToday: Bool {
        dominantState == .task
    }

    private var shouldShowTimeline: Bool {
        dominantState == .task || dominantState == .replan
    }

    private var shouldShowCommentary: Bool {
        adaptationSummary != nil
        || !trimmedAdaptationReasons.isEmpty
        || personalizedBaselineSummary != nil
        || featuredInsight != nil
        || !capacityDriverHighlights.isEmpty
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Support level")
                .font(AppTheme.Typography.sectionTitle)

            HStack(spacing: 10) {
                ForEach(PlanMode.allCases) { mode in
                    Button {
                        viewModel.selectedMode = mode
                        onModeChange(mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title)
                                .font(AppTheme.Typography.cardTitle)
                            Text(mode.supportiveLabel)
                                .font(AppTheme.Typography.caption)
                        }
                        .foregroundStyle(viewModel.selectedMode == mode ? Color.white : AppTheme.Colors.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(viewModel.selectedMode == mode ? AppTheme.Colors.primary : AppTheme.Colors.card)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var topSummaryCard: some View {
        Group {
            if hasOpenableCurrentContext {
                Button(action: onOpenCurrentContext) {
                    summaryCardContent(showsChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                summaryCardContent(showsChevron: false)
            }
        }
    }

    private func summaryCardContent(showsChevron: Bool) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ScreenModeBadge(title: "Current")
                    Spacer()
                    if showsChevron {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Colors.primary)
                            .accessibilityHidden(true)
                    }
                }
                Text("Current focus")
                    .font(AppTheme.Typography.sectionTitle)
                Text(viewModel.currentBlock?.title ?? viewModel.assessment.headline)
                    .font(AppTheme.Typography.heroTitle)
                Text(viewModel.currentBlock?.timeRangeText ?? viewModel.currentProgressText)
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                if showsChevron {
                    Text(openCurrentContextLabel)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
    }

    private var dayVisualCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day Visual")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("See where you are in the day and what is coming next.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Picker("Day Visual", selection: $dayVisualStyle) {
                        ForEach(DayVisualStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .disabled(visualSupportMode == .lowerStimulation)
                    .opacity(visualSupportMode == .lowerStimulation ? 0.55 : 1)
                }

                if dayVisualStyle == .timeline {
                    VStack(alignment: .leading, spacing: 10) {
                        GeometryReader { geometry in
                            HStack(spacing: 4) {
                                ForEach(dayVisualSegments) { segment in
                                    Button {
                                        if let anchorID = segment.anchorID {
                                            onFocusAnchor(anchorID)
                                        }
                                    } label: {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(segment.color)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(segment.isCurrent ? Color.white.opacity(0.9) : .clear, lineWidth: 2)
                                            )
                                            .frame(width: max((segment.ratio * geometry.size.width) - 4, 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: 24)

                        HStack {
                            Text(viewModel.currentBlock?.title ?? "No current block")
                                .font(AppTheme.Typography.cardTitle)
                            Spacer()
                            Text(viewModel.currentBlock?.timeRangeText ?? "")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(AppTheme.Colors.controlBackground, lineWidth: 22)

                            ForEach(dayVisualSegments) { segment in
                                Circle()
                                    .trim(from: segment.start, to: segment.end)
                                    .stroke(segment.color, style: StrokeStyle(lineWidth: segment.isCurrent ? 24 : 20, lineCap: .butt))
                                    .rotationEffect(.degrees(-90))
                            }

                            VStack(spacing: 4) {
                                Text(viewModel.currentBlock?.kindLabel ?? "Now")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Text(viewModel.currentBlock?.title ?? "No plan")
                                    .font(AppTheme.Typography.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 18)
                        }
                        .frame(width: 164, height: 164)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(dayVisualSegments.prefix(4)) { segment in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(segment.color)
                                        .frame(width: 10, height: 10)
                                    Text(segment.label)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var supportContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visualSupportMode != .lowerStimulation {
                DisclosureGroup(isExpanded: $isReasoningExpanded) {
                    capacityExplanationCard
                        .padding(.top, 8)
                } label: {
                    Text("Why Today Looks This Way")
                        .font(AppTheme.Typography.sectionTitle)
                }
                .padding(16)
                .background(AppTheme.Colors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.Colors.primaryMuted.opacity(0.35), lineWidth: 1)
                )
            }

            DisclosureGroup(isExpanded: $isContextExpanded) {
                contextSignalsCard
                    .padding(.top, 8)
            } label: {
                Text("Connected Context")
                    .font(AppTheme.Typography.sectionTitle)
            }
            .padding(16)
            .background(AppTheme.Colors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.Colors.primaryMuted.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var adaptationCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("How Support Is Adapting")
                    .font(AppTheme.Typography.sectionTitle)
                Text(adaptationSummary ?? "")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                ForEach(trimmedAdaptationReasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppTheme.Colors.primaryMuted)
                            .frame(width: 7, height: 7)
                            .padding(.top, 5)
                        Text(reason)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
                if let adaptationNextStepText {
                    Divider()
                    Text("Next step")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(adaptationNextStepText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }

    private var feedbackCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(feedbackPromptTitle ?? "")
                            .font(AppTheme.Typography.sectionTitle)
                        Text(feedbackPromptDetail ?? "")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Button("Not now", action: onDismissFeedback)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(CueFailureReason.allCases) { reason in
                        Button {
                            onFeedbackReason(reason)
                        } label: {
                            Text(reason.title)
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.Colors.controlBackground)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var liveExecutionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live Support Check")
                    .font(AppTheme.Typography.sectionTitle)
                Text(liveExecutionSummary)
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                if !liveExecutionSignals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(liveExecutionSignals) { signal in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)
                                Text(signal.supportText)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                    }
                }

                if shouldSuggestReplan {
                    Text("A lighter replan may help the next stretch land more cleanly.")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                if let suggestedReplan {
                    Divider()
                    Text("Reason: \(suggestedReplan.reason.title)")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(suggestedReplan.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text(suggestedReplan.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    if !suggestedReplan.adjustments.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(suggestedReplan.adjustments.prefix(2)), id: \.self) { adjustment in
                                Text("• \(adjustment.title)")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                    }
                    Button(pdaAwareSupport ? "Try \(suggestedReplan.recommendedMode.title)" : "Apply \(suggestedReplan.recommendedMode.title) Support") {
                        onApplySuggestedReplan(suggestedReplan.recommendedMode)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }
    }

    private var capacityExplanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.assessment.supportFocus)
                .font(AppTheme.Typography.supporting)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if communicationStyle == .supportive {
                Text(viewModel.assessment.reasoning)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(capacityDriverHighlights, id: \.self) { driver in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        Text(driver)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private var contextSignalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Health")
                    .font(AppTheme.Typography.cardTitle)
                Text(healthContextSummary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar")
                    .font(AppTheme.Typography.cardTitle)
                Text(calendarContextSummary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var baselineCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("What The App Is Learning")
                    .font(AppTheme.Typography.sectionTitle)
                Text(personalizedBaselineSummary ?? "")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(visualSupportMode == .lowerStimulation ? 2 : 3)
            }
        }
    }

    private var insightCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("What The App Is Noticing")
                    .font(AppTheme.Typography.sectionTitle)
                Text(featuredInsight?.title ?? "")
                    .font(AppTheme.Typography.cardTitle)
                Text(featuredInsight?.summary ?? "")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                Text(featuredInsight?.supportingDetail ?? "")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private var trimmedAdaptationReasons: [String] {
        let limit = visualSupportMode == .lowerStimulation ? 1 : 2
        return uniqueNonEmpty(adaptationReasons).prefix(limit).map { $0 }
    }

    private var capacityDriverHighlights: [String] {
        let limit = visualSupportMode == .lowerStimulation ? 2 : 3
        return uniqueNonEmpty(capacityDrivers).prefix(limit).map { $0 }
    }

    private var adaptationNextStepText: String? {
        if let suggestedReplan {
            return suggestedReplan.reason.recommendation
        }
        return liveExecutionSignals.first?.supportText
    }

    private func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                unique.append(trimmed)
            }
        }
        return unique
    }

    private var currentAnchorCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Now")
                    .font(AppTheme.Typography.sectionTitle)

                if let anchor = viewModel.currentAnchor {
                    Text(anchor.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text("\(anchor.timeLabel) • \(anchor.totalMinutes) min")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    if viewModel.currentTask == nil {
                        Text(anchor.prompt)
                            .font(AppTheme.Typography.supporting)
                            .lineLimit(3)
                    }

                    if let currentTask = viewModel.currentTask {
                        currentTaskExecutionCard(currentTask)

                        if dominantState == .task || dominantState == .replan {
                            HStack(spacing: 10) {
                                Button(action: onStartCurrentTask) {
                                    Text(startTaskButtonTitle(for: currentTask))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryActionButtonStyle())

                                Button(action: onOpenCurrentContext) {
                                    Text("Open Task")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                    }

                    if shouldShowTaskList {
                        VStack(spacing: 10) {
                            ForEach(anchor.tasks) { task in
                                Button {
                                    onTaskToggle(task.id, anchor.id, viewModel.selectedMode)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(task.isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(task.title)
                                                .font(AppTheme.Typography.supporting.weight(.semibold))
                                                .strikethrough(task.isCompleted)
                                                .foregroundStyle(AppTheme.Colors.text)
                                            Text(task.detail)
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                            if let sensoryCue = task.sensoryCue {
                                                Text("\(sensoryCue.categoryTitle): \(sensoryCue.title)")
                                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.Colors.primary)
                                            }
                                        }

                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(task.durationMinutes)m")
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                            if let suggested = task.suggestedDurationMinutes {
                                                Text("Suggest \(suggested)m")
                                                    .font(AppTheme.Typography.caption)
                                                    .foregroundStyle(AppTheme.Colors.primary)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Build a check-in to see your current task block.")
                        .font(AppTheme.Typography.supporting)
                }
            }
        }
    }

    private var hasOpenableCurrentContext: Bool {
        viewModel.currentTask != nil || activeRoutine != nil || viewModel.currentEventBlock != nil || viewModel.nextEventBlock != nil
    }

    private var openCurrentContextLabel: String {
        if viewModel.currentTask != nil {
            return "Open current task"
        }
        if activeRoutine != nil {
            return "Open current routine"
        }
        if viewModel.currentEventBlock != nil {
            return "Open current event"
        }
        if viewModel.nextEventBlock != nil {
            return "Open next event"
        }
        return "Open current context"
    }

    private func currentTaskExecutionCard(_ currentTask: Task) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current task")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(currentTask.title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(taskTimingSummary)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if let taskCueSummary {
                HStack(alignment: .center, spacing: 8) {
                    Text(taskCueSummary)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Spacer()
                    Button("Play Cue", action: onReplayCurrentTaskCue)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            if let taskCueDetail {
                Text(taskCueDetail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            if let reminderPlan {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminder rhythm: \(reminderPlan.profile.title)")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(reminderPlan.cadenceSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(reminderPlan.sampleCopy)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit this plan")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                HStack(spacing: 8) {
                    plannerEditChip(title: "Shrink 10m", action: onShrinkCurrentTask)
                    plannerEditChip(title: "Move Later", action: onMoveCurrentTaskLater)
                }

                HStack(spacing: 8) {
                    plannerEditChip(title: "Tomorrow", action: onDeferCurrentTask)
                    plannerEditChip(title: "Drop", action: onDropCurrentTask)
                }
            }
        }
        .padding(12)
        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func plannerEditChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.canvas)
                )
        }
        .buttonStyle(.plain)
    }

    private var laterTodayCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Later Today")
                    .font(AppTheme.Typography.sectionTitle)

                if viewModel.laterAnchors.isEmpty {
                    Text("The rest of the day is intentionally light after your next task block.")
                        .font(AppTheme.Typography.supporting)
                    Text("That space can stay flexible for recovery, travel, or decompression.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                } else {
                    ForEach(viewModel.laterAnchors) { anchor in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(anchor.title)
                                    .font(AppTheme.Typography.cardTitle)
                                Text(anchor.prompt)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            Text(anchor.timeLabel)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .padding(12)
                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var nextAnchorCard: some View {
        SurfaceCard {
            if let nextEventBlock = viewModel.nextEventBlock {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Next")
                        .font(AppTheme.Typography.sectionTitle)
                    Text(nextEventBlock.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text(nextEventBlock.timeRangeText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    if let leaveByBlock = viewModel.leaveByBlockForNextEvent {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text(leaveByHeadline(for: leaveByBlock))
                                    .font(AppTheme.Typography.supporting.weight(.semibold))
                            } icon: {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(leaveByAccentColor)

                            if let leaveByStatusText {
                                Text(leaveByStatusText)
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(leaveByAccentColor)
                            }

                            Text(leaveByBlock.detail)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(leaveByDetailColor)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(leaveByBackgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(leaveByAccentColor.opacity(0.35), lineWidth: 1.5)
                        )
                    }

                    Text(nextEventBlock.detail)
                        .font(AppTheme.Typography.supporting)

                    Text(nextEventBlock.cue.detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            } else if let anchor = viewModel.nextAnchor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next")
                        .font(AppTheme.Typography.sectionTitle)
                    Text(anchor.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text(anchor.timeLabel)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(anchor.prompt)
                        .font(AppTheme.Typography.supporting)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next")
                        .font(AppTheme.Typography.sectionTitle)
                    Text("Nothing urgent is queued after this.")
                        .font(AppTheme.Typography.supporting)
                    Text("This is a good place to protect recovery or close the day.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var transitionCard: some View {
        let transition = viewModel.transitionFocusBlock

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                ScreenModeBadge(title: "Transition")
                Text("Transition support")
                    .font(AppTheme.Typography.sectionTitle)

                if let transition {
                    Text(transition.title)
                        .font(AppTheme.Typography.cardTitle)

                    Text(transition.timeRangeText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    if let leaveStatus = transitionStatusText(for: transition) {
                        Text(leaveStatus)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(transitionAccentColor(for: transition))
                    }

                    Text(transition.detail)
                        .font(AppTheme.Typography.supporting)

                    CueBanner(text: transition.cue.detail)

                    Button(transitionPrimaryActionTitle(for: transition)) {
                        if let anchorID = transition.anchorID {
                            onFocusAnchor(anchorID)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                } else {
                    Text("No transition needs attention right now.")
                        .font(AppTheme.Typography.supporting)
                }
            }
        }
    }

    private var activeRoutineCard: some View {
        let routine = activeRoutine
        let support = activeRoutineSupport

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                ScreenModeBadge(title: "Doing")
                Text("Routine in progress")
                    .font(AppTheme.Typography.sectionTitle)

                if let routine, let support {
                    let currentStep = routine.steps.first(where: { !$0.isCompleted })
                    let nextStep = nextRoutineStep(in: routine, after: currentStep)
                    let completed = completedRoutineStepCount(in: routine)

                    Text(routine.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text(routine.progressText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    if let currentStep {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentStep.title)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                            Text("Step \(completed + 1) of \(max(routine.steps.count, 1)) • \(currentStep.estimatedMinutes) min")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            CueBanner(text: support.currentStepCue)
                            if let nextStep {
                                Text("Next: \(nextStep.title)")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primary)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        HStack(spacing: 10) {
                            Button(routinePauseButtonTitle) {
                                if isRoutinePaused {
                                    onResumeRoutine(routine.id)
                                } else {
                                    onPauseRoutine(routine.id)
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())

                            Button(completeRoutineStepButtonTitle) {
                                onToggleRoutineStep(currentStep.id, routine.id)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }

                        Text(support.resumeSupportText)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else {
                        Text("This routine is already complete.")
                            .font(AppTheme.Typography.supporting)
                    }
                }
            }
        }
    }

    private var whatMattersNowCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Focus")
                    .font(AppTheme.Typography.sectionTitle)
                Text(viewModel.currentPlan?.whatMattersNow ?? "No focus summary yet.")
                    .font(AppTheme.Typography.supporting)
                Text(viewModel.currentPlan?.modeSummary ?? "")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var timelineCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(AppTheme.Typography.sectionTitle)

                ForEach(viewModel.timelineBlocks) { block in
                    if let anchorID = block.anchorID {
                        Button {
                            onFocusAnchor(anchorID)
                        } label: {
                            timelineBlockRow(block)
                        }
                        .buttonStyle(.plain)
                    } else {
                        timelineBlockRow(block)
                    }
                }
            }
        }
    }

    private func timelineBlockRow(_ block: ScheduleBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(block.id == viewModel.currentBlock?.id ? AppTheme.Colors.primary : blockTint(for: block))
                .frame(width: 10, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(block.title)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(AppTheme.Colors.text)
                    Spacer()
                    Text(block.timeRangeText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Text(block.kindLabel)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)

                Text(block.detail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Text(block.cue.detail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func blockTint(for block: ScheduleBlock) -> Color {
        switch block.kind {
        case .routine:
            return AppTheme.Colors.primaryMuted
        case .anchor:
            return AppTheme.Colors.primaryMuted
        case .project:
            return Color.purple.opacity(0.45)
        case .transition:
            return AppTheme.Colors.primary.opacity(0.65)
        case .event:
            return Color.orange.opacity(0.55)
        case .buffer:
            return Color.blue.opacity(0.30)
        case .recovery:
            return Color.green.opacity(0.35)
        }
    }

    private var dayVisualSegments: [DayVisualSegment] {
        let blocks = viewModel.timelineBlocks
        let totalMinutes = max(blocks.reduce(0) { $0 + max($1.endMinute - $1.startMinute, 1) }, 1)
        var runningStart = 0.0

        return blocks.map { block in
            let duration = max(block.endMinute - block.startMinute, 1)
            let ratio = Double(duration) / Double(totalMinutes)
            let start = runningStart
            let end = min(start + ratio, 1.0)
            runningStart = end
            return DayVisualSegment(
                label: block.title,
                ratio: ratio,
                start: start,
                end: end,
                anchorID: block.anchorID,
                color: block.id == viewModel.currentBlock?.id ? AppTheme.Colors.primary : blockTint(for: block),
                isCurrent: block.id == viewModel.currentBlock?.id
            )
        }
    }

    private var rebuildButton: some View {
        Button(action: onRebuildDay) {
            Text("Rebuild Day")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private func clockString(for minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }

    private func leaveByHeadline(for block: ScheduleBlock) -> String {
        "Leave by \(clockString(for: block.startMinute))"
    }

    private var leaveByStatusText: String? {
        guard let minutesUntilLeave = viewModel.leaveByMinutesUntilNextEvent else { return nil }
        if minutesUntilLeave <= 0 {
            return "It is time to leave now."
        }
        if minutesUntilLeave <= 10 {
            return "Leaving soon: \(minutesUntilLeave) minute\(minutesUntilLeave == 1 ? "" : "s")."
        }
        if minutesUntilLeave <= 30 {
            return "Coming up in \(minutesUntilLeave) minutes."
        }
        return nil
    }

    private var leaveByAccentColor: Color {
        guard let minutesUntilLeave = viewModel.leaveByMinutesUntilNextEvent else { return AppTheme.Colors.primary }
        if minutesUntilLeave <= 10 {
            return .red
        }
        if minutesUntilLeave <= 30 {
            return .orange
        }
        return AppTheme.Colors.primary
    }

    private var leaveByBackgroundColor: Color {
        guard let minutesUntilLeave = viewModel.leaveByMinutesUntilNextEvent else {
            return AppTheme.Colors.primary.opacity(0.12)
        }
        if minutesUntilLeave <= 10 {
            return Color.red.opacity(0.12)
        }
        if minutesUntilLeave <= 30 {
            return Color.orange.opacity(0.14)
        }
        return AppTheme.Colors.primary.opacity(0.12)
    }

    private var leaveByDetailColor: Color {
        guard let minutesUntilLeave = viewModel.leaveByMinutesUntilNextEvent, minutesUntilLeave <= 10 else {
            return AppTheme.Colors.secondaryText
        }
        return Color.red.opacity(0.85)
    }

    private var topSummarySupportText: String {
        viewModel.currentPlan?.dailyPlan.supportSummary ?? "Current support plan is ready."
    }

    private var currentTaskPromptText: String {
        if dominantState == .pausedRoutine {
            return communicationStyle == .literal
                ? "Resume the current step from where you stopped."
                : "Pick back up here instead of restarting the whole routine."
        }
        if dominantState == .urgentTransition, let transition = viewModel.transitionFocusBlock {
            return transition.cue.detail
        }
        if communicationStyle == .literal, let currentTask = viewModel.currentTask {
            return "Current task: \(currentTask.title). Continue this before switching."
        }
        return viewModel.nextTaskPrompt
    }

    private var summarySupportText: String {
        switch dominantState {
        case .urgentTransition:
            return communicationStyle == .literal
                ? "Transition support is leading right now. Other guidance is reduced."
                : "The next handoff matters most right now, so the rest of the day is stepping back."
        case .replan:
            return communicationStyle == .literal
                ? "A lighter plan is available. Focus on the recovery move first."
                : "The app is focusing on recovery support before anything else."
        case .pausedRoutine:
            return communicationStyle == .literal
                ? "Resume the current routine step before widening your focus."
                : "Come back to the next visible step and let the rest wait."
        case .activeRoutine:
            return communicationStyle == .literal
                ? "Routine execution is leading. Secondary context is reduced."
                : "Stay inside the routine until the handoff changes."
        case .task:
            return topSummarySupportText
        }
    }

    private func transitionStatusText(for block: ScheduleBlock) -> String? {
        let currentMinute = minuteOfDay(for: Date())
        if currentMinute >= block.startMinute && currentMinute <= block.endMinute {
            return communicationStyle == .literal
                ? "This transition is active now."
                : "You are in the handoff window now."
        }

        let minutesUntil = block.startMinute - currentMinute
        if minutesUntil < 0 {
            return nil
        }
        if minutesUntil <= 10 {
            return "Coming up in \(minutesUntil) minute\(minutesUntil == 1 ? "" : "s")."
        }
        if minutesUntil <= 30 {
            return "Prepare for this shift in \(minutesUntil) minutes."
        }
        return nil
    }

    private func transitionAccentColor(for block: ScheduleBlock) -> Color {
        let currentMinute = minuteOfDay(for: Date())
        if currentMinute >= block.startMinute {
            return .red
        }
        let minutesUntil = block.startMinute - currentMinute
        if minutesUntil <= 10 {
            return .orange
        }
        return AppTheme.Colors.primary
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func nextRoutineStep(in routine: Routine, after currentStep: RoutineStep?) -> RoutineStep? {
        guard let currentStep,
              let currentIndex = routine.steps.firstIndex(where: { $0.id == currentStep.id }) else {
            return nil
        }
        let nextIndex = routine.steps.index(after: currentIndex)
        guard nextIndex < routine.steps.endIndex else { return nil }
        return routine.steps[nextIndex]
    }

    private func completedRoutineStepCount(in routine: Routine) -> Int {
        routine.steps.filter(\.isCompleted).count
    }

    private var shouldShowTaskList: Bool {
        dominantState == .task
    }

    private func transitionNeedsDominance(_ transition: ScheduleBlock) -> Bool {
        let currentMinute = minuteOfDay(for: Date())
        if currentMinute >= transition.startMinute && currentMinute <= transition.endMinute {
            return true
        }
        let minutesUntil = transition.startMinute - currentMinute
        return minutesUntil <= 20
    }

    private func transitionPrimaryActionTitle(for transition: ScheduleBlock) -> String {
        let currentMinute = minuteOfDay(for: Date())
        if pdaAwareSupport {
            if currentMinute >= transition.startMinute && currentMinute <= transition.endMinute {
                return transition.title.hasPrefix("Leave for") ? "Head Out When Ready" : "Ease Into This Shift"
            }
            return transition.title.hasPrefix("Leave for") ? "Get Set To Head Out" : "Get Set For The Switch"
        }
        if currentMinute >= transition.startMinute && currentMinute <= transition.endMinute {
            return transition.title.hasPrefix("Leave for") ? "Leave Now" : "Begin Transition"
        }
        return transition.title.hasPrefix("Leave for") ? "Get Ready To Leave" : "Start Transition"
    }

    private func startTaskButtonTitle(for task: Task) -> String {
        if pdaAwareSupport {
            return communicationStyle == .literal ? "Try \(task.title)" : "Start Here If It Helps"
        }
        return "Start \(task.title)"
    }

    private var routinePauseButtonTitle: String {
        if pdaAwareSupport {
            return isRoutinePaused ? "Pick This Back Up" : "Take A Break From This"
        }
        return isRoutinePaused ? "Resume Routine" : "Pause Routine"
    }

    private var completeRoutineStepButtonTitle: String {
        if pdaAwareSupport {
            return isRoutinePaused ? "Mark This Step Done" : "Move Past This Step"
        }
        return isRoutinePaused ? "Complete Resumed Step" : "Complete Step"
    }
}

private struct DayVisualSegment: Identifiable {
    let id = UUID()
    let label: String
    let ratio: Double
    let start: Double
    let end: Double
    let anchorID: UUID?
    let color: Color
    let isCurrent: Bool
}
