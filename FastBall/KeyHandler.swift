import AppKit

/// The single global `keydown` listener from renderer.js, as a local event monitor.
///
/// Returning nil swallows the event; returning it lets AppKit deliver it (which is
/// what makes typing and the standard edit-menu shortcuts work inside the text views).
struct KeyHandler {
    private static let keyDown: UInt16 = 125
    private static let keyUp: UInt16 = 126
    private static let keyReturn: UInt16 = 36
    private static let keyEscape: UInt16 = 53

    let state: AppState
    let hide: () -> Void

    func handle(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if command && key == "w" {
            hide()
            return nil
        }

        switch state.route {
        case .list:
            switch event.keyCode {
            case Self.keyDown:   state.moveSelection(by: 1);  return nil
            case Self.keyUp:     state.moveSelection(by: -1); return nil
            case Self.keyReturn: state.openSelected();        return nil
            default: break
            }
            if command && key == "," {
                state.showSettings()
                return nil
            }
            if command && key == "v" {
                if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                    state.beginCapture(with: text)
                }
                return nil
            }
            if let character = printableCharacter(in: event) {
                state.beginCapture(with: character)
                return nil
            }
            return event

        case .editor:
            if event.keyCode == Self.keyEscape {
                state.saveEditor()
                state.resetToList()
                return nil
            }
            if command && key == "o" {
                state.openCurrentNoteInEditor()
                return nil
            }
            if command && shift && key == "c" {
                state.clearCurrentNote()
                return nil
            }
            return event

        case .capture:
            if event.keyCode == Self.keyEscape {
                state.resetToList()
                return nil
            }
            if command && event.keyCode == Self.keyReturn {
                if state.saveCapture(state.pendingText) {
                    hide()
                }
                return nil
            }
            return event

        case .settings:
            if event.keyCode == Self.keyEscape {
                state.resetToList()
                return nil
            }
            return event
        }
    }

    /// The isPrintableKey() test: exactly one character, no command/control/option,
    /// and not a control code (so Escape, Tab and Delete don't start a capture).
    private func printableCharacter(in event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else {
            return nil
        }
        guard let characters = event.characters, characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else {
            return nil
        }
        return characters
    }
}
