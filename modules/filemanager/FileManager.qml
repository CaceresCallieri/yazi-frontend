import "../../components"
import "../../services"
import "../../config"
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal closeRequested()

    // Set by WindowFactory — determines starting directory for this window
    property string initialPath: Paths.home

    // Per-window tab manager — owns one WindowState per tab
    TabManager {
        id: tabManager
        initialPath: root.initialPath
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            Layout.fillWidth: true
            Layout.preferredHeight: tabManager.showBar ? implicitHeight : 0
            tabManager: tabManager
            clip: true
            onCloseRequested: root.closeRequested()
        }

        PathBar {
            Layout.fillWidth: true
            windowState: tabManager.activeTab
        }

        MillerColumns {
            id: millerColumns
            Layout.fillWidth: true
            Layout.fillHeight: true
            windowState: tabManager.activeTab
            tabManager: tabManager
            onCloseRequested: root.closeRequested()
        }

        StatusBar {
            Layout.fillWidth: true
            windowState: tabManager.activeTab
            fileCount: millerColumns.fileCount
            currentEntry: millerColumns.currentEntry
        }
    }

    // Modal overlays — render above the entire layout.
    // Each popup is itself a Loader with its own active guard;
    // picker guard is folded into the popup's active binding.
    DeleteConfirmPopup {
        anchors.fill: parent
        windowState: tabManager.activeTab
    }
    CreateFilePopup {
        anchors.fill: parent
        windowState: tabManager.activeTab
    }
    RenamePopup {
        anchors.fill: parent
        windowState: tabManager.activeTab
        targetItemY: millerColumns.y + millerColumns.currentItemBottomY
        targetColumnX: millerColumns.x + millerColumns.currentColumnX
        targetColumnWidth: millerColumns.currentColumnWidth
    }
    ContextMenuPopup {
        anchors.fill: parent
        windowState: tabManager.activeTab
    }
    ZoxidePopup {
        anchors.fill: parent
        windowState: tabManager.activeTab
    }

    // Train zoxide's frecency database on every directory visit.
    // Fire-and-forget: exit code is irrelevant.
    Process {
        id: zoxideAddProcess
    }

    Connections {
        target: tabManager.activeTab
        function onCurrentPathChanged(): void {
            const path = tabManager.activeTab.currentPath;
            if (path && path !== "" && !zoxideAddProcess.running) {
                zoxideAddProcess.command = ["zoxide", "add", "--", path];
                zoxideAddProcess.running = true;
            }
        }
    }
}
