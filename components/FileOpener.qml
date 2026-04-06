import "../services"
import Symmetria.FileManager.Models
import Quickshell.Io
import QtQuick

Item {
    id: root

    visible: false
    width: 0
    height: 0

    function open(path: string): void {
        const resolved = _previewHelper.resolvePathForOpen(path);
        // NOTE: xdg-open does NOT support "--" (it's a shell dispatcher, not
        // a getopt tool). Passing "--" causes "unexpected option" and silent failure.
        _xdgOpen.command = ["xdg-open", resolved];
        _xdgOpen.running = true;
    }

    PreviewImageHelper {
        id: _previewHelper
    }

    Process {
        id: _xdgOpen

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== Process.NormalExit)
                Logger.warn("FileOpener", "xdg-open exited with code " + exitCode + " for: " + command[1]);
        }
    }
}
