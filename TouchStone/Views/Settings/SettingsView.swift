import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var showSaveConfirmation = false
    @State private var showDeleteConfirmation = false

    private var hasExistingKey: Bool {
        APIKeyManager.shared.hasAPIKey
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI API Key")
                            .font(.headline)

                        Text("Required for AI-powered strategic planning. Your key is stored securely in the device Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if hasExistingKey {
                            existingKeyView
                        } else {
                            newKeyInputView
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("AI Integration")
                }

                Section {
                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Label("Get an API Key", systemImage: "key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Link(destination: URL(string: "https://platform.openai.com/usage")!) {
                        HStack {
                            Label("Check Usage", systemImage: "chart.bar")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("OpenAI Resources")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("API Key Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your OpenAI API key has been securely saved.")
            }
            .alert("Delete API Key?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAPIKey()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove your API key. You'll need to enter it again to use AI features.")
            }
        }
    }

    // MARK: - Existing Key View

    private var existingKeyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("API Key configured")
                    .foregroundStyle(.green)
            }
            .font(.subheadline)

            HStack(spacing: 12) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Text("Remove Key")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    // Switch to edit mode
                    apiKey = ""
                } label: {
                    Text("Update Key")
                        .font(.subheadline)
                }
            }

            if !apiKey.isEmpty {
                newKeyInputView
            }
        }
    }

    // MARK: - New Key Input View

    private var newKeyInputView: some View {
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
                Text("Save Key")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(apiKey.isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(apiKey.isEmpty)
        }
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
