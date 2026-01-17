import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var showSaveConfirmation = false
    @State private var showDeleteConfirmation = false

    @Bindable private var prefs = UserPreferences.shared

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Schedule
                Section("Schedule") {
                    HStack {
                        Text("Working Hours")
                        Spacer()
                        Text("\(formatHour(prefs.workDayStartHour)) – \(formatHour(prefs.workDayEndHour))")
                            .foregroundStyle(.secondary)
                    }
                    .background {
                        NavigationLink("", destination: WorkingHoursView())
                            .opacity(0)
                    }

                    NavigationLink {
                        RulesListView()
                    } label: {
                        Text("Time Blocks")
                    }
                }

                // MARK: - Focus
                Section("Focus") {
                    Stepper("Daily Goal: \(prefs.dailyProductiveHours) hrs",
                            value: $prefs.dailyProductiveHours,
                            in: 1...12)

                    Stepper("Session: \(prefs.sessionMinMinutes)–\(prefs.sessionMaxMinutes) min",
                            value: $prefs.sessionMaxMinutes,
                            in: 60...120,
                            step: 15)

                    HStack {
                        Text("Deadline Buffer")
                        Spacer()
                        Text("\(prefs.deadlineBufferPercent)%")
                            .foregroundStyle(.secondary)
                    }
                    .background {
                        NavigationLink("", destination: DeadlineBufferView())
                            .opacity(0)
                    }
                }

                // MARK: - Breaks
                Section {
                    Toggle("Breaks", isOn: $prefs.restBetweenSessionsEnabled)

                    if prefs.restBetweenSessionsEnabled {
                        Stepper("\(prefs.restDurationMinutes) min every \(prefs.workIntervalMinutes) min",
                                value: $prefs.restDurationMinutes,
                                in: 5...30,
                                step: 5)
                    }
                }

                // MARK: - AI
                Section("AI Assistant") {
                    if hasExistingKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                            Spacer()
                            Button("Remove", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                            .font(.subheadline)
                        }
                    } else {
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

                        Button("Save Key") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                    }

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Text("Get API Key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accent Color")
                            .font(.subheadline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(AccentColorOption.allCases) { option in
                                Button {
                                    prefs.accentColorOption = option
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            if prefs.accentColorOption == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/Ying-Kai-Liao/TouchStone")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .tint(prefs.accentColor)
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
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
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

#Preview {
    SettingsView()
}
