import SwiftUI

struct RootView: View {
    private enum RootTab: Hashable {
        case today
        case checkIn
        case planner
        case tasks
        case routines
        case settings
    }

    @StateObject private var appStore = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: RootTab = .today
    @State private var presentedTaskSelection: TaskSelection?
    @State private var presentedRoutine: Routine?
    @State private var presentedEvent: DayEvent?

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView(
                    viewModel: appStore.todayStore,
                    guidance: appStore.currentGuidance,
                    healthContextSummary: appStore.healthContextSummary,
                    calendarContextSummary: appStore.calendarContextSummary,
                    personalizedBaselineSummary: appStore.personalizedBaselineSummary,
                    featuredInsight: appStore.featuredInsight,
                    capacityDrivers: appStore.assessment.capacityDrivers,
                    communicationStyle: appStore.profileSettings.communicationStyle,
                    pdaAwareSupport: appStore.profileSettings.pdaAwareSupport,
                    visualSupportMode: appStore.profileSettings.visualSupportMode,
                    adaptationSummary: appStore.adaptationSummary,
                    adaptationReasons: appStore.adaptationReasonDetails,
                    feedbackPromptTitle: appStore.pendingFeedbackPrompt?.title,
                    feedbackPromptDetail: appStore.pendingFeedbackPrompt?.detail,
                    liveExecutionSummary: appStore.liveExecutionState.summary,
                    liveExecutionSignals: appStore.liveExecutionSignals,
                    shouldSuggestReplan: appStore.liveExecutionState.shouldSuggestReplan,
                    suggestedReplan: appStore.adaptiveReplanSuggestion,
                    taskTimingSummary: appStore.currentTaskTimingSummary,
                    taskCueSummary: appStore.currentTaskCueSummary,
                    taskCueDetail: appStore.currentTaskCueDetail,
                    reminderPlan: appStore.currentReminderPlan,
                    activeRoutine: appStore.activeRoutineForToday,
                    activeRoutineSupport: appStore.activeRoutineSupportForToday,
                    isRoutinePaused: appStore.isRoutinePausedForToday,
                    onModeChange: appStore.selectMode,
                    onTaskToggle: { taskID, anchorID, mode in
                        appStore.toggleTask(taskID, in: anchorID, mode: mode)
                    },
                    onStartCurrentTask: appStore.startCurrentTask,
                    onShrinkCurrentTask: appStore.shrinkCurrentTaskBlock,
                    onMoveCurrentTaskLater: appStore.moveCurrentTaskToNextAnchor,
                    onDeferCurrentTask: appStore.deferCurrentTaskToTomorrow,
                    onDropCurrentTask: appStore.dropCurrentTaskFromToday,
                    onReplayCurrentTaskCue: appStore.replayCurrentTaskCue,
                    onFocusAnchor: appStore.todayStore.setActiveAnchor,
                    onToggleRoutineStep: appStore.toggleRoutineStep,
                    onPauseRoutine: appStore.pauseRoutine,
                    onResumeRoutine: appStore.resumeRoutine,
                    onRebuildDay: appStore.rebuildDay,
                    onApplySuggestedReplan: appStore.applyReplanChoice,
                    onFeedbackReason: appStore.submitFeedbackReason,
                    onDismissFeedback: appStore.dismissFeedbackPrompt,
                    onOpenCurrentContext: openCurrentContext
                )
                .tag(RootTab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

                DailyCheckInView(
                    viewModel: appStore.checkInStore,
                    assessment: appStore.assessment,
                    healthContextSummary: appStore.healthContextSummary,
                    healthAutofillSummary: appStore.checkInHealthAutofillSummary,
                    calendarContextSummary: appStore.calendarContextSummary,
                    communicationStyle: appStore.profileSettings.communicationStyle,
                    pdaAwareSupport: appStore.profileSettings.pdaAwareSupport,
                    scenarios: appStore.scenarios,
                    selectedScenarioID: appStore.selectedScenarioID,
                    onScenarioSelect: appStore.loadScenario,
                    onApplyHealthAutofill: appStore.applyHealthAutofillToCheckIn,
                    onApply: appStore.applyCheckIn
                )
                .tag(RootTab.checkIn)
                .tabItem {
                    Label("Check-In", systemImage: "checkmark.circle.fill")
                }

                PlannerView(appStore: appStore)
                .tag(RootTab.planner)
                .tabItem {
                    Label("Planner", systemImage: "calendar.badge.clock")
                }

                TasksView(appStore: appStore)
                .tag(RootTab.tasks)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

                RoutinesView(appStore: appStore)
                .tag(RootTab.routines)
                .tabItem {
                    Label("Routines", systemImage: "repeat")
                }

                SettingsView(
                    appStore: appStore,
                    onOpenToday: {
                        selectedTab = .today
                    },
                    onOpenCheckIn: {
                        selectedTab = .checkIn
                    }
                )
                .tag(RootTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }

            if appStore.shouldShowOnboarding {
                OnboardingFlowView(appStore: appStore)
            }
        }
        .sheet(item: $presentedTaskSelection) { selection in
            TaskDetailSheet(
                title: selection.task.title,
                task: selection.task,
                anchorTitle: selection.anchor.title,
                onToggleCompletion: {
                    appStore.toggleTask(selection.task.id, in: selection.anchor.id, mode: appStore.selectedMode)
                    presentedTaskSelection = nil
                },
                onStart: {
                    appStore.startTask(selection.task.id, in: selection.anchor.id)
                },
                onShrink: {
                    appStore.todayStore.setActiveAnchor(selection.anchor.id)
                    appStore.shrinkCurrentTaskBlock()
                },
                onMoveLater: {
                    appStore.todayStore.setActiveAnchor(selection.anchor.id)
                    appStore.moveCurrentTaskToNextAnchor()
                    presentedTaskSelection = nil
                },
                onTomorrow: {
                    appStore.todayStore.setActiveAnchor(selection.anchor.id)
                    appStore.deferCurrentTaskToTomorrow()
                    presentedTaskSelection = nil
                },
                onDrop: {
                    appStore.todayStore.setActiveAnchor(selection.anchor.id)
                    appStore.dropCurrentTaskFromToday()
                    presentedTaskSelection = nil
                },
                onDelete: {
                    appStore.deleteTask(selection.task.id, from: selection.anchor.id)
                    presentedTaskSelection = nil
                },
                onPreviewCue: {
                    appStore.previewSensoryCue(selection.task.sensoryCue)
                },
                onStopPreview: appStore.stopSensoryCuePreview
            )
        }
        .sheet(item: $presentedRoutine) { routine in
            RoutineDetailView(
                routine: routine,
                executionSupport: appStore.routineExecutionSupport(for: routine),
                onToggleStep: appStore.toggleRoutineStep,
                onPauseRoutine: appStore.pauseRoutine,
                onResumeRoutine: appStore.resumeRoutine,
                onCueDelivered: appStore.recordRoutineCueDelivery,
                onCueMissed: appStore.recordRoutineCueMiss
            )
        }
        .sheet(item: $presentedEvent) { event in
            EventInfoSheet(
                event: event,
                onEdit: {
                    presentedEvent = nil
                    selectedTab = .planner
                },
                onHideFromPlanning: {
                    appStore.setEventPlanningVisibility(event, isVisible: false)
                    presentedEvent = nil
                },
                onShowInPlanning: {
                    appStore.setEventPlanningVisibility(event, isVisible: true)
                    presentedEvent = nil
                },
                onDelete: {
                    appStore.removeEvent(event)
                    presentedEvent = nil
                }
            )
        }
        .tint(AppTheme.Colors.primary)
        .environment(\.visualSupportMode, appStore.profileSettings.visualSupportMode)
        .overlay {
            BreathingGlowOverlay(
                isActive: appStore.activeSensoryCue == .rhythmicPulsingGlow
                && appStore.profileSettings.visualSupportMode == .standard
            )
                .allowsHitTesting(false)
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            _Concurrency.Task {
                await appStore.refreshIntegrations()
            }
        }
    }

    private func openCurrentContext() {
        if let anchor = appStore.todayStore.currentAnchor, let task = appStore.todayStore.currentTask {
            presentedTaskSelection = TaskSelection(anchor: anchor, task: task)
            return
        }
        if let routine = appStore.activeRoutineForToday {
            presentedRoutine = routine
            return
        }
        if let eventBlock = appStore.todayStore.currentEventBlock ?? appStore.todayStore.nextEventBlock,
           let event = appStore.allKnownEvents.first(where: { $0.title == eventBlock.title && $0.startMinute == eventBlock.startMinute && $0.dayOffset == 0 }) {
            presentedEvent = event
        }
    }
}

private struct TaskSelection: Identifiable {
    let anchor: Anchor
    let task: Task

    var id: UUID { task.id }
}

private struct PlannerView: View {
    private enum PlannerSurface: String, CaseIterable, Identifiable {
        case today
        case fiveDay
        case month

        var id: String { rawValue }
        var title: String {
            switch self {
            case .today:
                return "Today"
            case .fiveDay:
                return "5 Day"
            case .month:
                return "Month"
            }
        }
    }

    @ObservedObject var appStore: AppStore

    @State private var isPresentingCreateTask = false
    @State private var selectedDayOffset = 0
    @State private var plannerSurface: PlannerSurface = .fiveDay
    @State private var editingAnchor: Anchor?
    @State private var isPresentingCreateAnchor = false
    @State private var isPresentingCreateEvent = false
    @State private var editingEvent: DayEvent?
    @State private var selectedAgendaTask: TaskSelection?
    @State private var selectedAgendaRoutine: Routine?
    @State private var selectedEventInfo: DayEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ScreenModeBadge(title: "Planning")
                            Text("Planner")
                                .font(AppTheme.Typography.heroTitle)
                            Text("Plan across the week with one unified view of tasks, events, routines, and supports. Use this when you need to shape the day before you are in it.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    plannerSurfacePicker
                    plannerPrimarySurface
                    plannerAgendaCard
                    planningEventsCard
                    anchorsCard

                    HStack(spacing: 10) {
                        Button {
                            isPresentingCreateTask = true
                        } label: {
                            Label("Schedule Task", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button {
                            isPresentingCreateEvent = true
                        } label: {
                            Label("Add Event", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    ForEach(appStore.baseAnchors) { anchor in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(anchor.title)
                                            .font(AppTheme.Typography.sectionTitle)
                                        Text("\(anchor.timeLabel) • \(anchor.completionSummary)")
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    Spacer()
                                    Text(anchor.type.rawValue.capitalized)
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }

                                if anchor.tasks.isEmpty {
                                    Text("No tasks yet for this part of the day.")
                                        .font(AppTheme.Typography.supporting)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                } else {
                                    ForEach(anchor.tasks) { task in
                                        Button {
                                            appStore.toggleTask(task.id, in: anchor.id, mode: appStore.selectedMode)
                                        } label: {
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(task.isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(task.title)
                                                        .font(AppTheme.Typography.cardTitle)
                                                        .strikethrough(task.isCompleted)
                                                        .foregroundStyle(AppTheme.Colors.text)
                                                    Text(task.detail)
                                                        .font(AppTheme.Typography.caption)
                                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                                    Text(task.estimateSummary)
                                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                                        .foregroundStyle(AppTheme.Colors.primary)
                                                }

                                                Spacer()

                                                if let startTimeText = task.startTimeText {
                                                    Text(startTimeText)
                                                        .font(AppTheme.Typography.caption)
                                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Planner")
            .sheet(isPresented: $isPresentingCreateTask) {
                CreateTaskView(
                    anchors: appStore.baseAnchors,
                    initialDayOffset: selectedDayOffset,
                    onPreviewCue: appStore.previewSensoryCue,
                    onStopPreview: appStore.stopSensoryCuePreview
                ) { title, detail, anchorID, dayOffset, startMinute, durationMinutes, isEssential, sensoryCue in
                    appStore.addTask(
                        title: title,
                        detail: detail,
                        anchorID: anchorID,
                        dayOffset: dayOffset,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        isEssential: isEssential,
                        sensoryCue: sensoryCue
                    )
                    isPresentingCreateTask = false
                }
                .overlay {
                    BreathingGlowOverlay(
                        isActive: appStore.activeSensoryCue == .rhythmicPulsingGlow
                    )
                    .allowsHitTesting(false)
                }
            }
            .sheet(item: $editingAnchor) { anchor in
                EditAnchorView(anchor: anchor) { title, timeLabel, type, prompt in
                    appStore.updateAnchor(anchor.id, title: title, timeLabel: timeLabel, type: type, prompt: prompt)
                    editingAnchor = nil
                } onDelete: {
                    appStore.deleteAnchor(anchor.id)
                    editingAnchor = nil
                }
            }
            .sheet(isPresented: $isPresentingCreateAnchor) {
                EditAnchorView { title, timeLabel, type, prompt in
                    appStore.addAnchor(title: title, timeLabel: timeLabel, type: type, prompt: prompt)
                    isPresentingCreateAnchor = false
                }
            }
            .sheet(isPresented: $isPresentingCreateEvent) {
                CreateEventView { event in
                    appStore.addEvent(event)
                    isPresentingCreateEvent = false
                }
                .overlay {
                    BreathingGlowOverlay(
                        isActive: appStore.activeSensoryCue == .rhythmicPulsingGlow
                    )
                    .allowsHitTesting(false)
                }
            }
            .sheet(item: $editingEvent) { event in
                EditEventSupportView(event: event) { updatedEvent in
                    appStore.updateEventSupport(updatedEvent)
                    editingEvent = nil
                }
            }
            .sheet(item: $selectedAgendaTask) { selection in
                TaskDetailSheet(
                    title: "Task",
                    task: selection.task,
                    anchorTitle: selection.anchor.title,
                    onToggleCompletion: {
                        appStore.toggleTask(selection.task.id, in: selection.anchor.id, mode: appStore.selectedMode)
                        selectedAgendaTask = nil
                    },
                    onStart: {
                        appStore.startTask(selection.task.id, in: selection.anchor.id)
                    },
                    onShrink: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.shrinkCurrentTaskBlock()
                    },
                    onMoveLater: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.moveCurrentTaskToNextAnchor()
                        selectedAgendaTask = nil
                    },
                    onTomorrow: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.deferCurrentTaskToTomorrow()
                        selectedAgendaTask = nil
                    },
                    onDrop: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.dropCurrentTaskFromToday()
                        selectedAgendaTask = nil
                    },
                    onDelete: {
                        appStore.deleteTask(selection.task.id, from: selection.anchor.id)
                        selectedAgendaTask = nil
                    },
                    onPreviewCue: {
                        appStore.previewSensoryCue(selection.task.sensoryCue)
                    },
                    onStopPreview: appStore.stopSensoryCuePreview
                )
            }
            .sheet(item: $selectedAgendaRoutine) { routine in
                RoutineDetailView(
                    routine: routine,
                    executionSupport: appStore.routineExecutionSupport(for: routine),
                    onToggleStep: appStore.toggleRoutineStep,
                    onPauseRoutine: appStore.pauseRoutine,
                    onResumeRoutine: appStore.resumeRoutine,
                    onCueDelivered: appStore.recordRoutineCueDelivery,
                    onCueMissed: appStore.recordRoutineCueMiss
                )
            }
            .sheet(item: $selectedEventInfo) { event in
                EventInfoSheet(
                    event: event,
                    onEdit: {
                        selectedEventInfo = nil
                        editingEvent = event
                    },
                    onHideFromPlanning: {
                        appStore.setEventPlanningVisibility(event, isVisible: false)
                        selectedEventInfo = nil
                    },
                    onShowInPlanning: {
                        appStore.setEventPlanningVisibility(event, isVisible: true)
                        selectedEventInfo = nil
                    },
                    onDelete: {
                        appStore.removeEvent(event)
                        selectedEventInfo = nil
                    }
                )
            }
        }
    }

    private var plannerSurfacePicker: some View {
        HStack(spacing: 10) {
            ForEach(PlannerSurface.allCases) { surface in
                Button {
                    plannerSurface = surface
                } label: {
                    Text(surface.title)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(plannerSurface == surface ? Color.white : AppTheme.Colors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(plannerSurface == surface ? AppTheme.Colors.primary : AppTheme.Colors.card)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var plannerPrimarySurface: some View {
        switch plannerSurface {
        case .today:
            plannerTodaySurface
        case .fiveDay:
            plannerWeekStrip
        case .month:
            plannerMonthView
        }
    }

    private var plannerTodaySurface: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today")
                    .font(AppTheme.Typography.sectionTitle)
                Text("Use this to look at today’s real schedule before you edit the rest of the week.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Text(appStore.planningIntelligenceSummary)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)

                ForEach(appStore.plannerAgenda(for: 0)) { item in
                    plannerAgendaRow(item)
                }
            }
        }
    }

    private var plannerWeekStrip: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Five Day Planning")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(spacing: 10) {
                    ForEach(appStore.plannerDaySummaries.prefix(5)) { day in
                        Button {
                            selectedDayOffset = day.dayOffset
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(day.title)
                                        .font(AppTheme.Typography.cardTitle)
                                    Text(day.subtitle)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white.opacity(0.88) : AppTheme.Colors.secondaryText)
                                    Text(day.focusSummary)
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white.opacity(0.92) : AppTheme.Colors.primary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(day.pressureSummary)
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white : AppTheme.Colors.primary)
                                    Text("\(day.itemCount) items • \(day.projectBlockCount) project")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white.opacity(0.88) : AppTheme.Colors.secondaryText)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selectedDayOffset == day.dayOffset ? AppTheme.Colors.primary : AppTheme.Colors.controlBackground)
                            )
                            .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white : AppTheme.Colors.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var plannerMonthView: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Month Planning")
                    .font(AppTheme.Typography.sectionTitle)
                Text("Pick a day, then edit what belongs there below.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(appStore.plannerDaySummaries, id: \.dayOffset) { day in
                        Button {
                            selectedDayOffset = day.dayOffset
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(Calendar.current.component(.day, from: Calendar.current.date(byAdding: .day, value: day.dayOffset, to: Date()) ?? Date()))")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                Circle()
                                    .fill(day.projectBlockCount > 0 ? AppTheme.Colors.primary : (day.itemCount > 0 ? AppTheme.Colors.primaryMuted : Color.clear))
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedDayOffset == day.dayOffset ? AppTheme.Colors.primary : AppTheme.Colors.controlBackground)
                            )
                            .foregroundStyle(selectedDayOffset == day.dayOffset ? Color.white : AppTheme.Colors.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var plannerAgendaCard: some View {
        let agenda = appStore.plannerAgenda(for: selectedDayOffset)

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedDayOffset == 0 ? "Today Plan" : "Selected Day")
                    .font(AppTheme.Typography.sectionTitle)
                Text(selectedDayOffset == 0
                     ? "This combines the active schedule with your task and event structure."
                     : "Use this to place work and commitments before the day arrives.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                if let selectedDay = appStore.plannerDaySummaries.first(where: { $0.dayOffset == selectedDayOffset }) {
                    Text("\(selectedDay.pressureSummary) • \(selectedDay.focusSummary)")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                if agenda.isEmpty {
                    Text("Nothing is scheduled yet for this day. Add tasks or events to shape it before it becomes urgent.")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                } else {
                    ForEach(agenda) { item in
                        plannerAgendaRow(item)
                    }
                }
            }
        }
    }

    private var planningEventsCard: some View {
        let events = appStore.allKnownEvents
            .filter { $0.dayOffset == selectedDayOffset && $0.shouldAppearInPlanning }
            .sorted { $0.startMinute < $1.startMinute }

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Events In Planning")
                        .font(AppTheme.Typography.sectionTitle)
                    Spacer()
                    Button("Add Event") {
                        isPresentingCreateEvent = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Text("Imported calendar events live here now, so planning and event support stay in the same place.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                if events.isEmpty {
                    Text("No events are shaping this day yet.")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                } else {
                    ForEach(events) { event in
                        Button {
                            selectedEventInfo = event
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.orange.opacity(0.7))
                                    .frame(width: 10, height: 64)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(event.title)
                                            .font(AppTheme.Typography.cardTitle)
                                        Spacer()
                                        Text(clockString(event.startMinute))
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    if let sourceName = event.sourceName {
                                        Text(sourceName)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primary)
                                    }
                                    Text(event.detail)
                                        .font(AppTheme.Typography.caption)
                                        .lineLimit(2)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var anchorsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Anchors")
                        .font(AppTheme.Typography.sectionTitle)
                    Spacer()
                    Button("Add Anchor") {
                        isPresentingCreateAnchor = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Text("Anchors are planner building blocks, so they should be editable. Rename them, change their role, or delete them when they stop fitting.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                ForEach(appStore.baseAnchors) { anchor in
                    Button {
                        editingAnchor = anchor
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.Colors.primaryMuted)
                                .frame(width: 10, height: 64)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(anchor.title)
                                        .font(AppTheme.Typography.cardTitle)
                                    Spacer()
                                    Text(anchor.timeLabel)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                Text(anchor.type.rawValue.capitalized)
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primary)
                                Text(anchor.prompt)
                                    .font(AppTheme.Typography.caption)
                                    .lineLimit(2)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func plannerAccent(for kind: PlannerAgendaItem.SourceKind) -> Color {
        switch kind {
        case .event:
            return Color.orange.opacity(0.7)
        case .task:
            return AppTheme.Colors.primary
        case .projectBlock:
            return Color.purple.opacity(0.65)
        case .routine:
            return Color.green.opacity(0.7)
        case .transition:
            return Color.blue.opacity(0.6)
        case .recovery:
            return Color.green.opacity(0.45)
        }
    }

    private func clockString(_ minutes: Int) -> String {
        let normalized = max(minutes, 0)
        let hour24 = (normalized / 60) % 24
        let minute = normalized % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }

    @ViewBuilder
    private func plannerAgendaRow(_ item: PlannerAgendaItem) -> some View {
        if let action = plannerTapAction(for: item) {
            Button(action: action) {
                plannerAgendaContent(item)
            }
            .buttonStyle(.plain)
        } else {
            plannerAgendaContent(item)
        }
    }

    private func plannerAgendaContent(_ item: PlannerAgendaItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(plannerAccent(for: item.sourceKind))
                .frame(width: 10, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(AppTheme.Typography.cardTitle)
                    Spacer()
                    Text(clockString(item.startMinute))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Text(item.accentLabel)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(plannerAccent(for: item.sourceKind))
                if item.isSuggested {
                    Text("Suggested by planning intelligence")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Text(item.detail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func plannerTapAction(for item: PlannerAgendaItem) -> (() -> Void)? {
        switch item.sourceKind {
        case .event:
            guard let event = appStore.allKnownEvents.first(where: { $0.id == item.id }) else { return nil }
            return { selectedEventInfo = event }
        case .task:
            guard let selection = appStore.allTasks
                .first(where: { $0.task.id == item.id })
                .map({ TaskSelection(anchor: $0.anchor, task: $0.task) }) else { return nil }
            return { selectedAgendaTask = selection }
        case .projectBlock:
            return nil
        case .routine:
            guard let routine = appStore.routines.first(where: { $0.id == item.id || $0.title == item.title }) else { return nil }
            return { selectedAgendaRoutine = routine }
        case .transition, .recovery:
            return nil
        }
    }
}

private struct RoutinesView: View {
    @ObservedObject var appStore: AppStore

    @State private var editingRoutine: Routine?
    @State private var isPresentingCreateRoutine = false
    @State private var activeRoutine: Routine?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ScreenModeBadge(title: "Planning")
                            Text("Routines")
                                .font(AppTheme.Typography.heroTitle)
                            Text("Create routines that actually fit daily life, then edit them as you learn what makes transitions easier.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    Button {
                        isPresentingCreateRoutine = true
                    } label: {
                        Label("Add Routine", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    ForEach(appStore.routines) { routine in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(routine.title)
                                            .font(AppTheme.Typography.sectionTitle)
                                        Text(routine.timeWindow)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    Spacer()
                                    if routine.isPinned {
                                        Text("Pinned")
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.Colors.primary, in: Capsule())
                                    }
                                }

                                Text(routine.summary)
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.text)

                                Text("\(routine.steps.count) step\(routine.steps.count == 1 ? "" : "s")")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                HStack(spacing: 10) {
                                    Button("Start Routine") {
                                        activeRoutine = routine
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle())

                                    Button("Edit") {
                                        editingRoutine = routine
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Routines")
            .sheet(isPresented: $isPresentingCreateRoutine) {
                EditRoutineView { title, timeWindow, summary, stepTitles, isPinned in
                    appStore.addRoutine(
                        title: title,
                        timeWindow: timeWindow,
                        summary: summary,
                        stepTitles: stepTitles,
                        isPinned: isPinned
                    )
                    isPresentingCreateRoutine = false
                }
            }
            .sheet(item: $editingRoutine) { routine in
                EditRoutineView(routine: routine) { title, timeWindow, summary, stepTitles, isPinned in
                    appStore.updateRoutine(
                        routine.id,
                        title: title,
                        timeWindow: timeWindow,
                        summary: summary,
                        stepTitles: stepTitles,
                        isPinned: isPinned
                    )
                    editingRoutine = nil
                }
            }
            .sheet(item: $activeRoutine) { routine in
                RoutineDetailView(
                    routine: routine,
                    executionSupport: appStore.routineExecutionSupport(for: routine),
                    onToggleStep: appStore.toggleRoutineStep,
                    onPauseRoutine: appStore.pauseRoutine,
                    onResumeRoutine: appStore.resumeRoutine,
                    onCueDelivered: appStore.recordRoutineCueDelivery,
                    onCueMissed: appStore.recordRoutineCueMiss
                )
            }
        }
    }
}

private struct TasksView: View {
    @ObservedObject var appStore: AppStore

    @State private var isPresentingCreateTask = false
    @State private var isPresentingCreateProject = false
    @State private var isPresentingCreateGoal = false
    @State private var selectedTask: TaskSelection?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ScreenModeBadge(title: "Tasks")
                            Text("Tasks, Projects & Goals")
                                .font(AppTheme.Typography.heroTitle)
                            Text("Use this as your action surface. Tasks are concrete, projects hold multi-session work, and goals describe the change you want to build over time.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            isPresentingCreateTask = true
                        } label: {
                            Label("Add Task", systemImage: "checklist")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button {
                            isPresentingCreateProject = true
                        } label: {
                            Label("Add Project", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button {
                            isPresentingCreateGoal = true
                        } label: {
                            Label("Add Goal", systemImage: "target")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Projects")
                                .font(AppTheme.Typography.sectionTitle)

                            if appStore.projects.isEmpty {
                                Text("Projects are larger outcomes that take more than one session. Add one with a due date and estimated time, then break it into smaller work blocks.")
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            } else {
                                ForEach(appStore.projects) { project in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(project.title)
                                                    .font(AppTheme.Typography.cardTitle)
                                                Text("Due \(project.dueDateSummary) • \(project.progressSummary)")
                                                    .font(AppTheme.Typography.caption)
                                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                            }
                                            Spacer()
                                            Text("\(project.estimatedTotalMinutes)m total")
                                                .font(AppTheme.Typography.caption.weight(.semibold))
                                                .foregroundStyle(AppTheme.Colors.primary)
                                        }

                                        if !project.detail.isEmpty {
                                            Text(project.detail)
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }

                                        Text("Suggested work blocks: \(project.suggestedWorkBlockCount) x \(project.suggestedWorkBlockMinutes)m")
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primary)

                                        Text(appStore.projectPlanningSummary(for: project))
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)

                                        let scheduledBlocks = appStore.suggestedProjectBlocks(for: 0).filter { $0.projectID == project.id }
                                        if !scheduledBlocks.isEmpty {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Suggested next blocks")
                                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                                ForEach(scheduledBlocks.prefix(2)) { block in
                                                    HStack {
                                                        Text(block.title)
                                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                                        Spacer()
                                                        Text("\(block.durationMinutes)m • \(block.dayOffset == 0 ? "Today" : "In \(block.dayOffset) days")")
                                                            .font(AppTheme.Typography.caption)
                                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                                    }
                                                }
                                            }
                                        }

                                        ForEach(project.subtasks) { subtask in
                                            Button {
                                                appStore.toggleProjectSubtask(projectID: project.id, subtaskID: subtask.id)
                                            } label: {
                                                HStack {
                                                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(subtask.isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(subtask.title)
                                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                                            .foregroundStyle(AppTheme.Colors.text)
                                                        Text("\(subtask.estimatedMinutes)m")
                                                            .font(AppTheme.Typography.caption)
                                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goals")
                                .font(AppTheme.Typography.sectionTitle)

                            if appStore.goals.isEmpty {
                                Text("Goals track direction over time. Link them to routines, tasks, projects, or anchors so the app knows how that change shows up in daily life.")
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            } else {
                                ForEach(appStore.goals) { goal in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(goal.title)
                                                    .font(AppTheme.Typography.cardTitle)
                                                Text(goal.category.title)
                                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.Colors.primary)
                                            }
                                            Spacer()
                                            Text(goal.relationshipSummary)
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }

                                        Text(goal.targetSummary)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.text)

                                        if !goal.detail.isEmpty {
                                            Text(goal.detail)
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Tasks")
                                .font(AppTheme.Typography.sectionTitle)

                            if appStore.allTasks.isEmpty {
                                Text("No tasks yet. Add a task here, then schedule it into planning when you know where it fits.")
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            } else {
                                ForEach(appStore.allTasks, id: \.task.id) { item in
                                    Button {
                                        selectedTask = TaskSelection(anchor: item.anchor, task: item.task)
                                    } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: item.task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(item.task.isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.task.title)
                                                    .font(AppTheme.Typography.cardTitle)
                                                Text(item.anchor.title)
                                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.Colors.primary)
                                                Text(taskSummary(for: item.task))
                                                    .font(AppTheme.Typography.caption)
                                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }
                                        .padding(12)
                                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How these pieces work together")
                                .font(AppTheme.Typography.sectionTitle)

                            relationRow(title: "Events", detail: "Scheduled commitments like class, work, appointments, and social plans.")
                            relationRow(title: "Tasks", detail: "Concrete one-session actions like homework, hygiene, chores, or emails.")
                            relationRow(title: "Projects", detail: "Larger outcomes made of smaller tasks across more than one session.")
                            relationRow(title: "Routines", detail: "Repeatable sequences of tasks that structure common parts of the day.")
                            relationRow(title: "Reminders", detail: "Cues that point back to a task, routine, event, or transition.")
                            relationRow(title: "Goals", detail: "Longer-term improvements like drinking more water, moving more, or getting to bed earlier.")
                            relationRow(title: "Anchors", detail: "Stable points in the day that help you orient and decide what belongs before, during, or after them.")
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Tasks")
            .sheet(isPresented: $isPresentingCreateTask) {
                CreateTaskView(
                    anchors: appStore.baseAnchors,
                    initialDayOffset: 0,
                    onPreviewCue: appStore.previewSensoryCue,
                    onStopPreview: appStore.stopSensoryCuePreview
                ) { title, detail, anchorID, dayOffset, startMinute, durationMinutes, isEssential, sensoryCue in
                    appStore.addTask(
                        title: title,
                        detail: detail,
                        anchorID: anchorID,
                        dayOffset: dayOffset,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        isEssential: isEssential,
                        sensoryCue: sensoryCue
                    )
                    isPresentingCreateTask = false
                }
                .overlay {
                    BreathingGlowOverlay(
                        isActive: appStore.activeSensoryCue == .rhythmicPulsingGlow
                    )
                    .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $isPresentingCreateProject) {
                CreateProjectView { title, detail, dueDate, estimatedMinutes, subtasks in
                    appStore.addProject(
                        title: title,
                        detail: detail,
                        dueDate: dueDate,
                        estimatedTotalMinutes: estimatedMinutes,
                        subtaskTitles: subtasks
                    )
                    isPresentingCreateProject = false
                }
            }
            .sheet(isPresented: $isPresentingCreateGoal) {
                CreateGoalView(
                    anchors: appStore.baseAnchors,
                    routines: appStore.routines,
                    projects: appStore.projects,
                    tasks: appStore.allTasks.map(\.task)
                ) { title, detail, category, targetSummary, linkedTaskIDs, linkedRoutineIDs, linkedProjectIDs, linkedAnchorIDs in
                    appStore.addGoal(
                        title: title,
                        detail: detail,
                        category: category,
                        targetSummary: targetSummary,
                        linkedTaskIDs: linkedTaskIDs,
                        linkedRoutineIDs: linkedRoutineIDs,
                        linkedProjectIDs: linkedProjectIDs,
                        linkedAnchorIDs: linkedAnchorIDs
                    )
                    isPresentingCreateGoal = false
                }
            }
            .sheet(item: $selectedTask) { selection in
                TaskDetailSheet(
                    title: "Task",
                    task: selection.task,
                    anchorTitle: selection.anchor.title,
                    onToggleCompletion: {
                        appStore.toggleTask(selection.task.id, in: selection.anchor.id, mode: appStore.selectedMode)
                        selectedTask = nil
                    },
                    onStart: {
                        appStore.startTask(selection.task.id, in: selection.anchor.id)
                    },
                    onShrink: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.shrinkCurrentTaskBlock()
                    },
                    onMoveLater: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.moveCurrentTaskToNextAnchor()
                        selectedTask = nil
                    },
                    onTomorrow: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.deferCurrentTaskToTomorrow()
                        selectedTask = nil
                    },
                    onDrop: {
                        appStore.todayStore.setActiveAnchor(selection.anchor.id)
                        appStore.dropCurrentTaskFromToday()
                        selectedTask = nil
                    },
                    onDelete: {
                        appStore.deleteTask(selection.task.id, from: selection.anchor.id)
                        selectedTask = nil
                    },
                    onPreviewCue: {
                        appStore.previewSensoryCue(selection.task.sensoryCue)
                    },
                    onStopPreview: appStore.stopSensoryCuePreview
                )
            }
        }
    }

    private func taskSummary(for task: Task) -> String {
        let dayText: String
        switch task.dayOffset {
        case 0:
            dayText = "Today"
        case 1:
            dayText = "Tomorrow"
        default:
            dayText = "In \(task.dayOffset) days"
        }

        let timeText = task.startTimeText ?? "No start time"
        return "\(dayText) • \(timeText) • \(task.durationMinutes)m"
    }

    private func relationRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.text)
            Text(detail)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }
}

private struct TaskDetailSheet: View {
    let title: String
    let task: Task
    let anchorTitle: String
    let onToggleCompletion: () -> Void
    let onStart: () -> Void
    let onShrink: () -> Void
    let onMoveLater: () -> Void
    let onTomorrow: () -> Void
    let onDrop: () -> Void
    let onDelete: () -> Void
    let onPreviewCue: () -> Void
    let onStopPreview: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ScreenModeBadge(title: "Doing")
                            Text(task.title)
                                .font(AppTheme.Typography.heroTitle)
                            Text(anchorTitle)
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            Text(task.detail)
                                .font(AppTheme.Typography.supporting)
                            Text(task.estimateSummary)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    if let sensoryCue = task.sensoryCue {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sensory cue")
                                    .font(AppTheme.Typography.sectionTitle)
                                Text("\(sensoryCue.categoryTitle): \(sensoryCue.title)")
                                    .font(AppTheme.Typography.cardTitle)
                                Text(sensoryCue.detail)
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Button("Preview Cue", action: onPreviewCue)
                                    .buttonStyle(PrimaryActionButtonStyle())
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        Button(task.isCompleted ? "Mark Incomplete" : "Mark Done") {
                            onToggleCompletion()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button("Start Task") {
                            onStart()
                            dismiss()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Task options")
                                .font(AppTheme.Typography.sectionTitle)

                            HStack(spacing: 10) {
                                Button("Shrink 10m", action: onShrink)
                                    .buttonStyle(SecondaryActionButtonStyle())
                                Button("Move Later", action: onMoveLater)
                                    .buttonStyle(SecondaryActionButtonStyle())
                            }

                            HStack(spacing: 10) {
                                Button("Tomorrow", action: onTomorrow)
                                    .buttonStyle(SecondaryActionButtonStyle())
                                Button("Drop", action: onDrop)
                                    .buttonStyle(SecondaryActionButtonStyle())
                            }

                            Button(role: .destructive, action: onDelete) {
                                Text("Delete Task")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear(perform: onStopPreview)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct EventInfoSheet: View {
    let event: DayEvent
    let onEdit: () -> Void
    let onHideFromPlanning: () -> Void
    let onShowInPlanning: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ScreenModeBadge(title: "Event")
                            Text(event.title)
                                .font(AppTheme.Typography.heroTitle)
                            Text("\(clockString(event.startMinute)) • \(event.durationMinutes) min")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            Text(event.detail)
                                .font(AppTheme.Typography.supporting)
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Planning")
                                .font(AppTheme.Typography.sectionTitle)
                            Text(event.shouldAppearInPlanning ? "This event is currently shaping planning." : "This event is currently hidden from planning.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            Button("Edit Support", action: onEdit)
                                .buttonStyle(PrimaryActionButtonStyle())

                            Button(event.shouldAppearInPlanning ? "Hide From Planning" : "Show In Planning") {
                                if event.shouldAppearInPlanning {
                                    onHideFromPlanning()
                                } else {
                                    onShowInPlanning()
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())

                            if event.externalIdentifier == nil {
                                Button("Delete Event", action: onDelete)
                                    .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func clockString(_ minutes: Int) -> String {
        let normalized = max(minutes, 0)
        let hour24 = (normalized / 60) % 24
        let minute = normalized % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }
}

private struct EditRoutineView: View {
    let routine: Routine?
    let onSave: (String, String, String, [String], Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var timeWindow: String
    @State private var summary: String
    @State private var stepText: String
    @State private var isPinned: Bool

    init(routine: Routine? = nil, onSave: @escaping (String, String, String, [String], Bool) -> Void) {
        self.routine = routine
        self.onSave = onSave
        _title = State(initialValue: routine?.title ?? "")
        _timeWindow = State(initialValue: routine?.timeWindow ?? "Morning")
        _summary = State(initialValue: routine?.summary ?? "")
        _stepText = State(initialValue: routine?.steps.map(\.title).joined(separator: "\n") ?? "")
        _isPinned = State(initialValue: routine?.isPinned ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Routine name", text: $title)
                    TextField("Time window", text: $timeWindow)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("Pinned to Today", isOn: $isPinned)
                }

                Section("Steps") {
                    TextEditor(text: $stepText)
                        .frame(minHeight: 180)
                    Text("Put one step per line. Keep steps short and concrete.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(
                            title,
                            timeWindow,
                            summary,
                            stepText
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty },
                            isPinned
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CreateProjectView: View {
    let onSave: (String, String, Date, Int, [String]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var estimatedMinutes = 180
    @State private var subtaskText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project name", text: $title)
                    TextField("What needs to happen?", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Stepper("Estimated total time: \(estimatedMinutes) minutes", value: $estimatedMinutes, in: 30...2400, step: 15)
                }

                Section("Smaller tasks") {
                    TextEditor(text: $subtaskText)
                        .frame(minHeight: 180)
                    Text("Optional. Put one smaller task per line. If you leave this blank, the app will suggest work blocks from the total estimated time.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let subtasks = subtaskText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            detail.trimmingCharacters(in: .whitespacesAndNewlines),
                            dueDate,
                            estimatedMinutes,
                            subtasks
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CreateGoalView: View {
    let anchors: [Anchor]
    let routines: [Routine]
    let projects: [Project]
    let tasks: [Task]
    let onSave: (String, String, GoalCategory, String, [UUID], [UUID], [UUID], [UUID]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var category: GoalCategory = .hydration
    @State private var targetSummary = ""
    @State private var linkedTaskIDs: Set<UUID> = []
    @State private var linkedRoutineIDs: Set<UUID> = []
    @State private var linkedProjectIDs: Set<UUID> = []
    @State private var linkedAnchorIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Goal name", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    TextField("What would progress look like?", text: $targetSummary, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Why this matters (optional)", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                if !tasks.isEmpty {
                    Section("Link tasks") {
                        ForEach(tasks) { task in
                            relationToggleRow(
                                title: task.title,
                                subtitle: task.estimateSummary,
                                isSelected: linkedTaskIDs.contains(task.id)
                            ) {
                                toggle(task.id, in: &linkedTaskIDs)
                            }
                        }
                    }
                }

                if !routines.isEmpty {
                    Section("Link routines") {
                        ForEach(routines) { routine in
                            relationToggleRow(
                                title: routine.title,
                                subtitle: routine.summary,
                                isSelected: linkedRoutineIDs.contains(routine.id)
                            ) {
                                toggle(routine.id, in: &linkedRoutineIDs)
                            }
                        }
                    }
                }

                if !projects.isEmpty {
                    Section("Link projects") {
                        ForEach(projects) { project in
                            relationToggleRow(
                                title: project.title,
                                subtitle: project.progressSummary,
                                isSelected: linkedProjectIDs.contains(project.id)
                            ) {
                                toggle(project.id, in: &linkedProjectIDs)
                            }
                        }
                    }
                }

                if !anchors.isEmpty {
                    Section("Link anchors") {
                        ForEach(anchors) { anchor in
                            relationToggleRow(
                                title: anchor.title,
                                subtitle: anchor.timeLabel,
                                isSelected: linkedAnchorIDs.contains(anchor.id)
                            ) {
                                toggle(anchor.id, in: &linkedAnchorIDs)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            detail.trimmingCharacters(in: .whitespacesAndNewlines),
                            category,
                            targetSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                            Array(linkedTaskIDs),
                            Array(linkedRoutineIDs),
                            Array(linkedProjectIDs),
                            Array(linkedAnchorIDs)
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }

    private func relationToggleRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.text)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CreateTaskView: View {
    let anchors: [Anchor]
    let initialDayOffset: Int
    let onPreviewCue: (TaskSensoryCue?) -> Void
    let onStopPreview: () -> Void
    let onSave: (String, String, UUID, Int, Int?, Int, Bool, TaskSensoryCue?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var selectedAnchorID: UUID?
    @State private var startHour = 8
    @State private var startMinute = 0
    @State private var durationMinutes = 20
    @State private var isEssential = true
    @State private var selectedCue: TaskSensoryCue?
    @State private var selectedDayOffset = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $title)
                    TextField("What does done look like?", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("When") {
                    Picker("Day", selection: $selectedDayOffset) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                        Text("In 2 Days").tag(2)
                        Text("In 3 Days").tag(3)
                        Text("This Weekend").tag(5)
                    }

                    Picker("Part of day", selection: Binding(
                        get: { selectedAnchorID ?? anchors.first?.id ?? UUID() },
                        set: { selectedAnchorID = $0 }
                    )) {
                        ForEach(anchors) { anchor in
                            Text("\(anchor.title) • \(anchor.timeLabel)").tag(anchor.id)
                        }
                    }

                    HStack {
                        Picker("Hour", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(Self.hourLabel(for: hour)).tag(hour)
                            }
                        }

                        Picker("Minute", selection: $startMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                    }

                    Stepper("Estimated time: \(durationMinutes) min", value: $durationMinutes, in: 5...240, step: 5)
                    Toggle("Essential task", isOn: $isEssential)
                }

                Section("Sensory cue") {
                    Picker("Cue", selection: $selectedCue) {
                        Text("None").tag(TaskSensoryCue?.none)
                        ForEach(TaskSensoryCue.allCases) { cue in
                            Text(cue.title).tag(TaskSensoryCue?.some(cue))
                        }
                    }

                    Button(selectedCue == nil ? "Stop Cue Demo" : "Play Cue Demo") {
                        if selectedCue == nil {
                            onStopPreview()
                        } else {
                            onPreviewCue(selectedCue)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let anchorID = selectedAnchorID ?? anchors.first?.id else { return }
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            detail.trimmingCharacters(in: .whitespacesAndNewlines),
                            anchorID,
                            selectedDayOffset,
                            startHour * 60 + startMinute,
                            durationMinutes,
                            isEssential,
                            selectedCue
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                selectedAnchorID = selectedAnchorID ?? anchors.first?.id
                selectedDayOffset = initialDayOffset
            }
            .onChange(of: selectedCue) {
                onPreviewCue(selectedCue)
            }
            .onDisappear {
                onStopPreview()
            }
        }
    }

    private static func hourLabel(for hour: Int) -> String {
        let suffix = hour >= 12 ? "PM" : "AM"
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(hour12):00 \(suffix)"
    }
}

private struct EditAnchorView: View {
    let anchor: Anchor?
    let onSave: (String, String, Anchor.AnchorType, String) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var timeLabel: String
    @State private var type: Anchor.AnchorType
    @State private var prompt: String

    init(
        anchor: Anchor? = nil,
        onSave: @escaping (String, String, Anchor.AnchorType, String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.anchor = anchor
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: anchor?.title ?? "")
        _timeLabel = State(initialValue: anchor?.timeLabel ?? "")
        _type = State(initialValue: anchor?.type ?? .focus)
        _prompt = State(initialValue: anchor.map { canonicalAnchorPrompt(from: $0.prompt) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Anchor") {
                    TextField("Anchor name", text: $title)
                    TextField("Time label", text: $timeLabel)
                    Picker("Role", selection: $type) {
                        Text("Focus").tag(Anchor.AnchorType.focus)
                        Text("Maintenance").tag(Anchor.AnchorType.maintenance)
                        Text("Transition").tag(Anchor.AnchorType.transition)
                        Text("Recovery").tag(Anchor.AnchorType.recovery)
                    }
                }

                Section("Prompt") {
                    TextField("Support prompt", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                    Text("Keep the core prompt short. The planner will layer adaptive support onto it.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                if let onDelete {
                    Section {
                        Button("Delete Anchor", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(anchor == nil ? "New Anchor" : "Edit Anchor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            timeLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                            type,
                            prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct BreathingGlowOverlay: View {
    let isActive: Bool

    @State private var isExpanded = false

    var body: some View {
        GeometryReader { geometry in
            if isActive {
                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(AppTheme.Colors.primary.opacity(isExpanded ? 0.88 : 0.36), lineWidth: isExpanded ? 18 : 10)
                        .blur(radius: isExpanded ? 12 : 6)
                        .padding(6)

                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(isExpanded ? 0.30 : 0.08), lineWidth: 4)
                        .padding(12)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea()
                .onAppear {
                    isExpanded = false
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        isExpanded = true
                    }
                }
                .onDisappear {
                    isExpanded = false
                }
            }
        }
    }
}
