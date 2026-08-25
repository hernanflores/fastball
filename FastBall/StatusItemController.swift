import AppKit

/// The menu bar entry. Left-click toggles the panel, right-click opens the menu
/// that the Electron Tray built in updateTrayContextMenu().
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggle: () -> Void
    private let onSettings: () -> Void
    private let onOpenFolder: () -> Void

    init(onToggle: @escaping () -> Void,
         onSettings: @escaping () -> Void,
         onOpenFolder: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onSettings = onSettings
        self.onOpenFolder = onOpenFolder
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.title = "✎"
            button.toolTip = "FastBall"
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu()
        } else {
            onToggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Notes Folder", action: #selector(openFolder), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FastBall", action: #selector(quit), keyEquivalent: "q")
            .target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // restore click-to-toggle
    }

    @objc private func openFolder() { onOpenFolder() }
    @objc private func openSettings() { onSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
