// Tree-view flash handler. Parallels FlashHandler.js but operates on the
// flattened `_rows` array — a single logical column with no cross-view
// navigation. All jumps land inside the same FileTreeView ListView.
//
// Non-library JS — shares the QML component scope of FileTreeView.qml.
// FlashLogic (`.pragma library`) is accessed via the importing file's scope.

var _cachedAllEntries = null;

function invalidateEntryCache() {
    _cachedAllEntries = null;
}

function handleKey(event, root, view) {
    var windowState = root.windowState;
    var key = event.key;

    if (key === Qt.Key_Shift || key === Qt.Key_Control
        || key === Qt.Key_Alt || key === Qt.Key_Meta) {
        event.accepted = true;
        return;
    }

    if (key === Qt.Key_Escape) {
        view.currentIndex = root._preFlashIndex;
        view.positionViewAtIndex(view.currentIndex, ListView.Contain);
        windowState.clearFlash();
        event.accepted = true;
        return;
    }

    if (key === Qt.Key_Backspace) {
        if (windowState.flashPendingLabel !== "") {
            windowState.flashPendingLabel = "";
        } else if (windowState.flashQuery.length > 0) {
            windowState.flashQuery = windowState.flashQuery.slice(0, -1);
            recompute(root, view);
        } else {
            view.currentIndex = root._preFlashIndex;
            view.positionViewAtIndex(view.currentIndex, ListView.Contain);
            windowState.clearFlash();
        }
        event.accepted = true;
        return;
    }

    var ch = event.text.toLowerCase();
    if (ch === "") {
        event.accepted = true;
        return;
    }

    // Resolve second char of a 2-char label
    if (windowState.flashPendingLabel !== "") {
        var fullLabel = windowState.flashPendingLabel + ch;
        windowState.flashPendingLabel = "";
        var pending = windowState.flashMatches;
        for (var i = 0; i < pending.length; i++) {
            if (pending[i].label === fullLabel) {
                _jump(view, pending[i].index);
                windowState.clearFlash();
                event.accepted = true;
                return;
            }
        }
        event.accepted = true;
        return;
    }

    // Char is a label?
    if (windowState.flashLabelChars[ch]) {
        var matches = windowState.flashMatches;
        for (var j = 0; j < matches.length; j++) {
            if (matches[j].label === ch) {
                _jump(view, matches[j].index);
                windowState.clearFlash();
                event.accepted = true;
                return;
            }
        }
        // First char of a 2-char label?
        for (var k = 0; k < matches.length; k++) {
            if (matches[k].label.length === 2 && matches[k].label[0] === ch) {
                windowState.flashPendingLabel = ch;
                event.accepted = true;
                return;
            }
        }
    }

    // Continuation (or first char of an empty query) → extend
    if (windowState.flashQuery === "" || windowState.flashContinuations[ch]) {
        windowState.flashQuery += ch;
        recompute(root, view);
        event.accepted = true;
        return;
    }

    // Neither label nor continuation — drop
    event.accepted = true;
}

function _jump(view, index) {
    view.currentIndex = index;
    view.positionViewAtIndex(index, ListView.Contain);
}

function _buildAllEntries(root) {
    var allEntries = [];
    var rows = root._rows;
    for (var i = 0; i < rows.length; i++) {
        allEntries.push({
            name:   rows[i].name,
            column: "current",
            index:  i,
            path:   rows[i].path,
            isDir:  rows[i].isDir
        });
    }
    return allEntries;
}

function recompute(root, view) {
    var windowState = root.windowState;
    var query = windowState.flashQuery.toLowerCase();
    if (query === "") {
        windowState.flashMatches = [];
        windowState.flashLabelChars = {};
        windowState.flashContinuations = {};
        windowState.flashCurrentMatchMap = {};
        return;
    }

    if (!_cachedAllEntries)
        _cachedAllEntries = _buildAllEntries(root);

    var result = FlashLogic.computeFlash(query, _cachedAllEntries, view.currentIndex);
    windowState.flashMatches = result.matches;
    windowState.flashLabelChars = result.labelChars;
    windowState.flashContinuations = result.continuations;

    var currentMap = {};
    for (var m = 0; m < result.matches.length; m++)
        currentMap[result.matches[m].index] = result.matches[m];
    windowState.flashCurrentMatchMap = currentMap;
}
