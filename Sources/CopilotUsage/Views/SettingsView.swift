import CopilotUsageCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: UsageModel

    @State private var tokenField = ""
    @State private var isSaving = false
    @State private var status: (text: String, isError: Bool)?
    @State private var confirmClearHistory = false

    var body: some View {
        Form {
            Section("Menu bar") {
                Picker("Shows", selection: $model.settings.menuBarMode) {
                    ForEach(MenuBarMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            Section {
                TextField("Monthly limit", value: $model.settings.monthlyLimitOverride, format: .number, prompt: Text("From GitHub"))
            } footer: {
                Text("Only needed if GitHub does not report the right limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                SecureField("Token", text: $tokenField, prompt: Text(model.hasToken ? "Paste a new token to replace the saved one" : "Paste your GitHub token here"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .textContentType(.password)
                HStack {
                    Button("Save Token") { Task { await saveToken() } }
                        .disabled(isSaving || tokenField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove Token", role: .destructive) {
                        model.removeToken()
                        status = ("Token removed", false)
                    }
                    .disabled(!model.hasToken)
                    if isSaving { ProgressView().controlSize(.small) }
                }
                if let status {
                    Text(status.text)
                        .font(.caption)
                        .foregroundStyle(status.isError ? .red : .secondary)
                }
            } header: {
                Text("GitHub token")
            } footer: {
                Text("A personal access token (classic) without scopes. It is checked against GitHub and stored in your login keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Clear History…", role: .destructive) { confirmClearHistory = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Delete all recorded usage history?", isPresented: $confirmClearHistory) {
            Button("Clear History", role: .destructive) { model.clearHistory() }
        }
    }

    private func saveToken() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await model.setToken(tokenField)
            tokenField = ""
            status = ("Token saved", false)
        } catch {
            status = (error.message, true)
        }
    }
}
