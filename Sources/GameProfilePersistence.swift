import Foundation

private struct StoredGameProfiles: Codable, Sendable {
    let version: Int
    let profiles: [GameCompatibilityProfile]

    static let currentVersion = 1
}

enum GameProfilePersistence {
    static func loadProfiles(from url: URL, fileManager: FileManager = .default) throws -> [GameCompatibilityProfile] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        let payload = try decoder.decode(StoredGameProfiles.self, from: data)
        return payload.profiles
    }

    static func saveProfiles(
        _ profiles: [GameCompatibilityProfile],
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        let payload = StoredGameProfiles(
            version: StoredGameProfiles.currentVersion,
            profiles: profiles.sorted(by: { $0.appID < $1.appID })
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}

enum GameLaunchOptionsComposer {
    static let beginMarker = "__STEAVIUM_PROFILE_BEGIN__"
    static let endMarker = "__STEAVIUM_PROFILE_END__"

    static func managedSegment(forceWindowed: Bool) -> String? {
        guard forceWindowed else { return nil }
        return "\(beginMarker) -windowed \(endMarker)"
    }

    static func merge(existing: String, managedSegment: String?) -> String {
        let base = stripManagedSegment(from: existing)
        guard let managedSegment, !managedSegment.isEmpty else {
            return base
        }

        if base.isEmpty {
            return managedSegment
        }
        return normalizeWhitespace("\(base) \(managedSegment)")
    }

    static func stripManagedSegment(from value: String) -> String {
        var text = value

        while let start = text.range(of: beginMarker) {
            if let end = text.range(of: endMarker, range: start.upperBound..<text.endIndex) {
                text.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                text.removeSubrange(start.lowerBound..<text.endIndex)
            }
        }

        return normalizeWhitespace(text)
    }

    static func normalizeWhitespace(_ value: String) -> String {
        value
            .split { $0.isWhitespace }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
