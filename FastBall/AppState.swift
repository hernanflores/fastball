import AppKit
import Combine
import ServiceManagement

enum Route: Equatable {
    case list
    case editor
    case capture
    case settings
}

/// The four module-level variables the old renderer.js carried around
/// (currentView, notes, selectedIndex, currentNote, pendingChar), with the
/// view-switching logic that `showView()` used to perform.
final class AppState: ObservableObject {
    @Published var route: Route = .list
    @Published var notes: [Note] = []
    @Published var selectedIndex: Int = 0
    @Published var currentNote: Note?
    @Published var pendingText: String = ""
    @Published var editorText: String = ""
    @Published var settingsError: String?

    @Published private(set) var config: Config
    private(set) var store: NoteStore

    /// Wired up by the AppDelegate.
    var hideWindow: () -> Void = {}
    var applyShortcut: (String) -> Bool = { _ in true }
    var onNotesFolderChange: () -> Void = {}
    /// Suppresses the panel's hide-on-blur while an NSOpenPanel is up.
    var setDialogOpen: (Bool) -> Void = { _ in }

    init() {
        let loaded = ConfigStore.load()
        config = loaded
        store = NoteStore(folder: loaded.notesFolderURL)
    }

    // MARK: - Navigation

    /// Matches the `reset-to-list` message the main process sent on every window show.
    func resetToList() {
        route = .list
        currentNote = nil
        pendingText = ""
        settingsError = nil
        refreshNotes()
    }

    func refreshNotes() {
        notes = store.loadNotes()
        selectedIndex = min(selectedIndex, max(notes.count - 1, 0))
    }

    func moveSelection(by delta: Int) {
        guard !notes.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), notes.count - 1)
    }

    func openSelected() {
        guard notes.indices.contains(selectedIndex) else { return }
        open(notes[selectedIndex])
    }

    func open(_ note: Note) {
        currentNote = note
        editorText = store.content(of: note)
        route = .editor
    }

    /// Type-to-capture: any printable key in the list view lands here.
    func beginCapture(with text: String) {
        pendingText = text
        route = .capture
    }

    func showSettings() {
        settingsError = nil
        route = .settings
    }

    // MARK: - Note actions

    func saveEditor() {
        guard let note = currentNote else { return }
        store.save(content: editorText, to: note)
    }

    func clearCurrentNote() {
        guard let note = currentNote else { return }
        store.clear(note)
        editorText = ""
    }

    func saveCapture(_ text: String) {
        store.create(content: text)
        refreshNotes()
    }

    func openCurrentNoteInEditor() {
        guard let note = currentNote else { return }
        openExternally(note.url)
    }

    func openNotesFolder() {
        NSWorkspace.shared.open(config.notesFolderURL)
    }

    /// Replaces the `open-in-editor` handler: an .app bundle goes through
    /// NSWorkspace, a CLI binary through Process, and an unset editor falls
    /// back to whatever macOS associates with .md.
    private func openExternally(_ url: URL) {
        guard let editor = config.preferredEditorPath else {
            NSWorkspace.shared.open(url)
            return
        }
        let editorURL = URL(fileURLWithPath: editor)
        if editorURL.pathExtension == "app" {
            NSWorkspace.shared.open([url], withApplicationAt: editorURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            let process = Process()
            process.executableURL = editorURL
            process.arguments = [url.path]
            try? process.run()
        }
    }

    // MARK: - Login item

    /// Something the Electron build never had — users had to add FastBall to
    /// Login Items by hand.
    var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settingsError = nil
        } catch {
            settingsError = "Could not update login item: \(error.localizedDescription)"
        }
        objectWillChange.send()
    }

    // MARK: - Settings

    /// Mirrors save-config: validate and register the shortcut first, roll back on
    /// failure, and only then persist and re-point the note store.
    func saveConfig(notesFolder: String, globalShortcut: String, preferredEditor: String) -> Bool {
        let shortcut = globalShortcut.trimmingCharacters(in: .whitespaces)
        guard !shortcut.isEmpty else {
            settingsError = "Global shortcut cannot be empty"
            return false
        }
        guard applyShortcut(shortcut) else {
            settingsError = "Could not register \(shortcut) — it may be in use by another app"
            return false
        }

        var updated = config
        updated.notesFolder = notesFolder.trimmingCharacters(in: .whitespaces)
        updated.globalShortcut = shortcut
        updated.preferredEditor = preferredEditor.trimmingCharacters(in: .whitespaces)

        do {
            try ConfigStore.save(updated)
        } catch {
            _ = applyShortcut(config.globalShortcut)   // roll back
            settingsError = "Could not write config: \(error.localizedDescription)"
            return false
        }

        let folderChanged = updated.notesFolder != config.notesFolder
        config = updated
        if folderChanged {
            store = NoteStore(folder: updated.notesFolderURL)
        } else {
            store.ensureFolder()
        }
        onNotesFolderChange()
        settingsError = nil
        resetToList()
        return true
    }
}
