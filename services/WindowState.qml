import Quickshell
import QtQuick

QtObject {
    id: root

    // Set by the owning FileManager — determines starting directory
    property string initialPath: Paths.home

    // === Navigation ===
    property string currentPath: initialPath

    property var _history: [initialPath]
    property int _historyIndex: 0

    readonly property bool canGoBack: _historyIndex > 0
    readonly property bool canGoForward: _historyIndex < _history.length - 1

    // Per-directory cursor position cache: { path → index }
    property var _cursorCache: ({})

    function saveCursor(path: string, index: int): void {
        _cursorCache[path] = index;
    }

    function restoreCursor(path: string): int {
        return _cursorCache[path] ?? 0;
    }

    function navigate(path: string): void {
        if (path === currentPath)
            return;

        clearSearch();
        clearFlash();

        // Truncate forward history and append new path
        _history = _history.slice(0, _historyIndex + 1).concat([path]);
        _historyIndex = _history.length - 1;
        currentPath = path;
    }

    function back(): void {
        if (!canGoBack)
            return;

        clearSearch();
        clearFlash();
        _historyIndex--;
        currentPath = _history[_historyIndex];
    }

    function forward(): void {
        if (!canGoForward)
            return;

        clearSearch();
        clearFlash();
        _historyIndex++;
        currentPath = _history[_historyIndex];
    }

    function goUp(): void {
        if (currentPath === "/")
            return;

        clearSearch();
        clearFlash();
        const parentPath = currentPath.replace(/\/[^/]+$/, "") || "/";
        navigate(parentPath);
    }

    // === Search ===
    property bool searchActive: false
    property string searchQuery: ""
    property var matchIndices: []
    property int currentMatchIndex: -1

    signal searchConfirmed()
    signal searchCancelled()

    function clearSearch(): void {
        searchActive = false;
        searchQuery = "";
        matchIndices = [];
        currentMatchIndex = -1;
    }

    function startSearch(): void {
        clearSearch();
        clearFlash();
        searchActive = true;
    }

    function nextMatch(): void {
        if (matchIndices.length === 0)
            return;
        currentMatchIndex = (currentMatchIndex + 1) % matchIndices.length;
    }

    function previousMatch(): void {
        if (matchIndices.length === 0)
            return;
        currentMatchIndex = (currentMatchIndex - 1 + matchIndices.length) % matchIndices.length;
    }

    // === Flash navigation ===
    property bool flashActive: false
    property string flashQuery: ""
    property var flashMatches: []           // Match objects from FlashLogic.computeFlash()
    property var flashLabelChars: ({})      // { char: true } — chars assigned as labels
    property var flashContinuations: ({})   // { char: true } — chars that extend the query
    property string flashPendingLabel: ""   // First char of a 2-char label being resolved
    // O(1) lookup map: "column:index" → match object. Rebuilt when flashMatches changes.
    readonly property var flashMatchMap: {
        const map = {};
        for (let i = 0; i < flashMatches.length; i++) {
            const m = flashMatches[i];
            map[m.column + ":" + m.index] = m;
        }
        return map;
    }

    signal flashJump(string column, int index, string path)

    function startFlash(): void {
        clearFlash();
        clearSearch();
        flashActive = true;
    }

    function clearFlash(): void {
        flashActive = false;
        flashQuery = "";
        flashMatches = [];
        flashLabelChars = {};
        flashContinuations = {};
        flashPendingLabel = "";
    }

    // === Sort (per-window, ephemeral) ===
    property int sortBy: 1          // Default: Modified (matches C++ SortBy::Modified = 1)
    property bool sortReverse: true

    readonly property var _sortLabels: ["Alphabetical", "Modified", "Size", "Extension", "Natural"]
    readonly property string sortLabel: _sortLabels[sortBy] ?? "?"

    // === Chord / which-key state ===
    property string activeChordPrefix: ""
    readonly property bool chordActive: activeChordPrefix !== ""

    // Static chord configuration — never mutated at runtime.
    // chordBindings[prefix].binds lists the keys available after that prefix is pressed.
    readonly property var chordBindings: ({
        "g": {
            label: "go to",
            binds: [
                { key: "g", label: "Top", icon: "vertical_align_top" },
                { key: "h", label: "Home", icon: "home" },
                { key: "d", label: "Downloads", icon: "download" },
                { key: "s", label: "Screenshots", icon: "screenshot_monitor" },
                { key: "v", label: "Videos", icon: "video_library" }
            ]
        },
        "c": {
            label: "copy to clipboard",
            binds: [
                { key: "c", label: "File path", icon: "link" },
                { key: "f", label: "Filename", icon: "description" },
                { key: "n", label: "Name without extension", icon: "label" },
                { key: "d", label: "Directory path", icon: "folder" }
            ]
        },
        ",": {
            label: "sort by",
            binds: [
                { key: "a/A", label: "Alphabetical", icon: "sort_by_alpha" },
                { key: "m/M", label: "Modified date", icon: "schedule" },
                { key: "s/S", label: "Size", icon: "straighten" },
                { key: "e/E", label: "Extension", icon: "extension" },
                { key: "n/N", label: "Natural", icon: "format_list_numbered" }
            ]
        }
    })

    // === Selection (Space-toggled marks) ===
    // Stores absolute paths as keys: { "/home/user/file.txt": true, ... }
    // Persists across directory changes — cleared explicitly by the user.
    property var selectedPaths: ({})
    // Explicit counter avoids allocating a temporary array via Object.keys()
    // on every read of selectedCount (StatusBar + FileList both bind to it).
    property int _selectionCount: 0
    readonly property int selectedCount: _selectionCount

    function toggleSelection(path: string): void {
        const copy = Object.assign({}, selectedPaths);
        if (copy[path]) {
            delete copy[path];
            _selectionCount--;
        } else {
            copy[path] = true;
            _selectionCount++;
        }
        selectedPaths = copy;
    }

    function clearSelection(): void {
        selectedPaths = {};
        _selectionCount = 0;
    }

    function getSelectedPathsArray(): var {
        return Object.keys(selectedPaths);
    }

    // === Delete confirmation ===
    // Empty array means no pending deletion
    property var deleteConfirmPaths: []

    function requestDelete(paths: var): void {
        deleteConfirmPaths = paths;
    }

    function cancelDelete(): void {
        deleteConfirmPaths = [];
    }

    // === Create file/folder ===
    property bool createInputActive: false

    signal createCompleted(filename: string)

    function requestCreate(): void {
        createInputActive = true;
    }

    function cancelCreate(): void {
        createInputActive = false;
    }

    // === Rename ===
    property string renameTargetPath: ""
    property bool renameIncludeExtension: false

    signal renameCompleted(newName: string)

    function requestRename(path: string, includeExtension: bool): void {
        renameTargetPath = path;
        renameIncludeExtension = includeExtension;
    }

    function cancelRename(): void {
        renameTargetPath = "";
        renameIncludeExtension = false;
    }

    // === Context menu ===
    property string contextMenuTargetPath: ""
    property string contextMenuTargetMimeType: ""

    function requestContextMenu(path: string, mimeType: string): void {
        contextMenuTargetPath = path;
        contextMenuTargetMimeType = mimeType;
    }

    function cancelContextMenu(): void {
        contextMenuTargetPath = "";
        contextMenuTargetMimeType = "";
    }
}
