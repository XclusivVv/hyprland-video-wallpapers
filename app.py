#!/usr/bin/env python3
"""
Hyprland Video Wallpapers GUI - Complete Installer/Uninstaller
Full GTK4 + LibAdwaita application with all features integrated
Enhanced with multi-backend support (MPV + Hyprpaper)

Improvements:
1. Removed express install feature (streamlined to single custom flow)
2. Uninstaller cleans up leftover MPV sockets in /tmp/mpv-ws*
3. Uninstallation Complete page has "Start Again" button
4. App launches as floating window
5. Fixed Hyprpaper IPC socket control (proper unload/reload workflow)
"""

import os
import sys
import subprocess
import shutil
import json
import time
import hashlib
import logging
from pathlib import Path
from threading import Thread

# --- LOGGING SETUP ---
LOG_DIR = Path.home() / ".config" / "hyprland-video-wallpapers"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / f"gui_debug_{int(time.time())}.log"

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

logger.info("=" * 80)
logger.info("Hyprland Video Wallpapers GUI Starting")
logger.info(f"Log file: {LOG_FILE}")
logger.info("=" * 80)

try:
    import gi
    logger.info("✓ gi module imported")
    gi.require_version('Gtk', '4.0')
    gi.require_version('Gdk', '4.0')
    logger.info("✓ GTK/GDK versions required")
    from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Gio
    logger.info("✓ GTK/GDK modules imported")
except Exception as e:
    logger.error(f"✗ Failed to import GTK modules: {e}", exc_info=True)
    sys.exit(1)

try:
    gi.require_version('Adw', '1')
    from gi.repository import Adw
    HAS_ADW = True
    logger.info("✓ Adwaita available")
except Exception as e:
    HAS_ADW = False
    logger.warning(f"✗ Adwaita not available (non-critical): {e}")

# --- CONSTANTS ---
APP_ID = "org.example.hypr_video_wallpaper_gui"
HOME = Path.home()
CONFIG_DIR = HOME / ".config" / "hyprland-video-wallpapers"
HELPER_SCRIPT = HOME / ".local" / "bin" / "hyprland-video-wallpapers.sh"
HYPR_CONF = HOME / ".config" / "hypr" / "hyprland.conf"
HYPRPAPER_CONF = HOME / ".config" / "hypr" / "hyprpaper.conf"
RULES_DEST_DIR = CONFIG_DIR / "rules"
RULES_DEST = RULES_DEST_DIR / "hyprland-video-wallpapers.conf"
THUMB_CACHE = HOME / ".cache" / "hvw_thumbs"
THUMB_CACHE.mkdir(parents=True, exist_ok=True)

VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".mov", ".avi"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}

# --- UTILITIES ---
def run(cmd):
    """Execute command and return stdout, stderr"""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return p.stdout, p.stderr
    except Exception as e:
        return "", str(e)

def sha1(x: str) -> str:
    """Generate SHA1 hash"""
    return hashlib.sha1(x.encode()).hexdigest()

# --- MEDIA ITEM CLASSES ---
class MediaItem:
    def __init__(self, path: Path):
        self.path = path
        self.title = path.name
        self.thumb = None
        self.workspace = 0
        self.is_video = path.suffix.lower() in VIDEO_EXTS
        self.is_image = path.suffix.lower() in IMAGE_EXTS

class VideoItem(MediaItem):
    def __init__(self, path: Path):
        super().__init__(path)
        self.duration = 0.0
        self.width = 0
        self.height = 0
        self._probe()

    def _probe(self):
        """Probe video metadata using ffprobe"""
        cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", 
               "-show_format", "-show_streams", str(self.path)]
        out, err = run(cmd)
        if not out:
            return
        try:
            data = json.loads(out)
            streams = data.get("streams", [])
            v = next((s for s in streams if s.get("codec_type") == "video"), None)
            if v:
                self.width = int(v.get("width", 0))
                self.height = int(v.get("height", 0))
            self.duration = float(data.get("format", {}).get("duration", 0))
            self.thumb = self.ensure_thumb()
        except:
            pass

    def ensure_thumb(self):
        """Generate or retrieve cached thumbnail"""
        key = sha1(str(self.path))
        out = THUMB_CACHE / f"{key}.png"
        if out.exists():
            return out
        cmd = ["ffmpeg", "-y", "-ss", "00:00:01", "-i", str(self.path), 
               "-frames:v", "1", "-vf", "scale=320:-1", str(out)]
        run(cmd)
        return out if out.exists() else None

class ImageItem(MediaItem):
    def __init__(self, path: Path):
        super().__init__(path)
        self.width = 0
        self.height = 0
        self._probe()

    def _probe(self):
        """Get image dimensions"""
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file(str(self.path))
            self.width = pb.get_width()
            self.height = pb.get_height()
            self.thumb = self.path  # Images are their own thumbnails
        except:
            pass

# --- MEDIA SCANNER ---
class MediaScanner:
    def __init__(self, directory: Path, backend_types):
        self.dir = directory
        self.backend_types = backend_types

    def scan(self):
        """Scan directory for media files based on backend types"""
        if not self.dir.exists():
            return []
        
        media_items = []
        for p in sorted(self.dir.iterdir()):
            if not p.is_file():
                continue
            
            ext = p.suffix.lower()
            if "mpv" in self.backend_types and ext in VIDEO_EXTS:
                media_items.append(VideoItem(p))
            elif "hyprpaper" in self.backend_types and ext in IMAGE_EXTS:
                media_items.append(ImageItem(p))
        
        return media_items

# --- UI COMPONENTS ---
class ThumbnailCard(Gtk.Box):
    def __init__(self, media: MediaItem, on_preview):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.media = media
        self.on_preview = on_preview

        self.set_margin_top(6)
        self.set_margin_bottom(6)
        self.set_margin_start(6)
        self.set_margin_end(6)

        # Thumbnail
        img_box = Gtk.Box()
        img = Gtk.Image()
        if media.thumb and media.thumb.exists():
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(media.thumb), 300, -1, True)
            img.set_from_pixbuf(pb)
        else:
            icon_name = "video-x-generic-symbolic" if media.is_video else "image-x-generic-symbolic"
            img.set_from_icon_name(icon_name)
        img.set_pixel_size(200)
        ctx = img.get_style_context()
        ctx.add_class("thumbnail")
        img_box.append(img)
        self.append(img_box)

        dim_text = f"{media.width}x{media.height}" if hasattr(media, 'width') else ""
        media_type = "🎥 Video" if media.is_video else "🖼️ Image"
        label = Gtk.Label(label=f"{media.title}\n{dim_text}\n{media_type}")
        label.set_wrap(True)
        label.set_justify(Gtk.Justification.CENTER)
        self.append(label)

        h = Gtk.Box(spacing=6, homogeneous=True)
        b_prev = Gtk.Button(label="Preview")
        b_prev.connect("clicked", lambda *_: self.on_preview(media))
        h.append(b_prev)

        self.append(h)
        self.add_css_class("thumbnail-card")

# --- NAVIGATION UTILITY ---
def _wrap_with_nav_bar(title, content, pop_func, next_action_func=None, next_label="Next"):
    """Wraps a page content with an Adw.HeaderBar and navigation buttons."""
    if HAS_ADW:
        page_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        page_box.set_hexpand(True)
        page_box.set_vexpand(True)

        header = Adw.HeaderBar()
        header.set_title_widget(Adw.WindowTitle(title=title))

        # Back button (Left)
        back_btn = Gtk.Button()
        back_btn.set_icon_name("go-previous-symbolic")
        back_btn.connect("clicked", lambda *_: pop_func())
        header.pack_start(back_btn)

        # Next button (Right)
        if next_action_func:
            next_btn = Gtk.Button(label=next_label)
            next_btn.add_css_class("suggested-action")
            next_btn.connect("clicked", lambda *_: next_action_func())
            header.pack_end(next_btn)

        page_box.append(header)
        page_box.append(content)
        
        return page_box
    else:
        return content

# --- MAIN WINDOW ---
class MainWindow(Gtk.ApplicationWindow if not HAS_ADW else Adw.ApplicationWindow):
    def __init__(self, app):
        logger.info("MainWindow.__init__ called")
        try:
            super().__init__(application=app)
            logger.info("✓ ApplicationWindow initialized")
            self.set_title("Hyprland Video Wallpapers Installer")
            self.set_default_size(1200, 800)
            
            # Set window as floating
            self.set_decorated(True)
            
            logger.info("✓ Window title and size set")
            
            self.ws_to_media = {}
            self.selected_workspaces = set()
            self.backend_types = ["mpv"]
            self.backup_conf_path = None
            self.hyprpaper_backup_path = None

            if HAS_ADW:
                try:
                    Adw.StyleManager.get_default().set_color_scheme(1)
                    logger.info("✓ Adwaita dark mode set")
                except Exception as e:
                    logger.warning(f"Could not set Adwaita theme: {e}")

            self.stack = Gtk.Stack()
            self.set_content(self.stack)
            logger.info("✓ Stack created and set as content")
            
            self.video_dir = None
            self.image_dir = None

            self.media_items = []
            self.num_workspaces = 5
            self.gap_size = 15
            self.top_gap = 30
            self.original_hypr_conf = ""

            self.page_refs = {}
            self.ws_spin = None
            
            logger.info("Creating pages...")
            self._create_pages()
            logger.info("✓ Pages created")
            
            self._push_page("Welcome", self.welcome_page)
            logger.info("✓ Welcome page pushed")
            
        except Exception as e:
            logger.error(f"Error in MainWindow.__init__: {e}", exc_info=True)
            raise

    def _create_pages(self):
        """Create all UI pages"""
        logger.info("Creating static pages...")
        self.welcome_page = self._page_welcome()
        logger.info("✓ Welcome page created")
        self.prereq_page = self._page_prereq()
        logger.info("✓ Prereq page created")
        self.video_source_page = self._page_video_source()
        logger.info("✓ Video source page created")
        self.custom_settings_page = self._page_custom_settings()
        logger.info("✓ Custom settings page created")
        self.uninstall_page = self._page_uninstall()
        logger.info("✓ Uninstall page created")
        
        self.gallery_page = Gtk.Box()
        self.review_page = Gtk.Box()
        self.apply_page = Gtk.Box()
        self.summary_page = Gtk.Box()
        self.uninstall_progress_page = Gtk.Box()
        logger.info("✓ Dynamic page placeholders created")

    def _push_page(self, title, page_content):
        """Push page to navigation stack"""
        next_actions = {
            "Prerequisites": (self.prereq_to_source, "Next"),
            "Video Source": (self._proceed_to_settings, "Next"),
            "Custom Settings": (self._load_gallery, "Select Media"),
            "Gallery": (self._build_review, "Continue to Review"),
            "Review": (self._run_install_setup, "Apply Installation"),
        }
        
        next_action_func, next_label = next_actions.get(title, (None, None))
        
        content_to_push = page_content
        if HAS_ADW and title not in ["Welcome", "Summary", "Installing", "Uninstalling", "Uninstall"]:
            content_to_push = _wrap_with_nav_bar(
                title, 
                page_content, 
                self._pop_page, 
                next_action_func=next_action_func,
                next_label=next_label
            )
        
        page_name = title.lower().replace(" ", "-")

        if not self.stack.get_child_by_name(page_name):
            self.stack.add_titled(content_to_push, page_name, title)
            
        self.stack.set_visible_child_name(page_name)
        self.page_refs[title] = page_content

    def _pop_page(self):
        """Pop page from navigation stack"""
        current_name = self.stack.get_visible_child_name()

        flow = {
            "prerequisites": "welcome",
            "video-source": "prerequisites" if self.stack.get_child_by_name("prerequisites") else "welcome",
            "custom-settings": "video-source",
            "gallery": "custom-settings",
            "review": "gallery",
            "installing": "review",
            "summary": "installing",
            "uninstall": "welcome"
        }
        
        if current_name in flow:
            previous_name = flow[current_name]
            
            # Clear directory selections when going back from video-source
            if current_name == "video-source":
                self.video_dir = None
                self.image_dir = None
                self.video_dir_label.set_text("No directory selected")
                self.image_dir_label.set_text("No directory selected")
            
            # Clear selections when going back from custom-settings to video-source
            elif current_name == "custom-settings":
                self.selected_workspaces.clear()
                self.num_workspaces = 5
                self.gap_size = 15
                self.top_gap = 30
            
            # Clear media selections when going back from gallery to custom-settings
            elif current_name == "gallery":
                self.ws_to_media.clear()
            
            # Navigate to previous page
            if previous_name == "gallery":
                self._load_gallery(is_back_navigation=True)
            elif previous_name == "review":
                self._build_review(is_back_navigation=True)
            elif previous_name == "custom-settings":
                # Recreate custom settings page to reset checkboxes
                self.custom_settings_page = self._page_custom_settings()
                self._push_page("Custom Settings", self.custom_settings_page)
            elif previous_name == "video-source":
                self._push_page("Video Source", self.video_source_page)
            elif self.stack.get_child_by_name(previous_name):
                self.stack.set_visible_child_name(previous_name)
    
    def prereq_to_source(self):
        """Transition from prereq to source"""
        self.video_source_info_label.set_text("Choose a folder containing your wallpapers\n(Videos: MP4, MKV, WebM, MOV, AVI | Images: PNG, JPG, BMP, WebP)")
        self._push_page("Video Source", self.video_source_page)

    # --- PAGE BUILDERS ---
    def _page_welcome(self):
        # Kill old processes and clear sockets
        try:
            # Stop old MPV wallpaper processes
            subprocess.run(["pkill", "-f", "mpv"], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)  # Wait for processes to die
            # Stop old hyprpaper wallpaper processes
            subprocess.run(["pkill", "-f", "hyprpaper"], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)  # Wait for processes to die
            # Stop old instances of the script
            subprocess.run(["pkill", "-f", ".local/bin/hyprland-video-wallpapers.sh"], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)  # Wait for processes to die
        
            # Now clean up the socket files
            for socket_file in Path("/tmp").glob("mpv-ws*"):
                socket_file.unlink()
            logger.info("Cleared old MPV processes and sockets")
        except Exception as e:
            logger.warning(f"Could not clear MPV processes/sockets: {e}")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        box.set_margin_top(40)
        box.set_margin_bottom(40)
        box.set_margin_start(40)
        box.set_margin_end(40)
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)

        title = Gtk.Label(label="Hyprland Video Wallpapers")
        title.add_css_class("title-1")
        box.append(title)

        subtitle = Gtk.Label(label="Transform your desktop with dynamic video and image wallpapers")
        subtitle.add_css_class("subtitle")
        box.append(subtitle)

        button_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        button_box.set_halign(Gtk.Align.CENTER)

        b_install = Gtk.Button(label="Install / Configure")
        b_install.add_css_class("suggested-action")
        b_install.set_size_request(200, 40)
        b_install.connect("clicked", lambda *_: self._start_install())
        button_box.append(b_install)

        b_uninstall = Gtk.Button(label="Manage / Uninstall")
        b_uninstall.set_size_request(200, 40)
        b_uninstall.connect("clicked", lambda *_: self._push_page("Uninstall", self.uninstall_page))
        button_box.append(b_uninstall)

        box.append(button_box)
        return box

    def _page_prereq(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Checking Prerequisites")
        title.add_css_class("title-2")
        box.append(title)
        
        info = Gtk.Label(label="One or more required tools are missing. Please install them to continue.")
        info.add_css_class("subtitle")
        box.append(info)

        tools = ["ffmpeg", "ffprobe", "mpv", "socat", "jq", "hyprctl", "hyprpaper"]
        grid = Gtk.Grid(column_spacing=12, row_spacing=6)
        grid.set_halign(Gtk.Align.START)
        
        for i, t in enumerate(tools):
            found = shutil.which(t) is not None
            g_lbl = Gtk.Label(label=t)
            g_lbl.set_halign(Gtk.Align.START)
            status_text = "✓ Found" if found else "✗ Missing"
            g_status = Gtk.Label(label=status_text)
            g_status.add_css_class("status-" + ("found" if found else "missing"))
            g_status.set_halign(Gtk.Align.START)
            grid.attach(g_lbl, 0, i, 1, 1)
            grid.attach(g_status, 1, i, 1, 1)

        box.append(grid)
        
        return box

    def _page_video_source(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Select Media Directories")
        title.add_css_class("title-2")
        box.append(title)

        # Video directory section
        video_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        video_title = Gtk.Label(label="Video Directory (for MPV backend)")
        video_title.add_css_class("title-3")
        video_title.set_halign(Gtk.Align.START)
        video_section.append(video_title)

        video_info = Gtk.Label(label="⚠️ Note: workspaces with video wallpapers will apply 'master' layout rules and disable 'togglefloating' keybind (this does not apply to workspaces with image wallpapers)")
        video_info.add_css_class("warning")
        video_info.set_wrap(True)
        video_info.set_halign(Gtk.Align.START)
        video_section.append(video_info)

        b_choose_video = Gtk.Button(label="Choose Video Folder")
        b_choose_video.add_css_class("suggested-action")
        b_choose_video.set_size_request(200, 40)
        b_choose_video.connect("clicked", lambda *_: self._choose_video_dir())
        video_section.append(b_choose_video)

        self.video_dir_label = Gtk.Label(label="No directory selected")
        self.video_dir_label.add_css_class("dim-label")
        video_section.append(self.video_dir_label)

        box.append(video_section)

        # Image directory section
        image_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        image_section.set_margin_top(20)

        image_title = Gtk.Label(label="Image Directory (for Hyprpaper backend)")
        image_title.add_css_class("title-3")
        image_title.set_halign(Gtk.Align.START)
        image_section.append(image_title)

        b_choose_image = Gtk.Button(label="Choose Image Folder")
        b_choose_image.add_css_class("suggested-action")
        b_choose_image.set_size_request(200, 40)
        b_choose_image.connect("clicked", lambda *_: self._choose_image_dir())
        image_section.append(b_choose_image)

        self.image_dir_label = Gtk.Label(label="No directory selected")
        self.image_dir_label.add_css_class("dim-label")
        image_section.append(self.image_dir_label)

        box.append(image_section)

        return box

    def _proceed_to_settings(self):
        """Validate directory and proceed to settings page"""
        if not self.video_dir and not self.image_dir:
            dlg = Gtk.MessageDialog(transient_for=self, flags=0, 
                                   message_type=Gtk.MessageType.ERROR,
                                   buttons=Gtk.ButtonsType.OK, 
                                   text="No directory selected")
            dlg.format_secondary_text("Please select at least one media directory")
            dlg.present()
            return
        
        self._push_page("Custom Settings", self.custom_settings_page)
    
    def _choose_image_dir(self, *_):
        dlg = Gtk.FileDialog(title="Select Image Directory")
        dlg.set_initial_folder(Gio.File.new_for_path(str(HOME)))
        dlg.select_folder(self, None, self._image_folder_cb)

    def _image_folder_cb(self, dialog, result):
        try:
            f = dialog.select_folder_finish(result)
            self.image_dir = Path(f.get_path())
            self.image_dir_label.set_text(f"Selected: {self.image_dir.name}")
        except:
            pass

    def _choose_video_dir(self, *_):
        dlg = Gtk.FileDialog(title="Select Media Directory")
        dlg.set_initial_folder(Gio.File.new_for_path(str(HOME)))
        dlg.select_folder(self, None, self._folder_cb)

    def _folder_cb(self, dialog, result):
        try:
            f = dialog.select_folder_finish(result)
            self.video_dir = Path(f.get_path())
            self.video_dir_label.set_text(f"Selected: {self.video_dir.name}")
        except:
            pass

    def _page_custom_settings(self):
        """Custom install settings page with workspace and backend selection"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Configuration Settings")
        title.add_css_class("title-2")
        box.append(title)

        # Backend selection
        backend_title = Gtk.Label(label="Select Wallpaper Backends")
        backend_title.add_css_class("title-3")
        box.append(backend_title)

        backend_info = Gtk.Label(label="Choose which types of wallpapers to use:")
        backend_info.add_css_class("subtitle")
        box.append(backend_info)

        backend_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        
        self.mpv_check = Gtk.CheckButton(label="MPV (Video wallpapers)")
        if self.video_dir is not None:
            self.mpv_check.set_active(True)
        else:
            self.mpv_check.set_active(False)
        self.mpv_check.set_sensitive(True)  # Always selectable
        self.mpv_check.connect("toggled", self._on_backend_toggled)
        backend_box.append(self.mpv_check)

        self.hyprpaper_check = Gtk.CheckButton(label="Hyprpaper (Image wallpapers)")
        if self.image_dir is not None:
            self.hyprpaper_check.set_active(True)
        else:
            self.hyprpaper_check.set_active(False)
        self.hyprpaper_check.set_sensitive(True)  # Always selectable
        self.hyprpaper_check.connect("toggled", self._on_backend_toggled)
        backend_box.append(self.hyprpaper_check)

        # Initialize backend_types based on selected directories
        self._on_backend_toggled(None)

        box.append(backend_box)

        # Workspace selection
        ws_title = Gtk.Label(label="Select Workspaces")
        ws_title.add_css_class("title-3")
        box.append(ws_title)

        info = Gtk.Label(label="Select which workspaces to manage:")
        info.add_css_class("subtitle")
        box.append(info)

        grid = Gtk.Grid(column_spacing=12, row_spacing=8)
        grid.set_halign(Gtk.Align.START)
        grid.set_column_homogeneous(False)

        for i in range(1, 10):
            ws_label = Gtk.Label(label=f"Workspace {i}:")
            ws_label.set_halign(Gtk.Align.START)
            grid.attach(ws_label, 0, i - 1, 1, 1)

            ws_check = Gtk.CheckButton()
            ws_check.connect("toggled", lambda cb, ws=i: self._on_workspace_toggled(cb, ws))
            grid.attach(ws_check, 1, i - 1, 1, 1)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_child(grid)
        scroll.set_min_content_height(200)
        box.append(scroll)

        # Gap settings
        gap_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        gap_title = Gtk.Label(label="Gap Settings")
        gap_title.add_css_class("title-3")
        gap_box.append(gap_title)

        g_box = Gtk.Box(spacing=12, homogeneous=False)
        g_label = Gtk.Label(label="Window gap (px):")
        g_label.set_halign(Gtk.Align.START)
        g_spin = Gtk.SpinButton.new_with_range(0, 60, 1)
        g_spin.set_value(self.gap_size)
        g_spin.connect("value-changed", lambda w: setattr(self, "gap_size", int(w.get_value())))
        g_box.append(g_label)
        g_box.append(g_spin)
        gap_box.append(g_box)

        t_box = Gtk.Box(spacing=12, homogeneous=False)
        t_label = Gtk.Label(label="Top gap (px):")
        t_label.set_halign(Gtk.Align.START)
        t_spin = Gtk.SpinButton.new_with_range(0, 200, 5)
        t_spin.set_value(self.top_gap)
        t_spin.connect("value-changed", lambda w: setattr(self, "top_gap", int(w.get_value())))
        t_box.append(t_label)
        t_box.append(t_spin)
        gap_box.append(t_box)

        box.append(gap_box)
        return box

    def _on_backend_toggled(self, checkbox):
        """Handle backend checkbox toggle"""
        self.backend_types = []
        if self.mpv_check.get_active():
            self.backend_types.append("mpv")
        if self.hyprpaper_check.get_active():
            self.backend_types.append("hyprpaper")

    def _on_workspace_toggled(self, checkbox, ws_id):
        """Handle workspace checkbox toggle"""
        if checkbox.get_active():
            self.selected_workspaces.add(ws_id)
        else:
            self.selected_workspaces.discard(ws_id)
        self.num_workspaces = len(self.selected_workspaces)

    def _page_gallery(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        outer.set_margin_top(20)
        outer.set_margin_bottom(20)
        outer.set_margin_start(20)
        outer.set_margin_end(20)

        title = Gtk.Label(label="Select media for workspaces")
        title.add_css_class("title-2")
        outer.append(title)

        h_paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        h_paned.set_vexpand(True)
        h_paned.set_position(450)
        outer.append(h_paned)
        
        ws_assignment_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        ws_assignment_box.set_margin_end(10)
        ws_assignment_box.set_vexpand(True)
        h_paned.set_start_child(ws_assignment_box)
        
        ws_list = sorted(self.selected_workspaces)
        ws_count = len(ws_list)
        
        ws_info = Gtk.Label(label=f"Assign one media item to each of the {ws_count} workspaces")
        ws_info.set_wrap(True)
        ws_info.add_css_class("subtitle")
        ws_assignment_box.append(ws_info)

        grid = Gtk.Grid(column_spacing=12, row_spacing=8)
        grid.set_halign(Gtk.Align.START)
        grid.set_column_homogeneous(False) 
        
        media_strings = ["None (Unassigned)"] + [m.title for m in self.media_items]
        
        for idx, ws_id in enumerate(ws_list):
            ws_label = Gtk.Label(label=f"Workspace {ws_id}:")
            ws_label.set_halign(Gtk.Align.START)
            grid.attach(ws_label, 0, idx, 1, 1)

            ws_dropdown = Gtk.DropDown.new_from_strings(media_strings)
            ws_dropdown.set_halign(Gtk.Align.FILL)
            ws_dropdown.set_hexpand(True)
            
            current_media_path = self.ws_to_media.get(ws_id)
            if current_media_path:
                try:
                    current_media_title = Path(current_media_path).name
                    selected_index = media_strings.index(current_media_title)
                    ws_dropdown.set_selected(selected_index)
                except ValueError:
                    ws_dropdown.set_selected(0) 
            else:
                ws_dropdown.set_selected(0)

            ws_dropdown.connect("notify::selected", 
                               lambda dd, _, ws=ws_id, ms=self.media_items: self._on_media_selected(dd, ws, ms))
            
            grid.attach(ws_dropdown, 1, idx, 1, 1)

        grid_scroll = Gtk.ScrolledWindow()
        grid_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        grid_scroll.set_child(grid)
        grid_scroll.set_min_content_height(200)

        ws_assignment_box.append(grid_scroll)
        
        preview_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        preview_box.set_margin_start(10)
        preview_box.set_vexpand(True)
        h_paned.set_end_child(preview_box)

        preview_title = Gtk.Label(label="Media Preview Gallery")
        preview_title.add_css_class("title-3")
        preview_box.append(preview_title)

        preview_info = Gtk.Label(label="Click Preview to view media samples")
        preview_info.add_css_class("dim-label")
        preview_box.append(preview_info)

        self.flow = Gtk.FlowBox()
        self.flow.set_valign(Gtk.Align.START)
        self.flow.set_max_children_per_line(3)
        self.flow.set_min_children_per_line(1)
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)

        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True) 
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_child(self.flow)
        preview_box.append(scroll)
        
        self.gallery_page = outer 
        return outer

    def _load_gallery(self, is_back_navigation=False):
        if not self.video_dir and not self.image_dir:
            return

        if not is_back_navigation:
            self.media_items = []

            # Scan video directory if it was selected
            if self.video_dir:
                video_scanner = MediaScanner(self.video_dir, ["mpv"])
                self.media_items.extend(video_scanner.scan())

            # Scan image directory if it was selected
            if self.image_dir:
                image_scanner = MediaScanner(self.image_dir, ["hyprpaper"])
                self.media_items.extend(image_scanner.scan())

            if not self.media_items:
                dlg = Gtk.MessageDialog(transient_for=self, flags=0, 
                                    message_type=Gtk.MessageType.ERROR,
                                    buttons=Gtk.ButtonsType.OK, text="No media found")
                dlg.format_secondary_text("No valid media files found in the selected directories for the enabled backends")
                dlg.present()
                return

        current_paths = {str(m.path) for m in self.media_items}
        ws_list = sorted(self.selected_workspaces)
        self.ws_to_media = {ws: path for ws, path in self.ws_to_media.items() 
                            if path in current_paths and ws in ws_list}

        self._page_gallery()

        self.flow.remove_all()
        for media in self.media_items:
            card = ThumbnailCard(media, self._preview_media)
            self.flow.append(card)

        self._push_page("Gallery", self.gallery_page)

    def _preview_media(self, media):
        """Launch external preview for media"""
        try:
            if media.is_video:
                subprocess.Popen(["mpv", str(media.path), "--loop", "--no-terminal"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif media.is_image:
                viewers = ["eog", "feh", "sxiv", "gwenview"]
                for viewer in viewers:
                    if shutil.which(viewer):
                        subprocess.Popen([viewer, str(media.path)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        break
        except Exception as e:
            print(f"Preview failed: {e}")

    def _on_media_selected(self, dropdown, ws_id, media_items):
        """Handle media selection for a specific workspace"""
        selected_index = dropdown.get_selected()
        
        if selected_index == 0:
            if ws_id in self.ws_to_media:
                del self.ws_to_media[ws_id]
            return

        selected_media = media_items[selected_index - 1]
        
        for existing_ws, existing_path in self.ws_to_media.items():
            if existing_ws != ws_id and existing_path == str(selected_media.path):
                dlg = Gtk.MessageDialog(transient_for=self, flags=0,
                                       message_type=Gtk.MessageType.WARNING,
                                       buttons=Gtk.ButtonsType.OK,
                                       text="Media Already Assigned")
                dlg.format_secondary_text(
                    f"Media '{selected_media.title}' is already assigned to Workspace {existing_ws}.\n\n"
                    "Please choose a different media item or unassign the conflicting workspace first."
                )
                dlg.present()
                dropdown.set_selected(0)
                return
        
        self.ws_to_media[ws_id] = str(selected_media.path)

    def _page_review(self):
        # Create scrolled window wrapper
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Review Configuration")
        title.add_css_class("title-2")
        box.append(title)

        self.review_label = Gtk.Label(label="")
        self.review_label.set_wrap(True)
        self.review_label.set_selectable(True)
        self.review_label.set_halign(Gtk.Align.START)
        box.append(self.review_label)

        info_title = Gtk.Label(label="What will happen:")
        info_title.add_css_class("title-3")
        info_title.set_halign(Gtk.Align.START)
        box.append(info_title)

        info = Gtk.Label()
        info.set_wrap(True)
        info.set_halign(Gtk.Align.START)

        # Count video workspaces for dynamic info text
        video_ws_count = sum(1 for path in self.ws_to_media.values() 
                            if Path(path).suffix.lower() in VIDEO_EXTS)

        info_text = (
            "• Helper scripts will be written to ~/.local/bin\n"
            "• Configuration will be stored in ~/.config/hyprland-video-wallpapers\n"
            "• Your hyprland.conf will be backed up and modified to source the new rules\n"
        )

        if video_ws_count > 0:
            info_text += f"• 'togglefloating' will be disabled on {video_ws_count} video workspace(s), but enabled elsewhere\n"

        info_text += "• Wallpaper processes (MPV, Hyprpaper) will be launched"

        info.set_text(info_text)
        box.append(info)

        paths_title = Gtk.Label(label="Target paths:")
        paths_title.add_css_class("title-3")
        paths_title.set_halign(Gtk.Align.START)
        box.append(paths_title)

        paths = Gtk.Label()
        paths.set_wrap(True)
        paths.add_css_class("monospace")
        paths.set_halign(Gtk.Align.START)
        paths_text = (
            f"Helper: {HELPER_SCRIPT}\n"
            f"Config: {CONFIG_DIR}\n"
            f"Rules: {RULES_DEST}\n"
            f"Hyprpaper: {HYPRPAPER_CONF}"
        )
        paths.set_text(paths_text)
        box.append(paths)

        # Only show video workspace info if there are video workspaces
        if video_ws_count > 0:
            float_warning_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            float_warning_box.add_css_class("info-box")
            float_warning_box.set_margin_top(10)

            float_title = Gtk.Label(label="ℹ️ Note on Video Wallpaper Workspaces")
            float_title.add_css_class("title-3")
            float_title.set_halign(Gtk.Align.START)
            float_warning_box.append(float_title)

            float_text = Gtk.Label(label=f"Video wallpapers use a 'pseudo-tiling' system where windows are floated. The 'togglefloating' keybind will be automatically disabled on the {video_ws_count} workspace(s) with video wallpapers, but will remain enabled on other workspaces (including image wallpaper workspaces).")
            float_text.set_wrap(True)
            float_text.set_halign(Gtk.Align.START)
            float_warning_box.append(float_text)

            box.append(float_warning_box)

            warning_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            warning_box.add_css_class("warning-box")
            warning_box.set_margin_top(20)
            warning_box.set_margin_bottom(20)

            warning_title = Gtk.Label(label="⚠️ IMPORTANT: CLOSE ALL OPEN WINDOWS ⚠️")
            warning_title.add_css_class("title-2")
            warning_title.add_css_class("warning-text")
            warning_box.append(warning_title)

            warning_text = Gtk.Label(label="All currently open windows will be stuck under the wallpaper!\n\nCLOSE ALL WINDOWS BEFORE CLICKING 'Apply Installation' OR RELOADING HYPRLAND")
            warning_text.set_wrap(True)
            warning_text.add_css_class("warning-text")
            warning_box.append(warning_text)

            box.append(warning_box)

        scroll.set_child(box)
        self.review_page = scroll
        return scroll

    def _build_review(self, is_back_navigation=False):
        self._page_review()
    
        backend_str = ", ".join(self.backend_types).upper()
        summary = ""
        if self.video_dir:
            summary += f"🎥 Video Directory: {self.video_dir}\n"
        if self.image_dir:
            summary += f"🖼️ Image Directory: {self.image_dir}\n"
        summary += f"🖥️ Workspaces to manage: {self.num_workspaces}\n"
        summary += f"🎨 Backends: {backend_str}\n"
        summary += f"📏 Window Gap: {self.gap_size}px\n"
        summary += f"📐 Top Gap: {self.top_gap}px\n\n"
        summary += "Workspace Assignments:\n"

        assigned_count = 0
        sorted_assignments = sorted(self.ws_to_media.items())

        for ws_id, media_path_str in sorted_assignments:
            media_title = Path(media_path_str).name
            ext = Path(media_path_str).suffix.lower()
            media_type = "🎥" if ext in VIDEO_EXTS else "🖼️"
            summary += f"  WS{ws_id}: {media_type} {media_title}\n"
            assigned_count += 1

        if assigned_count == 0:
            summary += "  ⚠️ No media assigned! (Installation will proceed but no wallpapers will start)\n"

        self.review_label.set_text(summary)
        self._push_page("Review", self.review_page)

    def _run_install_setup(self):
        self._page_apply()
        self._push_page("Installing", self.apply_page)
        self._run_install_async() 

    def _page_apply(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Installing...")
        title.add_css_class("title-2")
        box.append(title)

        self.apply_log = Gtk.TextView()
        self.apply_log.set_editable(False)
        self.apply_log.set_monospace(True)
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.apply_log)
        scroll.set_min_content_height(400)
        box.append(scroll)
        
        self.apply_page = box
        return box

    def _log(self, msg):
        """Add message to log (Thread-safe)"""
        def do_log():
            buf = self.apply_log.get_buffer()
            buf.insert(buf.get_end_iter(), msg + "\n")
            insert_mark = buf.get_insert()
            self.apply_log.scroll_to_mark(insert_mark, 0.0, False, 0.0, 0.0)
            
        GLib.idle_add(do_log)

    def _run_install_async(self):
        """Run installer in background thread"""
        thread = Thread(target=self._run_install, daemon=True)
        thread.start()

    def _run_install(self):
        """Execute full installation"""
        try:
            self._log("🛑 Stopping conflicting processes...")
            run(["pkill", "-f", "mpvpaper"])
            run(["pkill", "-f", "mpv --title=mpv-workspace-video"])
            run(["pkill", "-f", "hyprpaper"])

            if "mpv" in self.backend_types:
                self._log("📝 Writing MPV helper script...")
                self._write_helper_script()

            if "hyprpaper" in self.backend_types:
                self._log("📝 Configuring Hyprpaper...")
                self._configure_hyprpaper()

            self._log("📋 Writing Hyprland rules...")
            self._write_rules_file()

            self._log("⚙️ Configuring hyprland.conf...")
            self._configure_hyprland()

            self._log("🚫 Disabling togglefloating...")
            self._disable_togglefloating()

            self._log("💾 Writing configuration...")
            self._write_config_file()

            self._log("✅ Installation complete! Starting wallpapers...")
            
            self._start_wallpapers_silent()
            
            self._log("⏳ Waiting for wallpapers to initialize...")
            time.sleep(5)
            
            self._log("✅ Wallpapers started! Pushing summary page...")
            
            def show_summary_and_close():
                self._push_page("Summary", self._page_summary())
                GLib.timeout_add(3000, self._close_app)
            
            GLib.idle_add(show_summary_and_close)
            
        except Exception as e:
            logger.error(f"Error during installation: {e}", exc_info=True)
            self._log(f"❌ FATAL ERROR during installation: {e}")
            self._log("Please check the log file for details.")
    def _close_app(self):
        """Helper function to close the window."""
        logger.info("Auto-closing application after successful install.")
        if self.get_application():
            self.get_application().quit()
        else:
            self.close()
        return False

    def _write_helper_script(self):
        """Write the main MPV helper script with improved Hyprpaper IPC control."""
        HELPER_SCRIPT.parent.mkdir(parents=True, exist_ok=True)
        
        # proper hyprpaper ipc control
        content = '''#!/bin/bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/hyprland-video-wallpapers/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE" >&2
    exit 1
fi
source "$CONFIG_FILE"

MPV_WINDOW_CLASS="mpv-workspace-video"
MPV_BASE_SOCKET="/tmp/mpv-ws"
HYPRPAPER_RUNNING=false

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

create_blank_image() {
    # Create a small black PNG to use as blank wallpaper
    BLANK_IMAGE="/tmp/hyprpaper_blank.png"
    
    if [ ! -f "$BLANK_IMAGE" ]; then
        # Create a 10x10 black PNG using ffmpeg
        ffmpeg -f lavfi -i color=black:s=10x10:d=0.1 -frames:v 1 "$BLANK_IMAGE" -y 2>/dev/null
        echo "Created blank wallpaper: $BLANK_IMAGE"
    fi
}

# Hyprpaper control functions
ensure_hyprpaper() {
    if ! pgrep -x hyprpaper > /dev/null; then
        hyprpaper &
        sleep 1
        HYPRPAPER_RUNNING=true
    else
        echo "Hyprpaper already running"
    fi
}

manage_togglefloating() {
    local workspace_id="$1"
    local has_video=false
    
    # Check if this workspace has a video wallpaper
    for entry in "${VIDEO_MAP[@]}"; do
        IFS=':' read -r ws_id video_path <<< "$entry"
        if [ "$ws_id" == "$workspace_id" ]; then
            has_video=true
            break
        fi
    done
    
    local togglefloat_conf="${HOME}/.config/hyprland-video-wallpapers/togglefloating.conf"
    local togglefloat_binds="${HOME}/.config/hyprland-video-wallpapers/togglefloating_binds.txt"
    
    if [ "$has_video" = true ]; then
        # Disable togglefloating for video workspace
        echo "# Togglefloating disabled on video workspace $workspace_id" > "$togglefloat_conf"
        echo "Disabled togglefloating on video workspace $workspace_id"
    else
        # Enable togglefloating for non-video workspace
        if [ -f "$togglefloat_binds" ]; then
            {
                echo "# Togglefloating enabled on non-video workspace $workspace_id"
                cat "$togglefloat_binds"
            } > "$togglefloat_conf"
            echo "Enabled togglefloating on non-video workspace $workspace_id"
        fi
    fi
}

set_hyprpaper_wallpaper() {
    local workspace_id="$1"
    local image_path="$2"
    
    ensure_hyprpaper
    
    # Preload the specific image
    hyprctl hyprpaper preload "$image_path" 2>/dev/null || true
    sleep 0.3
    
    # Get all monitors
    local monitors=$(hyprctl monitors -j | jq -r '.[].name')
    
    # Set the wallpaper on all monitors
    while IFS= read -r monitor; do
        hyprctl hyprpaper wallpaper "$monitor,$image_path" 2>/dev/null || true
        echo "Setting wallpaper on monitor $monitor: $image_path"
    done <<< "$monitors"
}

unload_all_images() {
    # Set blank wallpaper to clear images behind videos
    if pgrep -x hyprpaper > /dev/null; then
        echo "Setting blank wallpaper..."
        
        # Ensure blank image exists
        if [ -f "$BLANK_IMAGE" ]; then
            # Preload blank image
            hyprctl hyprpaper preload "$BLANK_IMAGE" 2>/dev/null || true
            sleep 0.1
            
            # Get all monitors and set blank on each
            local monitors=$(hyprctl monitors -j | jq -r '.[].name')
            while IFS= read -r monitor; do
                hyprctl hyprpaper wallpaper "$monitor,$BLANK_IMAGE" 2>/dev/null || true
            done <<< "$monitors"
            
            # Now unload all the actual image wallpapers (but keep blank loaded)
            for entry in "${IMAGE_MAP[@]}"; do
                IFS=':' read -r ws_id image_path <<< "$entry"
                hyprctl hyprpaper unload "$image_path" 2>/dev/null || true
            done
        fi
    fi
}

clear_hyprpaper_wallpaper() {
    # When leaving an image workspace, we need to clear the wallpaper
    # Hyprpaper doesn't have a "clear" command, so we use a dummy approach:
    # We'll set it to the first available wallpaper or unload all
    if pgrep -x hyprpaper > /dev/null; then
        # Unload all wallpapers to clear them from display
        hyprctl hyprpaper unload all 2>/dev/null || true
    fi
}

start_all_mpv() {
    echo "Starting MPV instances for all defined workspaces..."
    
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\\(.width) \\(.height)"')
    read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"

    for entry in "${VIDEO_MAP[@]}"; do
        IFS=':' read -r ws_id video_path <<< "$entry"
        
        local window_title=$(get_window_title "$ws_id")
        local socket_path=$(get_socket_path "$ws_id")
        
        rm -f "$socket_path"

        mpv \\
            --no-osc --no-stop-screensaver \\
            --input-ipc-server="$socket_path" \\
            --loop --video-sync=display-resample \\
            --title="$window_title" \\
            --geometry="${SCREEN_WIDTH}x${SCREEN_HEIGHT}+0+0" \\
            "$video_path" &
        
        sleep 2.0
        
        hyprctl dispatch movetoworkspace "$ws_id,title:$window_title" > /dev/null 2>&1
        sleep 0.5
        
        hyprctl dispatch focuswindow "title:$window_title" > /dev/null 2>&1
        hyprctl dispatch layoutmsg "focusmaster master" > /dev/null 2>&1
        hyprctl dispatch splitratio exact 1.0 > /dev/null 2>&1
        
        echo "  ↳ Started video for Workspace $ws_id"
        send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
    done
}

# Initialize Hyprpaper wallpapers
init_hyprpaper_wallpapers() {
    if [ ${#IMAGE_MAP[@]} -gt 0 ]; then
        echo "Initializing Hyprpaper wallpapers..."
        ensure_hyprpaper
        
        # Note: We preload images on-demand now to avoid conflicts with video workspaces
        echo "Hyprpaper ready for dynamic image switching"
    fi
}

pseudo_tile_workspace() {
    local ws_id="$1"
    
    local windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ws_id and .floating == true and (.title | test(\\"^mpv-workspace-video\\") | not)) | .address")
    
    local win_array=()
    while IFS= read -r addr; do
        [[ -n "$addr" ]] && win_array+=("$addr")
    done <<< "$windows"
    
    local win_count=${#win_array[@]}
    [[ $win_count -eq 0 ]] && return
    
    local monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\\(.width) \\(.height)"')
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

get_window_geometry() {
    local addr="$1"
    hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.address == \\"$addr\\") | \\"\\(.at[0]) \\(.at[1]) \\(.size[0]) \\(.size[1])\\""
}

find_adjacent_window() {
    local resize_addr="$1"
    local ws_id="$2"
    local edge="$3"  # "right" or "left"
    
    read -r rx ry rw rh <<< $(get_window_geometry "$resize_addr")
    local best_match=""
    local min_gap=99999
    
    while IFS= read -r addr; do
        [[ "$addr" == "$resize_addr" || -z "$addr" ]] && continue
        read -r wx wy ww wh <<< $(get_window_geometry "$addr")
        
        case "$edge" in
            "right")
                local resized_right=$((rx + rw))
                local gap=$((wx - resized_right))
                local resized_bottom=$((ry + rh))
                local candidate_bottom=$((wy + wh))
                
                if [ $gap -ge -20 ] && [ $gap -le 50 ] && [ $wy -lt $resized_bottom ] && [ $candidate_bottom -gt $ry ]; then
                    [ $gap -lt $min_gap ] && min_gap=$gap && best_match="$addr"
                fi
                ;;
            "left")
                local candidate_right=$((wx + ww))
                local gap=$((rx - candidate_right))
                local resized_bottom=$((ry + rh))
                local candidate_bottom=$((wy + wh))
                
                if [ $gap -ge -20 ] && [ $gap -le 50 ] && [ $wy -lt $resized_bottom ] && [ $candidate_bottom -gt $ry ]; then
                    [ $gap -lt $min_gap ] && min_gap=$gap && best_match="$addr"
                fi
                ;;
        esac
    done < <(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ws_id and .floating == true and (.title | test(\\"^mpv-workspace-video\\") | not)) | .address")
    
    echo "$best_match"
}

cleanup() {
    echo -e "\\nExiting script and closing all active video wallpapers..."
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
    done < <(hyprctl clients -j | jq -r '.[] | select(.title | test("^mpv-workspace-video") | not and .workspace.id != -1) | "\\(.address)|\\(.workspace.id)"')
    
    echo "Saved and moved $COUNT_MOVED windows to temporary workspace $TEMP_WORKSPACE_ID."
else
    echo "Skipping window movement: TEMP_WORKSPACE_ID ($TEMP_WORKSPACE_ID) is outside range 1-10."
fi

create_blank_image
start_all_mpv
init_hyprpaper_wallpapers

echo "Waiting for video wallpapers to initialize..."
sleep 3

if [ "$TEMP_WORKSPACE_ID" -le 10 ]; then
    echo "Restoring windows from temporary workspace..."
    for address in "${!SAVED_WINDOWS[@]}"; do
        original_ws="${SAVED_WINDOWS[$address]}"
        hyprctl dispatch movetoworkspacesilent "$original_ws,address:$address" > /dev/null 2>&1
        echo "  ↳ Restored window $address to workspace $original_ws"
    done
fi

sleep 1.0

echo "Applying window tiling..."
for ws_id in $(echo "${SAVED_WINDOWS[@]}" | tr ' ' '\\n' | sort -u); do
    if [[ "$ws_id" =~ ^[0-9]+$ ]]; then
        sleep 0.2
        pseudo_tile_workspace "$ws_id"
    fi
done

if [[ $CURRENT_WORKSPACE ]]; then
    manage_togglefloating "$CURRENT_WORKSPACE"
fi

CURRENT_WORKSPACE=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)

# Handle initial workspace (video or image)
if [[ $CURRENT_WORKSPACE ]]; then
    has_video=false
    has_image=false
    
    # Check if this workspace has a video
    for entry in "${VIDEO_MAP[@]}"; do
        IFS=':' read -r ws_id video_path <<< "$entry"
        if [ "$ws_id" == "$CURRENT_WORKSPACE" ]; then
            send_mpv_command "$CURRENT_WORKSPACE" '{"command":["set_property","pause",false]}'
            echo "Initial state: Video on Workspace $CURRENT_WORKSPACE is playing."
            has_video=true
            break
        fi
    done
    
    # Check if this workspace has an image (only if no video)
    if [ "$has_video" = false ]; then
        for entry in "${IMAGE_MAP[@]}"; do
            IFS=':' read -r ws_id image_path <<< "$entry"
            if [ "$ws_id" == "$CURRENT_WORKSPACE" ]; then
                set_hyprpaper_wallpaper "$ws_id" "$image_path"
                echo "Initial state: Image on Workspace $CURRENT_WORKSPACE is displayed."
                has_image=true
                break
            fi
        done
    fi
    
    # Unload images if we're on a video workspace OR a workspace with no wallpaper
    if [ "$has_video" = true ] || [ "$has_image" = false ]; then
        unload_all_images
    fi
fi

echo "Starting listener for Hyprland workspace events on $HYPRLAND_EVENT_SOCKET..."

declare -A WORKSPACE_WINDOWS
PREVIOUS_WORKSPACE=$CURRENT_WORKSPACE

socat -u UNIX-CONNECT:"$HYPRLAND_EVENT_SOCKET" - | while IFS= read -r event; do
    
    if [[ $event == workspace* ]]; then
        NEW_WORKSPACE=${event#workspace>>}
        
        if [[ "$NEW_WORKSPACE" =~ ^[0-9]+$ ]]; then
            has_video=false
            has_image=false
            
            # Step 1: Handle ALL video pause/play logic FIRST (complete the entire loop)
            for entry in "${VIDEO_MAP[@]}"; do
                IFS=':' read -r ws_id video_path <<< "$entry"
                
                if [ "$ws_id" == "$NEW_WORKSPACE" ]; then
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",false]}'
                    has_video=true
                else
                    send_mpv_command "$ws_id" '{"command":["set_property","pause",true]}'
                fi
            done
            
            # Step 2: Now handle images based on what workspace we're on
            if [ "$has_video" = false ]; then
                # Not a video workspace, check for images
                for entry in "${IMAGE_MAP[@]}"; do
                    IFS=':' read -r ws_id image_path <<< "$entry"
                    if [ "$ws_id" == "$NEW_WORKSPACE" ]; then
                        # This workspace has an image
                        set_hyprpaper_wallpaper "$ws_id" "$image_path"
                        has_image=true
                        break
                    fi
                done
            fi
            
            # Step 3: Unload images if we're on a video workspace OR a workspace with no image
            if [ "$has_video" = true ] || [ "$has_image" = false ]; then
                unload_all_images
            fi
            
            # Step 4: Manage togglefloating based on workspace type
            manage_togglefloating "$NEW_WORKSPACE"

            PREVIOUS_WORKSPACE=$NEW_WORKSPACE
        fi
    fi
    
    if [[ $event == openwindow* ]]; then
        NEW_WINDOW_ADDR=$(echo "$event" | cut -d'>' -f3 | cut -d',' -f1)
        
        sleep 0.3
        
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            monitor_info=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height)"')
            read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "$monitor_info"
            
            default_width=$((SCREEN_WIDTH - GAP_SIZE * 2))
            default_height=$((SCREEN_HEIGHT - TOP_GAP - GAP_SIZE))
            
            hyprctl dispatch resizewindowpixel "exact $default_width $default_height,address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            hyprctl dispatch movewindowpixel "exact $GAP_SIZE $((GAP_SIZE + TOP_GAP)),address:$NEW_WINDOW_ADDR" > /dev/null 2>&1
            
            sleep 0.3
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
if [[ $event == resizewindow* ]]; then
        RESIZE_ADDR=$(echo "$event" | cut -d'>' -f2 | cut -d',' -f1)
        
        CURRENT_WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .activeWorkspace.id' 2>/dev/null)
        
        if [[ "$CURRENT_WS" =~ ^[0-9]+$ ]]; then
            read -r rx ry rw rh <<< $(get_window_geometry "$RESIZE_ADDR")
            
            # Find and resize adjacent windows
            right_window=$(find_adjacent_window "$RESIZE_ADDR" "$CURRENT_WS" "right")
            if [[ -n "$right_window" ]]; then
                read -r wx wy ww wh <<< $(get_window_geometry "$right_window")
                local resized_right=$((rx + rw))
                local new_width=$((wx + ww - resized_right - GAP_SIZE))
                
                if [ $new_width -gt 100 ]; then
                    hyprctl dispatch resizewindowpixel "exact $new_width $wh,address:$right_window" > /dev/null 2>&1
                    hyprctl dispatch movewindowpixel "exact $((resized_right + GAP_SIZE)) $wy,address:$right_window" > /dev/null 2>&1
                fi
            fi
            
            left_window=$(find_adjacent_window "$RESIZE_ADDR" "$CURRENT_WS" "left")
            if [[ -n "$left_window" ]]; then
                read -r wx wy ww wh <<< $(get_window_geometry "$left_window")
                local new_width=$((rx - wx - GAP_SIZE))
                
                if [ $new_width -gt 100 ]; then
                    hyprctl dispatch resizewindowpixel "exact $new_width $wh,address:$left_window" > /dev/null 2>&1
                fi
            fi
        fi
    fi
done
'''
        
        HELPER_SCRIPT.write_text(content)
        HELPER_SCRIPT.chmod(0o755)

    def _configure_hyprpaper(self):
        """Configure hyprpaper for image wallpapers"""
        HYPRPAPER_CONF.parent.mkdir(parents=True, exist_ok=True)

        if HYPRPAPER_CONF.exists():
            backup_hyprpaper = HYPRPAPER_CONF.parent / "hyprpaper.conf.motion.bak"
            shutil.copy2(HYPRPAPER_CONF, backup_hyprpaper)
            self.hyprpaper_backup_path = str(backup_hyprpaper)
            self._log(f"Backed up hyprpaper.conf to {backup_hyprpaper.name}")
        
        config_lines = []
        config_lines.append("# Generated by Hyprland Video Wallpapers")
        config_lines.append("ipc = on")
        config_lines.append("splash = false")
        config_lines.append("")
        
        # We don't preload here anymore - the helper script handles it dynamically
        config_lines.append("# Wallpapers are managed dynamically via IPC")
        
        HYPRPAPER_CONF.write_text("\n".join(config_lines))

    def _write_rules_file(self):
        """Write Hyprland rules"""
        RULES_DEST_DIR.mkdir(parents=True, exist_ok=True)

        # Only apply master layout to workspaces with video wallpapers
        workspace_rules = "\n# Workspaces with video wallpapers using Master layout\n"
        video_workspaces = set()
        for ws_id, media_path in self.ws_to_media.items():
            if Path(media_path).suffix.lower() in VIDEO_EXTS:
                video_workspaces.add(ws_id)
                workspace_rules += f"workspace = {ws_id}, layout:master\n"

        if video_workspaces:
            static_rules = f"""

# Master layout settings (only for video workspaces)
master {{
    new_status = slave
    new_on_top = true
    orientation = left
    inherit_fullscreen = false
    mfact = 1.0
}}

# MPV video wallpaper rules
windowrulev2 = tile, title:^(mpv-workspace-video-.*)$
windowrulev2 = noborder, title:^(mpv-workspace-video-.*)$
windowrulev2 = nofocus, title:^(mpv-workspace-video-.*)$
windowrulev2 = noinitialfocus, title:^(mpv-workspace-video-.*)$
windowrulev2 = suppressevent fullscreen, title:^(mpv-workspace-video-.*)$

# Make windows float only on video workspaces
"""
            for ws_id in sorted(video_workspaces):
                static_rules += f"windowrulev2 = float, workspace:{ws_id}\n"
        else:
            static_rules = "\n# No video workspaces configured\n"

        content = f"# Hyprland Video Wallpapers Configuration\n{workspace_rules}{static_rules}"

        RULES_DEST.write_text(content)

    def _configure_hyprland(self):
        """Configure hyprland.conf"""
        if not HYPR_CONF.exists():
            self._log("⚠️ hyprland.conf not found, creating basic config")
            HYPR_CONF.parent.mkdir(parents=True, exist_ok=True)
            HYPR_CONF.touch()

        backup_path = HYPR_CONF.parent / "hyprland.conf.motion.bak"
        shutil.copy2(HYPR_CONF, backup_path)
        self.backup_conf_path = str(backup_path)
        self._log(f"✅ Created backup: {self.backup_conf_path}")

        conf_text = HYPR_CONF.read_text()

        if "hyprland-video-wallpapers" in conf_text:
            self._log("ℹ️ Config already present, removing old entries...")
            lines = conf_text.split('\n')
            new_lines = []
            skip_next = False
            for line in lines:
                if "hyprland-video-wallpapers" in line:
                    skip_next = True
                    continue
                if skip_next and (line.strip().startswith("source =") or line.strip().startswith("exec-once =")):
                    continue
                skip_next = False
                new_lines.append(line)
            conf_text = '\n'.join(new_lines)

        togglefloat_conf = CONFIG_DIR / "togglefloating.conf"

        conf_text += f"\n\n# Added by Hyprland Video Wallpapers Installer\n"
        conf_text += f"source = {RULES_DEST}\n"
        conf_text += f"source = {togglefloat_conf}\n"

        if "mpv" in self.backend_types:
            conf_text += f"exec-once = {HELPER_SCRIPT}\n"

        if "hyprpaper" in self.backend_types:
            conf_text += f"exec-once = hyprpaper\n"

        HYPR_CONF.write_text(conf_text)
        self._log("✅ hyprland.conf updated.")

    def _disable_togglefloating(self):
        """Create dynamic togglefloating management - will be controlled by the helper script"""
        hypr_dir = HYPR_CONF.parent

        # Create a togglefloating management file
        togglefloat_conf = CONFIG_DIR / "togglefloating.conf"
        togglefloat_conf.write_text("# Togglefloating dynamically managed by wallpaper script\n")

        # Find and backup original togglefloating binds
        togglefloat_binds = []
        for conf_file in hypr_dir.glob("*.conf"):
            try:
                text = conf_file.read_text()
            except Exception as e:
                self._log(f"⚠️ Could not read {conf_file.name}: {e}")
                continue

            if "togglefloating" in text:
                lines = text.split('\n')
                for line in lines:
                    if "togglefloating" in line and not line.strip().startswith("#"):
                        togglefloat_binds.append(line.strip())

                # Comment out togglefloating in original files
                backup = Path(str(conf_file) + ".toggle.bak")
                if not backup.exists():
                    shutil.copy2(conf_file, backup)

                    new_lines = []
                    modified = False
                    for line in lines:
                        if "togglefloating" in line and not line.strip().startswith("#"):
                            new_lines.append(f"# {line}")
                            modified = True
                        else:
                            new_lines.append(line)

                    if modified:
                        conf_file.write_text('\n'.join(new_lines))
                        self._log(f"ℹ️ Disabled togglefloating in {conf_file.name} (backup created)")

        # Save the original binds to config for restoration
        if togglefloat_binds:
            config_file = CONFIG_DIR / "togglefloating_binds.txt"
            config_file.write_text('\n'.join(togglefloat_binds))
            self._log(f"💾 Saved {len(togglefloat_binds)} togglefloating bind(s) for dynamic management")

    def _write_config_file(self):
        """Write main configuration file"""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        
        config_path = CONFIG_DIR / "config.conf"
        
        ws_list = sorted(self.selected_workspaces)
        temp_ws_id = max(ws_list) + 1 if ws_list else 10
        if temp_ws_id > 10:
            temp_ws_id = 99
        
        # Ensure backup_conf_path is set
        if not self.backup_conf_path:
            self.backup_conf_path = ""
        
        content = f"""# Configuration generated by Hyprland Video Wallpapers GUI on {time.strftime('%Y-%m-%d %H:%M:%S')}

NUM_WORKSPACES={self.num_workspaces}
TEMP_WORKSPACE_ID={temp_ws_id}
GAP_SIZE={self.gap_size}
TOP_GAP={self.top_gap}
BACKUP_CONF_PATH="{self.backup_conf_path}"
BACKUP_HYPRPAPER_PATH="{getattr(self, 'hyprpaper_backup_path', '')}"
BACKENDS="{','.join(self.backend_types)}"

# Video map: (Workspace_ID:Video_Path)
VIDEO_MAP=(
"""
        
        sorted_assignments = sorted(self.ws_to_media.items())
        for ws_id, media_path_str in sorted_assignments:
            if Path(media_path_str).suffix.lower() in VIDEO_EXTS:
                content += f'    "{ws_id}:{media_path_str}"\n'
        
        content += ")\n"
        
        content += "\n# Image map: (Workspace_ID:Image_Path)\n"
        content += "IMAGE_MAP=(\n"
        for ws_id, media_path_str in sorted_assignments:
            if Path(media_path_str).suffix.lower() in IMAGE_EXTS:
                content += f'    "{ws_id}:{media_path_str}"\n'
        content += ")\n"
        
        config_path.write_text(content)
        self._log(f"✅ Config written with backup path: {self.backup_conf_path}")

    def _page_uninstall(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Uninstall Wallpapers")
        title.add_css_class("title-2")
        box.append(title)

        info = Gtk.Label(label="This will:\n• Remove all helper scripts\n• Clean configuration files\n• Restore backups of hyprland.conf\n• Stop all wallpaper processes")
        info.set_wrap(True)
        info.add_css_class("subtitle")
        box.append(info)

        warning = Gtk.Label(label="⚠️ This action cannot be undone!")
        warning.add_css_class("warning")
        box.append(warning)

        button_box = Gtk.Box(spacing=12, homogeneous=True)
        
        b_un = Gtk.Button(label="Run Uninstaller")
        b_un.add_css_class("destructive-action")
        b_un.connect("clicked", lambda *_: self._run_uninstall_async())
        button_box.append(b_un)

        b_back = Gtk.Button(label="Cancel")
        b_back.connect("clicked", lambda *_: self._pop_page())
        button_box.append(b_back)

        box.append(button_box)
        return box

    def _run_uninstall_async(self):
        """Run uninstaller in background"""
        self._page_uninstall_progress()
        self._push_page("Uninstalling", self.uninstall_progress_page)
        thread = Thread(target=self._run_uninstall, daemon=True)
        thread.start()

    def _page_uninstall_progress(self):
        """Create uninstall progress page"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        title = Gtk.Label(label="Uninstalling...")
        title.add_css_class("title-2")
        box.append(title)

        self.uninstall_log = Gtk.TextView()
        self.uninstall_log.set_editable(False)
        self.uninstall_log.set_monospace(True)
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.uninstall_log)
        scroll.set_min_content_height(400)
        box.append(scroll)
        
        self.uninstall_progress_page = box
        return box

    def _uninstall_log(self, msg):
        """Add message to uninstall log (Thread-safe)"""
        def do_log():
            if not self.uninstall_log or not self.uninstall_log.get_buffer():
                return
            buf = self.uninstall_log.get_buffer()
            buf.insert(buf.get_end_iter(), msg + "\n")
            insert_mark = buf.get_insert()
            self.uninstall_log.scroll_to_mark(insert_mark, 0.0, False, 0.0, 0.0)
            
        GLib.idle_add(do_log)
        
    def _run_uninstall(self):
        """Execute uninstallation"""
        self._uninstall_log("🛑 Stopping wallpaper processes...")
        run(["pkill", "-f", "mpv --title=mpv-workspace-video"])
        run(["pkill", "-f", "hyprpaper"])

        backup_to_restore = None
        hyprpaper_backup = None
        config_file = CONFIG_DIR / "config.conf"
        if config_file.exists():
            self._uninstall_log(f"ℹ️ Reading config file: {config_file}")
            try:
                config_text = config_file.read_text()
                for line in config_text.split('\n'):
                    if line.startswith("BACKUP_CONF_PATH="):
                        backup_to_restore = line.split('=')[1].strip().strip('"')
                        self._uninstall_log(f"Found hyprland backup path: {backup_to_restore}")
                    elif line.startswith("BACKUP_HYPRPAPER_PATH="):
                        hyprpaper_backup = line.split('=')[1].strip().strip('"')
                        self._uninstall_log(f"Found hyprpaper backup path: {hyprpaper_backup}")
            except Exception as e:
                self._uninstall_log(f"⚠️ Could not read backup paths from config: {e}")

        self._uninstall_log("🗑️ Removing helper script...")
        if HELPER_SCRIPT.exists():
            try:
                HELPER_SCRIPT.unlink()
                self._uninstall_log(f"Removed {HELPER_SCRIPT}")
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to remove {HELPER_SCRIPT}: {e}")

        self._uninstall_log("🗑️ Cleaning up MPV socket files...")
        try:
            for socket_file in Path("/tmp").glob("mpv-ws*"):
                try:
                    socket_file.unlink()
                    self._uninstall_log(f"Removed socket: {socket_file}")
                except Exception as e:
                    self._uninstall_log(f"⚠️ Failed to remove {socket_file}: {e}")
        except Exception as e:
            self._uninstall_log(f"⚠️ Error during socket cleanup: {e}")

        self._uninstall_log("🗑️ Removing configuration directory...")
        if CONFIG_DIR.exists():
            try:
                shutil.rmtree(CONFIG_DIR)
                self._uninstall_log(f"Removed {CONFIG_DIR}")
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to remove {CONFIG_DIR}: {e}")

        self._uninstall_log("🗑️ Removing rules...")
        if RULES_DEST_DIR.exists():
            try:
                shutil.rmtree(RULES_DEST_DIR)
                self._uninstall_log(f"Removed {RULES_DEST_DIR}")
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to remove {RULES_DEST_DIR}: {e}")

        self._uninstall_log("🗑️ Removing hyprpaper config...")

        # Try to restore from tracked backup
        if hyprpaper_backup and Path(hyprpaper_backup).exists():
            try:
                shutil.copy2(hyprpaper_backup, HYPRPAPER_CONF)
                Path(hyprpaper_backup).unlink()
                self._uninstall_log(f"✅ Restored hyprpaper.conf from backup and deleted backup")
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to restore hyprpaper backup: {e}")
        elif HYPRPAPER_CONF.exists():
            try:
                HYPRPAPER_CONF.unlink()
                self._uninstall_log(f"Removed {HYPRPAPER_CONF}")
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to remove {HYPRPAPER_CONF}: {e}")

        # Clean up hyprpaper motion backup file
        self._uninstall_log("🧹 Cleaning up hyprpaper backup file...")
        try:
            motion_backup = HYPR_CONF.parent / "hyprpaper.conf.motion.bak"
            if motion_backup.exists():
                motion_backup.unlink()
                self._uninstall_log(f"✅ Removed hyprpaper.conf.motion.bak")
            else:
                self._uninstall_log("No motion backup file found")
        except Exception as e:
            self._uninstall_log(f"⚠️ Error cleaning hyprpaper backup: {e}")

        self._uninstall_log("🔧 Restoring hyprland.conf...")

        restored = False

        # First try the specific backup from config
        if backup_to_restore:
            backup_path = Path(backup_to_restore)
            self._uninstall_log(f"Checking for backup: {backup_path}")

            if backup_path.exists():
                try:
                    self._uninstall_log(f"Found backup file, restoring...")
                    shutil.copy2(backup_path, HYPR_CONF)
                    self._uninstall_log(f"✅ Restored hyprland.conf from {backup_path.name}")

                    # Delete the backup file after successful restore
                    try:
                        backup_path.unlink()
                        self._uninstall_log(f"Deleted backup file: {backup_path.name}")
                    except Exception as e:
                        self._uninstall_log(f"⚠️ Could not delete backup file: {e}")

                    restored = True
                except Exception as e:
                    self._uninstall_log(f"✗ Failed to restore from {backup_path}: {e}")
            else:
                self._uninstall_log(f"⚠️ Backup file not found at: {backup_path}")
        else:
            self._uninstall_log("ℹ️ No backup path specified in config")

        # Fallback: try to find and restore the motion backup
        if not restored:
            self._uninstall_log("Attempting to restore from motion backup...")
            motion_backup = HYPR_CONF.parent / "hyprland.conf.motion.bak"

            if motion_backup.exists():
                try:
                    self._uninstall_log(f"Found motion backup")
                    shutil.copy2(motion_backup, HYPR_CONF)
                    motion_backup.unlink()
                    self._uninstall_log(f"✅ Restored hyprland.conf from motion backup and deleted backup")
                    restored = True
                except Exception as e:
                    self._uninstall_log(f"✗ Failed to restore from motion backup: {e}")
            else:
                self._uninstall_log("⚠️ No motion backup file found")

        # If still not restored, try to manually remove the installer lines
        if not restored:
            self._uninstall_log("⚠️ No backup found, attempting to remove installer lines manually...")
            try:
                if HYPR_CONF.exists():
                    conf_text = HYPR_CONF.read_text()
                    lines = conf_text.split('\n')
                    new_lines = []
                    in_installer_section = False

                    for line in lines:
                        # Check if this is the start marker
                        if "Added by Hyprland Video Wallpapers Installer" in line:
                            in_installer_section = True
                            continue  # Skip the marker line itself
                        
                        # Check if we're still in the installer section
                        if in_installer_section:
                            # Check if this is the end marker (another occurrence)
                            if "Added by Hyprland Video Wallpapers Installer" in line:
                                in_installer_section = False
                                continue  # Skip the end marker too
                            # Skip all lines in the section
                            continue
                        
                        # Keep lines outside the installer section
                        new_lines.append(line)

                    HYPR_CONF.write_text('\n'.join(new_lines))
                    self._uninstall_log("✅ Manually removed installer lines from hyprland.conf")
                    restored = True
            except Exception as e:
                self._uninstall_log(f"✗ Failed to manually clean hyprland.conf: {e}")

        if not restored:
            self._uninstall_log("⚠️ WARNING: Could not restore hyprland.conf backup!")
            self._uninstall_log("You may need to manually restore from a backup or reconfigure.")

        self._uninstall_log("♻️ Restoring togglefloating entries...")
        for toggle_bak in HYPR_CONF.parent.glob("*.conf.toggle.bak"):
            try:
                orig_file_str = str(toggle_bak).removesuffix(".toggle.bak")
                orig_file = Path(orig_file_str)

                self._uninstall_log(f"Restoring {orig_file.name} from {toggle_bak.name}")
                shutil.copy2(toggle_bak, orig_file)
                toggle_bak.unlink()
            except Exception as e:
                self._uninstall_log(f"⚠️ Failed to restore {toggle_bak.name}: {e}")

        self._uninstall_log("✅ Uninstallation complete!")

        GLib.idle_add(self._update_uninstall_page_on_complete)

    def _update_uninstall_page_on_complete(self):
        """IMPROVEMENT 3: Replaces content with completion summary and 'Start Again' button."""
        page_box = self.uninstall_progress_page
        
        while child := page_box.get_first_child():
            page_box.remove(child)

        self.uninstall_log = None

        page_box.set_valign(Gtk.Align.CENTER)
        page_box.set_halign(Gtk.Align.CENTER)
        
        title = Gtk.Label(label="Uninstallation Complete")
        title.add_css_class("title-1")
        page_box.append(title)
        
        info = Gtk.Label(label="✅ All wallpaper components have been removed.")
        info.set_wrap(True)
        page_box.append(info)
        
        button_box = Gtk.Box(spacing=12, homogeneous=True)
        button_box.set_halign(Gtk.Align.CENTER)
        button_box.set_margin_top(20)
        
        b_restart = Gtk.Button(label="Start Again")
        b_restart.add_css_class("suggested-action")
        b_restart.connect("clicked", lambda *_: self._restart_installer())
        button_box.append(b_restart)
        
        b_close = Gtk.Button(label="Close Application")
        b_close.connect("clicked", lambda *_: self.close())
        button_box.append(b_close)
        
        page_box.append(button_box)
    
    def _restart_installer(self):
        """Reset state and return to welcome page"""
        # Reset state
        self.ws_to_media = {}
        self.selected_workspaces = set()
        self.backend_types = ["mpv"]
        self.backup_conf_path = None
        self.hyprpaper_backup_path = None
        self.video_dir = None
        self.image_dir = None
        self.media_items = []
        self.num_workspaces = 5
        self.gap_size = 15
        self.top_gap = 30
        
        # Create new log file for the new session
        global LOG_FILE, LOG_DIR, logger
        
        # Ensure log directory exists (uninstaller may have deleted it)
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        LOG_FILE = LOG_DIR / f"gui_debug_{int(time.time())}.log"
        
        # Remove old handlers
        for handler in logger.handlers[:]:
            handler.close()
            logger.removeHandler(handler)
        
        # Add new handlers with new log file
        logger.addHandler(logging.FileHandler(LOG_FILE))
        logger.addHandler(logging.StreamHandler(sys.stdout))
        
        logger.info("=" * 80)
        logger.info("Hyprland Video Wallpapers GUI Restarted")
        logger.info(f"New log file: {LOG_FILE}")
        logger.info("=" * 80)
        
        # Kill any lingering processes
        try:
            subprocess.run(["pkill", "-f", "mpv"], 
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
            subprocess.run(["pkill", "-f", "hyprpaper"], 
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
            subprocess.run(["pkill", "-f", ".local/bin/hyprland-video-wallpapers.sh"], 
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
            
            # Clean up socket files
            for socket_file in Path("/tmp").glob("mpv-ws*"):
                socket_file.unlink()
            logger.info("Cleared old processes and sockets")
        except Exception as e:
            logger.warning(f"Could not clear processes/sockets: {e}")
        
        self._push_page("Welcome", self.welcome_page)
        
    def _page_summary(self):
        """Simplified summary page."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)
        box.set_valign(Gtk.Align.CENTER)
        box.set_halign(Gtk.Align.CENTER)

        title = Gtk.Label(label="Installation Complete!")
        title.add_css_class("title-1")
        box.append(title)

        info = Gtk.Label(label="✅ Your wallpapers have been configured and started!\n\n"
                       "You can re-run this GUI anytime to reconfigure.\n"
                       "The application will now close automatically.")
        info.set_wrap(True)
        box.append(info)
        
        spinner = Gtk.Spinner()
        spinner.set_spinning(True)
        spinner.set_margin_top(20)
        box.append(spinner)

        self.summary_page = box
        return box

    def _start_wallpapers_silent(self):
        """Start wallpapers silently in background"""
        try:
            self._log("Ensuring old processes are stopped...")
            run(["pkill", "-f", "mpv --title=mpv-workspace-video"])
            time.sleep(1)
            
            if "mpv" in self.backend_types and HELPER_SCRIPT.exists():
                self._log(f"Starting MPV helper: {HELPER_SCRIPT}")
                command = f'nohup {HELPER_SCRIPT} > /dev/null 2>&1 &'
                subprocess.Popen(command, 
                               shell=True,
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL,
                               close_fds=True)
            
            if "hyprpaper" in self.backend_types:
                self._log("Starting Hyprpaper...")
                subprocess.Popen(["hyprpaper"],
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL,
                               close_fds=True)
                
        except Exception as e:
            self._log(f"❌ Error: Failed to start wallpapers: {e}")

    def _check_prerequisites(self):
        """Check if all required tools are present."""
        logger.info("Running prerequisite check...")
        tools = ["ffmpeg", "ffprobe", "mpv", "socat", "jq", "hyprctl", "hyprpaper"]
        all_found = True
        for t in tools:
            if shutil.which(t) is None:
                logger.warning(f"✗ Prerequisite missing: {t}")
                all_found = False
            else:
                logger.info(f"✓ Prerequisite found: {t}")
        return all_found

    def _perform_prereq_check_and_proceed(self):
        """Run prereq check and navigate to the correct first page."""
        if self._check_prerequisites():
            logger.info("✓ All prerequisites found. Skipping prereq page.")
            self._push_page("Video Source", self.video_source_page)
        else:
            logger.warning("✗ Missing prerequisites. Showing prereq page.")
            self._push_page("Prerequisites", self.prereq_page)

    def _start_install(self):
        """Start installation flow"""
        self.selected_workspaces = set()
        self.backend_types = ["mpv"]
        self._perform_prereq_check_and_proceed()

    def _apply_css(self):
        """Apply custom CSS styling"""
        css = b"""
        .title-1 { font-size: 32px; font-weight: 700; margin: 12px; }
        .title-2 { font-size: 24px; font-weight: 600; margin: 8px; }
        .title-3 { font-size: 18px; font-weight: 600; }
        .subtitle { font-size: 14px; opacity: 0.8; margin: 4px; }
        .thumbnail { border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.4); }
        .thumbnail:hover { transform: scale(1.03); }
        .thumbnail-card { padding: 8px; border-radius: 8px; background: alpha(@theme_bg_color, 0.5); }
        .thumbnail-card:hover { background: alpha(@theme_bg_color, 0.8); }
        .status-found { color: #26a269; }
        .status-missing { color: #e01b24; }
        .warning { color: #f57707; font-weight: 500; }
        .warning-box { 
            padding: 20px; 
            background: alpha(@error_bg_color, 0.3); 
            border: 3px solid @error_color; 
            border-radius: 12px; 
        }
        .warning-text { 
            color: @error_color; 
            font-weight: 700; 
            font-size: 16px;
        }
        .info-box { 
            padding: 12px; 
            background: alpha(@theme_selected_bg_color, 0.3); 
            border: 1px solid @theme_selected_bg_color; 
            border-radius: 8px; 
        }
        .monospace { font-family: monospace; font-size: 11px; opacity: 0.8; }
        """
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

class App:
    def __init__(self):
        logger.info(f"App.__init__ called")
        self.window = None
        logger.info("✓ App initialized")

    def create_window(self):
        logger.info("Creating MainWindow...")
        try:
            self.window = MainWindow(None)
            logger.info("✓ MainWindow created")
            self.window._apply_css()
            logger.info("✓ CSS applied")
            
            # Set window as floating via Hyprland
            try:
                window_address = None
                time.sleep(0.5)
                
                # Get all windows and find ours by title
                stdout, _ = run(["hyprctl", "clients", "-j"])
                if stdout:
                    import json
                    clients = json.loads(stdout)
                    for client in clients:
                        if "Hyprland Video Wallpaper" in client.get("title", ""):
                            window_address = client.get("address", "")
                            break
                
                if window_address:
                    # Force the window to float
                    run(["hyprctl", "dispatch", "togglefloating", f"address:{window_address}"])
                    logger.info(f"✓ Window set to floating: {window_address}")
            except Exception as e:
                logger.warning(f"Could not set window floating via hyprctl: {e}")
            
            self.window.present()
            logger.info("✓ Window presented")
            return self.window
        except Exception as e:
            logger.error(f"Error creating window: {e}", exc_info=True)
            raise

if __name__ == '__main__':
    logger.info("Starting application...")
    try:
        logger.info("Creating App instance...")
        app = App()
        logger.info("✓ App object created")
        
        logger.info("Creating main loop...")
        main_loop = GLib.MainLoop()
        logger.info(f"Main loop created: {main_loop}")
        
        logger.info("Creating window...")
        window = app.create_window()
        logger.info("✓ Window created and shown")
        
        def on_window_close(*args):
            logger.info("Window closed, exiting main loop...")
            main_loop.quit()
            return False
        
        window.connect('close-request', on_window_close)
        logger.info("Close signal connected")
        
        logger.info("Running main loop...")
        main_loop.run()
        
        logger.info("Main loop exited")
        sys.exit(0)
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error in main: {e}", exc_info=True)
        try:
            dlg = Gtk.MessageDialog(flags=0, 
                                   message_type=Gtk.MessageType.ERROR,
                                   buttons=Gtk.ButtonsType.OK, 
                                   text="Fatal Unhandled Error")
            dlg.format_secondary_text(f"The application encountered a fatal error:\n{e}\n\n"
                                      f"Please check the log file:\n{LOG_FILE}")
            
            def on_response(dialog, response):
                dialog.close()
                GLib.MainLoop().quit()
            
            dlg.connect("response", on_response)
            dlg.present()
            GLib.MainLoop().run()
        except Exception as e2:
             logger.error(f"Failed to even show error dialog: {e2}")
        sys.exit(1)