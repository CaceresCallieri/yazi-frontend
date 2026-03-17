#!/usr/bin/env bash
# Install yazi-frontend into Symmetria by creating symlinks.
# Idempotent — safe to run multiple times.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYMMETRIA_DIR="$HOME/.config/quickshell/symmetria"

if [[ ! -d "$SYMMETRIA_DIR" ]]; then
    echo "ERROR: Symmetria not found at $SYMMETRIA_DIR"
    exit 1
fi

echo "Installing yazi-frontend into Symmetria..."
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
echo "2. config/Config.qml — register config (see plan Step 12)"
echo
echo "3. modules/Shortcuts.qml — add IPC handler (see plan Step 12)"
echo
echo "4. Clear QML cache:"
echo "   rm -rf ~/.cache/quickshell/qmlcache"
echo
echo "5. Test:"
echo '   qs -c symmetria ipc call filemanager open'
