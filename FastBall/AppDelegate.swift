import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotePanel!
    private var statusItem: StatusItemController!
    private var hotKeys = HotKeyManager()
    private var keyMonitor: Any?
    private let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; this covers `swift run`-style launches.
        NSApp.setActivationPolicy(.accessory)

        panel = NotePanel(rootView: RootView(state: state))

        state.hideWindow = { [weak self] in self?.panel.hide() }
        state.setDialogOpen = { [weak self] open in self?.panel.isDialogOpen = open }
        state.applyShortcut = { [weak self] accelerator in
            self?.registerHotKey(accelerator) ?? false
        }
        state.onNotesFolderChange = { [weak self] in self?.state.refreshNotes() }

        statusItem = StatusItemController(
            onToggle: { [weak self] in self?.toggle() },
            onSettings: { [weak self] in
                guard let self else { return }
                self.show()
                self.state.showSettings()
            },
            onOpenFolder: { [weak self] in self?.state.openNotesFolder() }
        )

        installEditMenu()
        installKeyMonitor()

        if !registerHotKey(state.config.globalShortcut) {
            warnAboutShortcut(state.config.globalShortcut)
        }

        state.resetToList()

        // Handy when the hotkey can't be used (e.g. driving the app from a script).
        if CommandLine.arguments.contains("--show") { show() }

        // Dev helper for grabbing screenshots of a specific view.
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--route=") }) {
            switch arg.dropFirst("--route=".count) {
            case "editor":   state.openSelected()
            case "capture":  state.beginCapture(with: "Ship the landing page\nand cut a release")
            case "settings": state.showSettings()
            default:         break
            }
            try? "\(panel.windowNumber)".write(toFile: "/tmp/fb-window.txt",
                                               atomically: true, encoding: .utf8)
        }

        if CommandLine.arguments.contains("--selftest") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                SelfTest.run(state: self.state, panel: self.panel)
            }
        }

        if CommandLine.arguments.contains("--diag") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self else { return }
                let report = """
                visible=\(self.panel.isVisible) key=\(self.panel.isKeyWindow)                 appActive=\(NSApp.isActive) notes=\(self.state.notes.count)                 firstResponder=\(String(describing: self.panel.firstResponder))
                """
                try? report.write(toFile: "/tmp/fb-diag.txt", atomically: true, encoding: .utf8)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregister()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    // MARK: - Window

    private func toggle() {
        panel.toggle(onShow: { [weak self] in self?.state.resetToList() })
    }

    private func show() {
        if !panel.isVisible {
            state.resetToList()
            panel.centerOnActiveDisplay()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Hotkey

    @discardableResult
    private func registerHotKey(_ accelerator: String) -> Bool {
        hotKeys.register(accelerator) { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
    }

    private func warnAboutShortcut(_ accelerator: String) {
        let alert = NSAlert()
        alert.messageText = "FastBall could not register \(accelerator)"
        alert.informativeText = """
        Another app is probably already using that combination. \
        Pick a different one from the menu bar icon → Settings.
        """
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        let handler = KeyHandler(state: state, hide: { [weak self] in self?.panel.hide() })
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return handler.handle(event)
        }
    }

    /// An LSUIElement app has no menu bar, so the standard editing shortcuts inside
    /// the text views aren't wired up for free the way they were in a WebContents.
    private func installEditMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit FastBall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
