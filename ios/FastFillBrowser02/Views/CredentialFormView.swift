import SwiftUI
import SwiftData

struct CredentialFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var domain: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var notes: String = ""
    @State private var isShowingGenerator: Bool = false

    var body: some View {
        Form {
            Section("Website") {
                TextField("Domain (e.g. google.com)", text: $domain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("Credentials") {
                TextField("Username or Email", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)

                HStack {
                    SecureField("Password", text: $password)
                        .textContentType(.password)

                    Button("Generate", systemImage: "dice") {
                        isShowingGenerator = true
                    }
                    .labelStyle(.iconOnly)
                }
            }

            Section("Notes (Optional)") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Add Credential")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(domain.isEmpty || username.isEmpty || password.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingGenerator) {
            NavigationStack {
                PasswordGeneratorView(onSelect: { generated in
                    password = generated
                })
            }
        }
    }

    private func save() {
        let cleanDomain = CredentialImportService.extractDomain(from: domain)
        let credential = Credential(
            domain: cleanDomain.isEmpty ? domain.lowercased() : cleanDomain,
            username: username,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(credential)
        _ = KeychainService.shared.savePassword(password, for: credential.id)
        dismiss()
    }
}
