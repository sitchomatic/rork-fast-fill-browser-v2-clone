import Foundation

struct URLAliasProfile: Identifiable {
    let id = UUID()
    let name: String
    let aliases: [URLAlias]
}

struct URLAlias: Identifiable {
    let id = UUID()
    let shortcut: String
    let url: String
}

struct URLAliasService {
    static let profiles: [URLAliasProfile] = [
        URLAliasProfile(
            name: "Joe Fortune",
            aliases: [
                URLAlias(shortcut: "joep.win", url: "https://Joefortunepokies.win/login"),
                URLAlias(shortcut: "joe.club", url: "https://joefortune.club/login"),
                URLAlias(shortcut: "joe.eu.com", url: "https://joefortune.eu.com/login"),
                URLAlias(shortcut: "joe.lv", url: "https://joefortune.lv/login"),
                URLAlias(shortcut: "joe.ooo", url: "https://joefortune.ooo/login"),
                URLAlias(shortcut: "joeop.eu", url: "https://joefortuneonlinepokies.eu/login"),
                URLAlias(shortcut: "joeop.net", url: "https://joefortuneonlinepokies.net/login"),
                URLAlias(shortcut: "joep.eu", url: "https://joefortunepokies.eu/login"),
                URLAlias(shortcut: "joep.net", url: "https://joefortunepokies.net/login"),
            ]
        ),
        URLAliasProfile(
            name: "Ignition Casino",
            aliases: [
                URLAlias(shortcut: "ign.ooo", url: "https://ignitioncasino.ooo/login?overlay=login"),
                URLAlias(shortcut: "ign.lat", url: "https://ignitioncasino.lat/login?overlay=login"),
                URLAlias(shortcut: "ign.cool", url: "https://ignitioncasino.cool/login?overlay=login"),
                URLAlias(shortcut: "ign.buzz", url: "https://ignitioncasino.buzz/login?overlay=login"),
                URLAlias(shortcut: "ignp.eu", url: "https://ignitionpoker.eu/login?overlay=login"),
                URLAlias(shortcut: "ign.org.lv", url: "https://ignitioncasino.org.lv/login?overlay=login"),
                URLAlias(shortcut: "ign.ltd", url: "https://ignitioncasino.ltd/login?overlay=login"),
                URLAlias(shortcut: "ign.lv", url: "https://ignitioncasino.lv/login?overlay=login"),
                URLAlias(shortcut: "ign.eu", url: "https://ignitioncasino.eu/login?overlay=login"),
                URLAlias(shortcut: "ign.eu.com", url: "https://ignitioncasino.eu.com/login?overlay=login"),
            ]
        ),
    ]

    static var allAliases: [URLAlias] {
        profiles.flatMap { $0.aliases }
    }

    static func resolveAlias(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allAliases.first { $0.shortcut.lowercased() == trimmed }?.url
    }

    static func matchingAliases(for query: String) -> [URLAlias] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return allAliases.filter {
            $0.shortcut.lowercased().contains(lowered) ||
            $0.url.lowercased().contains(lowered)
        }
    }
}
