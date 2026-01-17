import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var showSaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var dragOffset: CGFloat = 0

    @Bindable private var prefs = UserPreferences.shared

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - Header
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.primary)
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
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

                    SettingsDivider()

                    NavigationLink(destination: RulesListView()) {
                        SettingsRow(icon: "calendar.badge.clock", title: "Time Blocks")
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

                    SettingsDivider()

                    NavigationLink(destination: SessionLengthView()) {
                        SettingsRow(
                            icon: "hourglass",
                            title: "Session Length",
                            value: "\(prefs.sessionMinMinutes)–\(prefs.sessionMaxMinutes) min"
                        )
                    }

                    SettingsDivider()

                    NavigationLink(destination: DeadlineBufferView()) {
                        SettingsRow(
                            icon: "calendar.badge.exclamationmark",
                            title: "Deadline Buffer",
                            value: "\(prefs.deadlineBufferPercent)%"
                        )
                    }

                    SettingsDivider()

                    NavigationLink(destination: BreaksView()) {
                        SettingsRow(
                            icon: "leaf",
                            title: "Breaks",
                            value: prefs.restBetweenSessionsEnabled ? "On" : "Off"
                        )
                    }

                    // MARK: - Appearance Section
                    SettingsSectionHeader(title: "Appearance")

                    NavigationLink(destination: AccentColorView()) {
                        SettingsRow(
                            icon: "circle.fill",
                            iconColor: prefs.accentColor,
                            title: "Accent Color",
                            value: prefs.accentColorOption.displayName
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

                    SettingsDivider()

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone")!) {
                        SettingsRow(icon: "chevron.left.forwardslash.chevron.right", title: "Source Code", isLink: true)
                    }

                    SettingsDivider()

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone/blob/main/PRIVACY.md")!) {
                        SettingsRow(icon: "hand.raised", title: "Privacy Policy", isLink: true)
                    }

                    SettingsDivider()

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone/blob/main/TERMS.md")!) {
                        SettingsRow(icon: "doc.text", title: "Terms of Service", isLink: true)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    let velocity = value.predictedEndTranslation.width - value.translation.width

                    if value.translation.width > threshold || velocity > 500 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    } else {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            dragOffset = 0
                        }
                    }
                }
        )
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
    var iconColor: Color = .primary
    let title: String
    var value: String? = nil
    var showChevron: Bool = true
    var isLink: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if let value = value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if showChevron {
                Image(systemName: isLink ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
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
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 8)
    }
}

// MARK: - Divider

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 58)
    }
}

// MARK: - Working Hours View

private struct WorkingHoursView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        List {
            Section {
                Picker("Start", selection: $prefs.workDayStartHour) {
                    ForEach(5...12, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }

                Picker("End", selection: $prefs.workDayEndHour) {
                    ForEach(17...23, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
            } footer: {
                Text("Sessions are scheduled within these hours.")
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
        List {
            Section {
                Stepper("\(prefs.dailyProductiveHours) hours", value: $prefs.dailyProductiveHours, in: 1...12)
            } footer: {
                Text("Target productive hours per day.")
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
        List {
            Section {
                Stepper("Min: \(prefs.sessionMinMinutes) min", value: $prefs.sessionMinMinutes, in: 30...60, step: 15)
                Stepper("Max: \(prefs.sessionMaxMinutes) min", value: $prefs.sessionMaxMinutes, in: 60...120, step: 15)
            } footer: {
                Text("Preferred focus session duration range.")
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
        List {
            Section {
                Toggle("Enable Breaks", isOn: $prefs.restBetweenSessionsEnabled)
            }

            if prefs.restBetweenSessionsEnabled {
                Section {
                    Stepper("Work: \(prefs.workIntervalMinutes) min", value: $prefs.workIntervalMinutes, in: 30...120, step: 15)
                    Stepper("Break: \(prefs.restDurationMinutes) min", value: $prefs.restDurationMinutes, in: 5...30, step: 5)
                } footer: {
                    Text("Take a \(prefs.restDurationMinutes)-minute break every \(prefs.workIntervalMinutes) minutes.")
                }
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
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Buffer")
                        Spacer()
                        Text("\(prefs.deadlineBufferPercent)%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(prefs.accentColor)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(prefs.deadlineBufferPercent) },
                            set: { prefs.deadlineBufferPercent = Int($0) }
                        ),
                        in: 0...50,
                        step: 5
                    )
                    .tint(prefs.accentColor)
                }
                .padding(.vertical, 8)
            } footer: {
                Text("Reserve \(prefs.deadlineBufferPercent)% of days before deadlines for unexpected issues.")
            }
        }
        .navigationTitle("Deadline Buffer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Accent Color View

private struct AccentColorView: View {
    @Bindable private var prefs = UserPreferences.shared

    var body: some View {
        List {
            Section {
                ForEach(AccentColorOption.allCases) { option in
                    Button {
                        prefs.accentColorOption = option
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(option.color)
                                .frame(width: 24, height: 24)

                            Text(option.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if prefs.accentColorOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(prefs.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
        .tint(prefs.accentColor)
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
        List {
            if hasExistingKey {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                        Spacer()
                    }

                    Button("Remove API Key", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            } else {
                Section {
                    HStack {
                        if showAPIKey {
                            TextField("sk-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Save Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                } footer: {
                    Text("Your API key is stored securely in the Keychain.")
                }
            }

            Section {
                Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                    HStack {
                        Text("Get API Key")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Link(destination: URL(string: "https://platform.openai.com/usage")!) {
                    HStack {
                        Text("View Usage")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
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
