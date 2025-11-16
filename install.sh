#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
#  HYPRLAND VIDEO WALLPAPERS - Modern Interactive Installer
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
STAR='★'
INFO='ℹ'
WARN='⚠'
GEAR='⚙'
FOLDER='📁'
FILM='🎬'

# Global State
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE_VIDEOS_DIR="${SCRIPT_DIR}/sample_videos"
PROJECT_CONFIG_DIR="${HOME}/.config/hyprland-video-wallpapers"
CONFIG_FILE="${PROJECT_CONFIG_DIR}/config.conf"
HELPER_SCRIPT_NAME="hyprland-video-wallpapers.sh"
HELPER_SCRIPT_PATH="${HOME}/.local/bin/${HELPER_SCRIPT_NAME}"
HYPR_RULES_FILE="hyprland-video-wallpapers.conf"
OPTIMIZER_BIN="${HOME}/.local/bin/hyprland-video-optimizer"
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"

# Setup variables
NUM_WORKSPACES=0
TOP_GAP=30
GAP_SIZE=15
VIDEO_DIR=""
declare -a VIDEO_FILES
declare -a WORKSPACE_VIDEOS
VIDEO_SOURCE="custom"
OPTIMIZER_INSTALLED_STATUS="no"
SOURCE_ADDED_STATUS="no"
TOGGLEFLOAT_DISABLED_STATUS="no"

# ============================================================================
#  UTILITY FUNCTIONS
# ============================================================================

print_header() {
    clear
    printf "%b" "${CYAN}${BOLD}"
    printf "╔════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                ║\n"
    printf "║          HYPRLAND VIDEO WALLPAPERS - INSTALLER                ║\n"
    printf "║                                                                ║\n"
    printf "╚════════════════════════════════════════════════════════════════╝\n"
    printf "%b" "${NC}"
}

print_section() {
    printf "\n%b" "${BLUE}${BOLD}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  %b\n" "$1${NC}"
    printf "%b" "${BLUE}${BOLD}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "%b\n" "${NC}"
}

print_substep() {
    printf "%b" "${MAGENTA}${BOLD}"
    printf "  ▸ %b\n" "$1${NC}"
}

print_success() {
    printf "%b" "${GREEN}${CHECK}${NC} ${GREEN}"
    printf "%b\n" "$1${NC}"
}

print_error() {
    printf "%b" "${RED}${CROSS}${NC} ${RED}"
    printf "%b\n" "$1${NC}"
}

print_warning() {
    printf "%b" "${YELLOW}${WARN}${NC} ${YELLOW}"
    printf "%b\n" "$1${NC}"
}

print_info() {
    printf "%b" "${CYAN}${INFO}${NC} ${CYAN}"
    printf "%b\n" "$1${NC}"
}

pause_for_user() {
    printf "\n%b" "${DIM}"
    printf "Press Enter to continue..."
    printf "%b\n" "${NC}"
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

format_size() {
    local bytes=$1
    if (( bytes < 1048576 )); then
        echo "$((bytes / 1024)) KB"
    else
        echo "$((bytes / 1048576)) MB"
    fi
}

clean_video_name() {
    local name="$1"
    name="${name//_optimized/}"
    name="${name//_compressed/}"
    name="${name%.mp4}"
    name="${name%.mkv}"
    echo "$name" | sed 's/\b\(.\)/\U\1/g' | sed 's/-/ /g'
}

# ============================================================================
#  WELCOME SCREEN
# ============================================================================

show_welcome() {
    print_header
    
    printf "%b" "${BOLD}"
    printf "Welcome to Hyprland Video Wallpapers!\n\n"
    printf "%b" "${NC}${DIM}"
    printf "A modern solution to bring animated wallpapers to your Hyprland desktop.\n\n"
    printf "%b" "${NC}"
    
    printf "%b" "${YELLOW}"
    printf "Created by: "
    printf "%b" "${BOLD}xclusivvvv${NC}\n"
    printf "%b" "${CYAN}"
    printf "🔗 GitHub: "
    printf "%b" "${BOLD}https://github.com/XclusivVv/hyprland-video-wallpapers${NC}\n"
    printf "%b" "${MAGENTA}"
    printf "💬 Discord: "
    printf "%b" "${BOLD}xclusivvvv${NC}\n\n"
    
    printf "%b" "${DIM}"
    printf "═══════════════════════════════════════════════════════════════\n\n"
    printf "%b" "${NC}"
    
    printf "This installer will guide you through:\n"
    printf "  %b Checking system requirements\n" "${CHECK}"
    printf "  %b Selecting your video wallpapers\n" "${CHECK}"
    printf "  %b Configuring workspace settings\n" "${CHECK}"
    printf "  %b Installing everything for you\n\n" "${CHECK}"
    
    print_warning "Before we begin, make sure to close all open windows!"
    print_info "Your existing windows will be temporarily moved during setup.\n"
    
    read -p "Ready to get started? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "\n%b\n" "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
}

# ============================================================================
#  SETUP MODE SELECTION
# ============================================================================

setup_mode_menu() {
    print_section "Installation Mode"
    
    printf "How would you like to set up your wallpapers?\n"
    printf "\n"
    printf "  %b1)%b %bExpress Setup%b\n" "${BOLD}" "${NC}" "${GREEN}" "${NC}"
    printf "     %bQuick installation with recommended defaults%b\n" "${DIM}" "${NC}"
    printf "\n"
    printf "  %b2)%b %bCustom Setup%b\n" "${BOLD}" "${NC}" "${CYAN}" "${NC}"
    printf "     %bFull control over all settings%b\n" "${DIM}" "${NC}"
    printf "\n"
    
    read -p "Select mode (1-2): " setup_mode
    
    case $setup_mode in
        1) return 0 ;;
        2) return 1 ;;
        *) 
            print_error "Invalid selection"
            pause_for_user
            setup_mode_menu
            ;;
    esac
}

# ============================================================================
#  PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local all_ok=true
    
    if command -v hyprctl >/dev/null 2>&1; then
        print_success "Hyprland detected"
    else
        print_error "Hyprland not found"
        print_info "Please ensure Hyprland is installed"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    for cmd in mpv socat jq; do
        if command -v $cmd >/dev/null 2>&1; then
            print_success "$cmd installed"
        else
            print_warning "$cmd not found"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = false ]; then
        echo ""
        if command -v pacman >/dev/null 2>&1; then
            read -p "Install missing dependencies with pacman? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo pacman -S --needed --noconfirm mpv socat jq &
                local pid=$!
                spinner $pid "Installing dependencies"
                wait $pid
                print_success "Dependencies installed"
            fi
        else
            print_warning "Please install mpv, socat, and jq manually"
        fi
    fi
    
    pause_for_user
}

# ============================================================================
#  VIDEO SOURCE SELECTION
# ============================================================================

select_video_source() {
    print_section "Video Source Selection"
    
    local has_samples=false
    [ -d "$SAMPLE_VIDEOS_DIR" ] && [ "$(ls -A "$SAMPLE_VIDEOS_DIR" 2>/dev/null | wc -l)" -gt 0 ] && has_samples=true
    
    if [ "$has_samples" = true ]; then
        printf "Choose your video source:\n"
        printf "\n"
        printf "  %b1)%b %bUse Sample Videos%b\n" "${BOLD}" "${NC}" "${GREEN}" "${NC}"
        printf "     %b30+ pre-optimized, high-quality wallpapers%b\n" "${DIM}" "${NC}"
        printf "     %bPerfect for quick setup and testing%b\n" "${DIM}" "${NC}"
        printf "\n"
        printf "  %b2)%b %bUse My Own Videos%b\n" "${BOLD}" "${NC}" "${CYAN}" "${NC}"
        printf "     %bBring your own video files%b\n" "${DIM}" "${NC}"
        printf "\n"
        
        read -p "Select option (1-2): " video_choice
        
        case $video_choice in
            1)
                VIDEO_SOURCE="sample"
                VIDEO_DIR="$SAMPLE_VIDEOS_DIR"
                load_sample_videos
                ;;
            2)
                VIDEO_SOURCE="custom"
                prompt_custom_video_dir
                ;;
            *)
                print_error "Invalid selection"
                pause_for_user
                select_video_source
                ;;
        esac
    else
        print_info "No sample videos found. Using custom video directory."
        VIDEO_SOURCE="custom"
        prompt_custom_video_dir
    fi
}

load_sample_videos() {
    print_section "Loading Sample Videos"
    
    mapfile -t VIDEO_FILES < <(find "$SAMPLE_VIDEOS_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" \) | sort)
    
    if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
        print_error "No video files found in sample directory"
        exit 1
    fi
    
    print_success "Found ${#VIDEO_FILES[@]} sample videos"
    printf "\n"
    
    local i=1
    for video in "${VIDEO_FILES[@]}"; do
        local name=$(clean_video_name "$(basename "$video")")
        local size=$(stat -f%z "$video" 2>/dev/null || stat -c%s "$video" 2>/dev/null)
        local size_fmt=$(format_size $size)
        printf "  %b %-35s [%-8s]\n" "${FILM}" "$name" "$size_fmt"
    done
    printf "\n"
    
    pause_for_user
}

prompt_custom_video_dir() {
    print_section "Custom Video Directory"
    
    while true; do
        printf "Enter the path to your video directory:\n"
        read -p "${ARROW} " VIDEO_DIR
        
        VIDEO_DIR="${VIDEO_DIR/#\~/$HOME}"
        
        if [ ! -d "$VIDEO_DIR" ]; then
            print_error "Directory not found: $VIDEO_DIR"
            continue
        fi
        
        mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" \) | sort)
        
        if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
            print_error "No .mp4 or .mkv files found"
            continue
        fi
        
        print_success "Found ${#VIDEO_FILES[@]} video files"
        break
    done
    
    pause_for_user
}

# ============================================================================
#  WORKSPACE CONFIGURATION
# ============================================================================

configure_workspaces() {
    print_section "Workspace Configuration"
    
    printf "How many workspaces would you like to configure?\n"
    printf "%b(Recommended: 5 for most users)%b\n" "${DIM}" "${NC}"
    printf "\n"
    
    while true; do
        read -p "${ARROW} Enter number (1-10): " NUM_WORKSPACES
        
        if [[ "$NUM_WORKSPACES" =~ ^[0-9]+$ ]] && [ "$NUM_WORKSPACES" -ge 1 ] && [ "$NUM_WORKSPACES" -le 10 ]; then
            print_success "Configured for $NUM_WORKSPACES workspaces"
            break
        else
            print_error "Please enter a number between 1 and 10"
        fi
    done
    
    pause_for_user
}

configure_gaps() {
    print_section "Gap Configuration"
    
    printf "Configure spacing for your windows:\n"
    printf "%b(Gaps create space around windows and between elements)%b\n" "${DIM}" "${NC}"
    printf "\n"
    
    while true; do
        printf "%bTop gap (for waybar/status bar):%b\n" "${DIM}" "${NC}"
        read -p "${ARROW} Pixels (recommended: 30): " TOP_GAP
        
        if [[ "$TOP_GAP" =~ ^[0-9]+$ ]]; then
            print_success "Top gap set to ${TOP_GAP}px"
            break
        else
            print_error "Please enter a valid number"
        fi
    done
    
    printf "\n"
    
    while true; do
        printf "%bGap around windows:%b\n" "${DIM}" "${NC}"
        read -p "${ARROW} Pixels (recommended: 15): " GAP_SIZE
        
        if [[ "$GAP_SIZE" =~ ^[0-9]+$ ]]; then
            print_success "Window gap set to ${GAP_SIZE}px"
            break
        else
            print_error "Please enter a valid number"
        fi
    done
    
    pause_for_user
}

# ============================================================================
#  VIDEO SELECTION FOR WORKSPACES
# ============================================================================

select_videos_for_workspaces() {
    print_section "Select Videos for Workspaces"
    
    printf "Choose a video for each workspace:\n"
    printf "\n"
    
    for i in "${!VIDEO_FILES[@]}"; do
        local name=$(clean_video_name "$(basename "${VIDEO_FILES[$i]}")")
        printf "  %b%2d)%b %s\n" "${BOLD}" "$((i+1))" "${NC}" "$name"
    done
    
    printf "\n"
    
    for ((ws=1; ws<=NUM_WORKSPACES; ws++)); do
        while true; do
            read -p "Workspace $ws: " video_num
            
            if [[ "$video_num" =~ ^[0-9]+$ ]] && [ "$video_num" -ge 1 ] && [ "$video_num" -le ${#VIDEO_FILES[@]} ]; then
                WORKSPACE_VIDEOS[$ws]="${VIDEO_FILES[$((video_num-1))]}"
                local name=$(clean_video_name "$(basename "${WORKSPACE_VIDEOS[$ws]}")")
                print_success "Workspace $ws: $name"
                break
            else
                print_error "Please enter a number between 1 and ${#VIDEO_FILES[@]}"
            fi
        done
    done
    
    pause_for_user
}

# ============================================================================
#  REVIEW SCREEN
# ============================================================================

show_review() {
    print_section "Review Configuration"
    
    printf "%bYour Setup:%b\n\n" "${BOLD}" "${NC}"
    
    printf "  %b Workspaces: %b%s%b\n" "${GEAR}" "${BOLD}" "$NUM_WORKSPACES" "${NC}"
    printf "  %b Top Gap: %b${TOP_GAP}px%b\n" "${GEAR}" "${BOLD}" "${NC}"
    printf "  %b Window Gap: %b${GAP_SIZE}px%b\n" "${GEAR}" "${BOLD}" "${NC}"
    printf "  %b Video Source: %b$([ "$VIDEO_SOURCE" = "sample" ] && echo "Sample Videos" || echo "Custom Directory")%b\n" "${GEAR}" "${BOLD}" "${NC}"
    printf "\n"
    
    printf "%bWorkspace Assignments:%b\n\n" "${BOLD}" "${NC}"
    for ((ws=1; ws<=NUM_WORKSPACES; ws++)); do
        local name=$(clean_video_name "$(basename "${WORKSPACE_VIDEOS[$ws]}")")
        printf "  Workspace %d: %b%s%b\n" "$ws" "${BOLD}" "$name" "${NC}"
    done
    
    printf "\n"
    print_warning "Important: Close all windows before continuing!"
    printf "\n"
    
    read -p "Proceed with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "\n%b\n" "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
}

# ============================================================================
#  INSTALLATION
# ============================================================================

install_optimizer() {
    local OPTIMIZER_REPO="https://github.com/XclusivVv/hyprland-video-optimizer.git"
    local TEMP_DIR
    
    print_substep "Cloning hyprland-video-optimizer repository..."
    
    if ! command -v git >/dev/null 2>&1; then
        print_error "git not found. Cannot install optimizer."
        return 1
    fi

    TEMP_DIR=$(mktemp -d)
    
    if git clone "$OPTIMIZER_REPO" "$TEMP_DIR" &>/dev/null; then
        if [ -f "${TEMP_DIR}/hyprland-video-optimizer.sh" ]; then
            mkdir -p "$(dirname "$OPTIMIZER_BIN")"
            cp "${TEMP_DIR}/hyprland-video-optimizer.sh" "${OPTIMIZER_BIN}"
            chmod +x "${OPTIMIZER_BIN}"
            print_success "hyprland-video-optimizer installed"
            rm -rf "$TEMP_DIR"
            return 0
        else
            print_error "Could not find optimizer script in repository"
        fi
    else
        print_error "Failed to clone repository"
    fi
    
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    return 1
}

install_helper_script() {
    print_substep "Installing helper script..."
    mkdir -p ~/.local/bin
    
    cat > "$HELPER_SCRIPT_PATH" <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/hyprland-video-wallpapers/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE" >&2
    exit 1
fi
source "$CONFIG_FILE"

MPV_WINDOW_CLASS="mpv-workspace-video"
MPV_BASE_SOCKET="/tmp/mpv-ws"

get_socket_path() {
    echo "${MPV_BASE_SOCKET}-$1-ipc"
}

get_window_title() {
    echo "${MPV_WINDOW_CLASS}-$1"
}

send_mpv_command() {
    local workspace_id="$1"
    local command_json="$2"
    local socket_path=$(get_socket_path "$workspace_id")
    
    if [ -S "$socket_path" ]; then
        echo "$command_json" | socat - "$socket_path" > /dev/null 2>&1
    fi 
}

start_all_mpv() {
    echo "Starting MPV instances for all defined workspaces..."
    
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
    read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"

    for entry in "${VIDEO_MAP[@]}"; do
        IFS=':' read -r ws_id video_path <<< "$entry"
        
        local window_title=$(get_window_title "$ws_id")
        local socket_path=$(get_socket_path "$ws_id")
        
        rm -f "$socket_path"

        mpv \
            --no-osc --no-stop-screensaver \
            --input-ipc-server="$socket_path" \
            --loop --video-sync=display-resample \
            --title="$window_title" \
            --geometry="${SCREEN_WIDTH}x${SCREEN_HEIGHT}+0+0" \
            "$video_path" &
        
        sleep 2.0
        
        hyprctl dispatch movetoworkspace "$ws_id,title:$window_title" > /dev/null 2>&1
        sleep 0.5
        
        hyprctl dispatch focuswindow "title:$window_title" > /dev/null 2>&1
        hyprctl dispatch layoutmsg "focusmaster master" > /dev/null 2>&1
        hyprctl dispatch splitratio exact 1.0 > /dev/null 2>&1
        
        echo "  → Started video for Workspace $ws_id"
        send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
    done
}

pseudo_tile_workspace() {
    local ws_id="$1"
    
    local windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ws_id and .floating == true and (.title | test(\"^mpv-workspace-video\") | not)) | .address")
    
    local win_array=()
    while IFS= read -r addr; do
        [[ -n "$addr" ]] && win_array+=("$addr")
    done <<< "$windows"
    
    local win_count=${#win_array[@]}
    [[ $win_count -eq 0 ]] && return
    
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
    read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"
    
    local usable_width=$((SCREEN_WIDTH - GAP_SIZE * 2))
    local usable_height=$((SCREEN_HEIGHT - TOP_GAP - GAP_SIZE * 2))
    local start_y=$((GAP_SIZE + TOP_GAP))
    
    case $win_count in
        1)
            hyprctl dispatch resizewindowpixel "exact $usable_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            ;;
        2)
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            ;;
        3)
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            local half_height_gap=$((start_y + half_height + GAP_SIZE))
            
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $half_height_gap,address:${win_array[2]}" > /dev/null 2>&1
            ;;
        4)
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            local half_height_gap=$((start_y + half_height + GAP_SIZE))
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $half_height_gap,address:${win_array[2]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[3]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $half_height_gap,address:${win_array[3]}" > /dev/null 2>&1
            ;;
        *)
            local cols=3
            local rows=$(( (win_count + cols - 1) / cols ))
            local win_width=$(( (usable_width - GAP_SIZE * (cols - 1)) / cols ))
            local win_height=$(( (usable_height - GAP_SIZE * (rows - 1)) / rows ))
            
            for i in "${!win_array[@]}"; do
                local col=$((i % cols))
                local row=$((i / cols))
                local x=$((GAP_SIZE + col * (win_width + GAP_SIZE)))
                
                if [ $row -eq 0 ]; then
                    local y=$start_y
                else
                    local y=$((start_y + row * (win_height + GAP_SIZE)))
                fi
                
                hyprctl dispatch resizewindowpixel "exact $win_width $win_height,address:${win_array[$i]}" > /dev/null 2>&1
                hyprctl dispatch movewindowpixel "exact $x $y,address:${win_array[$i]}" > /dev/null 2>&1
            done
            ;;
    esac
}

HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE"
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instance -j 2>&1 | jq -r '.instanceSignature' 2>/dev/null || echo "")
fi

SEARCH_PATHS=("/tmp/hypr/" "$XDG_RUNTIME_DIR/hypr/")
ACTUAL_SOCKET_PATH=""
for PATH_TO_SEARCH in "${SEARCH_PATHS[@]}"; do
    if [ -d "$PATH_TO_SEARCH" ]; then
        FOUND_PATH=$(find "$PATH_TO_SEARCH" -type s -name ".socket2*" 2>/dev/null | head -n 1)
        if [ -S "$FOUND_PATH" ]; then
            ACTUAL_SOCKET_PATH="$FOUND_PATH"
            break
        fi
    fi
done

if [ -S "$ACTUAL_SOCKET_PATH" ]; then
    HYPRLAND_EVENT_SOCKET="$ACTUAL_SOCKET_PATH"
else
    HYPRLAND_EVENT_SOCKET="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2"
fi

cleanup() {
    echo -e "\nExiting script and closing all active video wallpapers..."
    pkill -f "mpv --title=${MPV_WINDOW_CLASS}" || true 
    exit 0
}
trap cleanup EXIT

pkill -f "mpv --title=${MPV_WINDOW_CLASS}" || true 

if [ "$TEMP_WORKSPACE_ID" -le 10 ]; then
    echo "Moving existing windows to temporary Workspace $TEMP_WORKSPACE_ID..."
    declare -A SAVED_WINDOWS
    COUNT_MOVED=0
    
    while IFS='|' read -r address workspace_id; do
        if [[ -n "$address" ]] && [[ "$workspace_id" =~ ^[0-9]+$ ]] && [ "$workspace_id" -ge 1 ] && [ "$workspace_id" -le "$NUM_WORKSPACES" ]; then
            SAVED_WINDOWS["$address"]="$workspace_id"
            hyprctl dispatch movetoworkspacesilent "$TEMP_WORKSPACE_ID,address:$address" > /dev/null 2>&1
            COUNT_MOVED=$((COUNT_MOVED + 1))
        fi
    done < <(hyprctl clients -j | jq -r '.[] | select(.title | test("^mpv-workspace-video") | not and .workspace.id != -1) | "\(.address)|\(.workspace.id)"')
    
    echo "Saved and moved $COUNT_MOVED windows to temporary workspace $TEMP_WORKSPACE_ID."
else
    echo "Skipping window movement: TEMP_WORKSPACE_ID ($TEMP_WORKSPACE_ID) is outside range 1-10."
fi

start_all_mpv

echo "Waiting for video wallpapers to initialize..."
sleep 3

if [ "$TEMP_WORKSPACE_ID" -le 10 ]; then
    echo "Restoring windows from temporary workspace..."
    for address in "${!SAVED_WINDOWS[@]}"; do
        original_ws="${SAVED_WINDOWS[$address]}"
        hyprctl dispatch movetoworkspacesilent "$original_ws,address:$address" > /dev/null 2>&1
        echo "  → Restored window $address to workspace $original_ws"
    done
fi

sleep 1.0

echo "Applying window tiling..."
for ws_id in $(echo "${SAVED_WINDOWS[@]}" | tr ' ' '\n' | sort -u); do
    if [[ "$ws_id" =~ ^[0-9]+$ ]]; then
        sleep 0.2
        pseudo_tile_workspace "$ws_id"
    fi
done

CURRENT_WORKSPACE=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
if [[ $CURRENT_WORKSPACE ]]; then
    send_mpv_command "$CURRENT_WORKSPACE" '{"command":["set_property","pause",false]}'
    echo "Initial state: Video on Workspace $CURRENT_WORKSPACE is playing."
fi

echo "Starting listener for Hyprland workspace events on $HYPRLAND_EVENT_SOCKET..."

declare -A WORKSPACE_WINDOWS

socat -u UNIX-CONNECT:"$HYPRLAND_EVENT_SOCKET" - | while IFS= read -r event; do
    
    if [[ $event == workspace* ]]; then
        CURRENT_WORKSPACE=${event#workspace>>}
        
        if [[ "$CURRENT_WORKSPACE" =~ ^[0-9]+$ ]]; then
            for entry in "${VIDEO_MAP[@]}"; do
                IFS=':' read -r ws_id video_path <<< "$entry"
                
                if [ "$ws_id" == "$CURRENT_WORKSPACE" ]; then
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",false]}'
                else
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
                fi
            done
        fi
    fi
    
    if [[ $event == openwindow* ]]; then
        NEW_WINDOW_ADDR=$(echo "$event" | cut -d'>' -f3 | cut -d',' -f1)
        
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
            read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"
            
            local default_width=$((SCREEN_WIDTH - GAP_SIZE * 2))
            local default_height=$((SCREEN_HEIGHT - TOP_GAP - GAP_SIZE))
            
            hyprctl dispatch resizewindowpixel "exact $default_width $default_height,address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $TOP_GAP,address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            
            sleep 0.2
            pseudo_tile_workspace "$CURRENT_WS"
        fi
    fi
    
    if [[ $event == closewindow* ]]; then
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            sleep 0.1
            pseudo_tile_workspace "$CURRENT_WS"
        fi
    fi

done
SCRIPT_EOF

    chmod +x "$HELPER_SCRIPT_PATH"
    print_success "Helper script installed"
}

configure_hyprland() {
    print_substep "Configuring Hyprland..."
    
    if [ -f "$HYPR_CONF" ]; then
        print_success "Found hyprland.conf"
        
        if grep -q "source.*${HYPR_RULES_FILE}" "$HYPR_CONF"; then
            print_info "Source line already exists in hyprland.conf"
            SOURCE_ADDED_STATUS="yes"
        else
            echo "" >> "$HYPR_CONF"
            echo "# Video wallpapers configuration" >> "$HYPR_CONF"
            echo "source = ${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}" >> "$HYPR_CONF"
            print_success "Added source line to hyprland.conf"
            SOURCE_ADDED_STATUS="yes"
        fi
    else
        print_error "hyprland.conf not found"
        print_info "You'll need to manually add: source = ${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}"
    fi
}

disable_togglefloating() {
    print_substep "Disabling togglefloating keybind..."
    
    local HYPR_CONFIG_DIR="${HOME}/.config/hypr"
    local KEYBINDS_FILE=""
    
    if [[ -f "${HYPR_CONFIG_DIR}/keybindings.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybindings.conf"
    elif [[ -f "${HYPR_CONFIG_DIR}/hyprland.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/hyprland.conf"
    fi

    if [[ -n "$KEYBINDS_FILE" ]]; then
        sed -i 's/^\([^#]*togglefloating.*\)$/#\1/' "$KEYBINDS_FILE"
        print_success "togglefloating keybind disabled"
        TOGGLEFLOAT_DISABLED_STATUS="yes"
    else
        print_warning "Could not locate keybinds file"
    fi
}

write_config_file() {
    print_substep "Writing configuration file..."
    
    mkdir -p "$PROJECT_CONFIG_DIR"
    
    local TEMP_WORKSPACE_ID=$((NUM_WORKSPACES + 1))
    if [ "$TEMP_WORKSPACE_ID" -gt 10 ]; then
        TEMP_WORKSPACE_ID=99
    fi
    
    cat > "$CONFIG_FILE" <<CONFIG_EOF
# Configuration generated by Hyprland Video Wallpapers Installer on $(date)

NUM_WORKSPACES=$NUM_WORKSPACES
TEMP_WORKSPACE_ID=$TEMP_WORKSPACE_ID

# Status tracking for uninstallation
SOURCE_ADDED="$SOURCE_ADDED_STATUS"
TOGGLEFLOAT_DISABLED="$TOGGLEFLOAT_DISABLED_STATUS"
OPTIMIZER_INSTALLED="$OPTIMIZER_INSTALLED_STATUS"

# Gap configuration (in pixels)
GAP_SIZE=$GAP_SIZE
TOP_GAP=$TOP_GAP

# Video map: (Workspace_ID:Video_Path)
VIDEO_MAP=(
CONFIG_EOF

    for ((ws=1; ws<=NUM_WORKSPACES; ws++)); do
        echo "    \"$ws:${WORKSPACE_VIDEOS[$ws]}\"" >> "$CONFIG_FILE"
    done
    
    echo ")" >> "$CONFIG_FILE"
    
    print_success "Configuration file saved"
}

stop_conflicting_processes() {
    print_substep "Stopping conflicting video processes..."
    
    if pgrep -f "mpvpaper" > /dev/null; then
        print_warning "Detected mpvpaper instances"
        pkill -f "mpvpaper" || true
        pkill -f "mpv" || true
        print_success "Processes stopped"
    elif pgrep -f "mpv --title=mpv-workspace-video" > /dev/null; then
        print_warning "Detected previous wallpaper instances"
        pkill -f "mpv --title=mpv-workspace-video" || true
        print_success "Processes stopped"
    else
        print_success "No conflicting processes found"
    fi
}

install_system() {
    print_section "Installing System"
    
    stop_conflicting_processes
    
    print_substep "Creating configuration directory..."
    mkdir -p "$PROJECT_CONFIG_DIR"
    print_success "Configuration directory created"
    
    install_helper_script
    
    print_substep "Copying Hyprland rules..."
    cp "$HYPR_RULES_FILE" "$PROJECT_CONFIG_DIR/"
    print_success "Hyprland rules copied"
    
    configure_hyprland
    disable_togglefloating
    write_config_file
}

# ============================================================================
#  COMPLETION SCREEN
# ============================================================================

show_completion() {
    print_section "Installation Complete!"
    
    printf "%b%b🎉 Welcome to your new video wallpapers!%b\n\n" "${GREEN}" "${BOLD}" "${NC}"
    
    printf "%bConfiguration saved to:%b\n" "${BOLD}" "${NC}"
    printf "  %b~/.config/hyprland-video-wallpapers/%b\n\n" "${DIM}" "${NC}"
}

setup_autostart() {
    print_section "Autostart Configuration"
    
    printf "Would you like to automatically start video wallpapers on login?\n"
    printf "%b(This adds the script to your hyprland.conf)%b\n\n" "${DIM}" "${NC}"
    
    read -p "Enable autostart? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        printf "\n"
        print_substep "Adding exec-once to hyprland.conf..."
        
        if [ -f "$HYPR_CONF" ]; then
            echo "" >> "$HYPR_CONF"
            echo "# Auto-start video wallpapers" >> "$HYPR_CONF"
            echo "exec-once = $HELPER_SCRIPT_PATH" >> "$HYPR_CONF"
            print_success "Autostart configured"
            printf "\n%b(Wallpapers will start automatically when you reload/restart Hyprland)%b\n\n" "${DIM}" "${NC}"
        else
            print_error "Could not find hyprland.conf"
            printf "Please manually add this line to your config:\n"
            printf "  %bexec-once = %s%b\n\n" "${CYAN}" "$HELPER_SCRIPT_PATH" "${NC}"
        fi
    else
        printf "\n"
        print_info "Skipped autostart setup"
        printf "\nYou can enable it later by adding this to your hyprland.conf:\n"
        printf "  %bexec-once = %s%b\n\n" "${CYAN}" "$HELPER_SCRIPT_PATH" "${NC}"
    fi
}

start_wallpapers_now() {
    print_section "Start Video Wallpapers"
    
    printf "Would you like to start the video wallpapers now?\n"
    printf "%b(Close all windows first!)%b\n\n" "${YELLOW}" "${NC}"
    
    read -p "Start now? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        printf "\n"
        print_warning "Make sure all windows are closed!"
        printf "\n"
        read -p "Ready? Press Enter to start..." -r
        
        printf "\n"
        print_substep "Starting video wallpapers..."
        printf "\n"
        
        # Run the helper script in the background
        "$HELPER_SCRIPT_PATH" &
        local pid=$!
        
        sleep 2
        
        if kill -0 $pid 2>/dev/null; then
            print_success "Wallpapers started successfully!"
            printf "\n%b(Script running in background)%b\n\n" "${DIM}" "${NC}"
        else
            print_error "Failed to start wallpapers"
            printf "\nYou can try manually running:\n"
            printf "  %b%s%b\n\n" "${CYAN}" "$HELPER_SCRIPT_PATH" "${NC}"
        fi
    else
        printf "\n"
        print_info "Skipped starting wallpapers"
        printf "\nYou can start them manually by running:\n"
        printf "  %b%s%b\n\n" "${CYAN}" "$HELPER_SCRIPT_PATH" "${NC}"
    fi
}

show_final_info() {
    print_section "Installation Summary"
    
    printf "%bWhat was installed:%b\n\n" "${BOLD}" "${NC}"
    printf "  %b Helper script%b\n" "${CHECK}" "${NC}"
    printf "     %s%b\n\n" "$HELPER_SCRIPT_PATH" "${NC}"
    printf "  %b Configuration directory%b\n" "${CHECK}" "${NC}"
    printf "     %s%b\n\n" "$PROJECT_CONFIG_DIR" "${NC}"
    printf "  %b Hyprland rules%b\n" "${CHECK}" "${NC}"
    printf "     %s/hyprland-video-wallpapers.conf%b\n\n" "$PROJECT_CONFIG_DIR" "${NC}"
    
    printf "%bNeed help or have feedback?%b\n\n" "${BOLD}" "${NC}"
    printf "  %b🔗 GitHub: https://github.com/XclusivVv/hyprland-video-wallpapers%b\n" "${CYAN}" "${NC}"
    printf "  %b💬 Discord: xclusivvvv%b\n" "${MAGENTA}" "${NC}"
    printf "  %b📖 Docs: Check the README for advanced configuration%b\n\n" "${CYAN}" "${NC}"
    
    if [ "$OPTIMIZER_INSTALLED_STATUS" == "yes" ]; then
        printf "%bPro tip:%b\n" "${BOLD}" "${NC}"
        printf "  Use %bhyprland-video-optimizer%b to compress videos further\n" "${CYAN}" "${NC}"
        printf "  and improve performance!\n\n"
    fi
}

# ============================================================================
#  MAIN FLOW
# ============================================================================

main() {
    show_welcome
    
    if setup_mode_menu; then
        NUM_WORKSPACES=5
        TOP_GAP=30
        GAP_SIZE=15
        select_video_source
    else
        check_prerequisites
        select_video_source
        configure_workspaces
        configure_gaps
    fi
    
    select_videos_for_workspaces
    show_review
    install_system
    show_completion
    setup_autostart
    start_wallpapers_now
    show_final_info
}

main