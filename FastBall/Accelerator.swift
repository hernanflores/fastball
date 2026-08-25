import Carbon.HIToolbox
import Foundation

/// Parses the Electron accelerator strings already in users' config files
/// (e.g. "Ctrl+Cmd+,") into Carbon modifier flags and a virtual keycode.
struct Accelerator {
    var carbonModifiers: UInt32
    var keyCode: UInt32

    static func parse(_ string: String) -> Accelerator? {
        let parts = string.split(separator: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let last = parts.last, !last.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "cmd", "command", "super", "meta": modifiers |= UInt32(cmdKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            case "alt", "option": modifiers |= UInt32(optionKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "commandorcontrol", "cmdorctrl": modifiers |= UInt32(cmdKey)
            default: return nil
            }
        }

        guard let code = keyCodes[last.lowercased()] else { return nil }
        return Accelerator(carbonModifiers: modifiers, keyCode: code)
    }

    private static let keyCodes: [String: UInt32] = {
        var map: [String: UInt32] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
            "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
            "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
            "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            ",": 43, ".": 47, "/": 44, ";": 41, "'": 39, "[": 33, "]": 30,
            "\\": 42, "-": 27, "=": 24, "`": 50,
            "space": 49, "return": 36, "enter": 36, "tab": 48, "escape": 53, "esc": 53,
            "backspace": 51, "delete": 51, "left": 123, "right": 124, "down": 125, "up": 126,
        ]
        let functionKeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (index, code) in functionKeys.enumerated() {
            map["f\(index + 1)"] = code
        }
        return map
    }()
}
