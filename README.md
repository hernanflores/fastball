# FastBall

A global-hotkey-triggered macOS menubar app for quick markdown note capture and browsing.
Gotta Catch 'Em All!

## Features

- Lives in the menu bar as a `✎` icon — no dock icon
- Global shortcut to show/hide the note window from anywhere
- Browse notes sorted by most recently modified
- Instant capture: start typing from the list to create a new note
- Read-only editor view with external editor support
- Settings UI for folder, shortcut, and editor configuration

## Requirements

### Accessibility Permission (Required for Global Shortcut)

macOS requires Accessibility access for apps that register global keyboard shortcuts. Without it, the shortcut will silently fail.

To grant access:
1. Open **System Preferences** → **Privacy & Security** → **Accessibility**
2. Click the `+` button and add **FastBall**
3. Make sure the toggle is enabled

FastBall will show a notification on first launch if the shortcut could not be registered.

## Installation

### From source

```bash
git clone <repo>
cd fastball
npm install
npm start
```

### Build a .dmg

```bash
npm run dist
```

The `.dmg` will appear in the `dist/` folder.

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
| `Cmd+,` | Open Settings |
| `Cmd+W` | Hide window |
| Any key / Cmd+V | Start new note capture |

### Editor View

| Shortcut | Action |
|---|---|
| `Esc` | Back to list |
| `Cmd+W` | Hide window |
| `Cmd+O` | Open current note in preferred editor |
| `Shift+Cmd+C` | Clear note content |

### Capture View

| Shortcut | Action |
|---|---|
| `Cmd+Enter` | Save note and close |
| `Esc` | Discard and return to list |

### Settings View

| Shortcut | Action |
|---|---|
| `Esc` | Back to list |

## Configuration

Config is stored at:

```
~/Library/Application Support/FastBall/config.json
```

You can edit it manually while the app is not running:

```json
{
  "notesFolder": "~/Notes",
  "globalShortcut": "Ctrl+Cmd+,",
  "preferredEditor": "/usr/local/bin/code"
}
```

### Fields

- **notesFolder** — Path to the folder where `.md` files are stored. `~` is expanded automatically.
- **globalShortcut** — Electron-format accelerator string. See [Electron Accelerator docs](https://www.electronjs.org/docs/latest/api/accelerator) for valid key names.
- **preferredEditor** — Full path to your editor executable (e.g. `/usr/local/bin/code` for VS Code, `/usr/local/bin/nvim` for Neovim). Leave empty to use the system default app for `.md` files.

## Notes

- Notes are saved as `YYYY-MM-DD-HHmmss.md` files in the configured folder.
- The notes folder is auto-created if it does not exist.
- Tray right-click gives quick access to Open Notes Folder, Settings, and Quit.
