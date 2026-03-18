import "../../components"
import "../../services"
import "../../config"
import Symmetria.Models
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string previewPath

    // Background — slightly different shade for visual separation
    StyledRect {
        anchors.fill: parent
        color: Theme.layer(Theme.palette.m3surfaceContainerLow, 1)
    }

    // Empty / no-preview state
    Loader {
        anchors.centerIn: parent
        opacity: root.previewPath === "" || previewView.count === 0 ? 1 : 0
        active: opacity > 0
        asynchronous: true

        sourceComponent: ColumnLayout {
            spacing: Theme.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: root.previewPath === "" ? "description" : "folder_open"
                color: Theme.palette.m3outline
                font.pointSize: Theme.font.size.extraLarge * 2
                font.weight: 500
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.previewPath === "" ? qsTr("No preview") : qsTr("Empty folder")
                color: Theme.palette.m3outline
                font.pointSize: Theme.font.size.large
                font.weight: 500
            }
        }

        Behavior on opacity {
            Anim {}
        }
    }

    ListView {
        id: previewView

        anchors.fill: parent
        anchors.margins: Theme.padding.small
        visible: root.previewPath !== ""
        clip: true
        focus: false
        interactive: false
        keyNavigationEnabled: false
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds

        model: FileSystemModel {
            id: previewModel
            path: root.previewPath !== "" ? root.previewPath : ""
            showHidden: Config.fileManager.showHidden
            sortReverse: Config.fileManager.sortReverse
            watchChanges: false
        }

        delegate: FileListItem {
            width: previewView.width
        }
    }
}
