import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Credential.domain) private var credentials: [Credential]
    @State private var viewModel = VaultViewModel()

    private var filteredCredentials: [Credential] {
        guard !viewModel.searchText.isEmpty else { return credentials }
        let search = viewModel.searchText.lowercased()
        return credentials.filter {
            $0.domain.localizedStandardContains(search) ||
            $0.username.localizedStandardContains(search)
        }
    }

    private var groupedCredentials: [(String, [Credential])] {
        let grouped = Dictionary(grouping: filteredCredentials) { $0.domain }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            ForEach(groupedCredentials, id: \.0) { domain, creds in
                Section(domain) {
                    ForEach(creds) { credential in
                        Button {
                            viewModel.selectedCredential = credential
                        } label: {
                            credentialRow(credential)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteCredential(credential, context: modelContext)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if credentials.isEmpty {
                ContentUnavailableView(
                    "No Saved Credentials",
                    systemImage: "lock.shield",
                    description: Text("Add credentials manually or import from another browser")
                )
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search credentials")
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add Credential", systemImage: "plus") {
                        viewModel.isShowingAddCredential = true
                    }
                    Button("Import", systemImage: "square.and.arrow.down") {
                        viewModel.isShowingImport = true
                    }
                    Button("Password Generator", systemImage: "dice") {
                        viewModel.isShowingPasswordGenerator = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddCredential) {
            NavigationStack {
                CredentialFormView()
            }
        }
        .sheet(item: $viewModel.selectedCredential) { credential in
            NavigationStack {
                CredentialDetailView(credential: credential)
            }
        }
        .sheet(isPresented: $viewModel.isShowingImport) {
            NavigationStack {
                ImportCredentialsView()
            }
        }
        .sheet(isPresented: $viewModel.isShowingPasswordGenerator) {
            NavigationStack {
                PasswordGeneratorView()
            }
        }
    }

    private func credentialRow(_ credential: Credential) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.linearGradient(
                        colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)

                Text(String(credential.username.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.username)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if credential.usageCount > 0 {
                        Text("Used \(credential.usageCount)×")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let notes = credential.notes, !notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }
}
