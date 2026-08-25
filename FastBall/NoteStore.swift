import Foundation

struct Note: Identifiable, Hashable {
    var name: String        // basename without the .md extension
    var preview: String     // first line of the file
    var url: URL
    var mtime: Date

    var id: String { url.path }
}

/// Replaces the get-notes / get-note-content / save-note / clear-note IPC handlers.
final class NoteStore {
    private let folder: URL

    init(folder: URL) {
        self.folder = folder
        ensureFolder()
    }

    func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Markdown files in the notes folder, most recently modified first.
    func loadNotes() -> [Note] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .map { url in
                let mtime = (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
                return Note(
                    name: url.deletingPathExtension().lastPathComponent,
                    preview: Self.firstLine(of: url),
                    url: url,
                    mtime: mtime
                )
            }
            .sorted { $0.mtime > $1.mtime }
    }

    func content(of note: Note) -> String {
        (try? String(contentsOf: note.url, encoding: .utf8)) ?? ""
    }

    func save(content: String, to note: Note) {
        try? content.write(to: note.url, atomically: true, encoding: .utf8)
    }

    /// Truncates the file in place, matching the old `clear-note` handler.
    func clear(_ note: Note) {
        try? "".write(to: note.url, atomically: true, encoding: .utf8)
    }

    /// Creates a note named YYYY-MM-DD-HHmmss.md in local time.
    /// Whitespace-only content is discarded silently, as in the Electron build.
    @discardableResult
    func create(content: String) -> Note? {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        ensureFolder()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Two captures inside the same second would otherwise land on the same
        // filename and the second would silently overwrite the first.
        let stamp = formatter.string(from: Date())
        var name = stamp
        var url = folder.appendingPathComponent("\(name).md")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            name = "\(stamp)-\(suffix)"
            url = folder.appendingPathComponent("\(name).md")
            suffix += 1
        }

        try? content.write(to: url, atomically: true, encoding: .utf8)
        return Note(name: name, preview: Self.firstLine(of: url), url: url, mtime: Date())
    }

    /// Reads only the head of the file — the Electron version read every note in full
    /// just to show one line.
    private static func firstLine(of url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096), !data.isEmpty else { return "" }
        let head = String(decoding: data, as: UTF8.self)
        return head.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}
