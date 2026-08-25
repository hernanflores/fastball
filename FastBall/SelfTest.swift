import AppKit

/// Smoke test for the keyboard routing, run with `FastBall --selftest`.
///
/// The app is entirely keyboard-driven and macOS won't let a script post real key
/// events without Accessibility access, so this feeds synthesized NSEvents straight
/// through KeyHandler instead. Results are written to /tmp/fastball-selftest.txt.
enum SelfTest {
    static func run(state: AppState, panel: NotePanel) {
        var results: [String] = []
        var failures = 0

        func check(_ label: String, _ condition: @autoclosure () -> Bool) {
            let ok = condition()
            if !ok { failures += 1 }
            results.append("\(ok ? "PASS" : "FAIL")  \(label)")
        }

        // Seed fixtures so the test doesn't depend on the user's notes folder.
        var fixtures: [Note] = []
        state.refreshNotes()
        while state.notes.count + fixtures.count < 2 {
            if let note = state.store.create(content: "selftest fixture \(fixtures.count)") {
                fixtures.append(note)
            } else {
                break
            }
        }

        state.refreshNotes()

        var hidden = false
        let handler = KeyHandler(state: state, hide: { hidden = true })

        func press(_ keyCode: UInt16, characters: String = "", flags: NSEvent.ModifierFlags = []) {
            guard let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: keyCode
            ) else { return }
            _ = handler.handle(event)
        }

        state.resetToList()
        check("list view has notes", !state.notes.isEmpty)

        press(125)  // down
        check("down arrow moves selection", state.selectedIndex == 1)
        press(126)  // up
        check("up arrow moves selection back", state.selectedIndex == 0)

        press(4, characters: "h")   // printable
        check("printable key starts capture", state.route == .capture)
        check("capture is seeded with the character", state.pendingText == "h")

        press(53)   // escape
        check("escape leaves capture", state.route == .list)

        press(36)   // return
        check("return opens the editor", state.route == .editor)
        check("editor loaded the note", !state.editorText.isEmpty)

        press(53)
        check("escape leaves the editor", state.route == .list)

        press(43, characters: ",", flags: .command)
        check("cmd+, opens settings", state.route == .settings)
        press(53)
        check("escape leaves settings", state.route == .list)

        let before = state.notes.count
        state.beginCapture(with: "selftest note body")
        press(36, characters: "\r", flags: .command)
        check("cmd+return saved and hid", hidden)
        state.refreshNotes()
        check("a new note was written", state.notes.count == before + 1)

        if let created = state.notes.first(where: { $0.preview == "selftest note body" }) {
            try? FileManager.default.removeItem(at: created.url)
            results.append("cleaned up \(created.url.lastPathComponent)")
        } else {
            failures += 1
            results.append("FAIL  created note not found by preview")
        }

        for fixture in fixtures {
            try? FileManager.default.removeItem(at: fixture.url)
        }

        results.append(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        try? results.joined(separator: "\n")
            .write(toFile: "/tmp/fastball-selftest.txt", atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}
