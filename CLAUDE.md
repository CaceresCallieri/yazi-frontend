# CLAUDE.md

> **Principle: No duplicate sources of truth.** This document contains ONLY information that cannot be discovered by reading the codebase. For implementation details, read the actual source files.

## Project Overview

Yazi-frontend is a keyboard-first graphical file manager built as a standalone QuickShell application. It runs as a headless systemd service (`yazi-fm.service`) that spawns FloatingWindow instances on demand via IPC. No Yazi runtime dependency — pure native Qt/QML/C++ inspired by Yazi's UX philosophy.

**Do NOT restart the shell (Symmetria) or kill the yazi-fm service** without the user's consent — they may have open file manager or picker windows with unsaved state.

## Build & Run

### C++ Plugin (`YaziFM.Models`)

The file manager's core data models live in `plugin/` as a standalone CMake project that builds a Qt6 QML plugin. This plugin is separate from Symmetria's plugin build.

```bash
./build-plugin.sh              # Build + install (no restart)
./build-plugin.sh --restart    # Build + install + restart yazi-fm
```

Or manually:
```bash
cd plugin
cmake -B build
cmake --build build --parallel $(nproc)
sudo cmake --install build
systemctl --user restart yazi-fm
```

**Install path:** `/usr/lib/qt6/qml/YaziFM/Models/` — Qt's QML engine discovers modules here automatically.

**CMake variables:**
- `CMAKE_INSTALL_PREFIX` defaults to `/usr` — combined with `INSTALL_QMLDIR=lib/qt6/qml`, the final path is `/usr/lib/qt6/qml/`
- Do NOT pass `-DCMAKE_INSTALL_PREFIX=/` (old convention) — the CMakeLists already defaults correctly

**Build dependencies (Arch):** `qt6-base qt6-declarative syntax-highlighting libarchive qxlsx-qt6 freexl`

### QML Changes

No compilation needed — just restart the service:
```bash
systemctl --user restart yazi-fm
```
The service's `ExecStartPre` automatically clears the QML cache before each start.

### Opening the File Manager

```bash
qs ipc -c yazi-fm call filemanager open ""           # From terminal
# Or via Super+E keybinding (configured in Symmetria's Shortcuts.qml)
```

## Architecture

### Plugin: `YaziFM.Models` (C++ → QML)

Five model classes, all in C++ namespace `symmetria::models` (kept for migration simplicity — QML_ELEMENT doesn't require namespace to match URI):

| Class | Purpose |
|-------|---------|
| `FileSystemModel` + `FileSystemEntry` | Async directory listing with sorting, filtering, file watching |
| `ArchivePreviewModel` | Lists archive contents (zip, tar, 7z, rar) via libarchive |
| `SpreadsheetPreviewModel` | Reads .xlsx (QXlsx) and .xls (freexl) for preview |
| `SyntaxHighlightHelper` | Syntax-highlighted HTML for text file previews via KF6 |
| `PreviewImageHelper` | Image preview generation with background compositing + caching |

### Symmetria Dependency (One-Sided)

Symmetria imports `YaziFM.Models` in 5 QML files (wallpaper grid, file dialog, etc.) — it depends on this plugin being installed. Yazi-frontend does NOT depend on Symmetria.

If the plugin is not installed, Symmetria's wallpaper picker and file dialog will fail to load. After any plugin API changes, verify Symmetria still works.

### State Architecture

- **`WindowState.qml`** (per-window) — navigation, search, chords, modals
- **`FileManagerService.qml`** (singleton) — clipboard, picker mode, format utilities
- **`WindowFactory.qml`** (singleton) — creates/manages windows, handles IPC

### Service & Portal

- `yazi-fm.service` — headless systemd user service, `Restart=always`, auto-clears QML cache
- `portal/symmetria_portal.py` — XDG Desktop Portal backend for system file dialogs
- Communication: Portal → IPC → QML picker window → FIFO → Portal → D-Bus response

## Critical Pitfalls

**QML cache after plugin rebuild** — The service clears cache on restart (`ExecStartPre`), but if you're running the file manager manually (not via systemd), you must clear it yourself: `rm -rf ~/.cache/quickshell/qmlcache`

**FloatingWindow keyboard focus** — Must use `WlrKeyboardFocus.Exclusive` to prevent Hyprland from consuming key events meant for the file manager.

**QML Loader quirks** — `anchors.margins` silently fails inside Loader `sourceComponent` blocks. Always use explicit x/y/width/height positioning and explicit imports inside Loaders. See `QUIRKS.md` for details.

**QML Singleton lazy-init** — QuickShell singletons don't initialize until first referenced. `shell.qml` must contain `void WindowFactory;` to force IpcHandler registration at startup.

**Vim chord detection** — Uses timer-based multi-key detection (500ms timeout), NOT Symmetria's KeyChords module (those are for global shell shortcuts).
