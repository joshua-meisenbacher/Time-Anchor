import SwiftUI

struct OnboardingFlowView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case profile
        case support
        case calendars
        case health
        case finish

        var title: String {
            switch self {
            case .welcome:
                return "Welcome"
            case .profile:
                return "Profile"
            case .support:
                return "Support"
            case .calendars:
                return "Calendars"
            case .health:
                return "Health"
            case .finish:
                return "Ready"
            }
        }
    }

    struct Draft {
        var displayName: String = ""
        var userRole: UserRole = .selfPlanner
        var neurotype: Neurotype = .adhd
        var pdaAwareSupport: Bool = false
        var supportPreset: SupportPreset = .balanced
        var supportFocuses: [SupportFocus] = [.transitions]
        var communicationStyle: CommunicationStyle = .supportive
        var visualSupportMode: VisualSupportMode = .standard
        var reminderProfile: ReminderProfile = .balanced
        var googleClientID: String = ""
    }

    @ObservedObject var appStore: AppStore
    @State private var step: Step = .welcome
    @State private var draft = Draft()
    @State private var isSavingProfile = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case googleClientID
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header
                ScrollView(showsIndicators: false) {
                    stepView
                        .padding(.vertical, 2)
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(24)
        }
        .onAppear {
            draft.displayName = appStore.selectedUserProfile?.displayName ?? appStore.profileSettings.displayName
            draft.userRole = appStore.profileSettings.userRole
            draft.neurotype = appStore.profileSettings.neurotype
            draft.pdaAwareSupport = appStore.profileSettings.pdaAwareSupport
            draft.supportPreset = appStore.profileSettings.supportPreset
            draft.supportFocuses = [appStore.profileSettings.primarySupportFocus] + appStore.profileSettings.additionalSupportFocuses
            draft.communicationStyle = appStore.profileSettings.communicationStyle
            draft.visualSupportMode = appStore.profileSettings.visualSupportMode
            draft.reminderProfile = appStore.profileSettings.reminderProfile
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenModeBadge(title: "Set Up")
            Text("Set up Time Anchor")
                .font(AppTheme.Typography.heroTitle)
            Text("Build one profile, then optionally connect calendars and Apple Health so Today starts with real context.")
                .font(AppTheme.Typography.supporting)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { candidate in
                    Capsule()
                        .fill(candidate.rawValue <= step.rawValue ? AppTheme.Colors.primary : AppTheme.Colors.border)
                        .frame(height: 6)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .welcome:
            OnboardingCard {
                Text("Time Anchor helps you understand what is happening now, what comes next, and how to move through the day with less friction.")
                    .font(AppTheme.Typography.supporting)
                Text("This first setup keeps it light: profile basics, support style, calendars, and Apple Health.")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        case .profile:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 16) {
                    labeled("Profile name") {
                        TextField("What should this profile be called?", text: $draft.displayName)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .name)
                    }

                    labeled("Who is this profile for?") {
                        adaptivePicker(UserRole.allCases, selection: $draft.userRole) { role in
                            role.title
                        }
                    }
                }
            }
        case .support:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 16) {
                    labeled("Neurotype") {
                        adaptivePicker(Neurotype.allCases, selection: $draft.neurotype) { type in
                            type.title
                        }
                    }

                    Toggle("Use PDA-aware wording for this profile", isOn: $draft.pdaAwareSupport)
                        .tint(AppTheme.Colors.primary)

                    labeled("Support preset") {
                        adaptivePicker(SupportPreset.allCases, selection: $draft.supportPreset) { preset in
                            preset.title
                        }
                    }

                    labeled("How can the app help?") {
                        multiSelectSupportFocuses
                    }

                    labeled("Communication style") {
                        adaptivePicker(CommunicationStyle.allCases, selection: $draft.communicationStyle) { style in
                            style.title
                        }
                    }

                    labeled("Reminder posture") {
                        adaptivePicker(ReminderProfile.allCases, selection: $draft.reminderProfile) { profile in
                            profile.title
                        }
                    }

                    labeled("Visual mode") {
                        adaptivePicker(VisualSupportMode.allCases, selection: $draft.visualSupportMode) { mode in
                            mode.title
                        }
                    }
                }
            }
        case .calendars:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Calendar")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("Use Apple Calendar for built-in calendars and any Google calendars already synced to this device.")
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        if appStore.integrationStore.calendarStatus == .connected {
                            Button("Apple Calendar Connected") { }
                                .buttonStyle(SecondaryActionButtonStyle())
                                .disabled(true)
                        } else {
                            Button("Connect Apple Calendar") {
                                _Concurrency.Task {
                                    await appStore.connectCalendar()
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google Calendar")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("Connect Google directly if you want a separate Google source instead of relying on Apple Calendar sync.")
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        TextField("Google OAuth client ID", text: $draft.googleClientID)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .googleClientID)
                        if appStore.googleCalendarAccount != nil {
                            Button("Google Calendar Connected") { }
                                .buttonStyle(SecondaryActionButtonStyle())
                                .disabled(true)
                        } else {
                            Button("Connect Google Calendar") {
                                _Concurrency.Task {
                                    await appStore.connectGoogleCalendar(clientID: draft.googleClientID)
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(draft.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if let account = appStore.googleCalendarAccount {
                            Text("\(account.availableCalendars.count) Google calendars found.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                }
            }
        case .health:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Health")
                        .font(AppTheme.Typography.sectionTitle)
                    Text("Health data can shorten check-ins and help Time Anchor adjust support around sleep, recovery, and activity. This is optional.")
                        .font(AppTheme.Typography.supporting)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    if appStore.integrationStore.healthStatus == .connected {
                        Button("Apple Health Connected") { }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(true)
                    } else {
                        Button("Connect Apple Health") {
                            _Concurrency.Task {
                                await appStore.connectAppleHealth()
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
            }
        case .finish:
            OnboardingCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile summary")
                        .font(AppTheme.Typography.sectionTitle)
                    summaryRow("Name", value: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Profile" : draft.displayName)
                    summaryRow("Preset", value: draft.supportPreset.title)
                    summaryRow("Support focus", value: supportFocusSummary)
                    summaryRow("Calendars", value: calendarSummary)
                    summaryRow("Health", value: appStore.integrationStore.healthStatus.title)
                    Text("You can change any of this later in Settings.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button("Back") {
                    focusedField = nil
                    guard let previous = Step(rawValue: step.rawValue - 1) else { return }
                    step = previous
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else {
                Button("Skip for now") {
                    appStore.skipOnboardingForNow()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            Button(step == .finish ? (isSavingProfile ? "Saving..." : "Open Today") : "Continue") {
                focusedField = nil
                if step == .finish {
                    isSavingProfile = true
                    appStore.completeOnboarding(
                        displayName: draft.displayName,
                        userRole: draft.userRole,
                        neurotype: draft.neurotype,
                        pdaAwareSupport: draft.pdaAwareSupport,
                        supportPreset: draft.supportPreset,
                        primarySupportFocus: draft.supportFocuses.first ?? .transitions,
                        additionalSupportFocuses: Array(draft.supportFocuses.dropFirst()),
                        communicationStyle: draft.communicationStyle,
                        visualSupportMode: draft.visualSupportMode,
                        reminderProfile: draft.reminderProfile
                    )
                    isSavingProfile = false
                } else if let next = Step(rawValue: step.rawValue + 1) {
                    step = next
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .frame(maxWidth: .infinity)
        }
    }

    private var calendarSummary: String {
        if appStore.googleCalendarAccount != nil && appStore.integrationStore.calendarStatus == .connected {
            return "Apple Calendar and Google Calendar"
        }
        if appStore.googleCalendarAccount != nil {
            return "Google Calendar"
        }
        if appStore.integrationStore.calendarStatus == .connected {
            return "Apple Calendar"
        }
        return "Not connected yet"
    }

    private var supportFocusSummary: String {
        draft.supportFocuses.map(\.title).joined(separator: ", ")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.cardTitle)
            content()
        }
    }

    private func adaptivePicker<Value: Hashable>(
        _ values: [Value],
        selection: Binding<Value>,
        title: @escaping (Value) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    HStack {
                        Text(title(value))
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.text)
                        Spacer()
                        Image(systemName: selection.wrappedValue == value ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.wrappedValue == value ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selection.wrappedValue == value ? AppTheme.Colors.card : AppTheme.Colors.controlBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selection.wrappedValue == value ? AppTheme.Colors.primary : AppTheme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var multiSelectSupportFocuses: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose all that fit right now.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            ForEach(SupportFocus.allCases) { focus in
                let isSelected = draft.supportFocuses.contains(focus)
                Button {
                    toggleSupportFocus(focus)
                } label: {
                    HStack {
                        Text(focus.title)
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.text)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.secondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? AppTheme.Colors.card : AppTheme.Colors.controlBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleSupportFocus(_ focus: SupportFocus) {
        if let index = draft.supportFocuses.firstIndex(of: focus) {
            if draft.supportFocuses.count > 1 {
                draft.supportFocuses.remove(at: index)
            }
        } else {
            draft.supportFocuses.append(focus)
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(AppTheme.Typography.supporting)
                .foregroundStyle(AppTheme.Colors.text)
        }
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
    }
}
