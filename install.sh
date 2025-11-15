#!/usr/bin/env bash
set -euo pipefail

echo "=== Hyprland Video Wallpapers — Installer ==="
echo

# Check Hyprland
if ! command -v hyprctl >/dev/null 2>&1; then
  echo "[!] hyprctl not found. Ensure a Hyprland variant is installed."
  read -p "Continue anyway? (y/N) " yn
  case "$yn" in [Yy]*) ;; *) echo "Abort."; exit 1 ;; esac
fi

# Install runtime dependencies if pacman exists
if command -v pacman >/dev/null 2>&1; then
  echo "[+] Installing mpv, socat, jq..."
  sudo pacman -S --needed --noconfirm mpv socat jq
else
  echo "[!] pacman not detected. Install mpv, socat, jq manually."
fi

# Copy script
echo "[+] Installing script to ~/.local/bin"
mkdir -p ~/.local/bin
cp hyprland-video-wallpapers.sh ~/.local/bin/hyprland-video-wallpapers
chmod +x ~/.local/bin/hyprland-video-wallpapers

# Copy config
echo "[+] Copying config to ~/.config/hypr/"
mkdir -p ~/.config/hypr
cp hyprland-video-wallpapers.conf ~/.config/hypr/

# Autostart fragment
echo "[+] Creating autostart fragment"
cat > ~/.config/hypr/workspace-video-autostart.conf <<'EOF'
# Auto-added by installer
exec-once = ~/.local/bin/hyprland-video-wallpapers
EOF

# Optionally disable togglefloating keybind
echo
echo "[!] Important:"
echo "The 'togglefloating' keybind conflicts with per-workspace video wallpapers."
read -p "Would you like to automatically disable it? (y/N) " disable_toggle
if [[ "${disable_toggle,,}" == "y" ]]; then
    HYPR_CONFIG_DIR="${HOME}/.config/hypr"
    KEYBINDS_FILE=""
    if [[ -f "${HYPR_CONFIG_DIR}/keybinds.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybinds.conf"
    else
        if [[ -f "${HYPR_CONFIG_DIR}/hyprland.conf" ]]; then
            KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybinds.conf"
            if [[ ! -f "$KEYBINDS_FILE" ]]; then
                echo "[!] Could not locate keybinds.conf automatically. Skipping this step."
                KEYBINDS_FILE=""
            fi
        fi
    fi

    if [[ -n "$KEYBINDS_FILE" ]]; then
        echo "[+] Disabling 'togglefloating' in $KEYBINDS_FILE..."
        sed -i 's/^\(.*togglefloating.*\)$/#\1/' "$KEYBINDS_FILE"
        echo "[+] togglefloating keybind commented out."
    fi
fi

echo
ec
