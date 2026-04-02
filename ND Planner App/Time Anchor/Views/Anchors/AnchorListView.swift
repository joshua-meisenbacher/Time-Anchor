import SwiftUI

struct RoutineListView: View {
    let routines: [Routine]
    let supportForRoutine: (Routine) -> RoutineExecutionSupport
    let onToggleStep: (UUID, UUID) -> Void
    let onPauseRoutine: (UUID) -> Void
    let onResumeRoutine: (UUID) -> Void
    let onCueDelivered: (UUID, UUID, RoutineExecutionSupport.CueIntensity) -> Void
    let onCueMissed: (UUID, UUID) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Routines")
                                .font(AppTheme.Typography.heroTitle)
                            Text("Use routines to make transitions repeatable, reduce task-start friction, and keep the next step visible.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    ForEach(routines) { routine in
                        NavigationLink {
                            RoutineDetailView(
                                routine: routine,
                                executionSupport: supportForRoutine(routine),
                                onToggleStep: onToggleStep,
                                onPauseRoutine: onPauseRoutine,
                                onResumeRoutine: onResumeRoutine,
                                onCueDelivered: onCueDelivered,
                                onCueMissed: onCueMissed
                            )
                        } label: {
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(routine.title)
                                                    .font(AppTheme.Typography.cardTitle)
                                                if routine.isPinned {
                                                    Text("Pinned")
                                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(AppTheme.Colors.primaryMuted, in: Capsule())
                                                }
                                            }
                                            Text(routine.timeWindow)
                                                .font(AppTheme.Typography.caption)
                                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                        }
                                        Spacer()
                                        Text(routine.progressText)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }

                                    Text(routine.summary)
                                        .font(AppTheme.Typography.supporting)
                                        .foregroundStyle(AppTheme.Colors.text)

                                    if let currentStep = routine.steps.first(where: { !$0.isCompleted }) {
                                        CueBanner(text: "Current step: \(currentStep.title.lowercased())")
                                    }

                                    HStack {
                                        Text("\(routine.steps.reduce(0) { $0 + $1.estimatedMinutes }) min total")
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                        Spacer()
                                        Text("Open routine")
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Routines")
        }
    }
}
