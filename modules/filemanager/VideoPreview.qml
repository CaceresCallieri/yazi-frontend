import "../../components"
import "../../services"
import QtQuick
import QtQuick.Layouts
import QtMultimedia

Item {
    id: root

    required property var entry

    // Exposed for PreviewMetadata — reflects decoded video dimensions
    readonly property size naturalSize: {
        if (!videoPlayer.hasVideo) return Qt.size(0, 0);
        const r = videoOutput.sourceRect;
        return r.width > 0 ? Qt.size(r.width, r.height) : Qt.size(0, 0);
    }

    MediaPlayer {
        id: videoPlayer
        source: root.entry ? "file://" + root.entry.path : ""
        autoPlay: true
        loops: MediaPlayer.Infinite

        audioOutput: AudioOutput { muted: true }
        videoOutput: videoOutput
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        anchors.margins: Theme.padding.normal
        fillMode: VideoOutput.PreserveAspectFit

        opacity: videoPlayer.playbackState === MediaPlayer.PlayingState ? 1 : 0

        Behavior on opacity {
            Anim {}
        }
    }

    // Loading indicator — covers initial media loading and buffering
    Loader {
        anchors.centerIn: parent
        active: videoPlayer.mediaStatus === MediaPlayer.LoadingMedia
            || videoPlayer.mediaStatus === MediaPlayer.BufferingMedia
        asynchronous: true

        sourceComponent: StyledText {
            text: qsTr("Loading\u2026")
            color: Theme.palette.m3outline
            font.pointSize: Theme.font.size.normal
        }
    }

    // Error state
    Loader {
        anchors.centerIn: parent
        active: videoPlayer.error !== MediaPlayer.NoError
        asynchronous: true

        sourceComponent: ColumnLayout {
            spacing: Theme.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "videocam_off"
                color: Theme.palette.m3outline
                font.pointSize: Theme.font.size.extraLarge * 2
                font.weight: 500
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Cannot preview")
                color: Theme.palette.m3outline
                font.pointSize: Theme.font.size.large
                font.weight: 500
            }
        }
    }
}
