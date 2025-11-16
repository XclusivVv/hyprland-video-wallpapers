#!/usr/bin/env bash
set -euo pipefail

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Hyprland Video Wallpapers — Installer ===${NC}"
echo

# Global Variables
PROJECT_CONFIG_DIR="${HOME}/.config/hyprland-video-wallpapers"
CONFIG_FILE="${PROJECT_CONFIG_DIR}/config.conf"
HELPER_SCRIPT_NAME="hyprland-video-wallpapers.sh"
HELPER_SCRIPT_PATH="${HOME}/.local/bin/${HELPER_SCRIPT_NAME}"
HYPR_RULES_FILE="hyprland-video-wallpapers.conf"
OPTIMIZER_BIN="${HOME}/.local/bin/hyprland-video-optimizer"

# Status trackers
OPTIMIZER_INSTALLED_STATUS="no"


# --- OPTIMIZER INSTALLATION FUNCTION ---
install_optimizer() {
    local OPTIMIZER_REPO="https://github.com/XclusivVv/hyprland-video-optimizer.git"
    local TEMP_DIR
    
    echo -e "\n${BLUE}[*] Attempting to install hyprland-video-optimizer...${NC}"
    
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}[!] Error: 'git' command not found. Please install git to automatically install the optimizer.${NC}"
        return 1
    fi

    TEMP_DIR=$(mktemp -d)
    echo -e "${BLUE}[*] Cloning repository to temporary directory: ${TEMP_DIR}...${NC}"
    
    if git clone "$OPTIMIZER_REPO" "$TEMP_DIR"; then
        echo -e "${GREEN}[+] Clone successful. Installing optimizer script...${NC}"
        
        # Assume the main script is 'hyprland-video-optimizer.sh' inside the repo root
        if [ -f "${TEMP_DIR}/hyprland-video-optimizer.sh" ]; then
            mkdir -p "$(dirname "$OPTIMIZER_BIN")"
            cp "${TEMP_DIR}/hyprland-video-optimizer.sh" "${OPTIMIZER_BIN}"
            chmod +x "${OPTIMIZER_BIN}"
            echo -e "${GREEN}[+] hyprland-video-optimizer installed to ${OPTIMIZER_BIN}${NC}"
            rm -rf "$TEMP_DIR"
            return 0 # Success
        else
            echo -e "${RED}[!] Error: Could not find 'hyprland-video-optimizer.sh' in the cloned repository.${NC}"
        fi
    else
        echo -e "${RED}[!] Error: Git clone failed. Check network connectivity or repository URL.${NC}"
    fi
    
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    return 1 # Failure
}
# ----------------------------------------

# Check Hyprland
if ! command -v hyprctl >/dev/null 2>&1; then
  echo -e "${RED}[!] hyprctl not found. Ensure a Hyprland variant is installed.${NC}"
  read -p "Continue anyway? (y/N) " yn
  case "$yn" in [Yy]*) ;; *) echo -e "${RED}Abort.${NC}"; exit 1 ;; esac
fi

# Install runtime dependencies if pacman exists
if command -v pacman >/dev/null 2>&1; then
  echo -e "${BLUE}[+] Installing mpv, socat, jq...${NC}"
  sudo pacman -S --needed --noconfirm mpv socat jq
else
  echo -e "${YELLOW}[!] pacman not detected. Install mpv, socat, jq manually.${NC}"
fi

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  VIDEO WALLPAPER CHECK"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# --- VIDEO CHECK LOGIC ---
read -p "Do you have video wallpapers you would like to use for Hyprland? (Y/n) " has_videos

if [[ "${has_videos,,}" == "n" ]]; then
    echo
    echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}  You'll need a video to continue.${NC}"
    echo -e "  Consider checking out the ${GREEN}hyprland-video-optimizer${NC} project:"
    echo -e "  ${BLUE}https://github.com/XclusivVv/hyprland-video-optimizer${NC}"
    echo -e "  This repository contains ${GREEN}sample video wallpapers${NC} and a powerful tool"
    echo -e "  to re-encode and compress larger videos."
    echo -e "  (Example: The author compressed an 80MB video down to 5MB with no visible quality loss.)"
    echo -e "  ${RED}Note: Regular, unoptimized videos will hog system resources ALOT!${NC}"
    echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
    echo -e "${RED}Installation aborted. Please return when you have your videos ready.${NC}"
    exit 1
fi

echo
echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
echo -e "${YELLOW}  Author's Recommendation:${NC}"
echo -e "  Video wallpapers should be compressed to around ${GREEN}10MB or less${NC} to reduce system overhead."
echo -e "  ${RED}Running unoptimized videos as wallpapers can lead to high CPU/GPU usage.${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
echo

read -p "Have your videos been compressed to a wallpaper-friendly size (e.g., 10MB or less)? (Y/n) " is_compressed

if [[ "${is_compressed,,}" == "n" ]]; then
    echo
    echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
    echo -e "  It is strongly suggested you compress them before proceeding."
    echo -e "  You can use the ${GREEN}hyprland-video-optimizer${NC} tool for this."
    read -p "Would you like to automatically install hyprland-video-optimizer now? (Y/n) " install_optimizer_now
    
    if [[ "${install_optimizer_now,,}" != "n" ]]; then
        if install_optimizer; then
            OPTIMIZER_INSTALLED_STATUS="yes"
        fi
    else
        echo -e "${YELLOW}[-] Skipping automatic optimizer installation. You can install it manually later.${NC}"
    fi
    echo -e "${YELLOW}--------------------------------------------------------------------------------${NC}"
fi
# --- END VIDEO CHECK LOGIC ---

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  CONFIGURATION"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Ask for number of workspaces
while true; do
  read -p "How many workspaces would you like to configure? (1-10): " NUM_WORKSPACES
  if [[ "$NUM_WORKSPACES" =~ ^[0-9]+$ ]] && [ "$NUM_WORKSPACES" -ge 1 ] && [ "$NUM_WORKSPACES" -le 10 ]; then
    break
  else
    echo -e "${RED}[!] Please enter a number between 1 and 10.${NC}"
  fi
done

# Ask for gap sizes
echo
echo -e "Gap configuration (these create space around windows):"
while true; do
  read -p "Top gap size in pixels (for waybar/status bar, recommended: 30): " TOP_GAP
  if [[ "$TOP_GAP" =~ ^[0-9]+$ ]]; then
    break
  else
    echo -e "${RED}[!] Please enter a valid number.${NC}"
  fi
done

while true; do
  read -p "Gap size around windows in pixels (recommended: 15): " GAP_SIZE
  if [[ "$GAP_SIZE" =~ ^[0-9]+$ ]]; then
    break
  else
    echo -e "${RED}[!] Please enter a valid number.${NC}"
  fi
done

# Ask for video directory
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  VIDEO SELECTION"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
while true; do
  read -p "Enter the directory path containing your video wallpapers: " VIDEO_DIR
  VIDEO_DIR="${VIDEO_DIR/#\~/$HOME}"  # Expand ~
  
  if [ -d "$VIDEO_DIR" ]; then
    # Find video files
    mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" \) | sort)
    
    if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
      echo -e "${RED}[!] No .mp4 or .mkv files found in that directory.${NC}"
      read -p "Try a different directory? (y/N) " retry
      case "$retry" in [Yy]*) continue ;; *) echo -e "${RED}Abort.${NC}"; exit 1 ;; esac
    else
      echo -e "${GREEN}[+] Found ${#VIDEO_FILES[@]} video file(s).${NC}"
      break
    fi
  else
    echo -e "${RED}[!] Directory not found: $VIDEO_DIR${NC}"
    read -p "Try again? (y/N) " retry
    case "$retry" in [Yy]*) continue ;; *) echo -e "${RED}Abort.${NC}"; exit 1 ;; esac
  fi
done

# Display available videos
echo
echo -e "Available videos:"
for i in "${!VIDEO_FILES[@]}"; do
  echo "  [$((i+1))] $(basename "${VIDEO_FILES[$i]}")"
done

# Select videos for each workspace
declare -a WORKSPACE_VIDEOS
echo
echo -e "Select a video for each workspace (enter the number):"
for ((ws=1; ws<=NUM_WORKSPACES; ws++)); do
  while true; do
    read -p "Workspace $ws: " video_num
    if [[ "$video_num" =~ ^[0-9]+$ ]] && [ "$video_num" -ge 1 ] && [ "$video_num" -le ${#VIDEO_FILES[@]} ]; then
      WORKSPACE_VIDEOS[$ws]="${VIDEO_FILES[$((video_num-1))]}"
      echo -e "  → ${GREEN}$(basename "${WORKSPACE_VIDEOS[$ws]}") ${NC}"
      break
    else
      echo -e "${RED}[!] Please enter a number between 1 and ${#VIDEO_FILES[@]}.${NC}"
    fi
  done
done

# Setup installation
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  INSTALLATION"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# 0. Pre-Installation Check: Stop existing video processes
echo -e "${BLUE}[*] Checking for existing video wallpaper processes (mpv/mpvpaper)...${NC}"

# Check specifically for mpvpaper, as it is the most common conflict
if pgrep -f "mpvpaper" > /dev/null; then
    echo -e "${YELLOW}[!] WARNING: Detected running 'mpvpaper' instances!${NC}"
    echo "    'mpvpaper' will conflict with this script and MUST be killed."
    read -p "Allow the installer to kill mpvpaper and other conflicting processes? (Y/n) " allow_stop

    if [[ "${allow_stop,,}" != "n" ]]; then
        echo -e "${GREEN}[+] Killing conflicting processes...${NC}"
        # Use pkill with '|| true' to prevent script exit if no process is found
        pkill -f "mpvpaper" || true
        pkill -f "mpv" || true
        
        echo -e "${GREEN}[+] Conflicting video processes have been successfully closed.${NC}"
    else
        echo -e "${RED}[!] Conflicting processes were not closed. Installation aborted.${NC}"
        exit 1
    fi
# Check for our old script running
elif pgrep -f "mpv --title=mpv-workspace-video" > /dev/null; then
    # If the conflict is just our old script, kill it quietly
    echo -e "${YELLOW}[!] Detected previous instances of this script running. Killing them...${NC}"
    pkill -f "mpv --title=mpv-workspace-video" || true
    echo -e "${GREEN}[+] Conflicting video processes have been successfully closed.${NC}"
else
    echo -e "${GREEN}[+] No conflicting video processes found.${NC}"
fi

# 1. Install Static Helper Script
echo -e "${BLUE}[+] Installing helper script to ${HELPER_SCRIPT_PATH}${NC}"
mkdir -p ~/.local/bin

# Write the static core logic script (it sources the config file)
cat > "$HELPER_SCRIPT_PATH" <<'SCRIPT_CORE_LOGIC_EOF'
#!/bin/bash
set -euo pipefail

# Source the configuration file containing user-defined variables
CONFIG_FILE="${HOME}/.config/hyprland-video-wallpapers/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE. Run install.sh again." >&2
    exit 1
fi
source "$CONFIG_FILE"

# --- 1. CONFIGURATION (Static) ---
MPV_WINDOW_CLASS="mpv-workspace-video"
MPV_BASE_SOCKET="/tmp/mpv-ws"

# --- 2. CORE FUNCTIONS ---

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

# START_ALL_MPV (FIXED: Better timing and no initial pause)
start_all_mpv() {
    echo "Starting MPV instances for all defined workspaces..."
    
    # Get monitor resolution for MPV sizing
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
    read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"

    for entry in "${VIDEO_MAP[@]}"; do
        IFS=':' read -r ws_id video_path <<< "$entry"
        
        local window_title=$(get_window_title "$ws_id")
        local socket_path=$(get_socket_path "$ws_id")
        
        rm -f "$socket_path"

        # Start MPV in the background
        mpv \
            --no-osc --no-stop-screensaver \
            --input-ipc-server="$socket_path" \
            --loop --video-sync=display-resample \
            --title="$window_title" \
            --geometry="${SCREEN_WIDTH}x${SCREEN_HEIGHT}+0+0" \
            "$video_path" &
        
        sleep 2.0 # CRITICAL DELAY: Give MPV time to start socket
        
        # 1. Move to workspace
        hyprctl dispatch movetoworkspace "$ws_id,title:$window_title" > /dev/null 2>&1
        sleep 0.5 # Add small delay after move
        
        # 2. Force to master layout for full screen
        hyprctl dispatch focuswindow "title:$window_title" > /dev/null 2>&1
        hyprctl dispatch layoutmsg "focusmaster master" > /dev/null 2>&1
        hyprctl dispatch splitratio exact 1.0 > /dev/null 2>&1 # Ensure it takes up 100% of the master area
        
        echo "  -> Started video for Workspace $ws_id (master window)"

        # Pause initially
        send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
    done
}

# Function to pseudo-tile windows on a workspace
pseudo_tile_workspace() {
    local ws_id="$1"
    
    # Get all floating windows on this workspace (excluding MPV)
    local windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ws_id and .floating == true and (.title | test(\"^mpv-workspace-video\") | not)) | .address")
    
    # Convert to array
    local win_array=()
    while IFS= read -r addr; do
        [[ -n "$addr" ]] && win_array+=("$addr")
    done <<< "$windows"
    
    local win_count=${#win_array[@]}
    
    # Skip if no windows to tile
    [[ $win_count -eq 0 ]] && return
    
    # Get monitor resolution
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
    read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"
    
    # Apply outer gaps (top windows get extra TOP_GAP)
    local usable_width=$((SCREEN_WIDTH - GAP_SIZE * 2))
    local usable_height=$((SCREEN_HEIGHT - TOP_GAP - GAP_SIZE * 2))
    local start_y=$((GAP_SIZE + TOP_GAP))  # Top row starts below waybar
    
    # Simple tiling algorithm based on window count
    case $win_count in
        1)
            # Single window - fullscreen with gaps (top row)
            hyprctl dispatch resizewindowpixel "exact $usable_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            ;;
        2)
            # Two windows - split vertically with gaps (both in top row)
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            ;;
        3)
            # Three windows - one left (full height), two right stacked
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            local half_height_gap=$((start_y + half_height + GAP_SIZE))
            
            # Left window (full height, in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            # Top right window (in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            # Bottom right window (NOT in top row, so only regular GAP_SIZE from window above)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $half_height_gap,address:${win_array[2]}" > /dev/null 2>&1
            ;;
        4)
            # Four windows - 2x2 grid
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            local half_width_gap=$((GAP_SIZE + half_width + GAP_SIZE))
            local half_height_gap=$((start_y + half_height + GAP_SIZE))
            
            # Top row windows
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            # Bottom row windows (NOT in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $half_height_gap,address:${win_array[2]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[3]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $half_width_gap $half_height_gap,address:${win_array[3]}" > /dev/null 2>&1
            ;;
        *)
            # More than 4 windows - use grid layout (simplified)
            local cols=3
            local rows=$(( (win_count + cols - 1) / cols ))
            local win_width=$(( (usable_width - GAP_SIZE * (cols - 1)) / cols ))
            local win_height=$(( (usable_height - GAP_SIZE * (rows - 1)) / rows ))
            
            for i in "${!win_array[@]}"; do
                local col=$((i % cols))
                local row=$((i / cols))
                local x=$((GAP_SIZE + col * (win_width + GAP_SIZE)))
                
                # Top row gets start_y (which includes TOP_GAP), other rows only get GAP_SIZE spacing
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

# --- 3. SOCKET DISCOVERY (Static) ---

HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE"
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instance -j 2>&1 | grep -v 'ok' | grep -v 'Invalid dispatcher' | jq -r '.instanceSignature')
fi
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "FATAL: Could not retrieve HYPRLAND_INSTANCE_SIGNATURE."
    exit 1
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

# --- 4. MAIN EXECUTION ---

cleanup() {
    echo -e "\nExiting script and closing all active video wallpapers..."
    pkill -f "mpv --title=${MPV_WINDOW_CLASS}" || true 
    exit 0
}
trap cleanup EXIT

# Kill old instances before starting new ones
pkill -f "mpv --title=${MPV_WINDOW_CLASS}" || true 

# Save all currently open windows to temporary workspace before starting (FIXED retrieval logic)
if [ "$TEMP_WORKSPACE_ID" -le 10 ]; then
    echo "Moving existing windows to temporary Workspace $TEMP_WORKSPACE_ID..."
    declare -A SAVED_WINDOWS
    COUNT_MOVED=0
    
    # Select all windows that are not the video wallpaper and are on a configured workspace
    while IFS='|' read -r address workspace_id; do
        if [[ -n "$address" ]] && [[ "$workspace_id" =~ ^[0-9]+$ ]] && [ "$workspace_id" -ge 1 ] && [ "$workspace_id" -le "$NUM_WORKSPACES" ]; then
            SAVED_WINDOWS["$address"]="$workspace_id"
            # Move to temporary workspace
            hyprctl dispatch movetoworkspacesilent "$TEMP_WORKSPACE_ID,address:$address" > /dev/null 2>&1
            COUNT_MOVED=$((COUNT_MOVED + 1))
        fi
    done < <(hyprctl clients -j | jq -r '.[] | select(.title | test("^mpv-workspace-video") | not and .workspace.id != -1) | "\(.address)|\(.workspace.id)"')
    
    echo "Saved and moved $COUNT_MOVED windows to temporary workspace $TEMP_WORKSPACE_ID."
else
    echo "Skipping window movement: TEMP_WORKSPACE_ID ($TEMP_WORKSPACE_ID) is outside range 1-10."
fi


start_all_mpv

# Wait for MPV windows to fully initialize and settle as master windows
echo "Waiting for video wallpapers to initialize..."
sleep 3

# Restore windows from temporary workspace back to their original workspaces
if [ "$TEMP_WORKSPACE_ID" -le 10 ]; then
    echo "Restoring windows from temporary workspace..."
    for address in "${!SAVED_WINDOWS[@]}"; do
        original_ws="${SAVED_WINDOWS[$address]}"
        hyprctl dispatch movetoworkspacesilent "$original_ws,address:$address" > /dev/null 2>&1
        echo "  -> Restored window $address to workspace $original_ws"
    done
fi

# Small delay to let windows settle
sleep 1.0

# Retile each workspace that has windows
echo "Applying window tiling..."
for ws_id in $(echo "${SAVED_WINDOWS[@]}" | tr ' ' '\n' | sort -u); do
    if [[ "$ws_id" =~ ^[0-9]+$ ]]; then
        sleep 0.2
        pseudo_tile_workspace "$ws_id"
    fi
done

# Get initial workspace and play
CURRENT_WORKSPACE=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
if [[ $CURRENT_WORKSPACE ]]; then
    send_mpv_command "$CURRENT_WORKSPACE" '{"command":["set_property","pause",false]}'
    echo "Initial state: Video on Workspace $CURRENT_WORKSPACE is playing."
fi

echo "Starting listener for Hyprland workspace events on $HYPRLAND_EVENT_SOCKET..."

# Track windows per workspace for pseudo-tiling
declare -A WORKSPACE_WINDOWS

socat -u UNIX-CONNECT:"$HYPRLAND_EVENT_SOCKET" - | while IFS= read -r event; do
    
    if [[ $event == workspace* ]]; then
        
        CURRENT_WORKSPACE=${event#workspace>>}
        
        if [[ "$CURRENT_WORKSPACE" =~ ^[0-9]+$ ]]; then
            
            for entry in "${VIDEO_MAP[@]}"; do
                IFS=':' read -r ws_id video_path <<< "$entry"
                
                if [ "$ws_id" == "$CURRENT_WORKSPACE" ]; then
                    # Play video on current workspace
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",false]}'
                else
                    # Pause videos on other workspaces
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
                fi
            done
        fi
    fi
    
    # When a new window opens, immediately position it and then retile
    if [[ $event == openwindow* ]]; then
        # Extract window address from event: openwindow>>address,workspace,class,title
        NEW_WINDOW_ADDR=$(echo "$event" | cut -d'>' -f3 | cut -d',' -f1)
        
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            # Immediately resize and position the new window to prevent fullscreen flash
            # Get monitor resolution
            local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
            read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"
            
            local default_width=$((SCREEN_WIDTH - GAP_SIZE * 2))
            local default_height=$((SCREEN_HEIGHT - TOP_GAP - GAP_SIZE))
            
            # Immediately resize and move the new window
            hyprctl dispatch resizewindowpixel "exact $default_width $default_height,address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $TOP_GAP,address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            
            # Wait a moment for the resize to take effect
            sleep 0.2
            
            # Now retile all windows on this workspace properly
            pseudo_tile_workspace "$CURRENT_WS"
        fi
    fi
    
    # When a window closes, retile the workspace
    if [[ $event == closewindow* ]]; then
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            sleep 0.1
            pseudo_tile_workspace "$CURRENT_WS"
        fi
    fi

done
SCRIPT_CORE_LOGIC_EOF

chmod +x "$HELPER_SCRIPT_PATH"

# 2. Create Configuration Directory and Files
echo -e "${BLUE}[+] Creating configuration directory: ${PROJECT_CONFIG_DIR}${NC}"
mkdir -p "$PROJECT_CONFIG_DIR"

echo -e "${BLUE}[+] Copying Hyprland rules to ${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}${NC}"
cp "$HYPR_RULES_FILE" "$PROJECT_CONFIG_DIR/"

# Calculate the temporary workspace ID
TEMP_WORKSPACE_ID=$((NUM_WORKSPACES + 1))
if [ "$TEMP_WORKSPACE_ID" -gt 10 ]; then
    TEMP_WORKSPACE_ID=99 # Set to invalid/high value to skip move logic in helper script
    echo -e "${YELLOW}[!] WARNING: Configured ${NUM_WORKSPACES} workspaces. Cannot guarantee a free temporary workspace. Window saving will be skipped.${NC}"
fi

# 3. Handle hyprland.conf Sourcing
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  HYPRLAND CONFIGURATION"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"
SOURCE_LINE="source = ${PROJECT_CONFIG_DIR}/${HYPR_RULES_FILE}"
SOURCE_ADDED_STATUS="no"

if [ -f "$HYPR_CONF" ]; then
  echo -e "${GREEN}[+] Found hyprland.conf at ${HYPR_CONF}${NC}"

  # FIX: Check if the source line already exists before prompting
  if grep -q "source.*${HYPR_RULES_FILE}" "$HYPR_CONF"; then
      echo -e "${YELLOW}[!] The source line for video wallpapers already exists in hyprland.conf. Skipping addition.${NC}"
      SOURCE_ADDED_STATUS="yes" # Mark as present, so the uninstaller knows it exists
  else
      # If it does not exist, ask to add it
      echo "We will add the following line to load the video wallpaper settings:"
      echo -e "${YELLOW}  $SOURCE_LINE${NC}"
      
      read -p "Add this line to hyprland.conf? (Y/n) " add_source
      
      if [[ "${add_source,,}" != "n" ]]; then
          echo "" >> "$HYPR_CONF"
          echo "# Video wallpapers configuration" >> "$HYPR_CONF"
          echo "$SOURCE_LINE" >> "$HYPR_CONF"
          echo -e "${GREEN}[+] Added source line to hyprland.conf.${NC}"
          SOURCE_ADDED_STATUS="yes"
      else
          echo -e "${YELLOW}[-] Skipping adding source line. You must add it manually to use the wallpapers.${NC}"
      fi
  fi
else
  echo -e "${RED}[!] Could not find hyprland.conf at ${HYPR_CONF}${NC}"
  echo "    You'll need to manually add this line to your config:"
  echo -e "    ${YELLOW}$SOURCE_LINE${NC}"
fi

# 4. Handle togglefloating keybind
echo
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  IMPORTANT: TOGGLE FLOATING WARNING"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "The 'togglefloating' keybind can cause issues with video wallpapers."
echo "It is STRONGLY RECOMMENDED to disable this keybind."
echo
read -p "Disable the togglefloating keybind? (Y/n) " disable_toggle
TOGGLEFLOAT_DISABLED_STATUS="no"

if [[ "${disable_toggle,,}" != "n" ]]; then
    
    HYPR_CONFIG_DIR="${HOME}/.config/hypr"
    KEYBINDS_FILE=""
    
    # Check for keybinds.conf first
    if [[ -f "${HYPR_CONFIG_DIR}/keybindings.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/keybindings.conf"
    elif [[ -f "${HYPR_CONFIG_DIR}/hyprland.conf" ]]; then
        KEYBINDS_FILE="${HYPR_CONFIG_DIR}/hyprland.conf"
    fi

    if [[ -n "$KEYBINDS_FILE" ]]; then
        echo -e "${BLUE}[+] Commenting out 'togglefloating' in ${KEYBINDS_FILE}...${NC}"
        # Use sed to comment out any line containing 'togglefloating'
        sed -i 's/^\([^#]*togglefloating.*\)$/#\1/' "$KEYBINDS_FILE"
        echo -e "${GREEN}[+] togglefloating keybind has been disabled.${NC}"
        TOGGLEFLOAT_DISABLED_STATUS="yes"
    else
        echo -e "${RED}[!] Could not locate a keybinds file. You may need to disable 'togglefloating' manually.${NC}"
    fi
fi

# 5. Write config.conf with tracking status
cat > "$CONFIG_FILE" <<CONFIG_EOF
# Configuration generated by Hyprland Video Wallpapers Installer on $(date)

NUM_WORKSPACES=$NUM_WORKSPACES
# The workspace ID used to temporarily move existing windows (1-10, or 99 to skip)
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

# Add user's video mappings
for ((ws=1; ws<=NUM_WORKSPACES; ws++)); do
  # Write the path to the config file
  echo "    \"$ws:${WORKSPACE_VIDEOS[$ws]}\"" >> "$CONFIG_FILE"
done

# Close the array definition
echo ")" >> "$CONFIG_FILE"

# 6. Final Prompt and Execution
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  INSTALLATION COMPLETE!"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Important notes:"
echo
echo -e "1. The configuration is now stored in: ${YELLOW}${CONFIG_FILE}${NC}"
echo
echo -e "2. The executable script is: ${YELLOW}${HELPER_SCRIPT_PATH}${NC}"
echo
echo "3. To start the wallpapers, add this line to your hyprland.conf:"
echo -e "   ${YELLOW}exec-once = ${HELPER_SCRIPT_PATH}${NC}"
echo
echo -e "4. To uninstall, run the new script: ${YELLOW}./uninstall.sh${NC}"
echo

if [ "$OPTIMIZER_INSTALLED_STATUS" == "yes" ]; then
    echo
    echo -e "${BLUE}What would you like to run now?${NC}"
    PS3="Select an option (1-3): "
    options=("Run Video Wallpapers" "Run Video Optimizer" "Exit")
    select action in "${options[@]}"; do
        case $REPLY in
            1) echo -e "${GREEN}[+] Running video wallpapers: ${HELPER_SCRIPT_PATH}...${NC}"; "$HELPER_SCRIPT_PATH" & break;;
            2) echo -e "${GREEN}[+] Running video optimizer: hyprland-video-optimizer...${NC}"; "$OPTIMIZER_BIN"; break;;
            3) echo -e "${YELLOW}[-] Exiting.${NC}"; exit 0;;
            *) echo -e "${RED}[!] Invalid selection, please try again.${NC}";;
        esac
    done
else
    # Only offer to run the wallpaper script if the optimizer wasn't installed
    read -p "Would you like to run the video wallpapers script now? (Y/n) " run_now

    if [[ "${run_now,,}" != "n" ]]; then
        echo -e "${GREEN}[+] Running ${HELPER_SCRIPT_PATH}...${NC}"
        "$HELPER_SCRIPT_PATH" &
    else
        echo -e "${YELLOW}[-] Skipping execution. Remember to run it manually or add to autostart.${NC}"
    fi
fi