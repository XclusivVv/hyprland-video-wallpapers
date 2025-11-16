#!/usr/bin/env bash
set -euo pipefail

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== Hyprland Video Wallpapers — UNINSTALLER ===${NC}"
echo

# --- Configuration Paths ---
PROJECT_CONFIG_DIR="${HOME}/.config/hyprland-video-wallpapers"
CONFIG_FILE="${PROJECT_CONFIG_DIR}/config.conf"
HELPER_SCRIPT_NAME="hyprland-video-wallpapers.sh"
HELPER_SCRIPT_PATH="${HOME}/.local/bin/${HELPER_SCRIPT_NAME}"
HYPR_RULES_FILE="hyprland-video-wallpapers.conf"
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"
OPTIMIZER_BIN="${HOME}/.local/bin/hyprland-video-optimizer"
HYPR_CONFIG_DIR="${HOME}/.config/hypr"
KEYBINDS_FILE=""

# 1. Source config to get installation status
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${BLUE}[*] Loading configuration statuses from ${CONFIG_FILE}...${NC}"
    # This sources variables like SOURCE_ADDED, TOGGLEFLOAT_DISABLED, OPTIMIZER_INSTALLED
    source "$CONFIG_FILE"
else
    echo -e "${YELLOW}[!] Configuration file not found. Assuming 'no' for conditional reverts.${NC}"
    SOURCE_ADDED="no"
    TOGGLEFLOAT_DISABLED="no"
    OPTIMIZER_INSTALLED="no"
fi

# 2. Stop running script and video processes
echo -e "${BLUE}[*] Checking for and stopping any running video wallpaper instances...${NC}"

if pgrep -f "${HELPER_SCRIPT_PATH}\|mpv --title=mpv-workspace-video" > /dev/null; then
    echo -e "${YELLOW}[!] Detected running video wallpaper instances. Stopping...${NC}"
    pkill -f "${HELPER_SCRIPT_PATH}" || true
    pkill -f "mpv --title=mpv-workspace-video" || true
    echo -e "${GREEN}[+] Stopped all related processes.${NC}"
else
    echo -e "${GREEN}[+] No related video wallpaper processes were running.${NC}"
fi

# 3. Clean up Hyprland Configuration (source, exec-once, comment block)
echo -e "${BLUE}[*] Cleaning up Hyprland configuration (${HYPR_CONF})...${NC}"

if [ -f "$HYPR_CONF" ]; then
    # Escape forward slashes for sed to work correctly
    ESCAPED_HELPER_PATH=$(echo "$HELPER_SCRIPT_PATH" | sed 's/[\/&]/\\&/g')
    ESCAPED_RULES_FILE="${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}"
    ESCAPED_SOURCE_LINE=$(echo "$ESCAPED_RULES_FILE" | sed 's/[\/&]/\\&/g')

    # Remove the 'source' line (if it was added)
    if [[ "$SOURCE_ADDED" == "yes" ]]; then
        sed -i "/source = ${ESCAPED_SOURCE_LINE}/d" "$HYPR_CONF"
        # Remove the preceding comment block
        sed -i '/# Video wallpapers configuration/d' "$HYPR_CONF"
        echo -e "${GREEN}[+] Removed 'source' line and comment block.${NC}"
    fi

    # Remove the 'exec-once' line (manual instruction, but essential cleanup)
    # This ensures that even if the user added it manually, it is removed.
    sed -i "/exec-once = ${ESCAPED_HELPER_PATH}/d" "$HYPR_CONF"
    echo -e "${GREEN}[+] Removed 'exec-once' autostart line.${NC}"
else
    echo -e "${YELLOW}[!] WARNING: hyprland.conf not found. Manual cleanup may be required.${NC}"
fi

# 4. Restore 'togglefloating' Keybind
if [ "$TOGGLEFLOAT_DISABLED" == "yes" ]; then
    echo -e "${BLUE}[*] Attempting to revert 'togglefloating' keybind change...${NC}"
    
    # Try to find the file where the change was made
    if [[ -f "${HYPR_CONFIG_DIR}/keybindings.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybindings.conf"
    elif [[ -f "${HYPR_CONFIG_DIR}/hyprland.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/hyprland.conf"
    fi

    if [[ -n "$KEYBINDS_FILE" ]]; then
        # Uncomment any line that was previously commented out by the installer
        sed -i 's/^#\([^#]*togglefloating.*\)$/\1/' "$KEYBINDS_FILE"
        echo -e "${GREEN}[+] Restored 'togglefloating' keybind (uncommented).${NC}"
    else
        echo -e "${RED}[!] Keybind file not found. Could not revert 'togglefloating'.${NC}"
    fi
else
    echo -e "${YELLOW}[-] Skipping 'togglefloating' keybind reversion.${NC}"
fi

# 5. Cleanup files
echo -e "${BLUE}[*] Cleaning up installation files...${NC}"

if [ -f "$HELPER_SCRIPT_PATH" ]; then
    rm -f "$HELPER_SCRIPT_PATH"
    echo -e "${GREEN}[+] Removed helper script: ${HELPER_SCRIPT_PATH}${NC}"
fi

if [[ "$OPTIMIZER_INSTALLED" == "yes" ]] && [ -f "$OPTIMIZER_BIN" ]; then
    rm -f "$OPTIMIZER_BIN"
    echo -e "${GREEN}[+] Removed optimizer binary: ${OPTIMIZER_BIN}${NC}"
fi

if [ -d "$PROJECT_CONFIG_DIR" ]; then
    rm -rf "$PROJECT_CONFIG_DIR"
    echo -e "${GREEN}[+] Removed config directory: ${PROJECT_CONFIG_DIR}${NC}"
fi

# Remove temporary mpv sockets (best effort)
rm -f /tmp/mpv-ws-*-ipc || true
echo -e "${GREEN}[+] Cleaned up temporary mpv sockets.${NC}"


echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  UNINSTALLATION COMPLETE!"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "The video wallpaper system has been completely removed."
echo -e "You may need to reload or restart Hyprland for changes to take full effect.${NC}"