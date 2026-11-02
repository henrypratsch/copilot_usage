import Foundation

/// Stores a Codable value as JSON in `~/Library/Application Support/CopilotUsage`.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public init(fileName: String) {
        self.init(url: Self.directory.appending(path: fileName))
    }

    public static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "CopilotUsage", directoryHint: .isDirectory)
    }

    /// The stored value, or nil if the file is missing or unreadable.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    @discardableResult
    public func save(_ value: Value) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}

public typealias HistoryStore = JSONFileStore<History>
public typealias SettingsStore = JSONFileStore<AppSettings>

extension JSONFileStore where Value == History {
    public static var history: HistoryStore { HistoryStore(fileName: "history.json") }
}

extension JSONFileStore where Value == AppSettings {
    public static var settings: SettingsStore { SettingsStore(fileName: "settings.json") }
}
