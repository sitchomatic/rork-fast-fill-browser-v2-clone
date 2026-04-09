import SwiftUI
import SwiftData

@Observable
@MainActor
class VaultViewModel {
    var searchText: String = ""
    var isShowingAddCredential: Bool = false
    var isShowingImport: Bool = false
    var isShowingPasswordGenerator: Bool = false
    var selectedCredential: Credential?

    func deleteCredential(_ credential: Credential, context: ModelContext) {
        KeychainService.shared.deletePassword(for: credential.id)
        context.delete(credential)
    }

    func importCredentials(_ imported: [ImportedCredential], context: ModelContext) -> Int {
        var count = 0
        for item in imported {
            let credential = Credential(
                domain: item.domain,
                username: item.username,
                notes: item.notes
            )
            context.insert(credential)
            if KeychainService.shared.savePassword(item.password, for: credential.id) {
                count += 1
            }
        }
        return count
    }
}
