import Foundation

final class DependencyValues {
    static var current = DependencyValues()
    private var storage: [ObjectIdentifier: Any] = [:]

    subscript<K: DependencyKey>(key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            return K.liveValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    func withValues(_ configure: (inout DependencyValues) -> Void) -> DependencyValues {
        var copy = DependencyValues()
        copy.storage = self.storage
        configure(&copy)
        return copy
    }
}

protocol DependencyKey {
    associatedtype Value: Sendable
    static var liveValue: Value { get }
    static var testValue: Value { get }
    static var previewValue: Value { get }
}

extension DependencyKey {
    static var testValue: Value { liveValue }
    static var previewValue: Value { liveValue }
}

@propertyWrapper
struct Dependency<Value: Sendable>: Sendable {
    private let keyPath: KeyPath<DependencyValues, Value> & Sendable

    init(_ keyPath: KeyPath<DependencyValues, Value> & Sendable) {
        self.keyPath = keyPath
    }

    var wrappedValue: Value {
        DependencyValues.current[keyPath: keyPath]
    }
}
