import "../../components"
import "../../services"
import "../../config"
import Symmetria.Models
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property int index
    required property FileSystemEntry modelData
    property string searchQuery: ""

    signal activated()

    function _highlightMatches(name: string, query: string): string {
        if (query === "")
            return name;

        const lowerName = name.toLowerCase();
        const lowerQuery = query.toLowerCase();
        const matchPos = lowerName.indexOf(lowerQuery);
        if (matchPos === -1)
            return root._htmlEscape(name);

        const before = root._htmlEscape(name.substring(0, matchPos));
        const matched = root._htmlEscape(name.substring(matchPos, matchPos + query.length));
        const after = root._htmlEscape(name.substring(matchPos + query.length));
        return before + "<span style=\"background-color: " + Theme.palette.m3secondaryContainer + "; color: " + Theme.palette.m3onSecondaryContainer + ";\">" + matched + "</span>" + after;
    }

    function _htmlEscape(str: string): string {
        return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    readonly property bool _isSearchMatch: {
        if (root.searchQuery === "" || !root.modelData)
            return false;
        return root.modelData.name.toLowerCase().indexOf(root.searchQuery.toLowerCase()) !== -1;
    }

    implicitHeight: Config.fileManager.sizes.itemHeight

    // Search match highlight — subtle gray tint behind matching rows
    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.small
        color: Theme.palette.m3onSurface
        opacity: root._isSearchMatch ? 0.06 : 0
        Behavior on opacity { Anim {} }
    }

    // Selection highlight — separate Rectangle avoids StyledRect's color animation
    // which would cause visible stutter during rapid j/k navigation
    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.small
        color: Theme.palette.m3surfaceContainerHighest
        opacity: root.ListView.isCurrentItem ? 1 : 0
    }

    StateLayer {
        onClicked: root.ListView.view.currentIndex = root.index

        onDoubleClicked: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padding.large
        anchors.rightMargin: Theme.padding.large
        spacing: Theme.spacing.normal

        // File/folder icon
        MaterialIcon {
            text: {
                if (!root.modelData)
                    return "description";
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
            color: root.modelData?.isDir ? Theme.palette.m3primary : Theme.palette.m3onSurfaceVariant
            fill: root.modelData?.isDir ? 1 : 0
            font.pointSize: Theme.font.size.large
        }

        // File name
        StyledText {
            Layout.fillWidth: true
            textFormat: root.searchQuery !== "" ? Text.RichText : Text.PlainText
            text: {
                const name = root.modelData?.name ?? "";
                if (root.searchQuery !== "")
                    return root._highlightMatches(name, root.searchQuery);
                return name;
            }
            color: Theme.palette.m3onSurface
            font.pointSize: Theme.font.size.normal
            elide: Text.ElideRight
        }

        // File size (hidden for directories)
        StyledText {
            visible: !(root.modelData?.isDir ?? true)
            text: root.modelData ? FileManagerService.formatSize(root.modelData.size) : ""
            color: Theme.palette.m3onSurfaceVariant
            font.pointSize: Theme.font.size.small
            font.family: Theme.font.family.mono
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 60
        }
    }

}
