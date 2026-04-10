import SwiftUI
import SwiftData

struct CredentialDetailView: View {
    let credential: Credential
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isPasswordVisible: Bool = false
    @State private var password: String = ""
    @State private var isEditing: Bool = false
    @State private var editUsername: String = ""
    @State private var editPassword: String = ""
    @State private var editNotes: String = ""
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Domain", value: credential.domain)

                if isEditing {
                    TextField("Username", text: $editUsername)
                } else {
                    HStack {
                        LabeledContent("Username", value: credential.username)
                        Spacer()
                        Button("Copy", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = credential.username
                        }
                        .labelStyle(.iconOnly)
                        .font(.caption)
                    }
                }
            }

            Section("Password") {
                if isEditing {
                    SecureField("Password", text: $editPassword)
                } else {
                    HStack {
                        if isPasswordVisible {
                            Text(password)
                                .font(.body.monospaced())
                        } else {
                            Text("••••••••••")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.caption)
                        }

                        Button("Copy", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = password
                        }
                        .labelStyle(.iconOnly)
                        .font(.caption)
                    }
                }
            }

            Section("Notes") {
                if isEditing {
                    TextField("Notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    if let notes = credential.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                    } else {
                        Text("No notes")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Info") {
                LabeledContent("Created", value: credential.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: credential.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let lastUsed = credential.lastUsedAt {
                    LabeledContent("Last Used", value: lastUsed.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Times Used", value: "\(credential.usageCount)")
            }

            if !isEditing {
                Section {
                    Button("Delete Credential", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(credential.displayDomain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isEditing ? "Cancel" : "Done") {
                    if isEditing {
                        isEditing = false
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
        }
        .task {
            password = KeychainService.shared.getPassword(for: credential.id) ?? ""
        }
        .confirmationDialog("Delete Credential?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                KeychainService.shared.deletePassword(for: credential.id)
                modelContext.delete(credential)
                dismiss()
            }
        } message: {
            Text("This will permanently delete the credential for \(credential.username)")
        }
    }

    private func startEditing() {
        editUsername = credential.username
        editPassword = password
        editNotes = credential.notes ?? ""
        isEditing = true
    }

    private func saveChanges() {
        credential.username = editUsername
        credential.notes = editNotes.isEmpty ? nil : editNotes
        credential.updatedAt = Date()
        if editPassword != password {
            _ = KeychainService.shared.savePassword(editPassword, for: credential.id)
            password = editPassword
        }
        isEditing = false
    }
}
