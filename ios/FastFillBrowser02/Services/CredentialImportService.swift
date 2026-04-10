import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ImportedCredential: Sendable {
    let domain: String
    let username: String
    let password: String
    let notes: String?
}

enum ImportFormat: String, CaseIterable, Sendable {
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
        let records = parseCSVRecords(content)
        guard records.count > 1 else { return [] }

        var results: [ImportedCredential] = []

        for record in records.dropFirst() {
            let fields = parseCSVLine(record)
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

    private static func parseCSVRecords(_ content: String) -> [String] {
        var records: [String] = []
        var currentRecord = ""
        var isInsideQuotes = false
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]

            if character == "\"" {
                let nextIndex = content.index(after: index)
                // RFC 4180: two consecutive quotes inside a quoted field represent a single literal quote
                if isInsideQuotes, nextIndex < content.endIndex, content[nextIndex] == "\"" {
                    currentRecord.append(character)
                    currentRecord.append(content[nextIndex])
                    index = content.index(after: nextIndex)
                    continue
                }

                isInsideQuotes.toggle()
                currentRecord.append(character)
                index = nextIndex
                continue
            }

            if !isInsideQuotes, character == "\n" || character == "\r" {
                if !currentRecord.isEmpty {
                    records.append(currentRecord)
                    currentRecord = ""
                }

                if character == "\r" {
                    let nextIndex = content.index(after: index)
                    if nextIndex < content.endIndex, content[nextIndex] == "\n" {
                        index = content.index(after: nextIndex)
                        continue
                    }
                }

                index = content.index(after: index)
                continue
            }

            currentRecord.append(character)
            index = content.index(after: index)
        }

        if !currentRecord.isEmpty {
            records.append(currentRecord)
        }

        return records
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

        var iterator = line.makeIterator()
        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes {
                    // Check for doubled quote (escaped quote inside quoted field)
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else if next == "," {
                            fields.append(current.trimmingCharacters(in: .whitespaces))
                            current = ""
                            inQuotes = false
                        } else {
                            current.append(next)
                            inQuotes = false
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
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
