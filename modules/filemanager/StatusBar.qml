import "../../components"
import "../../services"
import "../../config"
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property int fileCount
    required property var currentEntry

    implicitHeight: inner.implicitHeight + Theme.padding.small * 2
    color: Theme.layer(Theme.palette.m3surfaceContainer, 1)

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: Theme.padding.large
        anchors.rightMargin: Theme.padding.large
        anchors.topMargin: Theme.padding.small
        anchors.bottomMargin: Theme.padding.small

        spacing: Theme.spacing.normal

        // Left: file count (hidden during search)
        StyledText {
            visible: !FileManagerService.searchActive
            text: root.fileCount + (root.fileCount === 1 ? " item" : " items")
            color: Theme.palette.m3onSurfaceVariant
            font.pointSize: Theme.font.size.small
        }

        Item {
            visible: !FileManagerService.searchActive
            Layout.fillWidth: true
        }

        // Center: current entry info (hidden during search)
        StyledText {
            visible: !FileManagerService.searchActive && root.currentEntry !== null
            text: {
                if (root.currentEntry?.isDir)
                    return root.currentEntry.name + "/";
                return (root.currentEntry?.name ?? "") + "  " + FileManagerService.formatSize(root.currentEntry?.size ?? 0);
            }
            color: Theme.palette.m3onSurface
            font.pointSize: Theme.font.size.small
            font.family: Theme.font.family.mono
        }

        Item {
            visible: !FileManagerService.searchActive
            Layout.fillWidth: true
        }

        // Search input (visible during search)
        StyledText {
            visible: FileManagerService.searchActive
            text: "/"
            color: Theme.palette.m3primary
            font.pointSize: Theme.font.size.small
            font.family: Theme.font.family.mono
        }

        TextInput {
            id: searchInput

            visible: FileManagerService.searchActive
            Layout.fillWidth: true
            color: Theme.palette.m3onSurface
            font.pointSize: Theme.font.size.small
            font.family: Theme.font.family.mono
            selectionColor: Theme.palette.m3primary
            selectedTextColor: Theme.palette.m3onPrimary
            clip: true

            onTextChanged: FileManagerService.searchQuery = text

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    FileManagerService.searchActive = false;
                    FileManagerService.searchConfirmed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    FileManagerService.searchActive = false;
                    FileManagerService.searchCancelled();
                    event.accepted = true;
                }
            }

            // Grab focus when search activates
            Connections {
                target: FileManagerService

                function onSearchActiveChanged() {
                    if (FileManagerService.searchActive) {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }
                }
            }
        }

        // Match count indicator (visible during search)
        StyledText {
            visible: FileManagerService.searchActive
            text: {
                const matches = FileManagerService.matchIndices;
                if (FileManagerService.searchQuery === "")
                    return "";
                if (matches.length === 0)
                    return "No matches";
                return (FileManagerService.currentMatchIndex + 1) + "/" + matches.length;
            }
            color: {
                if (FileManagerService.searchQuery !== "" && FileManagerService.matchIndices.length === 0)
                    return Theme.palette.m3error;
                return Theme.palette.m3onSurfaceVariant;
            }
            font.pointSize: Theme.font.size.small
            font.family: Theme.font.family.mono
        }

        // Right: abbreviated path (always visible)
        StyledText {
            text: Paths.shortenHome(FileManagerService.currentPath)
            color: Theme.palette.m3onSurfaceVariant
            font.pointSize: Theme.font.size.small
            elide: Text.ElideMiddle
            Layout.maximumWidth: root.width * 0.3
        }
    }
}
