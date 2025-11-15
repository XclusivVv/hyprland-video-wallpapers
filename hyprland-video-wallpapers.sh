#!/bin/bash

# This script creates one MPV instance for every workspace using master layout,
# where MPV becomes the "master" window and all other windows tile on top as "slaves"

# --- 1. CONFIGURATION ---
VIDEO_MAP=(
    "1:/home/x/Videos/Wallpapers/optimized-hevc/black-panther_optimized.mp4"
    "2:/home/x/Videos/Wallpapers/optimized-hevc/goku-lofi_optimized_optimized.mp4"
    "3:/home/x/Videos/Wallpapers/optimized-hevc/kakashi_optimized.mp4"
    "4:/home/x/Videos/Wallpapers/optimized-hevc/nier_optimized.mp4"
    "5:/home/x/Videos/Wallpapers/optimized-hevc/samurai-warrior-white_optimized.mp4"
    "6:/home/x/Videos/Wallpapers/optimized-hevc/vegeta-ultra_optimized.mp4"
    "7:/home/x/Videos/Wallpapers/optimized-hevc/venom-marvel_optimized_optimized.mp4"
    "8:/home/x/Videos/Wallpapers/optimized-hevc/itachi-red_optimized.mp4"
    "9:/home/x/Videos/Wallpapers/optimized-hevc/zoro-power_optimized.mp4"
)

MPV_WINDOW_CLASS="mpv-workspace-video"
MPV_BASE_SOCKET="/tmp/mpv-ws"

# Gap size for pseudo-tiling (in pixels)
GAP_SIZE=15

# Extra gap at top for waybar
TOP_GAP=30

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
        
        sleep 2.0 
        
        # Move to workspace
        hyprctl dispatch movetoworkspace "$ws_id,title:$window_title" > /dev/null 2>&1
        
        # In master layout, the first window becomes master automatically
        # Force it to be master and set mfact to 1.0 so it takes full screen
        hyprctl dispatch focuswindow "title:$window_title" > /dev/null 2>&1
        hyprctl dispatch layoutmsg "focusmaster master" > /dev/null 2>&1
        hyprctl dispatch splitratio exact 1.0 > /dev/null 2>&1
        
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
            
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $((GAP_SIZE + half_width + GAP_SIZE)) $start_y,address:${win_array[1]}" > /dev/null 2>&1
            ;;
        3)
            # Three windows - one left (full height), two right stacked
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            
            # Left window (full height, in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $usable_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            # Top right window (in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $((GAP_SIZE + half_width + GAP_SIZE)) $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            # Bottom right window (NOT in top row, so only regular GAP_SIZE from window above)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $((GAP_SIZE + half_width + GAP_SIZE)) $((start_y + half_height + GAP_SIZE)),address:${win_array[2]}" > /dev/null 2>&1
            ;;
        4)
            # Four windows - 2x2 grid
            local half_width=$(( (usable_width - GAP_SIZE) / 2 ))
            local half_height=$(( (usable_height - GAP_SIZE) / 2 ))
            
            # Top row windows
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[0]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $start_y,address:${win_array[0]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[1]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $((GAP_SIZE + half_width + GAP_SIZE)) $start_y,address:${win_array[1]}" > /dev/null 2>&1
            
            # Bottom row windows (NOT in top row)
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[2]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $((start_y + half_height + GAP_SIZE)),address:${win_array[2]}" > /dev/null 2>&1
            
            hyprctl dispatch resizewindowpixel "exact $half_width $half_height,address:${win_array[3]}" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $((GAP_SIZE + half_width + GAP_SIZE)) $((start_y + half_height + GAP_SIZE)),address:${win_array[3]}" > /dev/null 2>&1
            ;;
        *)
            # More than 4 windows - use grid layout
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

# --- 3. SOCKET DISCOVERY ---

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
    echo -e "\nExiting script and killing all active video wallpapers..."
    pkill -f "mpv --title=${MPV_WINDOW_CLASS}"
    exit 0
}
trap cleanup EXIT

# Kill old instances before starting new ones
pkill -f "mpv --title=${MPV_WINDOW_CLASS}"

# Save all currently open windows to special workspace before starting
echo "Moving existing windows to scratchpad..."
declare -A SAVED_WINDOWS

# Get all non-MPV windows with their workspace info
while IFS='|' read -r address workspace_id; do
    if [[ -n "$address" ]] && [[ -n "$workspace_id" ]]; then
        SAVED_WINDOWS["$address"]="$workspace_id"
        # Move to special scratchpad workspace
        hyprctl dispatch movetoworkspacesilent "special:temp_scratchpad,address:$address" > /dev/null 2>&1
    fi
done < <(hyprctl clients -j | jq -r '.[] | select(.title | test("^mpv-workspace-video") | not) | "\(.address)|\(.workspace.id)"')

echo "Saved ${#SAVED_WINDOWS[@]} windows to scratchpad"

start_all_mpv

# Restore windows from scratchpad back to their original workspaces
echo "Restoring windows from scratchpad..."
for address in "${!SAVED_WINDOWS[@]}"; do
    original_ws="${SAVED_WINDOWS[$address]}"
    hyprctl dispatch movetoworkspacesilent "$original_ws,address:$address" > /dev/null 2>&1
    echo "  -> Restored window $address to workspace $original_ws"
done

# Retile each workspace that has windows
for ws_id in $(echo "${SAVED_WINDOWS[@]}" | tr ' ' '\n' | sort -u); do
    if [[ "$ws_id" =~ ^[0-9]+$ ]] && [[ "$ws_id" -le 5 ]]; then
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
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]] && [[ "$CURRENT_WS" -le 5 ]]; then
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
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]] && [[ "$CURRENT_WS" -le 5 ]]; then
            sleep 0.1
            pseudo_tile_workspace "$CURRENT_WS"
        fi
    fi

done