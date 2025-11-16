![Centered Image](/assets/logo.png)

<div align="center">
  <h1>Per-workspace animated wallpapers with intelligent window management</h1>
  
  ![bash](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white)
  ![hyprland](https://img.shields.io/badge/Hyprland-Compatible-00A0FF?logo=wayland&logoColor=white)
  ![mpv](https://img.shields.io/badge/MPV-Video_Backgrounds-6A0DAD)
  ![license](https://img.shields.io/github/license/XclusivVv/hyprland-video-wallpapers)
  ![lastcommit](https://img.shields.io/github/last-commit/XclusivVv/hyprland-video-wallpapers)
</div>

<div align="center">
  <img src="docs/preview/preview.gif" alt="preview animation">
</div>

---

## Overview

Transform your Hyprland desktop with **per-workspace video wallpapers**. Each workspace gets its own animated background that automatically pauses when switching away. Windows are arranged intelligently in a pseudo-tiling layout above the wallpaper.

**Note:** 16GB RAM is recommended. Videos should be optimized (H.265, ~500kb–10mb).

---

## ✨ Features

### 🎨 Multiple Wallpapers
- Assign unique wallpapers to workspaces 1–10  
- 50+ pre-optimized wallpapers included  
- Automatic play/pause when switching  
- Supports MP4 and MKV  

### 🪄 Interactive Installation Wizard
- Modern, colorful TUI-based setup  
- Auto-detects Hyprland and dependencies  
- Sample video browser  
- Express + Custom modes  
- Optional autostart  

### 🖥️ Smart Window Management
- One MPV instance per workspace  
- Wallpaper windows set to lowest z-layer  
- Apps arranged in pseudo-tiling layout  
- Adjustable gaps  

### 📑 Pre-Optimized Wallpapers
- 50+ anime, abstract, nature, and tech clips  
- H.265 encoding for small size  
- Files typically 500kb-10mb  

### 🤯 Easy Management
- Enable autostart  
- Start/stop anytime  
- Re-run installer safely  
- Full uninstaller that reverts changes  

---

## 🔥 Quick Start

    git clone https://github.com/XclusivVv/hyprland-video-wallpapers.git
    cd hyprland-video-wallpapers

    chmod +x install.sh uninstall.sh
    ./install.sh

The installer guides you through everything interactively.

![Centered Image](/assets/tutorial.gif)

---

## 📋 Requirements

The installer checks (and installs on Arch systems):

- Hyprland  
- mpv  
- socat  
- jq  
- git (optional, needed for optimizer auto-install)

---

## 🏜️ Sample Videos Included

This project ships with **50+ fully optimized videos**, available in the `sample_videos/` directory. All videos are encoded with **H.265**, typically **500kb–10mb** each, and grouped by theme.

### Anime & Action

- black-panther_optimized.mp4  
- goku-lofi_optimized.mp4  
- kakashi_optimized.mp4  
- itachi-red_optimized.mp4  
- tekken-7_optimized.mp4  
- venom-marvel_optimized.mp4  

### Abstract & Visual

- burning_optimized.mp4  
- kaleidoscope_optimized.mp4  
- hypnotic_optimized.mp4  
- polygon-mesh_optimized.mp4  
- vaporwave_optimized.mp4  

### Nature & Atmospheric

- galaxy_optimized.mp4  
- butterflies_optimized.mp4  
- torii-waterfall_optimized.mp4  
- meteorite-falling_optimized.mp4  

These serve as ready-to-use wallpapers or templates to optimize your own videos.

---

## ℹ️ Usage

### Autostart
If enabled, reload Hyprland:

    Super + Shift + R

### Start Manually

    ~/.local/bin/hyprland-video-wallpapers.sh &

Foreground mode:

    ~/.local/bin/hyprland-video-wallpapers.sh

### Stop Wallpapers

    pkill -f hyprland-video-wallpapers.sh

### Reconfigure

    ./install.sh

Safely updates configuration without deleting existing values.

---

## ⚙️ Configuration

Config files live at:

    ~/.config/hyprland-video-wallpapers/config.conf
    ~/.config/hyprland-video-wallpapers/hyprland-video-wallpapers.conf

Installed script:

    ~/.local/bin/hyprland-video-wallpapers.sh

### Auto-Generated Hyprland Entries

    source = ~/.config/hyprland-video-wallpapers/hyprland-video-wallpapers.conf
    exec-once = ~/.local/bin/hyprland-video-wallpapers.sh

---

## 🧹 Uninstallation

    ./uninstall.sh

This removes and reverts any changes the install.sh made to your system:
- Running wallpaper processes  
- Autostart entries  
- Sourced config lines  
- Installed scripts & configs  
- Temporary IPC sockets  

Hyprland remains unchanged.

---

## 🔧 How It Works

### Per-Workspace MPV Instances
- A dedicated MPV runs for each workspace  
- Only the active workspace's video plays  
- Others pause automatically  

### Smart Window Layout
- New windows float by default  
- Script arranges windows in a pseudo-tiling grid  
- Wallpaper window is always behind user windows  

### Event Listener
Responds to:
- Workspace changes  
- Window creation/destruction  
- Monitor focus changes  

---

## 💡 Performance Tips

### Optimize Videos
Use the optimizer:

    hyprland-video-optimizer

Recommended settings:
- Codec: H.265  
- Bitrate: 500–1500 kbps  
- Resolution matching your display  
- <10MB ideal per wallpaper  

### Hardware
- Minimum: 8GB RAM  
- Recommended: 16GB RAM  
- Best: Dedicated GPU  

### Save Resources
- Lower bitrate  
- Lower resolution  
- Fewer wallpapers  
- Disable when on battery  

---

## 💬 Troubleshooting

### Wallpapers Not Starting

    pgrep -f hyprland-video-wallpapers.sh

Start manually:

    ~/.local/bin/hyprland-video-wallpapers.sh

Check Hyprland:

    hyprctl version

### Windows Behind Wallpaper
Disable togglefloating:

    # bind = $mainMod, f, togglefloating

Then restart the script.

### High CPU/GPU Use
- Re-optimize videos  
- Reduce resolution  
- Keep file sizes small  

---

## 🤝 Contributing

Pull requests and issues are welcome.

Ways to support:
- Star the repository  
- Report bugs  
- Submit features  
- Share wallpapers  

---

## 📞 Contact

**Creator:** xclusivvvv  
**Discord:** xclusivvvv  
**GitHub:** https://github.com/XclusivVv/hyprland-video-wallpapers  
**Issues:** https://github.com/XclusivVv/hyprland-video-wallpapers/issues  

---

## 📄 License

MIT License — see LICENSE.

---

## 📝 Credits

- MPV — video backend  
- Hyprland — window manager  
- socat — IPC utilities  
- [hyprland-video-optimizer](https://github.com/XclusivVv/hyprland-video-optimizer) 

Wallpapers sourced from various creators and optimized for performance.

---

**Enjoy your animated Hyprland desktop!**  
*"This was a struggle.." — xclusivvvv*
