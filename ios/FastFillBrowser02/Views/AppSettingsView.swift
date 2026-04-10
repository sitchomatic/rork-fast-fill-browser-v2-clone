import SwiftUI

struct AppSettingsView: View {
    let biometricService: BiometricService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("requireBiometricOnLaunch") private var requireBiometric: Bool = true
    @AppStorage("autoFillOnPageLoad") private var autoFillOnLoad: Bool = true
    @AppStorage("offerToSavePasswords") private var offerToSave: Bool = true
    @AppStorage("defaultSearchEngine") private var searchEngine: String = "Google"

    var body: some View {
        Form {
            Section("Security") {
                Toggle("Require \(biometricService.biometricName) on Launch", isOn: $requireBiometric)

                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.cyan)
                    Text("Passwords stored in iOS Keychain")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Auto Fill") {
                Toggle("Auto-fill on Page Load", isOn: $autoFillOnLoad)
                Toggle("Offer to Save New Passwords", isOn: $offerToSave)
            }

            Section("Browser") {
                Picker("Search Engine", selection: $searchEngine) {
                    Text("Google").tag("Google")
                    Text("DuckDuckGo").tag("DuckDuckGo")
                    Text("Bing").tag("Bing")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")

                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(.linearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    VStack(alignment: .leading) {
                        Text("Fast Fill Browser")
                            .font(.headline)
                        Text("The smartest, most forgiving login browser")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }
}
