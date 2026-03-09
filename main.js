'use strict';

const {
  app,
  BrowserWindow,
  globalShortcut,
  ipcMain,
  Menu,
  Notification,
  Tray,
  dialog,
  shell,
  screen,
  nativeImage,
} = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// ─── Paths ───────────────────────────────────────────────────────────────────

function getUserConfigPath() {
  return path.join(app.getPath('userData'), 'config.json');
}

function getBundledConfigPath() {
  // In packaged app resources are at process.resourcesPath/config.json
  // In dev they're next to main.js
  const packed = path.join(process.resourcesPath || '', 'config.json');
  if (fs.existsSync(packed)) return packed;
  return path.join(__dirname, 'config.json');
}

function expandPath(p) {
  if (!p) return p;
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  if (p === '~') return os.homedir();
  return p;
}

// ─── Config ──────────────────────────────────────────────────────────────────

let config = {};

function loadConfig() {
  const userPath = getUserConfigPath();

  // First run: copy bundled config to user data dir
  if (!fs.existsSync(userPath)) {
    const bundled = getBundledConfigPath();
    fs.mkdirSync(path.dirname(userPath), { recursive: true });
    fs.copyFileSync(bundled, userPath);
  }

  const raw = fs.readFileSync(userPath, 'utf8');
  config = JSON.parse(raw);
  // Always expand the path after loading
  config.notesFolder = expandPath(config.notesFolder);
}

function saveConfig(newConfig) {
  config = { ...newConfig };
  // Save with ~ notation preserved if it was originally ~ but expand in memory
  const userPath = getUserConfigPath();
  fs.writeFileSync(userPath, JSON.stringify(newConfig, null, 2), 'utf8');
  config.notesFolder = expandPath(config.notesFolder);
}

function ensureNotesFolder() {
  fs.mkdirSync(config.notesFolder, { recursive: true });
}

// ─── Window ──────────────────────────────────────────────────────────────────

let win = null;
let isDialogOpen = false;

function createWindow() {
  win = new BrowserWindow({
    width: 400,
    height: 500,
    show: false,
    frame: false,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  win.loadFile('index.html');

  // Hide on blur (but not when a dialog is open)
  win.on('blur', () => {
    if (!isDialogOpen) win.hide();
  });

  // Always reset to list view when window is shown
  win.on('show', () => {
    win.webContents.send('reset-to-list');
  });

  // Prevent actual close — just hide
  win.on('close', (e) => {
    e.preventDefault();
    win.hide();
  });
}

function centerWindowOnActiveDisplay() {
  const cursorPos = screen.getCursorScreenPoint();
  const display = screen.getDisplayNearestPoint(cursorPos);
  const { bounds } = display;
  const { width, height } = win.getBounds();
  const x = Math.round(bounds.x + (bounds.width - width) / 2);
  const y = Math.round(bounds.y + (bounds.height - height) / 2);
  win.setPosition(x, y);
}

function toggleWindow() {
  if (win.isVisible()) {
    win.hide();
  } else {
    centerWindowOnActiveDisplay();
    win.show();
    win.focus();
  }
}

// ─── Tray ────────────────────────────────────────────────────────────────────

let tray = null;

function createTrayIcon() {
  // Create a minimal 1x1 transparent image as the tray icon base
  // then use tray.setTitle() for the text glyph (macOS only)
  const img = nativeImage.createEmpty();
  // We need at least a valid (even tiny) image — create a 16x16 transparent PNG
  const size = 16;
  // Minimal PNG: 1×1 transparent pixel, scaled to 16x16 via Buffer
  // Use a base64 1x1 transparent PNG
  const transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAC0lEQVQ42mNk+A8AAQQBAScAAAAAElFTkSuQmCC';
  return nativeImage.createFromBuffer(Buffer.from(transparentPng, 'base64'), {
    scaleFactor: 1,
  });
}

function createTray() {
  const icon = createTrayIcon();
  tray = new Tray(icon);
  tray.setTitle('✎'); // macOS menu bar text
  tray.setToolTip('FastBall');

  tray.on('click', toggleWindow);

  updateTrayContextMenu();
}

function updateTrayContextMenu() {
  const menu = Menu.buildFromTemplate([
    {
      label: 'Open Notes Folder',
      click: () => shell.openPath(config.notesFolder),
    },
    {
      label: 'Settings',
      click: () => {
        if (!win.isVisible()) {
          centerWindowOnActiveDisplay();
          win.show();
          win.focus();
        }
        win.webContents.send('show-settings');
      },
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.exit(0);
      },
    },
  ]);
  tray.setContextMenu(menu);
}

// ─── Global Shortcut ─────────────────────────────────────────────────────────

function registerShortcut() {
  globalShortcut.unregisterAll();
  const ok = globalShortcut.register(config.globalShortcut, toggleWindow);
  if (!ok) {
    // Show a notification prompting the user to grant Accessibility access
    if (Notification.isSupported()) {
      const notif = new Notification({
        title: 'FastBall',
        body: 'Could not register global shortcut. Please grant Accessibility access in System Preferences → Privacy & Security → Accessibility.',
      });
      notif.show();
    }
  }
}

// ─── IPC Handlers ────────────────────────────────────────────────────────────

ipcMain.handle('get-notes', () => {
  const folder = config.notesFolder;
  if (!fs.existsSync(folder)) return [];

  const files = fs.readdirSync(folder).filter((f) => f.endsWith('.md'));

  const notes = files
    .map((filename) => {
      const fullPath = path.join(folder, filename);
      let mtime;
      try {
        mtime = fs.statSync(fullPath).mtimeMs;
      } catch {
        mtime = 0;
      }
      let preview = '';
      try {
        const content = fs.readFileSync(fullPath, 'utf8');
        preview = content.split('\n')[0] || '';
      } catch {
        preview = '';
      }
      return {
        name: path.basename(filename, '.md'),
        preview,
        path: fullPath,
        mtime,
      };
    })
    .sort((a, b) => b.mtime - a.mtime);

  return notes;
});

ipcMain.handle('get-note-content', (_e, filePath) => {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
});

ipcMain.handle('save-note', (_e, { filename, content }) => {
  const filePath = path.join(config.notesFolder, filename);
  fs.writeFileSync(filePath, content, 'utf8');
  return { ok: true };
});

ipcMain.handle('clear-note', (_e, filePath) => {
  fs.writeFileSync(filePath, '', 'utf8');
  return { ok: true };
});

ipcMain.handle('get-config', () => {
  // Return config with original (unexpanded) notesFolder for display
  const userPath = getUserConfigPath();
  try {
    return JSON.parse(fs.readFileSync(userPath, 'utf8'));
  } catch {
    return config;
  }
});

ipcMain.handle('save-config', (_e, newConfig) => {
  if (!newConfig.globalShortcut || !newConfig.globalShortcut.trim()) {
    return { ok: false, error: 'Global shortcut cannot be empty.' };
  }

  // Try registering the new shortcut first
  globalShortcut.unregisterAll();
  const ok = globalShortcut.register(newConfig.globalShortcut.trim(), toggleWindow);
  if (!ok) {
    // Re-register old shortcut so it still works
    globalShortcut.register(config.globalShortcut, toggleWindow);
    return { ok: false, error: 'Shortcut is invalid or already taken by another app.' };
  }

  // Persist old shortcut string for re-registration on failure (after re-read)
  const oldShortcut = config.globalShortcut;
  try {
    saveConfig({
      notesFolder: newConfig.notesFolder || '~/Notes',
      globalShortcut: newConfig.globalShortcut.trim(),
      preferredEditor: newConfig.preferredEditor || '',
    });
    ensureNotesFolder();
    updateTrayContextMenu();
    return { ok: true };
  } catch (err) {
    // Rollback shortcut
    globalShortcut.unregisterAll();
    globalShortcut.register(oldShortcut, toggleWindow);
    config.globalShortcut = oldShortcut;
    return { ok: false, error: err.message };
  }
});

ipcMain.handle('open-in-editor', (_e, filePath) => {
  const editor = config.preferredEditor;
  if (editor && editor.trim()) {
    spawn(editor.trim(), [filePath], { detached: true, stdio: 'ignore' }).unref();
  } else {
    shell.openPath(filePath);
  }
});

ipcMain.handle('show-open-dialog', async () => {
  isDialogOpen = true;
  try {
    const result = await dialog.showOpenDialog(win, {
      properties: ['openFile'],
      title: 'Select Editor Executable',
    });
    return result.canceled ? null : result.filePaths[0];
  } finally {
    isDialogOpen = false;
  }
});

ipcMain.handle('open-notes-folder', () => {
  shell.openPath(config.notesFolder);
});

ipcMain.handle('hide-window', () => {
  win.hide();
});

// ─── App Init ────────────────────────────────────────────────────────────────

// Prevent multiple instances
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    toggleWindow();
  });
}

app.on('ready', () => {
  // Suppress dock icon
  if (app.dock) app.dock.hide();

  loadConfig();
  ensureNotesFolder();
  createWindow();
  createTray();
  registerShortcut();
});

app.on('window-all-closed', (e) => {
  // Prevent default quit behavior — we want to keep the tray alive
  e.preventDefault();
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
