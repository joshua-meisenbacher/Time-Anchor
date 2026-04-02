import SwiftUI

struct InsightsView: View {
    @ObservedObject var appStore: AppStore
    let communicationStyle: CommunicationStyle

    private var recentOutcomes: [DayOutcome] {
        Array((appStore.selectedUserProfile?.outcomes ?? []).suffix(14))
    }

    private var groupedInsights: [(category: InsightCategory, cards: [InsightCard])] {
        InsightCategory.allCases.compactMap { category in
            let cards = appStore.insights.filter { $0.category == category }
            return cards.isEmpty ? nil : (category, cards)
        }
    }

    private var recentWindowLabel: String {
        let dayCount = max(recentOutcomes.count, 1)
        return "Recent pattern window: last \(dayCount) day\(dayCount == 1 ? "" : "s")"
    }

    private var totalTransitionMisses: Int {
        recentOutcomes.reduce(0) { $0 + $1.missedTransitionBlockIDs.count }
    }

    private var averageLateStart: Int? {
        let values = recentOutcomes.flatMap { $0.lateStartMinutesByBlockID.values }
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var cueLandingRate: Int? {
        let responses = recentOutcomes.flatMap(\.cueResponses)
        let actionable = responses.filter { $0.result != .delivered }
        guard !actionable.isEmpty else { return nil }
        let landed = actionable.filter { $0.result == .actedOn || $0.result == .helpful }.count
        return Int((Double(landed) / Double(actionable.count) * 100).rounded())
    }

    private var routineResumeRate: Int? {
        let pauses = recentOutcomes.reduce(0) { $0 + $1.routinePauseCount }
        guard pauses > 0 else { return nil }
        let resumes = recentOutcomes.reduce(0) { $0 + $1.routineResumeCount }
        return Int((Double(resumes) / Double(pauses) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewCard
                    metricsCard
                    supportPostureCard

                    if groupedInsights.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(groupedInsights, id: \.category.id) { section in
                            categorySection(section.category, cards: section.cards)
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Review")
        }
    }

    private var overviewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                ScreenModeBadge(title: "Reviewing")
                Text("What The App Is Learning")
                    .font(AppTheme.Typography.sectionTitle)
                if let featuredInsight = appStore.featuredInsight {
                    Text(featuredInsight.title)
                        .font(AppTheme.Typography.heroTitle)
                    Text(featuredInsight.summary)
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                } else {
                    Text(communicationStyle == .literal
                         ? "Patterns will appear here after the app has enough real usage data."
                         : "Patterns will build as the app watches how days actually go.")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Text(recentWindowLabel)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var metricsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pattern Snapshot")
                    .font(AppTheme.Typography.sectionTitle)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(
                        title: "Transition Misses",
                        value: "\(totalTransitionMisses)",
                        detail: "last 14 days"
                    )
                    metricTile(
                        title: "Average Late Start",
                        value: averageLateStart.map { "\($0)m" } ?? "None",
                        detail: "across tracked blocks"
                    )
                    metricTile(
                        title: "Cue Landing",
                        value: cueLandingRate.map { "\($0)%" } ?? "No data",
                        detail: "acted on or helpful"
                    )
                    metricTile(
                        title: "Routine Resume",
                        value: routineResumeRate.map { "\($0)%" } ?? "No data",
                        detail: "after pauses"
                    )
                }
            }
        }
    }

    private var supportPostureCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Current Support Posture")
                    .font(AppTheme.Typography.sectionTitle)
                Text(appStore.estimatedStateSummary)
                    .font(AppTheme.Typography.supporting)
                if let adaptationSummary = appStore.adaptationSummary {
                    Text(adaptationSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                ForEach(appStore.adaptationReasonDetails, id: \.self) { reason in
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
                if let baselineSummary = appStore.personalizedBaselineSummary {
                    Text(baselineSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Patterns will show up here")
                    .font(AppTheme.Typography.sectionTitle)
                Text(communicationStyle == .literal
                     ? "As you use routines, cues, and replanning, this screen will show which supports work and where more margin is needed."
                     : "As you use routines, cues, and replanning, the app will highlight where transitions stick, which support lands, and when the day usually needs more margin.")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private func categorySection(_ category: InsightCategory, cards: [InsightCard]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .font(AppTheme.Typography.sectionTitle)

            ForEach(cards) { card in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(card.title)
                                .font(AppTheme.Typography.cardTitle)
                            Spacer()
                            Text(priorityLabel(for: card.priority))
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }

                        Text(card.summary)
                            .font(AppTheme.Typography.supporting)
                        Text(card.supportingDetail)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private func metricTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(value)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.text)
            Text(detail)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func priorityLabel(for priority: InsightPriority) -> String {
        switch priority {
        case .high:
            return "High signal"
        case .medium:
            return "Worth watching"
        case .low:
            return "Light pattern"
        }
    }
}
