pragma Singleton

import "../../components"
import "../../services"
import "../../config"
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var _activeWindow: null
    property var _activePickerWindow: null

    function create(initialPath: string): void {
        if (_activeWindow)
            return;
        if (initialPath)
            FileManagerService.navigate(initialPath);
        _activeWindow = fileManagerWindow.createObject(dummy);
    }

    QtObject {
        id: dummy
    }

    // === IPC handler for external control ===
    IpcHandler {
        target: "filemanager"

        readonly property string _validFifoPrefix: "/tmp/symmetria-picker-"
        property real _lastPickerCallTime: 0
        readonly property int _rateLimitMs: 1000

        function open(initialPath: string): void {
            root.create(initialPath);
        }

        function createPicker(optionsJson: string): void {
            if (root._activePickerWindow) {
                console.warn("FileManager: Picker already active, ignoring request");
                return;
            }

            // Rate limiting — prevent rapid dialog spam
            const now = Date.now();
            if (now - _lastPickerCallTime < _rateLimitMs) {
                console.warn("FileManager: Picker rate-limited, ignoring request");
                return;
            }
            _lastPickerCallTime = now;

            let options;
            try {
                options = JSON.parse(optionsJson);
            } catch (e) {
                console.error("FileManager: Invalid picker options JSON:", e);
                return;
            }

            // 4-layer FIFO path validation (matches askpass pattern)
            const fifoPath = options.fifo || "";
            if (!fifoPath.startsWith(_validFifoPrefix)) {
                console.error("FileManager: Invalid FIFO path prefix:", fifoPath);
                return;
            }
            if (fifoPath.includes("..") || fifoPath.includes("\0")) {
                console.error("FileManager: Suspicious FIFO path rejected:", fifoPath);
                return;
            }
            if (fifoPath.length > 128) {
                console.error("FileManager: FIFO path too long:", fifoPath.substring(0, 50) + "...");
                return;
            }
            const suffix = fifoPath.substring(_validFifoPrefix.length);
            if (!/^[a-zA-Z0-9._-]+$/.test(suffix)) {
                console.error("FileManager: FIFO path contains invalid characters:", fifoPath);
                return;
            }

            FileManagerService.startPickerMode(options);
            root._activePickerWindow = pickerWindow.createObject(dummy);
        }
    }

    // === FIFO communication for picker results ===
    Connections {
        target: FileManagerService

        function onPickerCompleted(fifoPath: string, paths: var): void {
            if (!fifoPath)
                return;

            // Write raw absolute paths — Python backend builds file:// URIs
            const rawPaths = paths.join("\n");
            fifoWriteProcess.fifoPath = fifoPath;
            fifoWriteProcess.payload = rawPaths;
            fifoWriteProcess.running = true;
        }

        function onPickerCancelled(fifoPath: string): void {
            if (!fifoPath)
                return;

            fifoCancelProcess.fifoPath = fifoPath;
            fifoCancelProcess.running = true;
        }
    }

    // Write selected URIs to FIFO (askpass pattern)
    Process {
        id: fifoWriteProcess

        property string fifoPath: ""
        property string payload: ""

        command: ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "--", payload, fifoPath]

        onRunningChanged: {
            if (running) fifoWriteTimeout.start();
            else fifoWriteTimeout.stop();
        }

        onExited: (exitCode, exitStatus) => {
            fifoWriteTimeout.stop();
            if (exitCode !== 0)
                console.error("FileManager: FIFO write failed, exitCode:", exitCode);
            else
                console.log("FileManager: Picker result sent to FIFO");
            root._closePickerWindow();
        }
    }

    Timer {
        id: fifoWriteTimeout
        interval: 5000
        onTriggered: {
            console.error("FileManager: FIFO write timeout — forcing close");
            fifoWriteProcess.signal(9);
            root._closePickerWindow();
        }
    }

    // Write cancellation sentinel to FIFO
    Process {
        id: fifoCancelProcess

        property string fifoPath: ""

        command: ["sh", "-c", "printf '%s' '__PICKER_CANCELLED__' > \"$1\"", "--", fifoPath]

        onRunningChanged: {
            if (running) fifoCancelTimeout.start();
            else fifoCancelTimeout.stop();
        }

        onExited: (exitCode, exitStatus) => {
            fifoCancelTimeout.stop();
            if (exitCode !== 0)
                console.error("FileManager: FIFO cancel write failed, exitCode:", exitCode);
            else
                console.log("FileManager: Picker cancellation sent to FIFO");
            root._closePickerWindow();
        }
    }

    Timer {
        id: fifoCancelTimeout
        interval: 5000
        onTriggered: {
            console.error("FileManager: FIFO cancel timeout — forcing close");
            fifoCancelProcess.signal(9);
            root._closePickerWindow();
        }
    }

    // Setting visible = false triggers onVisibleChanged which nulls
    // _activePickerWindow and calls destroy()
    function _closePickerWindow(): void {
        if (_activePickerWindow)
            _activePickerWindow.visible = false;
    }

    // === Normal file manager window ===
    Component {
        id: fileManagerWindow

        FloatingWindow {
            id: win

            color: Theme.layer(Theme.palette.m3surface, 0)
            title: qsTr("File Manager")

            implicitWidth: Config.fileManager.sizes.windowWidth
            implicitHeight: Config.fileManager.sizes.windowHeight

            minimumSize.width: 600
            minimumSize.height: 400

            onVisibleChanged: {
                if (!visible) {
                    root._activeWindow = null;
                    destroy();
                }
            }

            FileManager {
                id: fm

                anchors.fill: parent

                onCloseRequested: win.visible = false
            }

            Behavior on color {
                CAnim {}
            }
        }
    }

    // === Picker window (portal file chooser) ===
    Component {
        id: pickerWindow

        FloatingWindow {
            id: pickerWin

            color: Theme.layer(Theme.palette.m3surface, 0)
            title: FileManagerService.pickerTitle || qsTr("Select a File")

            implicitWidth: Config.fileManager.sizes.windowWidth
            implicitHeight: Config.fileManager.sizes.windowHeight

            minimumSize.width: 600
            minimumSize.height: 400

            onVisibleChanged: {
                if (!visible) {
                    // If picker mode is still active, user closed the window — cancel
                    if (FileManagerService.pickerMode)
                        FileManagerService.cancelPickerMode();
                    root._activePickerWindow = null;
                    destroy();
                }
            }

            FileManager {
                id: pickerFm

                anchors.fill: parent

                onCloseRequested: {
                    if (FileManagerService.pickerMode)
                        FileManagerService.cancelPickerMode();
                    else
                        pickerWin.visible = false;
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
