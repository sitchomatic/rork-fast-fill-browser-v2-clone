import Foundation
import SwiftData
import UniformTypeIdentifiers

nonisolated struct ImportedCredential: Sendable {
    let domain: String
    let username: String
    let password: String
    let notes: String?
}

nonisolated enum ImportFormat: String, CaseIterable, Sendable {
    case chromeCSV = "Chrome CSV"
    case firefoxCSV = "Firefox CSV"
    case genericCSV = "Generic CSV"

    var description: String {
        switch self {
        case .chromeCSV: return "Export from Chrome: Settings → Passwords → Export"
        case .firefoxCSV: return "Export from Firefox: Settings → Logins → Export"
        case .genericCSV: return "CSV with columns: url, username, password"
        }
    }
}

struct CredentialImportService {
    static func parseCSV(_ content: String, format: ImportFormat) -> [ImportedCredential] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        var results: [ImportedCredential] = []

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 3 else { continue }

            let (urlField, userField, passField) = fieldIndices(for: format, fields: fields)
            guard let url = urlField, let user = userField, let pass = passField else { continue }
            guard !user.isEmpty, !pass.isEmpty else { continue }

            let domain = extractDomain(from: url)
            guard !domain.isEmpty else { continue }

            results.append(ImportedCredential(
                domain: domain,
                username: user,
                password: pass,
                notes: nil
            ))
        }

        return results
    }

    private static func fieldIndices(
        for format: ImportFormat,
        fields: [String]
    ) -> (String?, String?, String?) {
        switch format {
        case .chromeCSV:
            guard fields.count >= 4 else { return (nil, nil, nil) }
            return (fields[1], fields[2], fields[3])
        case .firefoxCSV:
            guard fields.count >= 3 else { return (nil, nil, nil) }
            return (fields[0], fields[1], fields[2])
        case .genericCSV:
            return (fields[0], fields[1], fields[2])
        }
    }

    static func extractDomain(from urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host(percentEncoded: false) {
            return host.lowercased().replacingOccurrences(of: "www.", with: "")
        }
        let cleaned = urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        return cleaned.components(separatedBy: "/").first?.lowercased() ?? ""
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))

        return fields
    }
}
