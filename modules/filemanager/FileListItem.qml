import qs.components
import qs.services
import qs.config
import Symmetria.Models
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property int index
    required property FileSystemEntry modelData

    signal activated()

    implicitHeight: Config.fileManager.sizes.itemHeight

    // Selection highlight — separate Rectangle avoids StyledRect's color animation
    // which would cause visible stutter during rapid j/k navigation
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Colours.tPalette.m3surfaceContainerHighest
        opacity: root.ListView.isCurrentItem ? 1 : 0
    }

    StateLayer {
        function onClicked(): void {
            root.ListView.view.currentIndex = root.index;
        }

        onDoubleClicked: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        spacing: Appearance.spacing.normal

        // File/folder icon
        MaterialIcon {
            text: {
                if (root.modelData.isDir)
                    return "folder";
                if (root.modelData.isImage)
                    return "image";
                const mime = root.modelData.mimeType;
                if (mime.startsWith("text/"))
                    return "article";
                if (mime.startsWith("video/"))
                    return "movie";
                if (mime.startsWith("audio/"))
                    return "music_note";
                return "description";
            }
            color: root.modelData.isDir ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fill: root.modelData.isDir ? 1 : 0
            font.pointSize: Appearance.font.size.large
        }

        // File name
        StyledText {
            Layout.fillWidth: true
            text: root.modelData.name
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.normal
            elide: Text.ElideRight
        }

        // File size (hidden for directories)
        StyledText {
            visible: !root.modelData.isDir
            text: FileManagerService.formatSize(root.modelData.size)
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.mono
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 60
        }
    }

}
