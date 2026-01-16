import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var showSaveConfirmation = false
    @State private var showDeleteConfirmation = false

    @State private var prefs = UserPreferences.shared

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Schedule Section
                Section {
                    HStack {
                        Label("Start", systemImage: "sunrise")
                        Spacer()
                        Picker("", selection: $prefs.workDayStartHour) {
                            ForEach(5...12, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Label("End", systemImage: "sunset")
                        Spacer()
                        Picker("", selection: $prefs.workDayEndHour) {
                            ForEach(17...23, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    NavigationLink {
                        RulesListView()
                    } label: {
                        Label("Time Blocks", systemImage: "clock.badge.checkmark")
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Working hours and blocked time slots.")
                }

                // MARK: - Focus Sessions Section
                Section {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                        Spacer()
                        Stepper("\(prefs.dailyProductiveHours) hrs",
                                value: $prefs.dailyProductiveHours,
                                in: 1...12)
                        .fixedSize()
                    }

                    HStack {
                        Label("Min Session", systemImage: "hourglass.bottomhalf.filled")
                        Spacer()
                        Stepper("\(prefs.sessionMinMinutes) min",
                                value: $prefs.sessionMinMinutes,
                                in: 30...60,
                                step: 15)
                        .fixedSize()
                    }

                    HStack {
                        Label("Max Session", systemImage: "hourglass.tophalf.filled")
                        Spacer()
                        Stepper("\(prefs.sessionMaxMinutes) min",
                                value: $prefs.sessionMaxMinutes,
                                in: 60...120,
                                step: 15)
                        .fixedSize()
                    }
                } header: {
                    Text("Focus Sessions")
                } footer: {
                    Text("Daily target and preferred session lengths.")
                }

                // MARK: - Rest & Recovery Section
                Section {
                    Toggle(isOn: $prefs.restBetweenSessionsEnabled) {
                        Label("Enable Breaks", systemImage: "leaf")
                    }

                    if prefs.restBetweenSessionsEnabled {
                        HStack {
                            Label("Work Interval", systemImage: "timer")
                            Spacer()
                            Stepper("\(prefs.workIntervalMinutes) min",
                                    value: $prefs.workIntervalMinutes,
                                    in: 30...120,
                                    step: 15)
                            .fixedSize()
                        }

                        HStack {
                            Label("Break Duration", systemImage: "cup.and.saucer")
                            Spacer()
                            Stepper("\(prefs.restDurationMinutes) min",
                                    value: $prefs.restDurationMinutes,
                                    in: 5...30,
                                    step: 5)
                            .fixedSize()
                        }
                    }
                } header: {
                    Text("Rest & Recovery")
                } footer: {
                    if prefs.restBetweenSessionsEnabled {
                        Text("\(prefs.restDurationMinutes)-min break after \(prefs.workIntervalMinutes) min of work.")
                    } else {
                        Text("Schedule breaks between focus sessions.")
                    }
                }

                // MARK: - AI Assistant Section
                Section {
                    if hasExistingKey {
                        HStack {
                            Label("Status", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("Connected")
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Remove API Key", systemImage: "trash")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if showAPIKey {
                                    TextField("sk-...", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("sk-...", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
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

                            Button {
                                saveAPIKey()
                            } label: {
                                Text("Save API Key")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.isEmpty)
                        }
                    }

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Label("Get API Key", systemImage: "key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Link(destination: URL(string: "https://platform.openai.com/usage")!) {
                        HStack {
                            Label("View Usage", systemImage: "chart.pie")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("AI Assistant")
                } footer: {
                    Text("OpenAI powers strategic planning. Key stored in Keychain.")
                }

                // MARK: - Appearance Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Accent Color", systemImage: "paintpalette")

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(AccentColorOption.allCases) { option in
                                Button {
                                    prefs.accentColorOption = option
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if prefs.accentColorOption == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .shadow(color: option.color.opacity(0.3), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose your preferred accent color for the app.")
                }

                // MARK: - Preferences Section
                Section {
                    Picker(selection: $prefs.appLanguage) {
                        Text("System").tag("system")
                        Text("English").tag("en")
                        Text("Chinese").tag("zh")
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Language support coming soon.")
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .tint(prefs.accentColor)
            .alert("API Key Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your OpenAI API key has been securely saved.")
            }
            .alert("Remove API Key?", isPresented: $showDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    deleteAPIKey()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to enter the key again to use AI features.")
            }
        }
    }

    // MARK: - Helper Functions

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    // MARK: - Actions

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
