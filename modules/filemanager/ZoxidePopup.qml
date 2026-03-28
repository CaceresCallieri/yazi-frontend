import "../../components"
import "../../services"
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Loader {
    id: root

    property WindowState windowState

    anchors.fill: parent

    opacity: windowState && windowState.zoxideActive ? 1 : 0
    // Drive active from the source property, not from animated opacity — avoids
    // a race where the Loader activates mid-fade-out with an already-closed state.
    active: windowState && windowState.zoxideActive
    asynchronous: true

    sourceComponent: FocusScope {
        id: popupScope

        // Internal state
        property var results: []
        property int selectedIndex: 0
        property bool _dirty: false
        property bool _zoxideAvailable: true

        Component.onCompleted: _runQuery()

        // === Scrim backdrop — click to cancel ===
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.windowState.cancelZoxide()
        }

        StyledRect {
            anchors.fill: parent
            color: Qt.alpha(Theme.palette.m3shadow, 0.5)
        }

        // === Dialog card ===
        StyledRect {
            id: dialog

            anchors.centerIn: parent
            radius: Theme.rounding.lg
            color: Theme.palette.m3surfaceContainerHigh

            width: Math.min(parent.width - Theme.padding.lg * 4, 500)
            implicitHeight: dialogLayout.implicitHeight + Theme.padding.lg * 3

            scale: 0.1
            Component.onCompleted: scale = 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5
                }
            }

            // Block clicks from reaching the scrim MouseArea
            MouseArea {
                anchors.fill: parent
            }

            // Swallow all keys not handled by searchInput — prevents leaking
            // to components behind the scrim (consistent with DeleteConfirmPopup)
            Keys.onPressed: function(event) {
                event.accepted = true;
            }

            ColumnLayout {
                id: dialogLayout

                anchors.fill: parent
                anchors.margins: Theme.padding.lg * 1.5
                spacing: Theme.spacing.md

                // Header row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.spacing.sm

                    MaterialIcon {
                        text: "jump_to_element"
                        color: Theme.palette.m3primary
                        font.pointSize: Theme.font.size.lg
                    }

                    StyledText {
                        text: qsTr("Jump to directory")
                        color: Theme.palette.m3onSurface
                        font.pointSize: Theme.font.size.md
                        font.weight: 600
                    }
                }

                // Search input container
                StyledRect {
                    Layout.fillWidth: true
                    radius: Theme.rounding.sm
                    color: Qt.alpha(Theme.palette.m3onSurface, 0.06)
                    implicitHeight: searchInput.implicitHeight + Theme.padding.md * 2

                    TextInput {
                        id: searchInput

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.padding.lg
                        anchors.rightMargin: Theme.padding.lg

                        color: Theme.palette.m3onSurface
                        font.pointSize: Theme.font.size.sm
                        font.family: Theme.font.family.mono
                        selectionColor: Theme.palette.m3primary
                        selectedTextColor: Theme.palette.m3onPrimary
                        clip: true
                        focus: true

                        Component.onCompleted: forceActiveFocus()

                        onTextChanged: debounceTimer.restart()

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.windowState.cancelZoxide();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                popupScope._confirmSelection();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down
                                       || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                                if (popupScope.selectedIndex < popupScope.results.length - 1)
                                    popupScope.selectedIndex++;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up
                                       || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                                if (popupScope.selectedIndex > 0)
                                    popupScope.selectedIndex--;
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Results list (Repeater — max 10 items, no virtualization needed)
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: popupScope.results.length > 0

                    Repeater {
                        model: popupScope.results

                        StyledRect {
                            required property var modelData
                            required property int index

                            width: parent.width
                            radius: Theme.rounding.sm
                            color: index === popupScope.selectedIndex
                                ? Qt.alpha(Theme.palette.m3primary, 0.15)
                                : "transparent"
                            implicitHeight: resultRow.implicitHeight + Theme.padding.sm * 2

                            Behavior on color {
                                CAnim {}
                            }

                            RowLayout {
                                id: resultRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.padding.md
                                anchors.rightMargin: Theme.padding.md
                                spacing: Theme.spacing.md

                                // Score (dimmed, right-aligned, fixed width)
                                StyledText {
                                    Layout.preferredWidth: 50
                                    text: Math.round(modelData.score).toString()
                                    color: Theme.palette.m3onSurfaceVariant
                                    font.pointSize: Theme.font.size.xs
                                    font.family: Theme.font.family.mono
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Path (with ~ substitution, elide in the middle for long paths)
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Paths.shortenHome(modelData.path)
                                    color: index === popupScope.selectedIndex
                                        ? Theme.palette.m3onSurface
                                        : Theme.palette.m3onSurfaceVariant
                                    font.pointSize: Theme.font.size.sm
                                    font.family: Theme.font.family.mono
                                    elide: Text.ElideMiddle
                                }
                            }

                            StateLayer {
                                onClicked: {
                                    popupScope.selectedIndex = index;
                                    popupScope._confirmSelection();
                                }
                            }
                        }
                    }
                }

                // Empty state
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.md
                    visible: popupScope.results.length === 0 && !zoxideProcess.running
                    text: popupScope._zoxideAvailable
                        ? qsTr("No matches")
                        : qsTr("zoxide not found — install with: paru -S zoxide")
                    color: Theme.palette.m3onSurfaceVariant
                    font.pointSize: Theme.font.size.sm
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // === Functions ===

        function _runQuery(): void {
            if (zoxideProcess.running) {
                _dirty = true;
                return;
            }
            const cmd = ["zoxide", "query", "--list", "--score"];
            const queryText = searchInput.text.trim();
            if (queryText !== "") {
                const keywords = queryText.split(/\s+/);
                for (const kw of keywords)
                    cmd.push(kw);
            }
            zoxideProcess.command = cmd;
            zoxideProcess.running = true;
        }

        function _parseResults(text: string): void {
            const lines = text.trim().split("\n");
            const parsed = [];
            const maxResults = 10;
            for (let i = 0; i < lines.length && parsed.length < maxResults; i++) {
                const m = lines[i].match(/^\s*([\d.]+)\s+(.+)$/);
                if (m)
                    parsed.push({ score: parseFloat(m[1]), path: m[2] });
            }
            results = parsed;
            selectedIndex = 0;
        }

        function _confirmSelection(): void {
            if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
                return;
            const targetPath = results[selectedIndex].path;
            root.windowState.navigate(targetPath);
        }

        // === Debounce timer ===
        Timer {
            id: debounceTimer
            interval: 100
            repeat: false
            onTriggered: popupScope._runQuery()
        }

        // === Zoxide query process ===
        Process {
            id: zoxideProcess

            stdout: StdioCollector {
                onStreamFinished: popupScope._parseResults(text)
            }

            onExited: (exitCode, exitStatus) => {
                if (exitCode === 127) {
                    // 127 = command not found — zoxide is not installed
                    popupScope._zoxideAvailable = false;
                    popupScope.results = [];
                } else if (exitCode !== 0) {
                    // No matches for this query — clear results
                    popupScope.results = [];
                }
                if (popupScope._dirty) {
                    popupScope._dirty = false;
                    popupScope._runQuery();
                }
            }
        }
    }

    Behavior on opacity {
        Anim {}
    }
}
