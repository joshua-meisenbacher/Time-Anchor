import SwiftUI

struct PersonalEventsView: View {
    let currentPlan: PlanVersion?
    let allEvents: [DayEvent]
    let communicationStyle: CommunicationStyle
    let onCreateEvent: (DayEvent) -> Void
    let onUpdateEventSupport: (DayEvent) -> Void

    @State private var selectedView: EventCalendarView = .day
    @State private var selectedMonthDay = 1
    @State private var selectedFamilyMember: DayEvent.FamilyMember? = nil
    @State private var selectedSensoryLevel = 0
    @State private var isPresentingCreateEvent = false
    @State private var editingEvent: DayEvent?
    @State private var isShowingFullDaySchedule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    actionRow
                    pickerRow

                    switch selectedView {
                    case .day:
                        dayView
                    case .fiveDay:
                        fiveDayView
                    case .month:
                        monthView
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Personal Events")
            .sheet(isPresented: $isPresentingCreateEvent) {
                CreateEventView(onSave: { event in
                    onCreateEvent(event)
                    isPresentingCreateEvent = false
                })
            }
            .sheet(item: $editingEvent) { event in
                EditEventSupportView(
                    event: event,
                    onSave: { updatedEvent in
                        onUpdateEventSupport(updatedEvent)
                        editingEvent = nil
                    }
                )
            }
        }
    }

    private var headerCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                ScreenModeBadge(title: "Planning")
                Text("Personal Events")
                    .font(AppTheme.Typography.heroTitle)
                Text(communicationStyle == .literal
                     ? "Use this screen to see event timing, prep windows, and leave-by support."
                     : "See time as a sequence of supports, commitments, and transitions instead of one long blur.")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var pickerRow: some View {
        HStack(spacing: 10) {
            ForEach(EventCalendarView.allCases) { view in
                Button {
                    selectedView = view
                } label: {
                    Text(view.title)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(selectedView == view ? Color.white : AppTheme.Colors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedView == view ? AppTheme.Colors.primary : AppTheme.Colors.card)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    isPresentingCreateEvent = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                Button("Reset Filters") {
                    selectedFamilyMember = nil
                    selectedSensoryLevel = 0
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    familyFilterChip(title: "Everyone", isSelected: selectedFamilyMember == nil) {
                        selectedFamilyMember = nil
                    }

                    ForEach(DayEvent.FamilyMember.allCases) { member in
                        familyFilterChip(title: member.title, isSelected: selectedFamilyMember == member) {
                            selectedFamilyMember = member
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Text("Sensory Level")
                    .font(AppTheme.Typography.cardTitle)
                Picker("Sensory Level", selection: $selectedSensoryLevel) {
                    Text("All").tag(0)
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var dayView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let currentBlock = currentDayBlock {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current focus")
                            .font(AppTheme.Typography.sectionTitle)
                        Text(currentBlock.title)
                            .font(AppTheme.Typography.cardTitle)
                        Text(currentBlock.timeRangeText)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Text(currentBlock.detail)
                            .font(AppTheme.Typography.supporting)
                    }
                }
            }

            if let nextEvent = nextSupportedEvent {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ScreenModeBadge(title: "Transition")
                        Text("Next Transition Support")
                            .font(AppTheme.Typography.sectionTitle)
                        Text(transitionHeadline(for: nextEvent))
                            .font(AppTheme.Typography.cardTitle)
                        Text(transitionSupportStatus(for: nextEvent))
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            supportTimingRow(label: "Event", value: "\(clockString(nextEvent.startMinute)) • \(nextEvent.title)")

                            if nextEvent.supportMetadata.transitionPrepMinutes > 0 {
                                supportTimingRow(label: "Prep", value: clockString(nextEvent.prepStartMinute))
                            }

                            if let leaveByMinute = nextEvent.leaveByMinute {
                                supportTimingRow(label: "Leave by", value: clockString(leaveByMinute))
                            }

                            if !nextEvent.supportMetadata.locationName.isEmpty {
                                supportTimingRow(label: "Location", value: nextEvent.supportMetadata.locationName)
                            }
                        }
                        .padding(12)
                        .background(transitionSupportBackground(for: nextEvent), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            if let nextBlock = nextDayBlock {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Up next")
                            .font(AppTheme.Typography.sectionTitle)
                        Text(nextBlockHeadline(nextBlock))
                            .font(AppTheme.Typography.cardTitle)
                        Text(nextBlock.cue.detail)
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today’s Schedule")
                            .font(AppTheme.Typography.sectionTitle)
                        Spacer()
                        Button(isShowingFullDaySchedule ? "Show Less" : "Show All") {
                            isShowingFullDaySchedule.toggle()
                        }
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    }

                    Text("Keep this compact if you mainly need the next transition and leave support.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    ForEach(displayedDayBlocks) { block in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(blockColor(block))
                                .frame(width: 12, height: 72)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(block.title)
                                        .font(AppTheme.Typography.cardTitle)
                                    Spacer()
                                    Text(block.timeRangeText)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                Text(block.kindLabel)
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(blockColor(block))
                                Text(block.detail)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            if !filteredEvents(for: 0).isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today Events")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("Open an event to adjust prep, leave-by support, and how strongly it should shape the day.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        ForEach(filteredEvents(for: 0)) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(event.title)
                                            .font(AppTheme.Typography.cardTitle)
                                        Spacer()
                                        Text(event.sourceName ?? "Manual")
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primary)
                                    }

                                    if let leaveByMinute = event.leaveByMinute {
                                        Text("Leave by \(clockString(leaveByMinute))")
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(Color.orange)
                                    }

                                    Text(eventSupportSummary(event))
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
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

    private var displayedDayBlocks: [ScheduleBlock] {
        let blocks = filteredBlocks(for: 0)
        return isShowingFullDaySchedule ? blocks : Array(blocks.prefix(4))
    }

    private var currentDayBlock: ScheduleBlock? {
        let blocks = filteredBlocks(for: 0)
        guard !blocks.isEmpty else { return nil }
        let currentMinute = minuteOfDay(for: Date())
        if let live = blocks.first(where: { $0.startMinute <= currentMinute && $0.endMinute > currentMinute }) {
            return live
        }
        if let upcoming = blocks.first(where: { $0.startMinute > currentMinute }) {
            return upcoming
        }
        return blocks.last
    }

    private var nextDayBlock: ScheduleBlock? {
        let blocks = filteredBlocks(for: 0)
        guard let currentDayBlock,
              let currentIndex = blocks.firstIndex(where: { $0.id == currentDayBlock.id }) else {
            return blocks.dropFirst().first
        }

        let nextIndex = blocks.index(after: currentIndex)
        guard nextIndex < blocks.endIndex else { return nil }
        return blocks[nextIndex]
    }

    private var fiveDayView: some View {
        let windows = fiveDayWindows

        return VStack(alignment: .leading, spacing: 20) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Five Day View")
                        .font(AppTheme.Typography.sectionTitle)
                    Text("Today is the busiest. The next transition to protect is \(windows.first?.priorityLabel ?? "not set").")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            SurfaceCard {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(windows) { window in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(window.dayLabel)
                                    .font(AppTheme.Typography.cardTitle)
                                Text(window.dayNumber)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                ForEach(window.blocks) { block in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(block.title)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .lineLimit(2)
                                        Text(shortTime(block))
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    .padding(8)
                                    .frame(width: 120, alignment: .leading)
                                    .background(blockColor(block).opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                if window.blocks.isEmpty {
                                    Text("Flexible")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(window.isToday ? AppTheme.Colors.primaryMuted.opacity(0.65) : AppTheme.Colors.controlBackground)
                            )
                        }
                    }
                }
            }
        }
    }

    private var monthView: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Month View")
                        .font(AppTheme.Typography.sectionTitle)
                    Text("Use this for orientation, not detail. Tap a date to preview what task blocks and events matter there.")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("November")
                        .font(AppTheme.Typography.cardTitle)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(1...30, id: \.self) { day in
                            let isSelected = selectedMonthDay == day
                            Button {
                                selectedMonthDay = day
                            } label: {
                                VStack(spacing: 6) {
                                    Text("\(day)")
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                    Circle()
                                        .fill(monthDayHasEvents(day) ? AppTheme.Colors.primary : Color.clear)
                                        .frame(width: 6, height: 6)
                                }
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.controlBackground)
                                )
                                .foregroundStyle(isSelected ? Color.white : AppTheme.Colors.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Day Preview")
                        .font(AppTheme.Typography.sectionTitle)
                    Text("November \(selectedMonthDay)")
                        .font(AppTheme.Typography.cardTitle)
                    Text(monthPreviewText(for: selectedMonthDay))
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var fiveDayWindows: [FiveDayWindow] {
        guard let currentPlan else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let calendar = Calendar.current
        let today = currentPlan.context.date

        return (0..<5).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let blocks = filteredBlocks(for: offset)
                .prefix(offset == 0 ? 4 : 3)

            return FiveDayWindow(
                dayLabel: formatter.string(from: date),
                dayNumber: String(calendar.component(.day, from: date)),
                blocks: Array(blocks),
                priorityLabel: currentPlan.dailyPlan.actionableBlocks.first?.title ?? "your first task block",
                isToday: offset == 0
            )
        }
    }

    private func monthDayHasEvents(_ day: Int) -> Bool {
        guard let currentPlan else { return false }
        let seeded = allEvents.count + currentPlan.dailyPlan.actionableBlocks.count
        return (day + seeded).isMultiple(of: 4) || day == Calendar.current.component(.day, from: currentPlan.context.date)
    }

    private func monthPreviewText(for day: Int) -> String {
        guard let currentPlan else { return "No scheduled context yet." }
        let dayOffset = max(day - Calendar.current.component(.day, from: currentPlan.context.date), 0)
        let blocks = filteredBlocks(for: dayOffset)
        let events = filteredEvents(for: dayOffset)
        if day == Calendar.current.component(.day, from: currentPlan.context.date) {
            return "Today includes \(blocks.count) scheduled blocks with a focus on \(currentPlan.whatMattersNow.lowercased())."
        }
        if !events.isEmpty {
            return "This day includes \(events.count) event\(events.count == 1 ? "" : "s"), including \(events.first?.title.lowercased() ?? "something planned")."
        }
        if !blocks.isEmpty {
            return "This day includes \(blocks.count) visible blocks, including \(blocks.first?.title.lowercased() ?? "an event")."
        }
        return "This day is lighter, which makes it a good candidate for routines, recovery, or lower-pressure tasks."
    }

    private func filteredBlocks(for dayOffset: Int) -> [ScheduleBlock] {
        guard let currentPlan else { return [] }
        let allowedEventTitles = Set(
            currentPlan.context.events.filter { event in
                event.dayOffset == dayOffset &&
                (selectedFamilyMember == nil || event.familyMember == selectedFamilyMember) &&
                (selectedSensoryLevel == 0 || event.sensoryLevel == selectedSensoryLevel)
            }
            .map(\.title)
        )

        return currentPlan.dailyPlan.blocks.filter { block in
            switch block.kind {
            case .event:
                return allowedEventTitles.contains(block.title)
            default:
                return dayOffset == 0
            }
        }
    }

    private func filteredEvents(for dayOffset: Int) -> [DayEvent] {
        return allEvents.filter { event in
            event.dayOffset == dayOffset &&
            (selectedFamilyMember == nil || event.familyMember == selectedFamilyMember) &&
            (selectedSensoryLevel == 0 || event.sensoryLevel == selectedSensoryLevel)
        }
        .sorted { $0.startMinute < $1.startMinute }
    }

    private var nextSupportedEvent: DayEvent? {
        let currentMinute = currentMinuteOfDay
        return filteredEvents(for: 0).first(where: { event in
            guard event.shouldAppearInPlanning else { return false }
            if event.supportMetadata.planningRelevance == .lightweightReminder {
                return event.startMinute >= currentMinute
            }
            return max(event.prepStartMinute, event.leaveByMinute ?? event.startMinute) >= currentMinute
        })
    }

    private func eventSupportSummary(_ event: DayEvent) -> String {
        var parts: [String] = []

        switch event.supportMetadata.planningRelevance {
        case .fullSupport:
            parts.append("Full support")
        case .lightweightReminder:
            parts.append("Lightweight reminder")
        case .ignoreForPlanning:
            parts.append("Ignored for planning")
        }

        if !event.supportMetadata.locationName.isEmpty {
            parts.append(event.supportMetadata.locationName)
        }

        if let estimatedDriveMinutes = event.supportMetadata.estimatedDriveMinutes {
            parts.append("Drive \(estimatedDriveMinutes)m")
        }

        if let leaveByMinute = event.leaveByMinute {
            parts.append("Leave by \(clockString(leaveByMinute))")
        }

        if event.supportMetadata.planningRelevance == .fullSupport, event.supportMetadata.transitionPrepMinutes > 0 {
            parts.append("Prep \(event.supportMetadata.transitionPrepMinutes)m")
        } else if event.supportMetadata.planningRelevance == .fullSupport {
            parts.append("No prep block")
        }

        if event.supportMetadata.planningRelevance == .fullSupport, let feltDeadlineOffset = event.supportMetadata.feltDeadlineOffsetMinutes {
            parts.append("Felt deadline \(feltDeadlineOffset)m early")
        } else if event.supportMetadata.planningRelevance == .fullSupport {
            parts.append("No felt deadline")
        }

        if !event.supportMetadata.sensoryNote.isEmpty {
            parts.append(event.supportMetadata.sensoryNote)
        }

        return parts.joined(separator: " • ")
    }

    private func clockString(_ minutes: Int) -> String {
        let normalized = max(minutes, 0)
        let hour24 = (normalized / 60) % 24
        let minute = normalized % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }

    private func blockColor(_ block: ScheduleBlock) -> Color {
        switch block.kind {
        case .routine:
            return AppTheme.Colors.primary
        case .anchor:
            return Color(red: 0.31, green: 0.52, blue: 0.77)
        case .project:
            return Color.purple.opacity(0.75)
        case .transition:
            return Color.orange
        case .event:
            return Color(red: 0.90, green: 0.53, blue: 0.23)
        case .buffer:
            return Color.blue.opacity(0.5)
        case .recovery:
            return Color(red: 0.35, green: 0.64, blue: 0.43)
        }
    }

    private func shortTime(_ block: ScheduleBlock) -> String {
        block.timeRangeText.replacingOccurrences(of: " ", with: "")
    }

    private var currentMinuteOfDay: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func familyFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : AppTheme.Colors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.controlBackground)
                )
        }
        .buttonStyle(.plain)
    }

    private func transitionHeadline(for event: DayEvent) -> String {
        if event.supportMetadata.planningRelevance == .lightweightReminder {
            return "\(event.title) is coming up at \(clockString(event.startMinute))"
        }
        if let leaveByMinute = event.leaveByMinute, leaveByMinute >= currentMinuteOfDay {
            return "Leave by \(clockString(leaveByMinute)) for \(event.title)"
        }
        if event.supportMetadata.transitionPrepMinutes > 0, event.prepStartMinute >= currentMinuteOfDay {
            return "Prep starts at \(clockString(event.prepStartMinute)) for \(event.title)"
        }
        return "\(event.title) is the next supported event"
    }

    private func transitionSupportStatus(for event: DayEvent) -> String {
        if event.supportMetadata.planningRelevance == .lightweightReminder {
            let minutesUntilEvent = event.startMinute - currentMinuteOfDay
            if minutesUntilEvent <= 0 {
                return "This event is happening now. Keep it as a light reminder instead of a full schedule handoff."
            }
            return "This event stays visible in \(minutesUntilEvent) minute\(minutesUntilEvent == 1 ? "" : "s") without adding extra transition scaffolding."
        }

        if let leaveByMinute = event.leaveByMinute {
            let minutesUntilLeave = leaveByMinute - currentMinuteOfDay
            if minutesUntilLeave <= 0 {
                return "It is time to leave now so travel and transition time stay protected."
            }
            return "Leave in \(minutesUntilLeave) minute\(minutesUntilLeave == 1 ? "" : "s"). The app is protecting prep, travel, and arrival time."
        }

        let minutesUntilPrep = event.prepStartMinute - currentMinuteOfDay
        if minutesUntilPrep <= 0 {
            return "Prep support is active now so this event does not become a hard edge."
        }
        return "Prep begins in \(minutesUntilPrep) minute\(minutesUntilPrep == 1 ? "" : "s") to make the transition easier."
    }

    private func transitionSupportBackground(for event: DayEvent) -> Color {
        if let leaveByMinute = event.leaveByMinute, leaveByMinute - currentMinuteOfDay <= 10 {
            return Color.orange.opacity(0.16)
        }
        return AppTheme.Colors.controlBackground
    }

    private func supportTimingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.text)
        }
    }

    private func nextBlockHeadline(_ block: ScheduleBlock) -> String {
        let delta = block.startMinute - minuteOfDay(for: Date())
        if delta <= 0 {
            return "Now: \(block.title)"
        }
        if delta < 60 {
            return "In \(delta) min: \(block.title)"
        }
        return "\(clockString(block.startMinute)): \(block.title)"
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private enum EventCalendarView: String, CaseIterable, Identifiable {
    case day
    case fiveDay
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .fiveDay:
            return "5 Day"
        case .month:
            return "Month"
        }
    }
}

private struct FiveDayWindow: Identifiable {
    let id = UUID()
    let dayLabel: String
    let dayNumber: String
    let blocks: [ScheduleBlock]
    let priorityLabel: String
    let isToday: Bool
}

struct CreateEventView: View {
    let onSave: (DayEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var dayOffset = 0
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var durationMinutes = 30
    @State private var familyMember: DayEvent.FamilyMember = .me
    @State private var repeatRule: DayEvent.RepeatRule = .none
    @State private var sensoryLevel = 3
    @State private var kind: DayEvent.EventKind = .commitment
    @State private var planningRelevance: DayEvent.SupportMetadata.PlanningRelevance = .fullSupport
    @State private var locationName = ""
    @State private var estimatedDriveMinutes = 0
    @State private var transitionPrepMinutes = 10
    @State private var feltDeadlineOffsetMinutes: Int? = 20
    @State private var sensoryNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you planning?") {
                    TextField("Event title", text: $title)
                    TextField("Support note or details", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("When") {
                    Picker("Day", selection: $dayOffset) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                        Text("In 2 Days").tag(2)
                        Text("In 3 Days").tag(3)
                        Text("In 4 Days").tag(4)
                    }

                    Picker("Hour", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }

                    Picker("Minute", selection: $startMinute) {
                        Text("00").tag(0)
                        Text("15").tag(15)
                        Text("30").tag(30)
                        Text("45").tag(45)
                    }

                    Stepper("Duration: \(durationMinutes) minutes", value: $durationMinutes, in: 15...240, step: 15)
                }

                Section("Who") {
                    Picker("Family Member", selection: $familyMember) {
                        ForEach(DayEvent.FamilyMember.allCases) { member in
                            Text(member.title).tag(member)
                        }
                    }
                }

                Section("Where") {
                    TextField("Location", text: $locationName)
                    Stepper(
                        estimatedDriveMinutes == 0
                        ? "Estimated drive time: None"
                        : "Estimated drive time: \(estimatedDriveMinutes) minutes",
                        value: $estimatedDriveMinutes,
                        in: 0...180,
                        step: 5
                    )
                }

                Section("Supports") {
                    Picker("Planning relevance", selection: $planningRelevance) {
                        ForEach(DayEvent.SupportMetadata.PlanningRelevance.allCases) { relevance in
                            Text(relevance.title).tag(relevance)
                        }
                    }

                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(DayEvent.RepeatRule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }

                    Picker("Event Type", selection: $kind) {
                        Text("Commitment").tag(DayEvent.EventKind.commitment)
                        Text("Travel").tag(DayEvent.EventKind.travel)
                        Text("Recovery").tag(DayEvent.EventKind.recovery)
                    }

                    Picker("Sensory Level", selection: $sensoryLevel) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                    }

                    Stepper("Transition prep: \(transitionPrepMinutes) minutes", value: $transitionPrepMinutes, in: 0...45, step: 5)

                    Picker("Felt deadline", selection: Binding(
                        get: { feltDeadlineOffsetMinutes ?? 0 },
                        set: { feltDeadlineOffsetMinutes = $0 == 0 ? nil : $0 }
                    )) {
                        Text("None").tag(0)
                        Text("10 min early").tag(10)
                        Text("15 min early").tag(15)
                        Text("20 min early").tag(20)
                        Text("30 min early").tag(30)
                        Text("45 min early").tag(45)
                        Text("60 min early").tag(60)
                    }

                    TextField("Sensory support note", text: $sensoryNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Create Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            DayEvent(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                dayOffset: dayOffset,
                                startMinute: startHour * 60 + startMinute,
                                durationMinutes: durationMinutes,
                                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                                kind: kind,
                                familyMember: familyMember,
                                repeatRule: repeatRule,
                                sensoryLevel: sensoryLevel,
                                supportMetadata: DayEvent.SupportMetadata(
                                    planningRelevance: planningRelevance,
                                    transitionPrepMinutes: transitionPrepMinutes,
                                    feltDeadlineOffsetMinutes: feltDeadlineOffsetMinutes,
                                    sensoryNote: sensoryNote.trimmingCharacters(in: .whitespacesAndNewlines),
                                    locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    estimatedDriveMinutes: estimatedDriveMinutes == 0 ? nil : estimatedDriveMinutes
                                )
                            )
                        )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    static func hourLabel(_ hour: Int) -> String {
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour >= 12 ? "PM" : "AM"
        return "\(hour12):00 \(suffix)"
    }
}

struct EditEventSupportView: View {
    let event: DayEvent
    let onSave: (DayEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String
    @State private var dayOffset: Int
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var durationMinutes: Int
    @State private var kind: DayEvent.EventKind
    @State private var transitionPrepMinutes: Int
    @State private var feltDeadlineOffsetSelection: Int
    @State private var sensoryNote: String
    @State private var locationName: String
    @State private var estimatedDriveMinutesSelection: Int
    @State private var planningRelevance: DayEvent.SupportMetadata.PlanningRelevance

    init(event: DayEvent, onSave: @escaping (DayEvent) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _detail = State(initialValue: event.detail)
        _dayOffset = State(initialValue: event.dayOffset)
        _startHour = State(initialValue: event.startMinute / 60)
        _startMinute = State(initialValue: event.startMinute % 60)
        _durationMinutes = State(initialValue: event.durationMinutes)
        _kind = State(initialValue: event.kind)
        _planningRelevance = State(initialValue: event.supportMetadata.planningRelevance)
        _transitionPrepMinutes = State(initialValue: event.supportMetadata.transitionPrepMinutes)
        _feltDeadlineOffsetSelection = State(initialValue: event.supportMetadata.feltDeadlineOffsetMinutes ?? 0)
        _sensoryNote = State(initialValue: event.supportMetadata.sensoryNote)
        _locationName = State(initialValue: event.supportMetadata.locationName)
        _estimatedDriveMinutesSelection = State(initialValue: event.supportMetadata.estimatedDriveMinutes ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Event title", text: $title)
                    TextField("Details", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Day", selection: $dayOffset) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                        Text("In 2 Days").tag(2)
                        Text("In 3 Days").tag(3)
                        Text("In 4 Days").tag(4)
                    }
                    Picker("Hour", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(CreateEventView.hourLabel(hour)).tag(hour)
                        }
                    }
                    Picker("Minute", selection: $startMinute) {
                        Text("00").tag(0)
                        Text("15").tag(15)
                        Text("30").tag(30)
                        Text("45").tag(45)
                    }
                    Stepper("Duration: \(durationMinutes) minutes", value: $durationMinutes, in: 15...240, step: 15)
                    Picker("Event Type", selection: $kind) {
                        Text("Commitment").tag(DayEvent.EventKind.commitment)
                        Text("Travel").tag(DayEvent.EventKind.travel)
                        Text("Recovery").tag(DayEvent.EventKind.recovery)
                    }
                    if let sourceName = event.sourceName {
                        Text("Source: \(sourceName)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Planner Support") {
                    Picker("Planning relevance", selection: $planningRelevance) {
                        ForEach(DayEvent.SupportMetadata.PlanningRelevance.allCases) { relevance in
                            Text(relevance.title).tag(relevance)
                        }
                    }

                    Text(planningRelevance.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Location", text: $locationName)

                    Stepper(
                        estimatedDriveMinutesSelection == 0
                        ? "Estimated drive time: None"
                        : "Estimated drive time: \(estimatedDriveMinutesSelection) minutes",
                        value: $estimatedDriveMinutesSelection,
                        in: 0...180,
                        step: 5
                    )

                    Stepper("Transition prep: \(transitionPrepMinutes) minutes", value: $transitionPrepMinutes, in: 0...45, step: 5)

                    Picker("Felt deadline", selection: $feltDeadlineOffsetSelection) {
                        Text("None").tag(0)
                        Text("10 min early").tag(10)
                        Text("15 min early").tag(15)
                        Text("20 min early").tag(20)
                        Text("30 min early").tag(30)
                        Text("45 min early").tag(45)
                        Text("60 min early").tag(60)
                    }

                    TextField("Sensory support note", text: $sensoryNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Support")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            DayEvent(
                                id: event.id,
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                dayOffset: dayOffset,
                                startMinute: startHour * 60 + startMinute,
                                durationMinutes: durationMinutes,
                                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                                kind: kind,
                                familyMember: event.familyMember,
                                repeatRule: event.repeatRule,
                                sensoryLevel: event.sensoryLevel,
                                sourceName: event.sourceName,
                                externalIdentifier: event.externalIdentifier,
                                supportMetadata: DayEvent.SupportMetadata(
                                    planningRelevance: planningRelevance,
                                    transitionPrepMinutes: transitionPrepMinutes,
                                    feltDeadlineOffsetMinutes: feltDeadlineOffsetSelection == 0 ? nil : feltDeadlineOffsetSelection,
                                    sensoryNote: sensoryNote.trimmingCharacters(in: .whitespacesAndNewlines),
                                    locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    estimatedDriveMinutes: estimatedDriveMinutesSelection == 0 ? nil : estimatedDriveMinutesSelection
                                )
                            )
                        )
                    }
                }
            }
        }
    }
}
