import SwiftUI

struct SettingsView: View {
    @Bindable private var prefs = UserPreferences.shared

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Header
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)

                    // MARK: - Schedule Section
                    SettingsSectionHeader(title: "Schedule")

                    NavigationLink(destination: WorkingHoursView()) {
                        SettingsRow(
                            icon: "clock",
                            title: "Working Hours",
                            value: "\(formatHour(prefs.workDayStartHour)) – \(formatHour(prefs.workDayEndHour))"
                        )
                    }

                    NavigationLink(destination: RulesListView()) {
                        SettingsRow(icon: "calendar.badge.clock", title: "Time Blocks")
                    }

                    NavigationLink(destination: ContextListView()) {
                        SettingsRow(icon: "calendar.badge.plus", title: "Day Plans")
                    }

                    // MARK: - Focus Section
                    SettingsSectionHeader(title: "Focus")

                    NavigationLink(destination: DailyGoalView()) {
                        SettingsRow(
                            icon: "target",
                            title: "Daily Goal",
                            value: "\(prefs.dailyProductiveHours) hrs"
                        )
                    }

                    NavigationLink(destination: SessionLengthView()) {
                        SettingsRow(
                            icon: "hourglass",
                            title: "Session Length",
                            value: "\(prefs.sessionMinMinutes)–\(prefs.sessionMaxMinutes) min"
                        )
                    }

                    NavigationLink(destination: DeadlineBufferView()) {
                        SettingsRow(
                            icon: "calendar.badge.exclamationmark",
                            title: "Deadline Buffer",
                            value: "\(prefs.deadlineBufferPercent)%"
                        )
                    }

                    NavigationLink(destination: BreaksView()) {
                        SettingsRow(
                            icon: "leaf",
                            title: "Breaks",
                            value: prefs.restBetweenSessionsEnabled ? "On" : "Off"
                        )
                    }

                    // MARK: - Appearance Section
                    SettingsSectionHeader(title: "Appearance")

                    NavigationLink(destination: AppearanceModeView()) {
                        SettingsRow(
                            icon: prefs.appearanceMode.icon,
                            title: "Appearance",
                            value: prefs.appearanceMode.displayName
                        )
                    }

                    NavigationLink(destination: ThemeColorView()) {
                        SettingsRow(
                            icon: "circle.fill",
                            iconColor: prefs.themeColorOption.accentColor,
                            title: "Theme Color",
                            value: prefs.themeColorOption.displayName
                        )
                    }

                    NavigationLink(destination: LanguageView()) {
                        SettingsRow(
                            icon: prefs.languageOption.icon,
                            title: "Language",
                            value: prefs.languageOption.displayName
                        )
                    }

                    // MARK: - AI Section
                    SettingsSectionHeader(title: "AI Assistant")

                    NavigationLink(destination: AISettingsView()) {
                        SettingsRow(
                            icon: "sparkles",
                            title: "OpenAI",
                            value: hasExistingKey ? "Connected" : "Not Set"
                        )
                    }

                    // MARK: - About Section
                    SettingsSectionHeader(title: "About")

                    SettingsRow(icon: "info.circle", title: "Version", value: "1.0.0", showChevron: false)

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone")!) {
                        SettingsRow(icon: "chevron.left.forwardslash.chevron.right", title: "Source Code", isLink: true)
                    }

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone/blob/main/PRIVACY.md")!) {
                        SettingsRow(icon: "hand.raised", title: "Privacy Policy", isLink: true)
                    }

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone/blob/main/TERMS.md")!) {
                        SettingsRow(icon: "doc.text", title: "Terms of Service", isLink: true)
                    }

                Spacer(minLength: 40)
            }
        }
        .background(DesignSystem.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Settings Row Component

private struct SettingsRow: View {
    let icon: String
    var iconColor: Color? = nil
    let title: String
    var value: String? = nil
    var showChevron: Bool = true
    var isLink: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor ?? DesignSystem.Colors.textPrimary)
                .frame(width: 24)

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            if let value = value {
                Text(value)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            if showChevron {
                Image(systemName: isLink ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Section Header

private struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 8)
    }
}

// MARK: - Working Hours View

private struct WorkingHoursView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Start time
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Start")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Picker("Start", selection: $prefs.workDayStartHour) {
                            ForEach(5...12, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    // End time
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("End")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Picker("End", selection: $prefs.workDayEndHour) {
                            ForEach(17...23, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    Text("Sessions are scheduled within these hours.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Working Hours")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Daily Goal View

private struct DailyGoalView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Text("\(prefs.dailyProductiveHours)")
                            .font(DesignSystem.Typography.statLarge)
                            .foregroundStyle(DesignSystem.Colors.accent)
                        + Text(" hours")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Stepper("", value: $prefs.dailyProductiveHours, in: 1...12)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    Text("Target productive hours per day.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Daily Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Session Length View

private struct SessionLengthView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Min duration
                        HStack {
                            Text("Minimum")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text("\(prefs.sessionMinMinutes) min")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                        Stepper("", value: $prefs.sessionMinMinutes, in: 30...60, step: 15)
                            .labelsHidden()

                        Divider()
                            .background(DesignSystem.Colors.divider)

                        // Max duration
                        HStack {
                            Text("Maximum")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text("\(prefs.sessionMaxMinutes) min")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                        Stepper("", value: $prefs.sessionMaxMinutes, in: 60...120, step: 15)
                            .labelsHidden()
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    Text("Preferred focus session duration range.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Session Length")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Breaks View

private struct BreaksView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Toggle card
                    HStack {
                        Text("Enable Breaks")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $prefs.restBetweenSessionsEnabled)
                            .labelsHidden()
                            .tint(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    if prefs.restBetweenSessionsEnabled {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            // Work interval
                            HStack {
                                Text("Work Interval")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Text("\(prefs.workIntervalMinutes) min")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                            Stepper("", value: $prefs.workIntervalMinutes, in: 30...120, step: 15)
                                .labelsHidden()

                            Divider()
                                .background(DesignSystem.Colors.divider)

                            // Break duration
                            HStack {
                                Text("Break Duration")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Text("\(prefs.restDurationMinutes) min")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                            Stepper("", value: $prefs.restDurationMinutes, in: 5...30, step: 5)
                                .labelsHidden()
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(DesignSystem.Colors.cardBackground)
                        )

                        Text("Take a \(prefs.restDurationMinutes)-minute break every \(prefs.workIntervalMinutes) minutes.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Breaks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Deadline Buffer View

private struct DeadlineBufferView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Text("\(prefs.deadlineBufferPercent)%")
                            .font(DesignSystem.Typography.statLarge)
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Slider(
                            value: Binding(
                                get: { Double(prefs.deadlineBufferPercent) },
                                set: { prefs.deadlineBufferPercent = Int($0) }
                            ),
                            in: 0...50,
                            step: 5
                        )
                        .tint(DesignSystem.Colors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    Text("Reserve \(prefs.deadlineBufferPercent)% of days before deadlines for unexpected issues.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Deadline Buffer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance Mode View

private struct AppearanceModeView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            prefs.appearanceMode = mode
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .frame(width: 32)

                                Text(mode.displayName)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                                Spacer()

                                if prefs.appearanceMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .fill(DesignSystem.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .strokeBorder(
                                        prefs.appearanceMode == mode
                                            ? DesignSystem.Colors.accent.opacity(0.5)
                                            : DesignSystem.Colors.textTertiary.opacity(0.2),
                                        lineWidth: prefs.appearanceMode == mode ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Note about the setting
                    Text("Choose how TouchStone appears. System follows your device settings.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language View

private struct LanguageView: View {
    @Bindable private var prefs = UserPreferences.shared
    @State private var showRestartAlert = false
    @State private var pendingLanguage: LanguageOption?

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(LanguageOption.allCases) { option in
                        Button {
                            if option != prefs.languageOption {
                                pendingLanguage = option
                                showRestartAlert = true
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .frame(width: 32)

                                Text(option.displayName)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                                Spacer()

                                if prefs.languageOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .fill(DesignSystem.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .strokeBorder(
                                        prefs.languageOption == option
                                            ? DesignSystem.Colors.accent.opacity(0.5)
                                            : DesignSystem.Colors.textTertiary.opacity(0.2),
                                        lineWidth: prefs.languageOption == option ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Changing the language requires restarting the app.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) {
                pendingLanguage = nil
            }
            Button("Change & Quit") {
                if let language = pendingLanguage {
                    prefs.languageOption = language
                    // Give time for UserDefaults to sync before exiting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(0)
                    }
                }
            }
        } message: {
            Text("The app will quit to apply the language change. Please reopen the app manually.")
        }
    }
}

// MARK: - Theme Color View

private struct ThemeColorView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(ThemeColorOption.allCases) { option in
                        Button {
                            prefs.themeColorOption = option
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                // Color preview circle
                                Circle()
                                    .fill(option.accentColor)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(option.displayName)
                                        .font(DesignSystem.Typography.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }

                                Spacer()

                                if prefs.themeColorOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(option.accentColor)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .fill(DesignSystem.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                    .strokeBorder(
                                        prefs.themeColorOption == option
                                            ? option.accentColor.opacity(0.5)
                                            : DesignSystem.Colors.textTertiary.opacity(0.2),
                                        lineWidth: prefs.themeColorOption == option ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Theme Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AI Settings View

private struct AISettingsView: View {
    @Bindable private var prefs = UserPreferences.shared
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var showSaveConfirmation = false
    @State private var showDeleteConfirmation = false

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    if hasExistingKey {
                        // Connected status card
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignSystem.Colors.success)
                                Text("Connected")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                            }

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Text("Remove API Key")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.error)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                                            .fill(DesignSystem.Colors.error.opacity(0.1))
                                    )
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                    } else {
                        // API Key input card
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            HStack {
                                if showAPIKey {
                                    TextField("sk-...", text: $apiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                } else {
                                    SecureField("sk-...", text: $apiKey)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }

                                Button {
                                    showAPIKey.toggle()
                                } label: {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                                    .fill(DesignSystem.Colors.backgroundLight)
                            )

                            Button {
                                saveAPIKey()
                            } label: {
                                Text("Save Key")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(apiKey.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                                            .fill(apiKey.isEmpty ? DesignSystem.Colors.cardBackgroundLight : DesignSystem.Colors.accent)
                                    )
                            }
                            .disabled(apiKey.isEmpty)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(DesignSystem.Colors.cardBackground)
                        )

                        Text("Your API key is stored securely in the Keychain.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                    }

                    // Links section
                    VStack(spacing: 0) {
                        Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                            HStack {
                                Text("Get API Key")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }

                        Divider()
                            .background(DesignSystem.Colors.divider)

                        Link(destination: URL(string: "https://platform.openai.com/usage")!) {
                            HStack {
                                Text("View Usage")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            .padding(DesignSystem.Spacing.lg)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .alert("API Key Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        }
        .alert("Remove API Key?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                deleteAPIKey()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func saveAPIKey() {
        do {
            try APIKeyManager.shared.setOpenAIKey(apiKey)
            apiKey = ""
            showSaveConfirmation = true
        } catch {
            print("Failed to save API key: \(error)")
        }
    }

    private func deleteAPIKey() {
        do {
            try APIKeyManager.shared.deleteOpenAIKey()
        } catch {
            print("Failed to delete API key: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}
