#!/bin/bash
# Install the Symmetria XDG Desktop Portal FileChooser backend.
# This replaces the GTK file dialog with the yazi-frontend file manager
# for all applications that use the portal (browsers, Electron, etc.).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Symmetria Portal FileChooser — Installation ==="
echo ""

# 1. Check dbus-fast is available for python3.12 (matches service ExecStart)
if ! python3.12 -c "import dbus_fast" 2>/dev/null; then
    echo "Installing dbus-fast for python3.12..."
    python3.12 -m pip install dbus-fast
fi

# 2. Install portal definition
echo "Installing portal definition..."
sudo cp "$SCRIPT_DIR/symmetria.portal" /usr/share/xdg-desktop-portal/portals/symmetria.portal

# 3. Install D-Bus service file
echo "Installing D-Bus service file..."
sudo cp "$SCRIPT_DIR/org.freedesktop.impl.portal.desktop.symmetria.service" \
    /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.symmetria.service

# 4. Install systemd user service
echo "Installing systemd user service..."
mkdir -p ~/.config/systemd/user
cp "$SCRIPT_DIR/xdg-desktop-portal-symmetria.service" ~/.config/systemd/user/

# 5. Update portals.conf to route FileChooser to our backend
PORTALS_CONF="$HOME/.config/xdg-desktop-portal/portals.conf"
echo "Updating $PORTALS_CONF..."
mkdir -p "$(dirname "$PORTALS_CONF")"
cat > "$PORTALS_CONF" << 'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=symmetria
org.freedesktop.impl.portal.Settings=gtk
EOF

# 6. Reload and restart
echo "Reloading systemd and restarting portal..."
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal

echo ""
echo "=== Installation complete ==="
echo ""
echo "IMPORTANT: Restart your browsers and Electron apps to use the new file picker."
echo "To test: open any file upload dialog in Firefox or Chrome."
echo ""
echo "To uninstall:"
echo "  sudo rm /usr/share/xdg-desktop-portal/portals/symmetria.portal"
echo "  sudo rm /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.symmetria.service"
echo "  rm ~/.config/systemd/user/xdg-desktop-portal-symmetria.service"
echo "  # Restore portals.conf to remove the FileChooser override"
