import SwiftUI

struct CredentialPickerSheet: View {
    let viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.matchingCredentials.isEmpty {
                    ContentUnavailableView(
                        "No Credentials",
                        systemImage: "key.slash",
                        description: Text("No saved credentials for \(viewModel.activeTab?.domain ?? "this site")")
                    )
                } else {
                    List(viewModel.matchingCredentials) { credential in
                        Button {
                            viewModel.fillCredential(credential)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.cyan)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(credential.username)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(credential.domain)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let lastUsed = credential.lastUsedAt {
                                    Text(lastUsed, format: .relative(presentation: .named))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Credential")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
