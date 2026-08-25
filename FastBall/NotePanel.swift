import AppKit
import SwiftUI

/// The Electron BrowserWindow: 400x500, frameless, always-on-top, hidden from the
/// Dock, hides when it loses focus, re-centered on the display holding the cursor
/// every time it is shown.
final class NotePanel: NSPanel, NSWindowDelegate {
    /// Guards the blur-hide while an NSOpenPanel is up, like the old isDialogOpen flag.
    var isDialogOpen = false

    private static let size = NSSize(width: 400, height: 500)

    init(rootView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false          // handled in windowDidResignKey, so the guard applies
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        delegate = self

        let host = NSHostingView(rootView: rootView)
        host.frame = NSRect(origin: .zero, size: Self.size)
        contentView = host
    }

    /// Borderless windows refuse key status by default; the whole app is keyboard-driven.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func toggle(onShow: () -> Void) {
        if isVisible {
            orderOut(nil)
        } else {
            onShow()
            centerOnActiveDisplay()
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        orderOut(nil)
    }

    /// Ports centerWindowOnActiveDisplay(): follow the mouse, not the main screen.
    func centerOnActiveDisplay() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        setFrameOrigin(NSPoint(
            x: frame.origin.x + (frame.width - Self.size.width) / 2,
            y: frame.origin.y + (frame.height - Self.size.height) / 2
        ))
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isDialogOpen else { return }
        hide()
    }
}
