import SwiftUI
import UIKit

struct RoutineDetailView: View {
    let routine: Routine
    let executionSupport: RoutineExecutionSupport
    let pdaAwareSupport: Bool = false
    let onToggleStep: (UUID, UUID) -> Void
    let onPauseRoutine: (UUID) -> Void
    let onResumeRoutine: (UUID) -> Void
    let onCueDelivered: (UUID, UUID, RoutineExecutionSupport.CueIntensity) -> Void
    let onCueMissed: (UUID, UUID) -> Void

    @State private var isPaused = false
    @State private var cueArmedAt: Date = Date()
    @State private var deliveredCueCount = 0
    @State private var liveCueMessage: String?
    @State private var cueMessageExpiresAt: Date?
    @State private var cueSequenceExpiresAt: Date?
    @State private var hasReportedCueMiss = false
    @State private var isShowingAllSteps = false

    private var currentStepIndex: Int? {
        routine.steps.firstIndex(where: { !$0.isCompleted })
    }

    private var currentStep: RoutineStep? {
        guard let currentStepIndex else { return nil }
        return routine.steps[currentStepIndex]
    }

    private var nextStep: RoutineStep? {
        guard let currentStepIndex else { return nil }
        let nextIndex = routine.steps.index(after: currentStepIndex)
        guard nextIndex < routine.steps.endIndex else { return nil }
        return routine.steps[nextIndex]
    }

    private var completedSteps: Int {
        routine.steps.filter(\.isCompleted).count
    }

    private var remainingMinutes: Int {
        routine.steps.filter { !$0.isCompleted }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    private let cueTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ScreenModeBadge(title: "Doing")
                        Text(routine.title)
                            .font(AppTheme.Typography.heroTitle)
                        Text(routine.timeWindow)
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Text(routine.summary)
                            .font(AppTheme.Typography.supporting)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Progress")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("Step \(min(completedSteps + 1, max(routine.steps.count, 1))) of \(max(routine.steps.count, 1))")
                            .font(AppTheme.Typography.cardTitle)
                        Text("\(remainingMinutes) minutes remaining")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        ProgressView(value: Double(completedSteps), total: Double(max(routine.steps.count, 1)))
                            .tint(AppTheme.Colors.primary)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ScreenModeBadge(title: "Doing")
                        Text("Focus")
                            .font(AppTheme.Typography.sectionTitle)

                        if let currentStep {
                            Text(currentStep.title)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.text)
                            Text(executionSupport.currentStepCue)
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            HStack(spacing: 10) {
                                focusChip(title: "Now", value: "Step \(min(completedSteps + 1, max(routine.steps.count, 1)))")
                                focusChip(title: "Time", value: "\(currentStep.estimatedMinutes) min")
                                if let nextStep {
                                    focusChip(title: "Next", value: nextStep.title)
                                }
                            }
                        } else {
                            Text("Routine complete")
                                .font(AppTheme.Typography.cardTitle)
                            Text("You made it through every step.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ScreenModeBadge(title: "Doing")
                        Text("Current Step")
                            .font(AppTheme.Typography.sectionTitle)

                        if let currentStep {
                            Text("Estimated time: \(currentStep.estimatedMinutes) minutes")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            if let liveCueMessage {
                                CueBanner(text: liveCueMessage)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Routine support")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primary)
                                Text("Cue style: \(executionSupport.cueIntensity.title) • cue about \(executionSupport.leadTimeMinutes) min before the next step")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Text("Live cue repeats: \(executionSupport.maxCueRepeats)")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                if executionSupport.suppressIfAlreadyMoving {
                                    Text("If you are already moving, the app should back off instead of piling on.")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                if let adjustmentSummary = executionSupport.adjustmentSummary {
                                    Text(adjustmentSummary)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            if let nextStep {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Next after this")
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                    CueBanner(text: "Next: \(nextStep.title.lowercased())")
                                }
                            }

                            HStack(spacing: 10) {
                                Button(isPaused ? "Resume" : "Pause") {
                                    isPaused.toggle()
                                    if isPaused {
                                        liveCueMessage = nil
                                        cueSequenceExpiresAt = nil
                                        onPauseRoutine(routine.id)
                                    } else {
                                        cueArmedAt = Date().addingTimeInterval(TimeInterval(executionSupport.resumeCueDelaySeconds))
                                        deliveredCueCount = 0
                                        cueSequenceExpiresAt = nil
                                        hasReportedCueMiss = false
                                        onResumeRoutine(routine.id)
                                    }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())

                                Button(pdaAwareSupport ? "Move Past This Step" : "Complete Step") {
                                    onToggleStep(currentStep.id, routine.id)
                                }
                                .buttonStyle(PrimaryActionButtonStyle())
                            }

                            Text(executionSupport.resumeSupportText)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        } else {
                            Text("This routine is complete.")
                                .font(AppTheme.Typography.cardTitle)
                            Text("You made it through every step.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Step List")
                                .font(AppTheme.Typography.sectionTitle)
                            Spacer()
                            Button(isShowingAllSteps ? "Hide" : "Show") {
                                isShowingAllSteps.toggle()
                            }
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        }

                        Text("Keep this collapsed while you are working if the full list starts competing for attention.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        if isShowingAllSteps {
                            ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(AppTheme.Typography.supporting.weight(.semibold))
                                            .strikethrough(step.isCompleted)
                                        Text(step.cue)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }

                                    Spacer()

                                    Button(step.isCompleted ? "Undo" : (pdaAwareSupport ? "Mark Done" : "Done")) {
                                        onToggleStep(step.id, routine.id)
                                    }
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                }
                                .padding(12)
                                .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        } else if let currentStepIndex {
                            VStack(alignment: .leading, spacing: 8) {
                                compactStepRow(label: "Current", index: currentStepIndex, step: routine.steps[currentStepIndex])

                                if let nextStep {
                                    compactStepRow(label: "Next", index: currentStepIndex + 1, step: nextStep)
                                }

                                if currentStepIndex + 2 < routine.steps.count {
                                    Text("\(routine.steps.count - (currentStepIndex + 1)) step\(routine.steps.count - (currentStepIndex + 1) == 1 ? "" : "s") remain after this.")
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
            .padding()
        }
        .background(AppTheme.Colors.canvas.ignoresSafeArea())
        .navigationTitle("Routine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            armCueWindow()
        }
        .onChange(of: currentStep?.id) { _, _ in
            armCueWindow()
        }
        .onChange(of: executionSupport) { _, _ in
            armCueWindow()
        }
        .onReceive(cueTicker) { now in
            updateLiveCueState(now: now)
        }
    }

    private func armCueWindow() {
        let leadSeconds = max(executionSupport.leadTimeMinutes * 60, 15)
        cueArmedAt = Date().addingTimeInterval(TimeInterval(leadSeconds))
        deliveredCueCount = 0
        liveCueMessage = nil
        cueMessageExpiresAt = nil
        cueSequenceExpiresAt = nil
        hasReportedCueMiss = false
    }

    private func updateLiveCueState(now: Date) {
        if let cueMessageExpiresAt, now >= cueMessageExpiresAt {
            liveCueMessage = nil
            self.cueMessageExpiresAt = nil
        }

        if let cueSequenceExpiresAt, now >= cueSequenceExpiresAt, !hasReportedCueMiss, let currentStep {
            hasReportedCueMiss = true
            self.cueSequenceExpiresAt = nil
            onCueMissed(routine.id, currentStep.id)
        }

        guard currentStep != nil, !isPaused else { return }
        guard deliveredCueCount < executionSupport.maxCueRepeats else { return }
        guard now >= cueArmedAt else { return }

        deliverLiveCue()
        deliveredCueCount += 1

        if executionSupport.suppressIfAlreadyMoving {
            cueArmedAt = .distantFuture
            cueSequenceExpiresAt = now.addingTimeInterval(cueGracePeriod)
        } else {
            let repeatDelay: TimeInterval
            switch executionSupport.cueIntensity {
            case .calm:
                repeatDelay = 120
            case .steady:
                repeatDelay = 90
            case .elevated:
                repeatDelay = 60
            }
            if deliveredCueCount >= executionSupport.maxCueRepeats {
                cueArmedAt = .distantFuture
                cueSequenceExpiresAt = now.addingTimeInterval(cueGracePeriod)
            } else {
                cueArmedAt = now.addingTimeInterval(repeatDelay)
            }
        }
    }

    private func deliverLiveCue() {
        guard let currentStep else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        onCueDelivered(routine.id, currentStep.id, executionSupport.cueIntensity)

        switch executionSupport.cueIntensity {
        case .calm:
            generator.notificationOccurred(.success)
            liveCueMessage = "A soft cue: return to this step when it feels workable."
        case .steady:
            generator.notificationOccurred(.warning)
            liveCueMessage = "Routine cue: come back to the current step and keep the sequence moving."
        case .elevated:
            generator.notificationOccurred(.warning)
            liveCueMessage = "Transition cue: return now so this routine does not lose its handoff."
        }

        cueMessageExpiresAt = Date().addingTimeInterval(8)
    }

    private var cueGracePeriod: TimeInterval {
        switch executionSupport.cueIntensity {
        case .calm:
            return 120
        case .steady:
            return 90
        case .elevated:
            return 60
        }
    }

    private func focusChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(value)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func compactStepRow(label: String, index: Int, step: RoutineStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(label == "Current" ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(index + 1): \(step.title)")
                    .font(AppTheme.Typography.supporting.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.text)
                Text(step.cue)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()
        }
    }
}
