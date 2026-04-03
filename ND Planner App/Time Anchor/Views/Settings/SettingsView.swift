import SwiftUI

struct SettingsView: View {
    private enum SettingsSection: String, Identifiable {
        case demo
        case profiles
        case supportStyle
        case reminders
        case integrations

        var id: String { rawValue }

        var title: String {
            switch self {
            case .demo:
                return "Demo Stories"
            case .profiles:
                return "Profiles"
            case .supportStyle:
                return "Support Style"
            case .reminders:
                return "Reminders"
            case .integrations:
                return "Integrations"
            }
        }

        var subtitle: String {
            switch self {
            case .demo:
                return "Guided user stories for live walkthroughs and video capture."
            case .profiles:
                return "Choose who the app is helping and manage saved people."
            case .supportStyle:
                return "Presets, language, visuals, and sensory defaults."
            case .reminders:
                return "Reminder rhythm, quiet hours, and preview copy."
            case .integrations:
                return "Health and calendar connections that shape planning."
            }
        }
    }

    @ObservedObject var appStore: AppStore
    let onOpenToday: (() -> Void)?
    let onOpenCheckIn: (() -> Void)?
    @State private var presentedSection: SettingsSection?
    @State private var isPresentingExternalFeedSheet = false
    @State private var googleClientID = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time Anchor")
                                .font(AppTheme.Typography.heroTitle)
                            Text("A planner built to make time, transitions, and routines feel more workable.")
                                .font(AppTheme.Typography.supporting)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }

                    Button {
                        presentedSection = .demo
                    } label: {
                        settingsHubCard(
                            title: "Demo Stories",
                            subtitle: "User-centered walkthroughs you can load in one tap."
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedSection = .profiles
                    } label: {
                        settingsHubCard(
                            title: "Profiles",
                            subtitle: "People, names, and who the plan is for."
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedSection = .supportStyle
                    } label: {
                        settingsHubCard(
                            title: "Support Style",
                            subtitle: "\(appStore.profileSettings.supportPreset.title) • \(appStore.profileSettings.communicationStyle.title) language"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedSection = .reminders
                    } label: {
                        settingsHubCard(
                            title: "Reminders",
                            subtitle: appStore.profileSettings.reminderProfile.summary
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedSection = .integrations
                    } label: {
                        settingsHubCard(
                            title: "Integrations",
                            subtitle: "Health: \(appStore.integrationStore.healthStatus.title) • Calendars: \(appStore.integrationStore.calendarStatus.title)"
                        )
                    }
                    .buttonStyle(.plain)

                }
                .padding()
            }
            .background(AppTheme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(item: $presentedSection) { section in
                NavigationStack {
                    settingsSectionPage(
                        title: section.title,
                        subtitle: section.subtitle,
                        content: {
                            settingsSectionContent(for: section)
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                presentedSection = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var profileSettingsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Current Profile")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name or nickname")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    TextField("Who should reminders speak to?", text: displayNameBinding)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Primary neurotype")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Primary neurotype", selection: neurotypeBinding) {
                        ForEach(Neurotype.allCases) { neurotype in
                            Text(neurotype.title).tag(neurotype)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Use PDA-aware support phrasing", isOn: pdaAwareSupportBinding)
                    .font(AppTheme.Typography.supporting.weight(.semibold))

                Text("This keeps prompts more invitational for this profile, so support feels more like an option than a demand.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Who is this plan for?")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("User role", selection: userRoleBinding) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(appStore.profileSettings.userRole.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Text(appStore.profileSettings.profileSummary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
    }

    private var profileSwitcherCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("People")
                        .font(AppTheme.Typography.sectionTitle)
                    Spacer()
                    Button("Add Profile") {
                        appStore.addUserProfile()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                if appStore.userProfiles.count > 1 {
                    Button("Delete Current Profile") {
                        appStore.deleteSelectedProfile()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                ForEach(appStore.userProfiles) { profile in
                    Button {
                        appStore.switchToProfile(profile.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.title)
                                    .font(AppTheme.Typography.cardTitle)
                                    .foregroundStyle(
                                        appStore.selectedProfileID == profile.id
                                        ? Color.white
                                        : AppTheme.Colors.text
                                    )
                                Text(profile.summary)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(
                                        appStore.selectedProfileID == profile.id
                                        ? Color.white.opacity(0.85)
                                        : AppTheme.Colors.secondaryText
                                    )
                            }

                            Spacer()

                            if appStore.selectedProfileID == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    appStore.selectedProfileID == profile.id
                                    ? AppTheme.Colors.primary
                                    : AppTheme.Colors.controlBackground
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var supportPreferencesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Support Preferences")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Primary support focus")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Primary support focus", selection: primarySupportFocusBinding) {
                        ForEach(SupportFocus.allCases) { focus in
                            Text(focus.title).tag(focus)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Support tone")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Support tone", selection: supportToneBinding) {
                        ForEach(SupportTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appStore.profileSettings.supportTone.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Language style")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Language style", selection: communicationStyleBinding) {
                        ForEach(CommunicationStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appStore.profileSettings.communicationStyle.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Visual support mode")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Visual support mode", selection: visualSupportModeBinding) {
                        ForEach(VisualSupportMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appStore.profileSettings.visualSupportMode.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Default sensory cue")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Default sensory cue", selection: defaultCueBinding) {
                        Text("Use task-specific cue only").tag(TaskSensoryCue?.none)
                        ForEach(TaskSensoryCue.allCases) { cue in
                            Text(cue.title).tag(TaskSensoryCue?.some(cue))
                        }
                    }
                    .pickerStyle(.menu)

                    Text(defaultCueSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Transition prep window")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Picker("Transition prep window", selection: transitionPrepBinding) {
                        ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("This changes how early the app starts preparing for the next shift in attention or activity.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var supportPresetCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Support Preset")
                    .font(AppTheme.Typography.sectionTitle)

                Picker("Support preset", selection: supportPresetBinding) {
                    ForEach(SupportPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                Text(appStore.profileSettings.supportPreset.summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var reminderSettingsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reminder Support")
                    .font(AppTheme.Typography.sectionTitle)

                Picker("Reminder style", selection: reminderProfileBinding) {
                    ForEach(ReminderProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.segmented)

                Text(appStore.profileSettings.reminderProfile.summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(appStore.reminderPreviewPlan.cadenceSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(appStore.reminderPreviewPlan.sampleCopy)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text("Why this plan")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .padding(.top, 2)
                    Text(appStore.reminderPreviewPlan.escalationRule)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Divider()

                Toggle("Use quiet hours", isOn: quietHoursEnabledBinding)
                    .font(AppTheme.Typography.supporting.weight(.semibold))

                if appStore.profileSettings.quietHoursEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        hourPicker(
                            title: "Quiet hours start",
                            selection: quietHoursStartBinding
                        )
                        hourPicker(
                            title: "Quiet hours end",
                            selection: quietHoursEndBinding
                        )
                    }
                }

                Text(appStore.profileSettings.quietHoursSummary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var demoOverviewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Demo Flow")
                    .font(AppTheme.Typography.sectionTitle)

                Text("Each story loads a real profile and scenario so you can move from who the user is to how the plan adapts for them. It works well for a live walkthrough or a quick screen recording.")
                    .font(AppTheme.Typography.supporting)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    demoBeat(number: 1, text: "Pick the user situation you want to tell.")
                    demoBeat(number: 2, text: "Load the story to switch the app into a matching profile and day.")
                    demoBeat(number: 3, text: "Open Check-In to show how the app understands the day, or Today to show how that understanding becomes a plan.")
                    demoBeat(number: 4, text: "Narrate the support outcome: clearer focus, gentler recovery, or lower coordination stress.")
                }
            }
        }
    }

    private var demoStoriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            demoOverviewCard

            ForEach(MockData.demoStories) { story in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            storyMonogram(for: story.profileName)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.title)
                                    .font(AppTheme.Typography.sectionTitle)
                                Text(story.subtitle)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }

                        demoStoryBlock(title: "Persona", body: story.personaSummary)
                        demoStoryBlock(title: "Challenge", body: story.challenge)
                        demoStoryBlock(title: "How the app helps", body: story.appSupportSummary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested walkthrough")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            ForEach(Array(story.walkthroughMoments.enumerated()), id: \.offset) { index, moment in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                    Text(moment)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                        }

                        Text("Loads \(story.profileName) with the \(story.scenario.title) scenario.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.primary)

                        HStack(spacing: 10) {
                            Button("Load Story") {
                                appStore.activateDemoStory(story)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button("Load + Check-In") {
                                appStore.activateDemoStory(story)
                                onOpenCheckIn?()
                            }
                            .buttonStyle(SecondaryActionButtonStyle())

                            Button("Load + Today") {
                                appStore.activateDemoStory(story)
                                onOpenToday?()
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Health")
                        .font(AppTheme.Typography.sectionTitle)
                    settingsRow(
                        title: appStore.integrationStore.healthStatus.title,
                        subtitle: "Sleep, heart rate, hydration, activity, and exercise help estimate likely capacity before the day gets away from you."
                    )

                    if let health = appStore.integrationStore.importedHealthSignals {
                        Text(healthStatusSummary(health))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else if appStore.integrationStore.healthStatus == .connected {
                        Text("Health access is connected, but no imported samples are loaded yet. Try Refresh Connected Data after choosing the data categories you want to share.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Button(appStore.integrationStore.healthStatus == .connected ? "Reconnect Apple Health" : "Connect Apple Health") {
                        _Concurrency.Task {
                            await appStore.connectAppleHealth()
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calendars")
                        .font(AppTheme.Typography.sectionTitle)
                    settingsRow(
                        title: appStore.integrationStore.calendarStatus.title,
                        subtitle: "EventKit can import Apple Calendar events and any Google calendars already synced on this device."
                    )

                    if !appStore.integrationStore.calendarSourceNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Included sources")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(appStore.integrationStore.calendarSourceNames, id: \.self) { sourceName in
                                    Button {
                                        appStore.toggleCalendarSourceSelection(sourceName)
                                    } label: {
                                        Text(sourceName)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(
                                                appStore.integrationStore.selectedCalendarSourceNames.contains(sourceName)
                                                ? Color.white
                                                : AppTheme.Colors.text
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(
                                                        appStore.integrationStore.selectedCalendarSourceNames.contains(sourceName)
                                                        ? AppTheme.Colors.primary
                                                        : AppTheme.Colors.controlBackground
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text("\(appStore.integrationStore.allImportedEvents.count) imported events are available across the next year.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Toggle("Include holiday events in planning", isOn: includeHolidayEventsBinding)
                        .font(AppTheme.Typography.supporting.weight(.semibold))

                    Text("Keep common calendar holidays like Tax Day and bank holidays out of the day plan unless this profile actually wants them visible.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Button("Connect Calendars") {
                        _Concurrency.Task {
                            await appStore.connectCalendar()
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Google Calendar")
                        .font(AppTheme.Typography.sectionTitle)
                    settingsRow(
                        title: appStore.googleCalendarAccount?.isConnected == true ? "Connected directly" : "Not connected directly",
                        subtitle: "Use Google as its own calendar source instead of relying on Apple Calendar sync. This helps avoid duplicate mirrored events."
                    )

                    if appStore.googleCalendarAccount == nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Google OAuth client ID")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            TextField("Paste your Google OAuth client ID", text: $googleClientID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Text("This direct Google option is advanced. Most people should use Apple Calendar sync or an external feed instead. You only need a Google OAuth client ID if you created your own Google Cloud OAuth app for Calendar access.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text("If you do not already know where your OAuth client ID is, skip this for now and use `Connect Calendars` above or `Add External Feed` below.")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        Button("Connect Google Calendar") {
                            _Concurrency.Task {
                                await appStore.connectGoogleCalendar(clientID: googleClientID)
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(googleClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        if let account = appStore.googleCalendarAccount, !account.availableCalendars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Included Google calendars")
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                                    ForEach(account.availableCalendars) { calendar in
                                        Button {
                                            _Concurrency.Task {
                                                await appStore.toggleGoogleCalendarSelection(calendar.id)
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(calendar.title)
                                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                                    .lineLimit(2)
                                                Text(calendar.subtitle)
                                                    .font(AppTheme.Typography.caption)
                                                    .lineLimit(2)
                                            }
                                            .foregroundStyle(
                                                account.selectedCalendarIDs.contains(calendar.id)
                                                ? Color.white
                                                : AppTheme.Colors.text
                                            )
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(
                                                        account.selectedCalendarIDs.contains(calendar.id)
                                                        ? AppTheme.Colors.primary
                                                        : AppTheme.Colors.controlBackground
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Text("\(appStore.googleImportedEvents.count) events are currently imported from Google Calendar.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        HStack(spacing: 12) {
                            Button("Refresh Google") {
                                _Concurrency.Task {
                                    await appStore.refreshGoogleCalendar()
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())

                            Button("Disconnect Google") {
                                appStore.disconnectGoogleCalendar()
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("External Calendar Feeds")
                        .font(AppTheme.Typography.sectionTitle)
                    settingsRow(
                        title: "Google, Skylight, or other subscribe links",
                        subtitle: "Paste a private calendar feed if you want events outside Apple Calendar sync. This is useful for Google calendars you do not want mirrored into Apple Calendar, or any Skylight-style exported feed."
                    )

                    if appStore.externalCalendarSubscriptions.isEmpty {
                        Text("No external feeds connected yet.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(appStore.externalCalendarSubscriptions) { subscription in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(subscription.title)
                                            .font(AppTheme.Typography.cardTitle)
                                        Text(subscription.provider.title)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                        Text(subscription.feedURL)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                            .lineLimit(2)
                                            .textSelection(.enabled)
                                    }

                                    Spacer()

                                    Button("Remove") {
                                        _Concurrency.Task {
                                            await appStore.removeExternalCalendarSubscription(subscription.id)
                                        }
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppTheme.Colors.controlBackground)
                                )
                            }
                        }
                    }

                    Text("\(appStore.externalImportedEvents.count) events are currently imported from external feeds.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    HStack(spacing: 12) {
                        Button("Add External Feed") {
                            isPresentingExternalFeedSheet = true
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button("Refresh External Feeds") {
                            _Concurrency.Task {
                                await appStore.refreshExternalCalendarFeeds()
                                appStore.regeneratePlans()
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    Text("For Google Calendar, use the private iCal address for the specific calendar you want. For Skylight, paste any calendar subscribe link or exported feed URL if the service provides one.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            Button("Refresh Connected Data") {
                _Concurrency.Task {
                    await appStore.refreshIntegrations()
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .sheet(isPresented: $isPresentingExternalFeedSheet) {
            NavigationStack {
                CreateExternalCalendarFeedView { title, provider, feedURL in
                    _Concurrency.Task {
                        await appStore.addExternalCalendarSubscription(
                            title: title,
                            provider: provider,
                            feedURL: feedURL
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isPresentingExternalFeedSheet = false
                        }
                    }
                }
            }
        }
        .onAppear {
            if googleClientID.isEmpty {
                googleClientID = appStore.googleCalendarAccount?.clientID ?? ""
            }
        }
    }

    private func settingsHubCard(title: String, subtitle: String) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Typography.sectionTitle)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(.top, 4)
            }
        }
    }

    private func settingsSectionPage<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(AppTheme.Typography.heroTitle)
                        Text(subtitle)
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                content()
            }
            .padding()
        }
        .background(AppTheme.Colors.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Typography.cardTitle)
            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func demoBeat(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppTheme.Colors.primary))

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func demoStoryBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(body)
                .font(AppTheme.Typography.supporting)
        }
    }

    private func storyMonogram(for name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()

        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Colors.primaryMuted)
                .frame(width: 56, height: 56)
            Text(initials.isEmpty ? "TA" : initials)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primary)
        }
    }

    private func healthSummary(_ health: HealthSignals) -> String {
        var parts: [String] = []

        if let sleepHours = health.sleepHours {
            parts.append(String(format: "Sleep %.1fh", sleepHours))
        }
        if let averageHeartRate = health.averageHeartRate {
            parts.append("Avg HR \(averageHeartRate)")
        }
        if let heartRateVariabilityMilliseconds = health.heartRateVariabilityMilliseconds {
            parts.append(String(format: "HRV %.0fms", heartRateVariabilityMilliseconds))
        }
        if let respiratoryRate = health.respiratoryRate {
            parts.append(String(format: "Resp %.1f", respiratoryRate))
        }
        if let hydrationLiters = health.hydrationLiters {
            parts.append(String(format: "Water %.1fL", hydrationLiters))
        }
        if let exerciseMinutes = health.exerciseMinutes {
            parts.append("Exercise \(Int(exerciseMinutes))m")
        }
        if let stepCount = health.stepCount {
            parts.append("Steps \(stepCount)")
        }
        if let recoveryScore = health.recoveryScore {
            parts.append("Recovery \(recoveryScore)")
        }

        return parts.isEmpty ? "No imported health profile yet." : parts.joined(separator: " • ")
    }

    private func healthStatusSummary(_ health: HealthSignals) -> String {
        if health.hasAnyData {
            return healthSummary(health)
        }
        return "Health access is connected, but the app has not found recent samples in the supported HealthKit categories yet."
    }

    @ViewBuilder
    private func settingsSectionContent(for section: SettingsSection) -> some View {
        switch section {
        case .demo:
            demoStoriesSection
        case .profiles:
            profileSwitcherCard
            profileSettingsCard
        case .supportStyle:
            supportPresetCard
            supportPreferencesCard
        case .reminders:
            reminderSettingsCard
        case .integrations:
            integrationsSection
        }
    }

    private func hourPicker(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Picker(title, selection: selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(hourLabel(for: hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let suffix = hour >= 12 ? "PM" : "AM"
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(hour12):00 \(suffix)"
    }

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { appStore.profileSettings.displayName },
            set: { appStore.setProfileDisplayName($0) }
        )
    }

    private var reminderProfileBinding: Binding<ReminderProfile> {
        Binding(
            get: { appStore.profileSettings.reminderProfile },
            set: { appStore.setReminderProfile($0) }
        )
    }

    private var pdaAwareSupportBinding: Binding<Bool> {
        Binding(
            get: { appStore.profileSettings.pdaAwareSupport },
            set: { appStore.setPDAAwareSupport($0) }
        )
    }

    private var includeHolidayEventsBinding: Binding<Bool> {
        Binding(
            get: { appStore.profileSettings.includeHolidayEvents },
            set: { appStore.setIncludeHolidayEvents($0) }
        )
    }

    private var userRoleBinding: Binding<UserRole> {
        Binding(
            get: { appStore.profileSettings.userRole },
            set: { appStore.setUserRole($0) }
        )
    }

    private var neurotypeBinding: Binding<Neurotype> {
        Binding(
            get: { appStore.profileSettings.neurotype },
            set: { appStore.setNeurotype($0) }
        )
    }

    private var primarySupportFocusBinding: Binding<SupportFocus> {
        Binding(
            get: { appStore.profileSettings.primarySupportFocus },
            set: { appStore.setPrimarySupportFocus($0) }
        )
    }

    private var supportToneBinding: Binding<SupportTone> {
        Binding(
            get: { appStore.profileSettings.supportTone },
            set: { appStore.setSupportTone($0) }
        )
    }

    private var supportPresetBinding: Binding<SupportPreset> {
        Binding(
            get: { appStore.profileSettings.supportPreset },
            set: { appStore.applySupportPreset($0) }
        )
    }

    private var communicationStyleBinding: Binding<CommunicationStyle> {
        Binding(
            get: { appStore.profileSettings.communicationStyle },
            set: { appStore.setCommunicationStyle($0) }
        )
    }

    private var visualSupportModeBinding: Binding<VisualSupportMode> {
        Binding(
            get: { appStore.profileSettings.visualSupportMode },
            set: { appStore.setVisualSupportMode($0) }
        )
    }

    private var defaultCueBinding: Binding<TaskSensoryCue?> {
        Binding(
            get: { appStore.profileSettings.defaultSensoryCue },
            set: { appStore.setDefaultSensoryCue($0) }
        )
    }

    private var quietHoursEnabledBinding: Binding<Bool> {
        Binding(
            get: { appStore.profileSettings.quietHoursEnabled },
            set: { appStore.setQuietHoursEnabled($0) }
        )
    }

    private var quietHoursStartBinding: Binding<Int> {
        Binding(
            get: { appStore.profileSettings.quietHoursStartHour },
            set: { appStore.setQuietHours(startHour: $0) }
        )
    }

    private var quietHoursEndBinding: Binding<Int> {
        Binding(
            get: { appStore.profileSettings.quietHoursEndHour },
            set: { appStore.setQuietHours(endHour: $0) }
        )
    }

    private var defaultCueSummary: String {
        if let defaultCue = appStore.profileSettings.defaultSensoryCue {
            return "Tasks without their own cue will fall back to \(defaultCue.title.lowercased())."
        }
        return "Tasks keep their own cue settings. Nothing extra is added if a task has no cue."
    }

    private var transitionPrepBinding: Binding<Int> {
        Binding(
            get: { appStore.profileSettings.transitionPrepMinutes },
            set: { appStore.setTransitionPrepMinutes($0) }
        )
    }
}

private struct CreateExternalCalendarFeedView: View {
    let onSave: (String, ExternalCalendarSubscription.Provider, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var provider: ExternalCalendarSubscription.Provider = .googleCalendar
    @State private var feedURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add External Feed")
                            .font(AppTheme.Typography.heroTitle)
                        Text("Connect a subscribe URL outside Apple Calendar. Use one feed per calendar so you can control exactly what gets pulled in.")
                            .font(AppTheme.Typography.supporting)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            Picker("Provider", selection: $provider) {
                                ForEach(ExternalCalendarSubscription.Provider.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Feed name")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            TextField(defaultTitle, text: $title)
                                .textInputAutocapitalization(.words)
                                .padding(12)
                                .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Feed URL")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            TextField("https://...", text: $feedURL, axis: .vertical)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(12)
                                .background(AppTheme.Colors.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Text(helpText)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                Button("Save Feed") {
                    onSave(resolvedTitle, provider, feedURL)
                    dismiss()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .background(AppTheme.Colors.canvas.ignoresSafeArea())
        .navigationTitle("External Feed")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle : trimmed
    }

    private var defaultTitle: String {
        switch provider {
        case .googleCalendar:
            return "Google Calendar"
        case .skylight:
            return "Skylight Calendar"
        case .other:
            return "External Calendar"
        }
    }

    private var helpText: String {
        switch provider {
        case .googleCalendar:
            return "Paste the private iCal address for the specific Google calendar you want to import."
        case .skylight:
            return "Paste a Skylight subscribe URL or any calendar feed URL Skylight gives you."
        case .other:
            return "Paste any valid .ics or subscribe URL the service provides."
        }
    }
}
