# FastBall

A global-hotkey-triggered macOS menubar app for quick markdown note capture and browsing.
Gotta Catch 'Em All!

Native Swift — AppKit + SwiftUI. No Electron, no runtime dependencies, ~470 KB binary.

## Features

- Lives in the menu bar as a `✎` icon — no dock icon
- Global shortcut to show/hide the note window from anywhere, **without Accessibility permission**
- Browse notes sorted by most recently modified
- Instant capture: start typing from the list to create a new note
- Auto-saving editor, with a shortcut to hand the file to your real editor
- Settings for folder, shortcut, editor, and launch-at-login

## Requirements

macOS 14 (Sonoma) or later. The Command Line Tools are enough to build it — Xcode is not required.

No Accessibility permission is needed. The hotkey is registered through Carbon's
`RegisterEventHotKey`, not an event tap, so macOS grants it without a prompt. (The old
Electron build did require Accessibility; if you granted it, you can revoke it.)

## Installation

### From source

```bash
git clone <repo>
cd fastball
make run
```

### Build a .dmg

```bash
make dmg
```

The `.dmg` appears in `build/`.

## Default Keybindings

### Global

| Shortcut | Action |
|---|---|
| `Ctrl+Cmd+,` | Toggle FastBall window |

### List View

| Shortcut | Action |
|---|---|
| `↑` / `↓` | Navigate notes |
| `Enter` | Open selected note |
| any printable key | Start a new note seeded with that character |
| `Cmd+V` | Start a new note from the clipboard |
| `Cmd+,` | Settings |
| `Cmd+W` | Hide |

### Editor View

| Shortcut | Action |
|---|---|
| `Esc` | Back to the list |
| `Cmd+O` | Open in your preferred editor |
| `Shift+Cmd+C` | Clear the note |
| `Cmd+W` | Hide |

### Capture View

| Shortcut | Action |
|---|---|
| `Cmd+Enter` | Save and hide |
| `Esc` | Discard |
| `Cmd+W` | Hide |

## Configuration

`~/Library/Application Support/FastBall/config.json` — same path and schema the Electron
build used, so existing settings carry over untouched:

```json
{
  "notesFolder": "~/Notes",
  "globalShortcut": "Ctrl+Cmd+,",
  "preferredEditor": ""
}
```

Notes are plain `.md` files named `YYYY-MM-DD-HHmmss.md`. The folder is created if missing.
Right-click the menu bar icon for **Open Notes Folder**, **Settings**, and **Quit**.

## Development

```
FastBall/
├── main.swift               NSApplication bootstrap
├── AppDelegate.swift        wiring: panel, status item, hotkey, key monitor, edit menu
├── AppState.swift           routes and note actions (was renderer.js's module state)
├── KeyHandler.swift         the single keydown switch, per view
├── NotePanel.swift          borderless floating NSPanel, hide-on-blur, cursor-display centering
├── HotKeyManager.swift      Carbon RegisterEventHotKey
├── Accelerator.swift        parses "Ctrl+Cmd+," accelerator strings
├── Config.swift             config.json read/write
├── NoteStore.swift          the .md files on disk
├── SelfTest.swift           synthesized-NSEvent smoke test
└── Views/                   SwiftUI views + theme
```

Debug flags, useful because the UI can only be reached by keyboard:

| Flag | Effect |
|---|---|
| `--show` | Show the panel immediately at launch |
| `--selftest` | Run the keyboard-routing smoke test, write `/tmp/fastball-selftest.txt`, quit |
| `--diag` | Write panel/app state to `/tmp/fb-diag.txt` |
| `--route=editor\|capture\|settings` | Open straight into a view (for screenshots) |

```bash
make && open build/FastBall.app --args --selftest && sleep 4 && cat /tmp/fastball-selftest.txt
```
