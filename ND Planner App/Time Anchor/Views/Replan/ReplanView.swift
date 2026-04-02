import SwiftUI

struct ReplanView: View {
    let selectedReason: ReplanReason
    let lastAppliedMode: PlanMode
    let currentGuidance: String
    let communicationStyle: CommunicationStyle
    let adaptiveSuggestion: ReplanSuggestion?
    let onReasonSelect: (ReplanReason) -> Void
    let onApplyMode: (PlanMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introCard
                    if adaptiveSuggestion != nil {
                        adaptiveSuggestionCard
                    }
                    reasonsCard
                    suggestionCard
                    modeButtons
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Replan")
        }
    }

    private var introCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                ScreenModeBadge(title: "Adjusting")
                Text("Need to replan?")
                    .font(AppTheme.Typography.heroTitle)
                Text(communicationStyle == .literal
                     ? "Use this when the current plan no longer fits what you can realistically do."
                     : "This screen is for the moments when the original plan stopped fitting your actual capacity.")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var reasonsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What feels true right now?")
                    .font(AppTheme.Typography.sectionTitle)

                ForEach(ReplanReason.allCases) { reason in
                    reasonButton(reason)
                }
            }
        }
    }

    private var suggestionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                ScreenModeBadge(title: "Reviewing")
                Text("Suggested next move")
                    .font(AppTheme.Typography.sectionTitle)
                CueBanner(text: currentGuidance)
                Text("Current support level: \(lastAppliedMode.supportiveLabel)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var adaptiveSuggestionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Replan Suggestion")
                    .font(AppTheme.Typography.sectionTitle)
                Text(adaptiveSuggestion?.title ?? "")
                    .font(AppTheme.Typography.cardTitle)
                Text(adaptiveSuggestion?.summary ?? "")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                if let adaptiveSuggestion, !adaptiveSuggestion.adjustments.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(adaptiveSuggestion.adjustments) { adjustment in
                            Text(adjustment.title)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                }
                if let adaptiveSuggestion {
                    Button("Apply \(adaptiveSuggestion.recommendedMode.title)") {
                        onApplyMode(adaptiveSuggestion.recommendedMode)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }
    }

    private var modeButtons: some View {
        HStack(spacing: 10) {
            ForEach(PlanMode.allCases) { mode in
                modeButton(for: mode)
            }
        }
    }

    private func reasonButton(_ reason: ReplanReason) -> some View {
        let isSelected = selectedReason == reason

        return Button {
            onReasonSelect(reason)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(AppTheme.Typography.cardTitle)
                    Text(reason.recommendation)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : AppTheme.Colors.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .foregroundStyle(isSelected ? Color.white : AppTheme.Colors.text)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.controlBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeButton(for mode: PlanMode) -> some View {
        let button = Button {
            onApplyMode(mode)
        } label: {
            Text(mode.title)
                .frame(maxWidth: .infinity)
        }

        if mode == .minimum {
            return AnyView(button.buttonStyle(PrimaryActionButtonStyle()))
        } else {
            return AnyView(button.buttonStyle(SecondaryActionButtonStyle()))
        }
    }
}
