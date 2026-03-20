//@ pragma Env QT_QPA_PLATFORM=wayland
//@ pragma Env QSG_RENDER_LOOP=threaded

import "modules/filemanager"
import Quickshell
import QtQuick

ShellRoot {
    // WindowFactory is a Singleton — importing the module registers the
    // IPC handler automatically. The portal backend (or manual IPC) calls
    // create("") or createPicker("...") to open windows on demand.
    //
    // To open the file manager manually:
    //   qs ipc --any-display -c yazi-fm call filemanager open ""
    Component.onCompleted: {
        console.log("yazi-fm: IPC ready (target: filemanager)");
        // Auto-open file manager window for standalone usage
        WindowFactory.create("");
    }
}
