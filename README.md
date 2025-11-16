<p align="center">
  <img src="/assets/logo.png" alt="Logo">
</p>

**Per-workspace video wallpapers with pseudo-tiling window management**

![bash](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![hyprland](https://img.shields.io/badge/Hyprland-Compatible-00A0FF?logo=wayland&logoColor=white)
![mpv](https://img.shields.io/badge/MPV-Video_Backgrounds-6A0DAD?logo=mpv&logoColor=white)
![license](https://img.shields.io/github/license/XclusivVv/hyprland-video-wallpapers)
![lastcommit](https://img.shields.io/github/last-commit/XclusivVv/hyprland-video-wallpapers)

---

## Preview

<p align="center">
  <img src="docs/preview/preview.gif" alt="Preview">
</p>

*Note: Not recommended for low-spec systems. 16GB RAM minimum is strongly advised.*

---

## Features

Includes a full **interactive installation wizard**:

### 🔧 Interactive Setup Wizard
- Step-by-step guided installation
- Detects and installs missing dependencies
- Automatically configures Hyprland rules
- Maps videos to workspaces interactively

### 📦 Dependency Management
- Ensures `hyprctl` is installed  
- Installs `mpv`, `socat`, and `jq` on Arch-based systems

### 🎞️ Video Optimizer (Optional)
- Recommends compressing large videos
- Can auto-install `hyprland-video-optimizer`

### 🎥 Workspace Video Mapping
- Choose your video directory
- Select videos for workspaces **1–10**

### ⚙️ Hyprland Config Integration
- Offers to add required `source` line to `hyprland.conf`
- Detects and warns of togglefloating conflicts
- Can auto-disable conflicting keybinds

### 🧹 Safe Uninstaller Included
`uninstall.sh` fully reverts all changes.

---

## Quick Start

    git clone https://github.com/XclusivVv/hyprland-video-wallpapers.git
    cd hyprland-video-wallpapers

    chmod +x install.sh uninstall.sh
    ./install.sh

---

## Installation Process

Running `./install.sh` will:

1. **Check Dependencies**  
   Verifies `hyprctl`; installs `mpv`, `socat`, `jq` (Arch only).

2. **Warn About Video Size**  
   Recommends keeping videos below ~10MB.

3. **Offer Video Optimizer**  
   Optionally installs `hyprland-video-optimizer`.

4. **Configure Layout Gaps**  
   Prompts for:
   - `TOP_GAP`
   - `GAP_SIZE`

5. **Map Videos to Workspaces**  
   Scans your directory for `.mp4` / `.mkv`  
   Lets you assign videos for workspaces 1–10.

6. **Install Files**
   - `~/.local/bin/hyprland-video-wallpapers.sh`
   - `~/.config/hyprland-video-wallpapers/config.conf`
   - `~/.config/hyprland-video-wallpapers/hyprland-video-wallpapers.conf`

7. **Patch Hyprland Config**
   - Offers to add `source` line automatically
   - Offers to disable togglefloating if conflicting

8. **Ask to Start Immediately**

---

## Autostart

Add this line to your `~/.config/hypr/hyprland.conf` (preferably at the end):

    exec-once = ~/.local/bin/hyprland-video-wallpapers.sh

### Start / Stop Manually

    # Run in background
    ~/.local/bin/hyprland-video-wallpapers.sh &

    # Stop all running instances
    pkill -f hyprland-video-wallpapers.sh

---

## Configuration

Your full configuration is stored in:

    ~/.config/hyprland-video-wallpapers/config.conf

You may edit it manually, but the recommended method is to re-run the installer:

    ./install.sh

The wizard safely overwrites old settings.

---

## Uninstallation

From inside the cloned repo:

    ./uninstall.sh

This will automatically:

- Stop all mpv and wallpaper scripts  
- Remove `exec-once` from `hyprland.conf`  
- Remove the sourced config file  
- Restore the togglefloating keybind  
- Delete:
  - `~/.local/bin/hyprland-video-wallpapers.sh`
  - `~/.config/hyprland-video-wallpapers`
  - `~/.local/bin/hyprland-video-optimizer` (if installed)

---

## How It Works

- Each workspace runs its own **mpv** instance.
- The mpv window on its workspace is promoted to Hyprland's **master** and fills the screen.
- When you switch workspaces:
  - The active workspace's video plays.
  - Other workspaces' videos pause.
- Regular application windows are set to **floating** by Hyprland rules.
- The script listens for open/close window events and arranges floating windows into a **pseudo-tiled layout** above the video.

---

## License

MIT — see `LICENSE`.

---

*PS: This was a struggle..*
