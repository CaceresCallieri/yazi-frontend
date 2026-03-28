pragma ComponentBehavior: Bound

import "../../components"
import "../../services"
import "../../config"
import QtQuick

Item {
    id: root

    property TabManager tabManager
    signal closeRequested()

    readonly property real _barHorizontalMargin: Theme.padding.lg + Theme.padding.md
    // Tab pill height: match the PathBar breadcrumb pill height
    readonly property real _tabHeight: Config.fileManager.sizes.itemHeight + Theme.padding.sm * 2

    // Height is always set — ColumnLayout skips invisible items automatically
    implicitHeight: _tabHeight + Theme.padding.md * 2

    onHeightChanged: {
        if (tabManager)
            Logger.info("TabBar", "height=" + height + " implicitHeight=" + implicitHeight + " showBar=" + tabManager.showBar + " tabCount=" + tabManager.count);
    }

    Row {
        id: tabRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root._barHorizontalMargin
        spacing: Theme.spacing.sm

        Repeater {
            model: root.tabManager ? root.tabManager.tabs : []

            Item {
                id: tabItem

                required property var modelData  // WindowState
                required property int index

                // Bind to tabManager.activeIndex explicitly so QML re-evaluates on every switch
                readonly property bool isActive: root.tabManager
                    && root.tabManager.activeIndex === tabItem.index
                readonly property bool isHovered: tabHoverArea.containsMouse
                readonly property string tabLabel: {
                    if (!modelData || !modelData.currentPath)
                        return "~";
                    const path = modelData.currentPath;
                    const home = Paths.home;
                    if (path === home)
                        return "~";
                    if (path === "/")
                        return "/";
                    return path.split("/").pop() || "/";
                }

                width: Math.max(120, tabLabel_text.implicitWidth + (tabItem.isHovered ? closeBtn.width + Theme.spacing.sm : 0) + Theme.padding.lg * 2)
                height: root._tabHeight

                Behavior on width { Anim {} }

                // Background: active tab gets matte pill, inactive is transparent
                StyledRect {
                    anchors.fill: parent
                    radius: Theme.rounding.full
                    color: tabItem.isActive ? Theme.pillMedium.background : "transparent"
                    border.color: tabItem.isActive ? Theme.pillMedium.border : "transparent"
                    border.width: tabItem.isActive ? 1 : 0

                    Behavior on color { Anim {} }
                    Behavior on border.color { Anim {} }
                }

                // Hover/click area for the entire tab
                MouseArea {
                    id: tabHoverArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.tabManager)
                            root.tabManager.activateTab(tabItem.index);
                    }
                }

                // Centered label: "1 dirname"
                StyledText {
                    id: tabLabel_text

                    anchors.centerIn: parent
                    // Offset left when close button is showing to keep text visually centered
                    anchors.horizontalCenterOffset: tabItem.isHovered ? -(closeBtn.width + Theme.spacing.sm) / 2 : 0

                    text: (tabItem.index + 1) + " " + tabItem.tabLabel
                    color: tabItem.isActive ? Theme.palette.m3onSurface : Theme.palette.m3onSurfaceVariant
                    font.pixelSize: Theme.font.size.sm

                    Behavior on anchors.horizontalCenterOffset { Anim {} }
                }

                // Close button — only visible on hover
                Item {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padding.md
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: closeIcon.implicitWidth + Theme.padding.sm * 2
                    implicitHeight: closeIcon.implicitHeight + Theme.padding.sm * 2
                    visible: tabItem.isHovered
                    opacity: tabItem.isHovered ? 1 : 0

                    Behavior on opacity { Anim {} }

                    MaterialIcon {
                        id: closeIcon

                        anchors.centerIn: parent
                        text: "close"
                        color: Theme.palette.m3onSurfaceVariant
                        font.pixelSize: Theme.font.size.sm
                    }

                    StateLayer {
                        radius: Theme.rounding.full
                        onClicked: {
                            if (root.tabManager) {
                                if (!root.tabManager.closeTab(tabItem.index))
                                    root.closeRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
