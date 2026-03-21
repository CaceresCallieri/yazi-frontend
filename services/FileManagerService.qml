pragma Singleton

import Quickshell

Singleton {
    id: root

    // === Clipboard (yank/cut) — shared across all windows ===
    property var clipboardPaths: []      // Array of absolute paths, [] when empty
    property string clipboardMode: ""    // "" | "yank" | "cut"

    // Materialized Set for O(1) delegate lookups — rebuilt whenever clipboardPaths changes.
    // Without this, each FileListItem delegate would call indexOf (O(n) per item per render).
    property var _clipboardSet: ({})

    onClipboardPathsChanged: {
        const s = {};
        clipboardPaths.forEach(p => s[p] = true);
        _clipboardSet = s;
    }

    function yank(paths: var): void {
        clipboardPaths = paths;
        clipboardMode = "yank";
    }

    function cut(paths: var): void {
        clipboardPaths = paths;
        clipboardMode = "cut";
    }

    function clearClipboard(): void {
        clipboardPaths = [];
        clipboardMode = "";
    }

    // === Picker mode (portal file chooser) — one picker at a time globally ===
    property bool pickerMode: false
    property string pickerFifoPath: ""
    property string pickerTitle: ""
    property string pickerAcceptLabel: ""
    property bool pickerMultiple: false
    property bool pickerDirectory: false
    property bool pickerSaveMode: false
    property string pickerSuggestedName: ""

    signal pickerCompleted(fifoPath: string, paths: var)
    signal pickerCancelled(fifoPath: string)

    function startPickerMode(options: var): void {
        pickerMode = true;
        pickerFifoPath = options.fifo || "";
        pickerTitle = options.title || "Select a File";
        pickerAcceptLabel = options.acceptLabel || "";
        pickerMultiple = options.multiple || false;
        // Protocol note: returning a single URI when multiple=true is conformant —
        // the FileChooser spec does not require returning the maximum requested count.
        pickerDirectory = options.directory || false;
        pickerSaveMode = options.saveMode || false;
        pickerSuggestedName = options.suggestedName || "";
        // Navigation to currentFolder is handled by WindowFactory when creating
        // the picker window — it passes the path as initialPath to the window.
    }

    function completePickerMode(paths: var): void {
        // Capture fifo path before _resetPickerState() clears it.
        // Signal emission must happen after reset so pickerMode=false
        // is already observable by the time listeners react.
        const fifo = pickerFifoPath;
        _resetPickerState();
        pickerCompleted(fifo, paths);
    }

    function cancelPickerMode(): void {
        // Same capture-before-reset invariant as completePickerMode.
        const fifo = pickerFifoPath;
        _resetPickerState();
        pickerCancelled(fifo);
    }

    function _resetPickerState(): void {
        pickerMode = false;
        pickerFifoPath = "";
        pickerTitle = "";
        pickerAcceptLabel = "";
        pickerMultiple = false;
        pickerDirectory = false;
        pickerSaveMode = false;
        pickerSuggestedName = "";
    }

    // === Utilities (stateless, shared) ===

    function formatSize(bytes: double): string {
        if (bytes < 1024)
            return bytes + " B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " K";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " M";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " G";
    }

    function formatDate(date: date): string {
        if (!date || isNaN(date.getTime()))
            return "";

        const now = new Date();
        const diffMs = now.getTime() - date.getTime();
        const diffSec = Math.floor(diffMs / 1000);
        const diffMin = Math.floor(diffSec / 60);
        const diffHour = Math.floor(diffMin / 60);
        const diffDay = Math.floor(diffHour / 24);

        if (diffSec < 60)
            return "just now";
        if (diffMin < 60)
            return diffMin + "m ago";
        if (diffHour < 24)
            return diffHour + "h ago";
        if (diffDay < 7)
            return diffDay + "d ago";

        return Qt.formatDateTime(date, "MMM d");
    }
}
