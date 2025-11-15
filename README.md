<div align="center">

<img src="logo.svg" width="540" alt="HyprVideo logo" />

**Per-workspace video wallpapers with pseudo-tiling window management**

<img src="https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white" alt="bash" />
<img src="https://img.shields.io/badge/Hyprland-Compatible-00A0FF?logo=wayland&logoColor=white" alt="hyprland" />
<img src="https://img.shields.io/badge/MPV-Video_Backgrounds-6A0DAD?logo=mpv&logoColor=white" alt="mpv" />
<img src="https://img.shields.io/github/license/XclusivVv/hyprland-video-wallpapers" alt="license" />
<img src="https://img.shields.io/github/last-commit/XclusivVv/hyprland-video-wallpapers" alt="last commit" />

</div>

---

## Preview

<p align="center">
![Preview GIF](docs/preview/preview.gif)
</p>

<p align="center"><i>Note: Not recommended for low-spec systems. 16GB RAM minimum is strongly advised.</i></p>

---

## Quick Start (Arch Linux)

```bash
git clone https://github.com/XclusivVv/hyprland-video-wallpapers.git
cd hyprland-video-wallpapers

chmod +x install.sh
./install.sh
```

---

## What the installer does

- Verifies `hyprctl` exists (warns if not).  
- Installs runtime dependencies (`mpv`, `socat`, `jq`) via pacman if available.  
- Copies `hyprland-video-wallpapers.sh` to `~/.local/bin/hyprland-video-wallpapers`.  
- Copies config `hyprland-video-wallpapers.conf` to `~/.config/hypr/`.  
- Creates autostart fragment `~/.config/hypr/workspace-video-autostart.conf`.  
- Optionally comments out `togglefloating` in `keybinds.conf` to prevent conflicts.  

> Works with any Hyprland variant (`hyprland`, `hyprland-git`, etc.).

---

## Hyprland configuration

Add **only this line** to your `hyprland.conf`:

```conf
source = ~/.config/hypr/hyprland-video-wallpapers.conf
```

---

## Script configuration

Edit `hyprland-video-wallpapers.sh`:

```bash
VIDEO_MAP=(
  "1:/home/you/videos/video1.mp4"
  "2:/home/you/videos/video2.mp4"
  # ...
)

GAP_SIZE=5
TOP_GAP=15
```

---

## Usage

Run:

```bash
~/.local/bin/hyprland-video-wallpapers &
```

Stop:

```bash
pkill -f hyprland-video-wallpapers.sh
```

---

## How it works

- MPV is promoted to master tile and pushed to the bottom of the tiled layer (`alterzorder bottom`).  
- All other apps float and are pseudo-tiled via exact geometry dispatchers.  
- Ensures stable video backgrounds per workspace while other apps float on top.  

---

## License

MIT — see `LICENSE`.

---

_PS: This was a struggle._
