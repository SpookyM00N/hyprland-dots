--- SOURCES ---

--- MATUGEN COLORS ---
local matu = require ("colors")

--- MONITORS ---

hl.monitor ({
    output = "",
    mode = "1920x1080@75",
    position = "auto",
    scale = 1,
})

--- MY PROGRAMS ---

local terminal = "kitty"
local fileManager = "dolphin"
local bar = "waybar"

--- AUTOSTART ---
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function () 
    hl.exec_cmd("swaync")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd(bar)
    hl.exec_cmd("hyprsunset.sh init")
    hl.exec_cmd("hyprsunset & hypridle")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

--- ENVIRONMENT VARIABLES ---
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

--- DIRECTORIES ---
hl.env("PATH", os.getenv("PATH") .. ":" .. os.getenv("HOME") .. "/.local/bin")
hl.env("HYPRSHOT_DIR",os.getenv("HOME").."/Pictures/Screenshots")

--- CURSER_THEME ---
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

--- XDG SPECIFICATIONS ---
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

--- QT APPLICATIONS ---
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("GTK_THEME", "adw-gtk3")

-- XDG Vars
local XDG_CONFIG_HOME = os.getenv("HOME") .. "/.config"
local XDG_DATA_HOME = os.getenv("HOME") .. "/.local/share"
local XDG_STATE_HOME = os.getenv("HOME") .. "/.local/state"
local XDG_CACHE_HOME = os.getenv("HOME") .. "/.cache"

--- NVIDIA ---
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

--- LOOK AND FEEL ---
-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border = matu.primary,
            inactive_border = matu.outline_variant,
        },

        resize_on_border = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 7,
        rounding_power = 4,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 5,
            render_power = 1,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            special = true,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
        new_on_active = focus,
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },

    misc = {
        force_default_wallpaper = -1, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background.
    },	

})

--- ANIMATIONS ---
-- Refer to https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.curve("quart", { type = "bezier", points = { {0.25, 1}, {0.5, 1} } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("smoothOut", { type = "bezier", points = { {0.5, 0}, {0.99, 0.99} } })
hl.curve("smoothIn", { type = "bezier", points = { {0.5, -0.5},{0.68, 1.5} } })

hl.animation({ leaf = "layersIn", enabled = true, speed = 6, bezier = "quart", style = "slide top"})
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "quart", style = "fade"})
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "overshot",style = "gnomed"})
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smoothOut", style = "popin 50%"})
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "smoothIn", style = "popin 20%"})
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "smoothIn", style = "slide"})
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "smoothIn" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "quart", style = "slidefade"})

--- INPUT ---

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,
        sensitivity = 0,
        force_no_accel = true,
    },
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

--- KEYBINDS ---

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("killall rofi || rofi -show drun"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd("killall rofi || rofi -show window"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -theme ~/.config/rofi/clipboard.rasi | cliphist decode | wl-copy"))
hl.bind("F11",hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("killall -9 waybar ; waybar &"))
--- Wallpaper Selection ---
hl.bind("CONTROL + SHIFT + W", hl.dsp.exec_cmd("wallset -s"))
hl.bind("CONTROL + ALT_L + Right", hl.dsp.exec_cmd("wallset -n"))
hl.bind("CONTROL + ALT_L + Left", hl.dsp.exec_cmd("wallset -p"))

--- Move focus with mainMod + arrow keys ---
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + Tab",   hl.dsp.window.cycle_next())

--- Switch workspaces with mainMod + [0-9] ---
for i = 1, 10 do
    local key = i % 10 
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

--- Example special workspace (scratchpad) ---
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

--- Scroll through existing workspaces with mainMod + scroll ---
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

--- Move/resize windows with mainMod + LMB/RMB and dragging ---
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--- Laptop multimedia keys for volume and LCD brightness ---
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

--- Brightness Control ---
hl.bind("F6", hl.dsp.exec_cmd("brightness.sh +"), { locked = true, repeating = true})
hl.bind("F5", hl.dsp.exec_cmd("brightness.sh -"), { locked = true, repeating = true})

--- Requires playerctl ---
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("swayosd-client --playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("swayosd-client --playerctl previous"),   { locked = true })

--- ScreenShot Keybinds Requires hyprshot and hyprpicker ---
hl.bind("Print", hl.dsp.exec_cmd("killall hyprshot|| hyprshot -zm output"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("killall hyprshot || hyprshot -zm region"))

--- WINDOWS AND WORKSPACES ---


--- Hyprland-run windowrule ---
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

--- fix some dragging issues with XWayland ---
hl.window_rule({ 
    name  = "fix-xwayland-drags", 
    match = { 
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

--- Picture in Picture windows ---
hl.window_rule({
    name = "picture_in_picture",
    match = { title = "Picture-in-Picture|" },

    float = true,
    keep_aspect_ratio = true,
    move = {"monitor_w*0.68", "monitor_h*0.51" },
    size = {"monitor_w*0.31", "monitor_h*0.31" },
    pin = true,
})

--- Floating Application Windows ---
hl.window_rule({
    name = "floating-windows",
    match = {
        class = "^blueman-manager$|"..
        "^pavucontrol-qt$|"..
        "nm-(applet|connection-editor)|"..
        "^com.gabm.satty$|"..
        "^vlc$|"..
        "^kvantummanager$|"..
        "^qt[56]ct$|"..
        "^nwg-look$|"..
        "polkit-gnome-authentication-agent-1|"..
        "^net.davidotek.pupgui2$|"..
        "^protonup-qt$|"..
        "^DesktopEditors$|"..
        "^xdg-desktop-portal-gtk$|"..
        "console-dropdown|"..
        "Choose Files|"..
        "Save As|"..
        "Confirm to replace files|"..
        "File Operation Progress|"..
        "Open|"..
        "Authentication Required"
    },

    float = true,
    center = true,
    opacity = "0.80 0.70 1",
})

hl.window_rule({
    name = "dolphin_popups",
    match = {
        class = "^org.kde.dolphin$",
        title = "^Progress Dialog - Dolphin$|".."^Copying - Dolphin$|".."^Delete Permanently — Dolphin$"
    },

    float = true,
})

--- Translucent Windows ---
hl.window_rule({
    name = "translucent_apps_1",
    match = {
        class = "^kitty$|"..
        "^org.kde.dolphin$|"..
        "^org.kde.ark$"
    },

    opacity = "0.80 0.80 1",
})

hl.window_rule({
    name = "translucent_apps_2",
    match = {
        class = "^[Ss]team$|"..
        "^steamwebhelper$|"..
        "^[Ss]potify$|"..
        "^heroic$"
    },

    opacity = "0.70 0.70 1",
})

hl.window_rule({
    name = "translucent_browsers",
    match = {
        class = "firefox$|"..
        "^waterfox$|"..
        "^brave-browser$|"
    },

    opacity = "0.90 0.80 1",
})

--- windowrule to force steam games/apps to fullscreen ---
hl.window_rule({ match = { class = "^steam_app_.*$" }, fullscreen = true })

--- LAYERRULES ---

hl.layer_rule({
    name = "no_ignore_alpha_blur",
    match = {
        namespace = "waybar|"..
        "logout_dialog"
    },

    blur = true,
})

hl.layer_rule({
    name = "blurred_layers",
    match = {
        namespace = "swaync-notification-window|"..
        "swaync-control-center|"..
        "rofi|"..
        "swayosd"
    },

    blur = true,
    ignore_alpha = 0,
})

-- FUNCTIONS --
-- enable/disable effects || gamemode --
hl.bind(mainMod .. " + SHIFT + h", function ()
    local game_mode = (hl.get_config("animations.enabled") == false)

    if game_mode then
        hl.exec_cmd("hyprctl reload")
        return
    end

    hl.config({
        general = {
            gaps_in = 0, gaps_out = 0, -- Disable gaps  
            border_size = 0,
        },

        animations = {
            enabled = false, -- Disable animations
        },

        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = 0,
        }
    })
end)
