pragma Singleton

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Singleton {
    id: root

    function create(initialPath: string): void {
        if (initialPath)
            FileManagerService.navigate(initialPath);
        fileManagerWindow.createObject(dummy);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: fileManagerWindow

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface
            title: qsTr("File Manager")

            implicitWidth: Config.fileManager.sizes.windowWidth
            implicitHeight: Config.fileManager.sizes.windowHeight

            minimumSize.width: 600
            minimumSize.height: 400

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            FileManager {
                id: fm

                anchors.fill: parent

                onCloseRequested: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
