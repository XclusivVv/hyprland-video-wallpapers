hyprland-video-wallpapers
-------------------------

This is a small tool I wrote to make video wallpapers behave (sort of) properly on Hyprland.
MPV does the video part, Hyprpaper handles images, and the script glues everything
together per workspace. Nothing too fancy, just something that works the way I wanted.

The GUI walks you through setup and writes the config + scripts automatically.
It also comes with an uninstaller that puts your Hyprland config back the way it was.


What it does
------------

- Picks a wallpaper (video or image) for each workspace
- Runs MPV in the background for video workspaces
- Uses Hyprpaper for image workspaces
- Switches things cleanly when you change workspaces
- Disables floating on video workspaces so windows don’t overlap the wallpaper
- Handles MPV IPC so videos pause when you leave the workspace, etc.
- Makes thumbnails for quick preview in the GUI

I made this mostly because nothing else did exactly what I needed.


Prereqs (Arch)
--------------

Install everything this needs in one line:

`sudo pacman -S python python-gobject gtk4 libadwaita mpv ffmpeg jq socat hyprpaper`

Then run the script:

`python app.py`


Files it creates
----------------

Config:        `~/.config/hyprland-video-wallpapers/`
Rules:         `~/.config/hyprland-video-wallpapers/rules/hyprland-video-wallpapers.conf`
Script:        `~/.local/bin/hyprland-video-wallpapers.sh`
Thumbnails:    `~/.cache/hvw_thumbs/`
Hyprland:      Adds a couple `source=` lines + one `exec-once=` to hyprland.conf


How it works (rough version)
----------------------------

The GUI gathers your wallpaper folders and maps them to workspaces.
A rules file gets generated for Hyprland.  
The helper script launches MPV instances for the video ones.
Hyprland workspace events (via socat) control which video is running,
when to pause, resume, or kill old ones.

Image-only workspaces just use Hyprpaper normally.

Uninstall removes everything and restores your backups. No surprises. If anything is left behind, run the uninstall again.


https://github.com/xclusivvv/hyprland-video-wallpapers

Contact: xclusivvvv on Discord