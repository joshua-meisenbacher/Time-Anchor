import Combine
import Foundation

final class TodayStore: ObservableObject {
    @Published private(set) var availablePlans: [PlanVersion]
    @Published var selectedMode: PlanMode
    @Published private(set) var assessment: DayAssessment
    @Published var activeAnchorID: UUID?
    @Published var activeTaskID: UUID?
    @Published var activeBlockID: UUID?
    @Published private(set) var now: Date

    private var timerCancellable: AnyCancellable?

    init(availablePlans: [PlanVersion], selectedMode: PlanMode, assessment: DayAssessment) {
        self.availablePlans = availablePlans
        self.selectedMode = selectedMode
        self.assessment = assessment
        now = Date()
        activeAnchorID = availablePlans.first(where: { $0.mode == selectedMode })?.anchors.first?.id
        activeBlockID = availablePlans.first(where: { $0.mode == selectedMode })?.dailyPlan.actionableBlocks.first?.id
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }

    var currentPlan: PlanVersion? {
        availablePlans.first(where: { $0.mode == selectedMode })
    }

    var currentAnchor: Anchor? {
        guard let currentPlan else { return nil }
        if let activeTaskID,
           let taskAnchor = currentPlan.anchors.first(where: { anchor in
               anchor.tasks.contains(where: { $0.id == activeTaskID && !$0.isCompleted })
           }) {
            return taskAnchor
        }
        if let activeAnchorID,
           let selectedAnchor = currentPlan.anchors.first(where: { $0.id == activeAnchorID }) {
            return selectedAnchor
        }
        if let blockAnchorID = currentBlock?.anchorID {
            return currentPlan.anchors.first(where: { $0.id == blockAnchorID }) ?? currentPlan.anchors.first
        }
        return nil
    }

    var nextAnchor: Anchor? {
        guard let currentPlan, let currentAnchor else { return currentPlan?.anchors.first }
        guard let currentIndex = currentPlan.anchors.firstIndex(where: { $0.id == currentAnchor.id }) else {
            return currentPlan.anchors.first
        }
        let nextIndex = currentPlan.anchors.index(after: currentIndex)
        guard nextIndex < currentPlan.anchors.endIndex else { return nil }
        return currentPlan.anchors[nextIndex]
    }

    var currentBlock: ScheduleBlock? {
        guard let currentPlan else { return nil }
        let currentMinute = Self.minuteOfDay(for: now)
        if let liveBlock = currentPlan.dailyPlan.actionableBlocks.first(where: { block in
            block.startMinute <= currentMinute && block.endMinute > currentMinute
        }) {
            return liveBlock
        }

        return currentPlan.dailyPlan.actionableBlocks.first(where: { block in
            block.startMinute > currentMinute
        })
    }

    var nextTimelineBlock: ScheduleBlock? {
        guard let currentPlan, let currentBlock else { return currentPlan?.dailyPlan.actionableBlocks.first }
        guard let currentIndex = currentPlan.dailyPlan.actionableBlocks.firstIndex(where: { $0.id == currentBlock.id }) else {
            return currentPlan.dailyPlan.actionableBlocks.first
        }
        let nextIndex = currentPlan.dailyPlan.actionableBlocks.index(after: currentIndex)
        guard nextIndex < currentPlan.dailyPlan.actionableBlocks.endIndex else { return nil }
        return currentPlan.dailyPlan.actionableBlocks[nextIndex]
    }

    var transitionFocusBlock: ScheduleBlock? {
        if currentBlock?.kind == .transition {
            return currentBlock
        }

        if let leaveByBlockForNextEvent {
            return leaveByBlockForNextEvent
        }

        let blocks = timelineBlocks
        let startIndex: Int
        if let currentBlock, let currentIndex = blocks.firstIndex(where: { $0.id == currentBlock.id }) {
            startIndex = currentIndex
        } else {
            startIndex = 0
        }

        return blocks[startIndex...].first(where: { $0.kind == .transition })
    }

    var nextEventBlock: ScheduleBlock? {
        let blocks = timelineBlocks
        guard !blocks.isEmpty else { return nil }

        let startIndex: Int
        if let currentBlock, let currentIndex = blocks.firstIndex(where: { $0.id == currentBlock.id }) {
            startIndex = currentIndex
        } else {
            startIndex = 0
        }

        return blocks[startIndex...].first(where: { $0.kind == .event })
    }

    var currentEventBlock: ScheduleBlock? {
        guard let currentBlock, currentBlock.kind == .event else { return nil }
        return currentBlock
    }

    var leaveByBlockForNextEvent: ScheduleBlock? {
        guard let nextEventBlock else { return nil }
        return timelineBlocks.first(where: { block in
            block.kind == .transition &&
            block.endMinute == nextEventBlock.startMinute &&
            block.title == "Leave for \(nextEventBlock.title)"
        })
    }

    var leaveByMinutesUntilNextEvent: Int? {
        guard let leaveByBlockForNextEvent else { return nil }
        let currentMinute = Self.minuteOfDay(for: now)
        return leaveByBlockForNextEvent.startMinute - currentMinute
    }

    var timelineBlocks: [ScheduleBlock] {
        currentPlan?.dailyPlan.blocks ?? []
    }

    var laterAnchors: [Anchor] {
        guard let currentPlan else { return [] }
        guard let nextAnchor else { return [] }
        guard let nextIndex = currentPlan.anchors.firstIndex(where: { $0.id == nextAnchor.id }) else { return [] }
        let laterIndex = currentPlan.anchors.index(after: nextIndex)
        guard laterIndex < currentPlan.anchors.endIndex else { return [] }
        return Array(currentPlan.anchors[laterIndex...])
    }

    var currentTask: Task? {
        guard let currentAnchor else { return nil }
        let currentMinute = Self.minuteOfDay(for: now)
        let todaysTasks = currentAnchor.tasks
            .filter { $0.dayOffset == 0 }
            .sorted { lhs, rhs in
                switch (lhs.startMinute, rhs.startMinute) {
                case let (left?, right?):
                    return left < right
                case (.some, .none):
                    return false
                case (.none, .some):
                    return true
                case (.none, .none):
                    return lhs.title < rhs.title
                }
            }
        let incompleteTasks = todaysTasks.filter { !$0.isCompleted }

        if let activeTaskID, let task = incompleteTasks.first(where: { $0.id == activeTaskID }) {
            return task
        }

        if let currentBlock {
            let blockTasks = incompleteTasks.filter { task in
                guard let startMinute = task.startMinute else { return true }
                return startMinute >= currentBlock.startMinute && startMinute < currentBlock.endMinute
            }

            if let liveTask = blockTasks.first(where: { task in
                guard let startMinute = task.startMinute else { return true }
                return startMinute + max(task.durationMinutes, 5) > currentMinute
            }) {
                return liveTask
            }

            if let firstBlockTask = blockTasks.first {
                return firstBlockTask
            }
        }

        if let liveOrUpcomingTask = incompleteTasks.first(where: { task in
            guard let startMinute = task.startMinute else { return true }
            return startMinute + max(task.durationMinutes, 5) > currentMinute
        }) {
            return liveOrUpcomingTask
        }

        return incompleteTasks.first ?? todaysTasks.first ?? currentAnchor.tasks.first(where: { !$0.isCompleted }) ?? currentAnchor.tasks.first
    }

    func activeRoutine(from routines: [Routine]) -> Routine? {
        if let currentBlock, currentBlock.kind == .routine {
            if let matching = routines.first(where: { $0.title == currentBlock.title }) {
                return matching
            }
        }

        if let currentAnchor, let matching = routines.first(where: {
            $0.timeWindow == currentAnchor.timeLabel || $0.title == currentAnchor.title
        }) {
            return matching
        }
        
        return nil
    }

    var nextTaskPrompt: String {
        guard let currentTask else { return "Your current anchor does not have an active task yet." }
        return "Start with \(currentTask.title.lowercased()) and stay in this lane until it is easier to switch."
    }

    var currentProgressText: String {
        guard let currentPlan else { return "No plan built yet." }
        let completed = currentPlan.anchors.reduce(0) { $0 + $1.completedTaskCount }
        let total = max(currentPlan.anchors.reduce(0) { $0 + $1.totalTaskCount }, 1)
        return "\(completed) of \(total) tasks completed"
    }

    func updatePlans(_ plans: [PlanVersion], selectedMode: PlanMode, assessment: DayAssessment) {
        availablePlans = plans
        self.selectedMode = selectedMode
        self.assessment = assessment
        if let currentPlan = plans.first(where: { $0.mode == selectedMode }) {
            if let activeAnchorID, currentPlan.anchors.contains(where: { $0.id == activeAnchorID }) {
                self.activeAnchorID = activeAnchorID
            } else {
                self.activeAnchorID = currentPlan.dailyPlan.actionableBlocks.first?.anchorID ?? currentPlan.anchors.first?.id
            }
            if let activeTaskID, currentPlan.anchors.flatMap(\.tasks).contains(where: { $0.id == activeTaskID && !$0.isCompleted && $0.dayOffset == 0 }) {
                self.activeTaskID = activeTaskID
            } else {
                self.activeTaskID = nil
            }
            if let activeBlockID, currentPlan.dailyPlan.actionableBlocks.contains(where: { $0.id == activeBlockID }) {
                self.activeBlockID = activeBlockID
            } else {
                self.activeBlockID = currentPlan.dailyPlan.actionableBlocks.first?.id
            }
        } else {
            activeAnchorID = nil
            activeTaskID = nil
            activeBlockID = nil
        }
    }

    func setActiveAnchor(_ anchorID: UUID) {
        activeAnchorID = anchorID
        activeTaskID = currentAnchor?.tasks.first(where: { !$0.isCompleted })?.id
        activeBlockID = currentPlan?.dailyPlan.actionableBlocks.first(where: { $0.anchorID == anchorID })?.id
    }

    func startCurrentTask() {
        activeTaskID = currentAnchor?.tasks.first(where: { !$0.isCompleted })?.id ?? currentAnchor?.tasks.first?.id
    }

    func startTask(_ taskID: UUID, in anchorID: UUID) {
        activeAnchorID = anchorID
        activeTaskID = taskID
        activeBlockID = currentPlan?.dailyPlan.actionableBlocks.first(where: { $0.anchorID == anchorID })?.id
    }

    func clearActiveTask(_ taskID: UUID) {
        guard activeTaskID == taskID else { return }
        activeTaskID = currentAnchor?.tasks.first(where: { !$0.isCompleted && $0.id != taskID })?.id
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
