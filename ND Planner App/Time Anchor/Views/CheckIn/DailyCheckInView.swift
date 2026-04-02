import SwiftUI

struct DailyCheckInView: View {
    @ObservedObject var viewModel: CheckInStore
    let assessment: DayAssessment
    let healthContextSummary: String
    let healthAutofillSummary: String?
    let calendarContextSummary: String
    let communicationStyle: CommunicationStyle
    let pdaAwareSupport: Bool
    let scenarios: [MockScenario]
    let selectedScenarioID: UUID
    let onScenarioSelect: (UUID) -> Void
    let onApplyHealthAutofill: () -> Void
    let onApply: () -> Void

    @FocusState private var isPriorityFocused: Bool
    @State private var showPlanConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showPlanConfirmation {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today’s support plan is ready")
                                    .font(AppTheme.Typography.sectionTitle)
                                Text(communicationStyle == .literal
                                     ? "Your check-in was saved and the app rebuilt today around it."
                                     : "Your check-in landed. Time Anchor has rebuilt support around what feels true today.")
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ScreenModeBadge(title: "Planning")
                            Text("How does today feel?")
                                .font(AppTheme.Typography.sectionTitle)
                            Text(communicationStyle == .literal
                                 ? "Give the app a quick picture of today so it can shape support more accurately."
                                 : "Time Anchor works best when it knows what kind of support today needs.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            Picker("Day Type", selection: Binding(
                                get: { selectedScenarioID },
                                set: onScenarioSelect
                            )) {
                                ForEach(scenarios) { scenario in
                                    Text(scenario.title).tag(scenario.id)
                                }
                            }
                            .pickerStyle(.menu)

                            if let selectedScenario = scenarios.first(where: { $0.id == selectedScenarioID }) {
                                Text(selectedScenario.subtitle)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                    }

                    if healthAutofillSummary != nil {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Health Autofill")
                                    .font(AppTheme.Typography.sectionTitle)
                                Text(healthAutofillSummary ?? "")
                                    .font(AppTheme.Typography.supporting)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                Button(pdaAwareSupport ? "Try Health Suggestions" : "Use Health Suggestions", action: onApplyHealthAutofill)
                                    .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connected Context")
                                .font(AppTheme.Typography.sectionTitle)

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

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Start")
                                .font(AppTheme.Typography.sectionTitle)
                            Text(communicationStyle == .literal
                                 ? "Use a preset if you want a faster check-in, then adjust only what looks wrong."
                                 : "If you do not want to tune every slider, start with a preset and then adjust anything that feels off.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            ForEach(CheckInPreset.allCases) { preset in
                                Button {
                                    viewModel.applyQuickPreset(preset)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title)
                                            .font(AppTheme.Typography.cardTitle)
                                        Text(preset.summary)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Capacity Snapshot")
                                .font(AppTheme.Typography.sectionTitle)

                            SliderField(
                                title: "Energy",
                                helpText: "How much usable momentum do you have for starting and staying with tasks?",
                                valueText: "\(Int(viewModel.energy)) / 5",
                                value: $viewModel.energy,
                                range: 1...5,
                                step: 1
                            )
                            SliderField(
                                title: "Stress",
                                helpText: "How activated, tense, or internally noisy does today feel right now?",
                                valueText: "\(Int(viewModel.stress)) / 5",
                                value: $viewModel.stress,
                                range: 1...5,
                                step: 1
                            )
                            SliderField(
                                title: "Sensory Load",
                                helpText: "How likely is sound, light, motion, touch, or general input to drain you today?",
                                valueText: "\(Int(viewModel.sensoryLoad)) / 5",
                                value: $viewModel.sensoryLoad,
                                range: 1...5,
                                step: 1
                            )
                            SliderField(
                                title: "Transition Friction",
                                helpText: "How hard does it feel to switch tasks, leave, begin, or change direction today?",
                                valueText: "\(Int(viewModel.transitionFriction)) / 5",
                                value: $viewModel.transitionFriction,
                                range: 1...5,
                                step: 1
                            )
                            SliderField(
                                title: "Sleep",
                                helpText: "This can be adjusted manually even when Health autofill is available.",
                                valueText: String(format: "%.1f hours", viewModel.sleepHours),
                                value: $viewModel.sleepHours,
                                range: 0...12,
                                step: 0.5
                            )
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What matters most today?")
                                .font(AppTheme.Typography.sectionTitle)
                            TextField("Name the one priority you want the app to protect.", text: $viewModel.priority, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($isPriorityFocused)
                                .submitLabel(.done)
                                .padding(12)
                                .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ScreenModeBadge(title: "Planning")
                            Text("Recommended Support")
                                .font(AppTheme.Typography.sectionTitle)
                            Text(assessment.headline)
                                .font(AppTheme.Typography.cardTitle)
                            Text(assessment.supportFocus)
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            Text(assessment.recommendedMode.supportiveLabel)
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.Colors.primaryMuted, in: Capsule())

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("What is shaping this recommendation")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                ForEach(assessment.capacityDrivers, id: \.self) { driver in
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

                    Button(action: applySupportPlan) {
                        Text(pdaAwareSupport ? "Shape Today’s Support" : "Build Today’s Support Plan")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Check-In")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isPriorityFocused = false
                    }
                }
            }
        }
    }

    private func applySupportPlan() {
        isPriorityFocused = false
        onApply()
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlanConfirmation = true
        }
    }
}

private struct SliderField: View {
    let title: String
    let helpText: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .font(AppTheme.Typography.supporting)

            Slider(value: $value, in: range, step: step)
                .tint(AppTheme.Colors.primary)

            Text(helpText)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }
}
