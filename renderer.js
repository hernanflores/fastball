'use strict';

const { ipcRenderer, clipboard } = require('electron');

// ─── State ───────────────────────────────────────────────────────────────────

let currentView = 'list'; // 'list' | 'editor' | 'capture' | 'settings'
let notes = [];
let selectedIndex = 0;
let currentNote = null;
let pendingChar = null; // first-char passthrough from list → capture

// ─── Elements ────────────────────────────────────────────────────────────────

const views = {
  list: document.getElementById('list-view'),
  editor: document.getElementById('editor-view'),
  capture: document.getElementById('capture-view'),
  settings: document.getElementById('settings-view'),
};

const listContainer = document.getElementById('list-container');
const emptyState = document.getElementById('empty-state');
const settingsBtn = document.getElementById('settings-btn');

const editorTitle = document.getElementById('editor-title');
const editorContent = document.getElementById('editor-content');
const editorBackBtn = document.getElementById('editor-back-btn');

const captureTextarea = document.getElementById('capture-textarea');

const settingsBackBtn = document.getElementById('settings-back-btn');
const settingNotesFolder = document.getElementById('setting-notes-folder');
const settingShortcut = document.getElementById('setting-shortcut');
const settingEditor = document.getElementById('setting-editor');
const browseBtn = document.getElementById('browse-btn');
const settingsError = document.getElementById('settings-error');
const settingsSave = document.getElementById('settings-save');

// ─── View Management ─────────────────────────────────────────────────────────

function showView(name) {
  currentView = name;
  for (const [key, el] of Object.entries(views)) {
    el.classList.toggle('active', key === name);
  }

  if (name === 'capture') {
    captureTextarea.value = pendingChar !== null ? pendingChar : '';
    pendingChar = null;
    // Place cursor at end
    const len = captureTextarea.value.length;
    captureTextarea.setSelectionRange(len, len);
    captureTextarea.focus();
  } else if (name === 'settings') {
    loadSettingsForm();
  }
}

// ─── List View ───────────────────────────────────────────────────────────────

async function loadNotes() {
  notes = await ipcRenderer.invoke('get-notes');
  renderNoteList();
}

function renderNoteList() {
  // Remove all note rows (keep empty-state element)
  const rows = listContainer.querySelectorAll('.note-row');
  rows.forEach((r) => r.remove());

  if (notes.length === 0) {
    emptyState.style.display = 'block';
    return;
  }

  emptyState.style.display = 'none';

  notes.forEach((note, i) => {
    const row = document.createElement('div');
    row.className = 'note-row' + (i === selectedIndex ? ' selected' : '');
    row.dataset.index = i;

    const name = document.createElement('span');
    name.className = 'note-name';
    name.textContent = note.name;

    const preview = document.createElement('span');
    preview.className = 'note-preview';
    preview.textContent = note.preview;

    row.appendChild(name);
    row.appendChild(preview);

    row.addEventListener('click', () => {
      selectedIndex = i;
      openEditor(notes[i]);
    });

    listContainer.appendChild(row);
  });

  scrollSelectedIntoView();
}

function updateSelection(newIndex) {
  const rows = listContainer.querySelectorAll('.note-row');
  rows.forEach((r, i) => r.classList.toggle('selected', i === newIndex));
  selectedIndex = newIndex;
  scrollSelectedIntoView();
}

function scrollSelectedIntoView() {
  const rows = listContainer.querySelectorAll('.note-row');
  if (rows[selectedIndex]) {
    rows[selectedIndex].scrollIntoView({ block: 'nearest' });
  }
}

// ─── Editor View ─────────────────────────────────────────────────────────────

async function openEditor(note) {
  currentNote = note;
  editorTitle.textContent = note.name;
  const content = await ipcRenderer.invoke('get-note-content', note.path);
  editorContent.value = content;
  showView('editor');
}

// ─── Settings View ───────────────────────────────────────────────────────────

async function loadSettingsForm() {
  settingsError.textContent = '';
  const cfg = await ipcRenderer.invoke('get-config');
  settingNotesFolder.value = cfg.notesFolder || '';
  settingShortcut.value = cfg.globalShortcut || '';
  settingEditor.value = cfg.preferredEditor || '';
}

// ─── Filename Generator ──────────────────────────────────────────────────────

function generateNoteFilename() {
  const now = new Date();
  const pad = (n, len = 2) => String(n).padStart(len, '0');
  const y = now.getFullYear();
  const mo = pad(now.getMonth() + 1);
  const d = pad(now.getDate());
  const h = pad(now.getHours());
  const mi = pad(now.getMinutes());
  const s = pad(now.getSeconds());
  return `${y}-${mo}-${d}-${h}${mi}${s}.md`;
}

// ─── Keyboard Handling ───────────────────────────────────────────────────────

function isPrintableKey(e) {
  // Single printable character, no modifier except shift
  if (e.key.length !== 1) return false;
  if (e.metaKey || e.ctrlKey || e.altKey) return false;
  return true;
}

document.addEventListener('keydown', async (e) => {
  // ── List view ──
  if (currentView === 'list') {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (notes.length > 0) {
        updateSelection(Math.min(selectedIndex + 1, notes.length - 1));
      }
      return;
    }

    if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (notes.length > 0) {
        updateSelection(Math.max(selectedIndex - 1, 0));
      }
      return;
    }

    if (e.key === 'Enter') {
      if (notes.length > 0) {
        openEditor(notes[selectedIndex]);
      }
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === 'w') {
      e.preventDefault();
      ipcRenderer.invoke('hide-window');
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === ',') {
      e.preventDefault();
      showView('settings');
      return;
    }

    // Paste: grab clipboard text, use as pendingChar
    if ((e.metaKey || e.ctrlKey) && e.key === 'v') {
      const text = clipboard.readText();
      if (text) {
        pendingChar = text;
        showView('capture');
      }
      return;
    }

    // Any printable key → switch to capture, pass char through
    if (isPrintableKey(e)) {
      pendingChar = e.key;
      showView('capture');
      // Prevent the char from firing again in the textarea (it will be set directly)
      e.preventDefault();
      return;
    }
  }

  // ── Editor view ──
  if (currentView === 'editor') {
    if (e.key === 'Escape') {
      showView('list');
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === 'w') {
      e.preventDefault();
      ipcRenderer.invoke('hide-window');
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === 'o') {
      e.preventDefault();
      if (currentNote) ipcRenderer.invoke('open-in-editor', currentNote.path);
      return;
    }

    // Shift+Cmd+C → clear file
    if (e.shiftKey && (e.metaKey || e.ctrlKey) && e.key === 'c') {
      e.preventDefault();
      if (currentNote) {
        await ipcRenderer.invoke('clear-note', currentNote.path);
        editorContent.value = '';
      }
      return;
    }
  }

  // ── Capture view ──
  if (currentView === 'capture') {
    if (e.key === 'Escape') {
      pendingChar = null;
      showView('list');
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      const content = captureTextarea.value;
      if (content.trim()) {
        const filename = generateNoteFilename();
        await ipcRenderer.invoke('save-note', { filename, content });
      }
      ipcRenderer.invoke('hide-window');
      return;
    }

    if ((e.metaKey || e.ctrlKey) && e.key === 'w') {
      e.preventDefault();
      ipcRenderer.invoke('hide-window');
      return;
    }
  }

  // ── Settings view ──
  if (currentView === 'settings') {
    if (e.key === 'Escape') {
      showView('list');
      return;
    }
  }
});

// ─── Editor Auto-save ────────────────────────────────────────────────────────

let saveTimer = null;

editorContent.addEventListener('input', () => {
  if (!currentNote) return;
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    ipcRenderer.invoke('save-note', {
      filename: currentNote.name + '.md',
      content: editorContent.value,
    });
  }, 500);
});

// ─── Button Handlers ─────────────────────────────────────────────────────────

settingsBtn.addEventListener('click', () => showView('settings'));
editorBackBtn.addEventListener('click', () => showView('list'));
settingsBackBtn.addEventListener('click', () => showView('list'));

browseBtn.addEventListener('click', async () => {
  const filePath = await ipcRenderer.invoke('show-open-dialog');
  if (filePath) settingEditor.value = filePath;
});

settingsSave.addEventListener('click', async () => {
  const shortcut = settingShortcut.value.trim();
  if (!shortcut) {
    settingsError.textContent = 'Global shortcut cannot be empty.';
    return;
  }

  const result = await ipcRenderer.invoke('save-config', {
    notesFolder: settingNotesFolder.value.trim() || '~/Notes',
    globalShortcut: shortcut,
    preferredEditor: settingEditor.value.trim(),
  });

  if (result.ok) {
    settingsError.textContent = '';
    showView('list');
    loadNotes();
  } else {
    settingsError.textContent = result.error || 'Failed to save settings.';
  }
});

// ─── IPC from Main ───────────────────────────────────────────────────────────

ipcRenderer.on('reset-to-list', () => {
  pendingChar = null;
  selectedIndex = 0;
  showView('list');
  loadNotes();
});

ipcRenderer.on('show-settings', () => {
  showView('settings');
});

// ─── Init ────────────────────────────────────────────────────────────────────

showView('list');
loadNotes();
