#!/usr/bin/env bash
# Install Symmetria File Manager in standalone or Symmetria-integrated mode.
# Idempotent — safe to run multiple times.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYMMETRIA_DIR="$HOME/.config/quickshell/symmetria"
STANDALONE_DIR="$HOME/.config/quickshell/symmetria-fm"

usage() {
    echo "Usage: $0 [--standalone | --symmetria]"
    echo
    echo "  --standalone   (default) Symlink project for 'qs -c symmetria-fm'"
    echo "  --symmetria    Symlink into Symmetria shell for integrated mode"
    exit 1
}

MODE="${1:---standalone}"

case "$MODE" in
    --standalone)
        echo "Installing Symmetria File Manager in standalone mode..."
        echo "  Project:   $PROJECT_DIR"
        echo "  Target:    $STANDALONE_DIR"
        echo

        ln -sfn "$PROJECT_DIR" "$STANDALONE_DIR"
        echo "  Linked $STANDALONE_DIR → $PROJECT_DIR"

        # Install icon to XDG icon directory
        ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
        mkdir -p "$ICON_DIR"
        cp "$PROJECT_DIR/assets/symmetria-fm.png" "$ICON_DIR/"
        echo "  Installed icon → $ICON_DIR/symmetria-fm.png"

        # Install .desktop file
        DESKTOP_DIR="$HOME/.local/share/applications"
        mkdir -p "$DESKTOP_DIR"
        cp "$PROJECT_DIR/symmetria-fm.desktop" "$DESKTOP_DIR/"
        echo "  Installed desktop entry → $DESKTOP_DIR/symmetria-fm.desktop"

        # Update icon and desktop entry caches
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

        echo
        echo "Done. Run with:"
        echo "  qs -c symmetria-fm"
        echo
        echo "Or for development (clears QML cache):"
        echo "  ./run.sh"
        ;;

    --symmetria)
        # Icon and .desktop installation are intentionally omitted here;
        # integrated mode relies on the parent Symmetria Shell's own launcher setup.
        if [[ ! -d "$SYMMETRIA_DIR" ]]; then
            echo "ERROR: Symmetria not found at $SYMMETRIA_DIR"
            exit 1
        fi

        echo "Installing Symmetria File Manager into Symmetria Shell..."
        echo "  Project:   $PROJECT_DIR"
        echo "  Symmetria: $SYMMETRIA_DIR"
        echo

        # Module directory (entire dir as one symlink)
        ln -sfn "$PROJECT_DIR/modules/filemanager" "$SYMMETRIA_DIR/modules/filemanager"
        echo "  Linked modules/filemanager/"

        # Service singleton
        ln -sfn "$PROJECT_DIR/services/FileManagerService.qml" "$SYMMETRIA_DIR/services/FileManagerService.qml"
        echo "  Linked services/FileManagerService.qml"

        # Config object
        ln -sfn "$PROJECT_DIR/config/FileManagerConfig.qml" "$SYMMETRIA_DIR/config/FileManagerConfig.qml"
        echo "  Linked config/FileManagerConfig.qml"

        echo
        echo "Symlinks created. Now apply these manual edits:"
        echo
        echo "1. shell.qml — add import and component:"
        echo '   import "modules/filemanager"'
        echo '   // inside ShellRoot:'
        echo '   FileManagerModule {}'
        echo
        echo "2. config/Config.qml — register FileManagerConfig"
        echo
        echo "3. modules/Shortcuts.qml — add IPC handler"
        echo
        echo "4. Clear QML cache:"
        echo "   rm -rf ~/.cache/quickshell/qmlcache"
        echo
        echo "5. Test:"
        echo '   qs -c symmetria ipc call filemanager open'
        ;;

    *)
        usage
        ;;
esac
