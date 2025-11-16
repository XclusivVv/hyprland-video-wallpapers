#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
#  HYPRLAND VIDEO WALLPAPERS - Modern Interactive Uninstaller
#  Author: xclusivvvv
#  GitHub: https://github.com/XclusivVv/hyprland-video-wallpapers
#  Discord: xclusivvvv
# ============================================================================

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Unicode Symbols
CHECK='✓'
CROSS='✗'
ARROW='→'
DOT='●'
TRASH='🗑'
INFO='ℹ'
WARN='⚠'
GEAR='⚙'

# Configuration Paths
PROJECT_CONFIG_DIR="${HOME}/.config/hyprland-video-wallpapers"
CONFIG_FILE="${PROJECT_CONFIG_DIR}/config.conf"
HELPER_SCRIPT_NAME="hyprland-video-wallpapers.sh"
HELPER_SCRIPT_PATH="${HOME}/.local/bin/${HELPER_SCRIPT_NAME}"
HYPR_RULES_FILE="hyprland-video-wallpapers.conf"
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"
OPTIMIZER_BIN="${HOME}/.local/bin/hyprland-video-optimizer"
HYPR_CONFIG_DIR="${HOME}/.config/hypr"

# Default tracking values
SOURCE_ADDED="no"
TOGGLEFLOAT_DISABLED="no"
OPTIMIZER_INSTALLED="no"

# ============================================================================
#  UTILITY FUNCTIONS
# ============================================================================

print_header() {
    clear
    echo -e "${RED}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║       HYPRLAND VIDEO WALLPAPERS - UNINSTALLER                 ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_substep() {
    echo -e "${MAGENTA}${BOLD}  ▸ $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK}${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS}${NC} ${RED}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARN}${NC} ${YELLOW}$1${NC}"
}

print_info() {
    echo -e "${CYAN}${INFO}${NC} ${CYAN}$1${NC}"
}

print_item_removed() {
    echo -e "${TRASH}${NC} ${DIM}$1${NC}"
}

pause_for_user() {
    echo -e "\n${DIM}Press Enter to continue...${NC}"
    read -r
}

spinner() {
    local pid=$1
    local msg=$2
    local i=0
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    while kill -0 $pid 2>/dev/null; do
        echo -ne "\r${CYAN}${frames[$((i % ${#frames[@]}))]}${NC} ${msg}..."
        i=$((i + 1))
        sleep 0.1
    done
    echo -ne "\r   \r"
}

# ============================================================================
#  WELCOME SCREEN
# ============================================================================

show_welcome() {
    print_header
    
    echo -e "${BOLD}We're sorry to see you go!${NC}\n"
    echo -e "${DIM}This uninstaller will completely remove all video wallpaper components.${NC}\n"
    
    echo -e "${YELLOW}Created by: ${BOLD}xclusivvvv${NC}"
    echo -e "${CYAN}🔗 GitHub: ${BOLD}https://github.com/XclusivVv/hyprland-video-wallpapers${NC}"
    echo -e "${MAGENTA}💬 Discord: ${BOLD}xclusivvvv${NC}\n"
    
    echo -e "${DIM}═══════════════════════════════════════════════════════════════${NC}\n"
    
    print_warning "This will remove:"
    echo "  • Helper script and configuration"
    echo "  • Hyprland configuration changes"
    echo "  • Window manager settings"
    echo "  • Optional: Video optimizer (if installed)\n"
    
    read -p "Are you sure you want to uninstall? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${CYAN}Uninstall cancelled.${NC}"
        exit 0
    fi
}

# ============================================================================
#  LOAD CONFIGURATION
# ============================================================================

load_configuration() {
    print_section "Loading Configuration"
    
    if [ -f "$CONFIG_FILE" ]; then
        print_success "Configuration file found"
        source "$CONFIG_FILE"
        print_info "Installation status loaded"
    else
        print_warning "Configuration file not found"
        print_info "Using default uninstall settings"
    fi
    
    pause_for_user
}

# ============================================================================
#  STOP PROCESSES
# ============================================================================

stop_processes() {
    print_section "Stopping Video Wallpapers"
    
    print_substep "Checking for running instances..."
    
    if pgrep -f "${HELPER_SCRIPT_PATH}\|mpv --title=mpv-workspace-video" > /dev/null; then
        print_warning "Detected running video wallpaper processes"
        
        print_substep "Stopping helper script..."
        pkill -f "${HELPER_SCRIPT_PATH}" || true
        print_success "Helper script stopped"
        
        print_substep "Stopping MPV instances..."
        pkill -f "mpv --title=mpv-workspace-video" || true
        print_success "MPV instances stopped"
    else
        print_success "No running processes detected"
    fi
    
    sleep 1
    pause_for_user
}

# ============================================================================
#  CLEANUP HYPRLAND CONFIGURATION
# ============================================================================

cleanup_hyprland_config() {
    print_section "Cleaning Hyprland Configuration"
    
    if [ ! -f "$HYPR_CONF" ]; then
        print_warning "hyprland.conf not found"
        return
    fi
    
    print_success "Found hyprland.conf"
    
    # Remove source line
    if [[ "$SOURCE_ADDED" == "yes" ]]; then
        print_substep "Removing source line..."
        
        local ESCAPED_RULES_FILE="${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}"
        ESCAPED_RULES_FILE=$(echo "$ESCAPED_RULES_FILE" | sed 's/[\/&]/\\&/g')
        
        sed -i "/source = ${ESCAPED_RULES_FILE}/d" "$HYPR_CONF"
        sed -i '/# Video wallpapers configuration/d' "$HYPR_CONF"
        print_item_removed "Source line removed"
    fi
    
    # Remove exec-once line
    print_substep "Removing exec-once line..."
    local ESCAPED_HELPER=$(echo "$HELPER_SCRIPT_PATH" | sed 's/[\/&]/\\&/g')
    sed -i "/exec-once = ${ESCAPED_HELPER}/d" "$HYPR_CONF"
    print_item_removed "Exec-once line removed"
    
    print_success "Hyprland configuration cleaned"
    pause_for_user
}

# ============================================================================
#  RESTORE KEYBINDS
# ============================================================================

restore_keybinds() {
    print_section "Restoring Keybinds"
    
    if [[ "$TOGGLEFLOAT_DISABLED" != "yes" ]]; then
        print_info "Togglefloating was not disabled by installer"
        pause_for_user
        return
    fi
    
    print_substep "Searching for keybind configuration..."
    
    local KEYBINDS_FILE=""
    
    if [[ -f "${HYPR_CONFIG_DIR}/keybindings.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybindings.conf"
    elif [[ -f "${HYPR_CONFIG_DIR}/hyprland.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/hyprland.conf"
    fi

    if [[ -n "$KEYBINDS_FILE" ]]; then
        print_success "Found: $KEYBINDS_FILE"
        print_substep "Restoring togglefloating keybind..."
        
        # Uncomment any lines that were previously commented out by the installer
        sed -i 's/^#\([^#]*togglefloating.*\)$/\1/' "$KEYBINDS_FILE"
        print_item_removed "Togglefloating restored"
        
        print_success "Keybinds restored"
    else
        print_error "Keybind file not found"
        print_info "You may need to manually restore togglefloating keybind"
    fi
    
    pause_for_user
}

# ============================================================================
#  CLEANUP FILES
# ============================================================================

cleanup_files() {
    print_section "Removing Installation Files"
    
    # Remove helper script
    if [ -f "$HELPER_SCRIPT_PATH" ]; then
        print_substep "Removing helper script..."
        rm -f "$HELPER_SCRIPT_PATH"
        print_item_removed "Removed: $HELPER_SCRIPT_PATH"
    fi
    
    # Remove optimizer (if installed)
    if [[ "$OPTIMIZER_INSTALLED" == "yes" ]] && [ -f "$OPTIMIZER_BIN" ]; then
        print_substep "Removing video optimizer..."
        rm -f "$OPTIMIZER_BIN"
        print_item_removed "Removed: $OPTIMIZER_BIN"
    fi
    
    # Remove config directory
    if [ -d "$PROJECT_CONFIG_DIR" ]; then
        print_substep "Removing configuration directory..."
        rm -rf "$PROJECT_CONFIG_DIR"
        print_item_removed "Removed: $PROJECT_CONFIG_DIR"
    fi
    
    # Remove temporary MPV sockets
    print_substep "Cleaning temporary MPV sockets..."
    rm -f /tmp/mpv-ws-*-ipc 2>/dev/null || true
    print_item_removed "Temporary sockets cleaned"
    
    print_success "All installation files removed"
    pause_for_user
}

# ============================================================================
#  COMPLETION SCREEN
# ============================================================================

show_completion() {
    print_section "Uninstallation Complete!"
    
    echo -e "${GREEN}${BOLD}✓ Hyprland Video Wallpapers has been successfully removed.${NC}\n"
    
    echo -e "${BOLD}What to do next:${NC}\n"
    echo "  1. Reload Hyprland to apply changes:"
    echo -e "     ${CYAN}Super + Shift + R${NC}\n"
    echo "  2. Your windows should now display normally\n"
    
    echo -e "${BOLD}Before you go:${NC}\n"
    echo -e "  We'd love to hear your feedback! If you encountered any issues,"
    echo -e "  please let us know on GitHub or Discord.\n"
    
    echo -e "${CYAN}🔗 GitHub: https://github.com/XclusivVv/hyprland-video-wallpapers${NC}"
    echo -e "${MAGENTA}💬 Discord: xclusivvvv${NC}\n"
    
    echo -e "${DIM}Thanks for using Hyprland Video Wallpapers!${NC}\n"
}

# ============================================================================
#  SUMMARY SCREEN
# ============================================================================

show_summary() {
    print_section "Uninstall Summary"
    
    echo -e "${BOLD}What will be removed:${NC}\n"
    
    if [ -f "$HELPER_SCRIPT_PATH" ]; then
        echo "  ${TRASH} Helper script"
    fi
    
    if [ -d "$PROJECT_CONFIG_DIR" ]; then
        echo "  ${TRASH} Configuration directory"
    fi
    
    if [[ "$TOGGLEFLOAT_DISABLED" == "yes" ]]; then
        echo "  ${TRASH} Togglefloating keybind modifications"
    fi
    
    if [ -f "$HYPR_CONF" ]; then
        echo "  ${TRASH} Hyprland configuration changes"
    fi
    
    if [[ "$OPTIMIZER_INSTALLED" == "yes" ]] && [ -f "$OPTIMIZER_BIN" ]; then
        echo "  ${TRASH} Video optimizer (optional)"
    fi
    
    echo "  ${TRASH} Temporary MPV sockets"
    echo ""
    
    read -p "Proceed with uninstallation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi
}

# ============================================================================
#  MAIN FLOW
# ============================================================================

main() {
    show_welcome
    load_configuration
    show_summary
    stop_processes
    cleanup_hyprland_config
    restore_keybinds
    cleanup_files
    show_completion
}

main