![Centered Image](/assets/logo.png){: .center}

<div align="center">
  <h1>Per-workspace animated wallpapers with intelligent window management</h1>
  
  ![bash](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white)
  ![hyprland](https://img.shields.io/badge/Hyprland-Compatible-00A0FF?logo=wayland&logoColor=white)
  ![mpv](https://img.shields.io/badge/MPV-Video_Backgrounds-6A0DAD)
  ![license](https://img.shields.io/github/license/XclusivVv/hyprland-video-wallpapers)
  ![lastcommit](https://img.shields.io/github/last-commit/XclusivVv/hyprland-video-wallpapers)
</div>

![Centered Image](/docs/preview/preview.gif){: .center}

---

## Overview

Transform your Hyprland desktop with **per-workspace video wallpapers**. Each workspace can have its own unique animated background, automatically pausing when you switch workspaces. Windows are intelligently arranged in a pseudo-tiling layout above the wallpaper.

**Note:** 16GB RAM minimum is recommended. Videos should be optimized (H.265, ~5–10MB).

---

## ✨ Features

### 🎨 Multiple Wallpapers
- Assign different video wallpapers to each workspace (1–10)
- 50+ pre-optimized sample wallpapers included
- Automatic play/pause when switching workspaces
- Supports MP4 and MKV formats

### 🧙 Interactive Installation Wizard
- Modern, colorful TUI-based flow
- Auto-detection of Hyprland and dependencies
- Sample video selector and preview list
- Express or Custom setup modes
- Optional autostart

### ⚙️ Smart Window Management
- Wallpaper handled by per-workspace MPV instances
- MPV windows pushed to bottom z-layer
- Other windows arranged in pseudo-tiling layout
- Configurable top gaps and window gaps

### 🎬 Pre-Optimized Wallpapers
- 50+ anime, abstract, nature, and tech wallpapers
- H.265 codec for high quality + small size
- Typically 2–25MB each

### 🚀 Easy Management
- Enable autostart
- Start/stop manually
- Re-run installer anytime
- Full uninstaller that reverts changes

---

## 🚀 Quick Start

    git clone https://github.com/XclusivVv/hyprland-video-wallpapers.git
    cd hyprland-video-wallpapers

    chmod +x install.sh uninstall.sh
    ./install.sh

The installer will walk you through everything interactively.

---

## 📋 Requirements

The installer checks and installs these automatically on Arch-based systems:

- Hyprland
- mpv
- socat
- jq
- git (optional, needed for auto-installing the optimizer tool)

---

## 🎯 Installation Process

### 1. Choose Setup Mode
- **Express Mode:**  
  5 workspaces  
  30px top gap  
  15px window gaps  
- **Custom Mode:**  
  Fine-tune every setting.

### 2. Select Video Source
Choose between:
- **Included sample wallpapers**
- **Your own video files**

### 3. Assign Wallpapers per Workspace
Installer shows thumbnail filenames and sizes.

### 4. Review Configuration
Verify gaps, videos, workspaces, and autostart settings.

### 5. Autostart (Optional)
Installer adds entries to:
- exec-once  
- Hyprland source config

### 6. Start Immediately (Optional)
Start wallpapers right away after installation.

---

## 🎬 Sample Videos Included

A curated library of 50+ wallpapers located in `sample_videos/`.

### Anime & Action
Examples:
- black-panther_optimized.mp4
- goku-lofi_optimized.mp4
- kakashi_optimized.mp4
- itachi-red_optimized.mp4
- tekken-7_optimized.mp4
- venom-marvel_optimized.mp4

### Abstract & Visual
Examples:
- burning_optimized.mp4  
- kaleidoscope_optimized.mp4  
- hypnotic_optimized.mp4  
- polygon-mesh_optimized.mp4  
- vaporwave_optimized.mp4  

### Nature & Atmospheric
Examples:
- galaxy_optimized.mp4  
- butterflies_optimized.mp4  
- torii-waterfall_optimized.mp4  
- meteorite-falling_optimized.mp4  

Files are compressed to 2–26MB using H.265.

---

## 🎮 Usage

### Autostart
If enabled during installation, reload Hyprland:

    Super + Shift + R

### Start Manually

    ~/.local/bin/hyprland-video-wallpapers.sh &

Or run in the foreground:

    ~/.local/bin/hyprland-video-wallpapers.sh

### Stop Wallpapers

    pkill -f hyprland-video-wallpapers.sh

### Reconfigure

    ./install.sh

This updates your configuration safely without deleting the existing one.

---

## ⚙️ Configuration

Stored in:

    ~/.config/hyprland-video-wallpapers/config.conf

You may edit this manually, but running the installer again is recommended.

### Installed Files

    ~/.local/bin/hyprland-video-wallpapers.sh
    ~/.config/hyprland-video-wallpapers/config.conf
    ~/.config/hyprland-video-wallpapers/hyprland-video-wallpapers.conf

### Hyprland Integration (set automatically)

    source = ~/.config/hyprland-video-wallpapers/hyprland-video-wallpapers.conf
    exec-once = ~/.local/bin/hyprland-video-wallpapers.sh

---

## 🧹 Uninstallation

    ./uninstall.sh

This will:
- Kill all wallpaper processes  
- Remove exec-once entries  
- Remove source lines  
- Restore original keybinds if modified  
- Delete config and installed files  
- Clean up temporary sockets  

Your Hyprland setup remains intact.

---

## 🔧 How It Works

### Per-Workspace Wallpapers
- Each workspace gets its own MPV instance
- MPV windows sit behind all other windows
- Only the active workspace's video plays

### Intelligent Window Layout
- Script listens to Hyprland events  
- New windows float automatically  
- Windows arranged in pseudo-tiling  
- Never overlap the wallpaper MPV window

### Event Listener
The script reacts to:
- Workspace changes  
- Window open/close events  
- Monitor focus changes  

---

## 💡 Performance Tips

### Optimize Videos
Use:

    hyprland-video-optimizer

Recommended specs:
- Codec: H.265  
- Bitrate: 500–1500 kbps  
- Target size: 5–10MB  
- Match your monitor resolution  

### Hardware Recommendations
- **Minimum:** 8GB RAM  
- **Recommended:** 16GB RAM  
- **Ideal:** Dedicated GPU  

### Resource-Saving Tips
- Lower bitrate  
- Reduce resolution  
- Use fewer wallpapers  
- Disable while on battery  

---

## 🐛 Troubleshooting

### Wallpapers Not Starting
Check if process is running:

    pgrep -f hyprland-video-wallpapers.sh

Run script manually:

    ~/.local/bin/hyprland-video-wallpapers.sh

Verify Hyprland:

    hyprctl version

### Windows Behind Wallpaper
Ensure togglefloating is disabled:

    # bind = $mainMod, f, togglefloating

Restart the script afterward.

### High CPU/GPU Usage
- Optimize videos  
- Use H.265  
- Reduce resolution  
- Ensure videos are small  

---

## 🤝 Contributing

Open an issue or PR on GitHub!

Ways to support:
- Star the repo  
- Report bugs  
- Request features  
- Share wallpapers  

---

## 📞 Contact

**Creator:** xclusivvvv  
**Discord:** xclusivvvv  
**GitHub:** https://github.com/XclusivVv/hyprland-video-wallpapers  
**Issues:** https://github.com/XclusivVv/hyprland-video-wallpapers/issues  

---

## 📄 License

MIT License – see LICENSE.

---

## 🎬 Credits

- MPV — video backend  
- Hyprland — window manager  
- socat — IPC utilities  
- hyprland-video-optimizer — compression tool  

Wallpapers sourced from various creators and optimized for performance.

---

**Enjoy your animated Hyprland desktop!**  
*"This was a struggle.." — xclusivvvv*
