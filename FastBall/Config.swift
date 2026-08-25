import Foundation

/// User configuration, stored at ~/Library/Application Support/FastBall/config.json.
///
/// Same path and same keys as the Electron build, so an existing install's settings
/// carry over untouched. Like the old `expandPath()`, `~/` is kept literal on disk and
/// expanded only in memory.
struct Config: Codable {
    var notesFolder: String = "~/Notes"
    var globalShortcut: String = "Ctrl+Cmd+,"
    var preferredEditor: String = ""

    var notesFolderURL: URL {
        URL(fileURLWithPath: (notesFolder as NSString).expandingTildeInPath)
    }

    var preferredEditorPath: String? {
        let trimmed = preferredEditor.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (trimmed as NSString).expandingTildeInPath
    }
}

enum ConfigStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FastBall", isDirectory: true)
    }

    static var url: URL { directory.appendingPathComponent("config.json") }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            let fresh = Config()
            try? save(fresh)
            return fresh
        }
        return config
    }

    static func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }
}
