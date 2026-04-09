import Foundation
import Security

nonisolated final class KeychainService: Sendable {
    static let shared = KeychainService()
    private let serviceIdentifier = "com.fastfillbrowser.credentials"

    private init() {}

    func savePassword(_ password: String, for credentialID: String) -> Bool {
        deletePassword(for: credentialID)

        guard let data = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: credentialID,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getPassword(for credentialID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: credentialID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func batchGetPasswords(for credentialIDs: [String]) -> [String: String] {
        var results: [String: String] = [:]
        for id in credentialIDs {
            if let password = getPassword(for: id) {
                results[id] = password
            }
        }
        return results
    }

    @discardableResult
    func deletePassword(for credentialID: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: credentialID
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
