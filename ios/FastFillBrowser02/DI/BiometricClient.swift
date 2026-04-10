import Foundation
import LocalAuthentication

enum BiometricType: Sendable {
    case none
    case touchID
    case faceID
    case opticID

    var displayName: String {
        switch self {
        case .none: return "Biometrics"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
}

struct BiometricClient: Sendable {
    var checkAvailability: @Sendable () async -> BiometricType
    var authenticate: @Sendable (_ reason: String) async throws -> Bool
    var isAvailable: @Sendable () async -> Bool
}

extension BiometricClient {
    static let unimplemented = BiometricClient(
        checkAvailability: { fatalError("BiometricClient.checkAvailability unimplemented") },
        authenticate: { _ in fatalError("BiometricClient.authenticate unimplemented") },
        isAvailable: { fatalError("BiometricClient.isAvailable unimplemented") }
    )

    static let preview = BiometricClient(
        checkAvailability: { .faceID },
        authenticate: { _ in true },
        isAvailable: { true }
    )
}

private enum BiometricClientKey: DependencyKey {
    static let liveValue: BiometricClient = .unimplemented
    static let previewValue: BiometricClient = .preview
}

extension DependencyValues {
    var biometricClient: BiometricClient {
        get { self[BiometricClientKey.self] }
        set { self[BiometricClientKey.self] = newValue }
    }
}
