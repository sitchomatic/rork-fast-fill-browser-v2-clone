import Foundation

struct KeychainClient: Sendable {
    var savePassword: @Sendable (_ password: String, _ credentialID: String) async throws -> Void
    var getPassword: @Sendable (_ credentialID: String) async throws -> String?
    var batchGetPasswords: @Sendable (_ credentialIDs: [String]) async throws -> [String: String]
    var deletePassword: @Sendable (_ credentialID: String) async throws -> Void
}

extension KeychainClient {
    static let unimplemented = KeychainClient(
        savePassword: { _, _ in fatalError("KeychainClient.savePassword unimplemented") },
        getPassword: { _ in fatalError("KeychainClient.getPassword unimplemented") },
        batchGetPasswords: { _ in fatalError("KeychainClient.batchGetPasswords unimplemented") },
        deletePassword: { _ in fatalError("KeychainClient.deletePassword unimplemented") }
    )

    static let preview = KeychainClient(
        savePassword: { _, _ in },
        getPassword: { _ in nil },
        batchGetPasswords: { _ in [:] },
        deletePassword: { _ in }
    )
}

private enum KeychainClientKey: DependencyKey {
    static let liveValue: KeychainClient = .unimplemented
    static let previewValue: KeychainClient = .preview
}

extension DependencyValues {
    var keychainClient: KeychainClient {
        get { self[KeychainClientKey.self] }
        set { self[KeychainClientKey.self] = newValue }
    }
}
