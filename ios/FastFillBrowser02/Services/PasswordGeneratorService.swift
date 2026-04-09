import Foundation
import Security

struct PasswordGeneratorService {
    static func generate(
        length: Int = 20,
        includeUppercase: Bool = true,
        includeLowercase: Bool = true,
        includeNumbers: Bool = true,
        includeSymbols: Bool = true
    ) -> String {
        var chars = ""
        if includeUppercase { chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if includeLowercase { chars += "abcdefghijklmnopqrstuvwxyz" }
        if includeNumbers { chars += "0123456789" }
        if includeSymbols { chars += "!@#$%^&*()-_=+[]{}|;:,.<>?" }

        guard !chars.isEmpty else { return "" }

        let charArray = Array(chars)
        var password = ""

        for _ in 0..<length {
            let index = randomIndex(upperBound: charArray.count)
            password.append(charArray[index])
        }

        return password
    }

    private static func randomIndex(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }

        if upperBound <= 256 {
            // Rejection sampling: discard values >= floor(256/upperBound)*upperBound
            // to eliminate modulo bias from non-uniform byte distribution.
            let acceptableUpperBound = (256 / upperBound) * upperBound
            var randomByte: UInt8 = 0

            while true {
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
                if status != errSecSuccess {
                    break
                }

                let value = Int(randomByte)
                if value < acceptableUpperBound {
                    return value % upperBound
                }
            }
        }

        var generator = SystemRandomNumberGenerator()
        return Int(generator.next(upperBound: UInt64(upperBound)))
    }

    static func calculateStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        if length == 0 { return .empty }
        if length < 8 { return .weak }

        var score = 0
        if length >= 12 { score += 1 }
        if length >= 16 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        if score <= 2 { return .weak }
        if score <= 4 { return .medium }
        return .strong
    }
}

enum PasswordStrength: String {
    case empty = ""
    case weak = "Weak"
    case medium = "Medium"
    case strong = "Strong"

    var color: String {
        switch self {
        case .empty: return "secondary"
        case .weak: return "red"
        case .medium: return "orange"
        case .strong: return "green"
        }
    }
}
