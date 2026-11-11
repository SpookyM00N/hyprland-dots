#!/usr/bin/env bash
# Hyprland dotfiles installer for a fresh Arch Linux install.
# Usage: ./install.sh [--yes] [--no-reboot] [--skip-chaotic]
#   --yes          unattended: pass --noconfirm to pacman/yay, auto-reboot after countdown
#   --no-reboot    never reboot at the end
#   --skip-chaotic don't add Chaotic-AUR (yay is then built from the AUR)

set -Eeuo pipefail

# ---------------------------------------------------------
# Options, logging, helpers
# ---------------------------------------------------------
ASSUME_YES=0 NO_REBOOT=0 SKIP_CHAOTIC=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)       ASSUME_YES=1 ;;
        --no-reboot)    NO_REBOOT=1 ;;
        --skip-chaotic) SKIP_CHAOTIC=1 ;;
        -h|--help)      sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

CONFIRM=()
if (( ASSUME_YES )); then CONFIRM=(--noconfirm); fi

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/hypr-install-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SUDO_PID=""
cleanup() { if [[ -n "$SUDO_PID" ]]; then kill "$SUDO_PID" 2>/dev/null || true; fi; }
trap cleanup EXIT
trap 'die "Failed at line $LINENO: $BASH_COMMAND (log: $LOG)"' ERR

# enable_now [--user] <unit>: enable + start a systemd unit if it exists
enable_now() {
    local scope=() as_root=(sudo)
    if [[ $1 == --user ]]; then scope=(--user); as_root=(); shift; fi
    local unit="$1"
    if ! systemctl "${scope[@]}" cat "$unit" >/dev/null 2>&1; then
        echo "unit not found, skipping: $unit"
        return 0
    fi
    if "${as_root[@]}" systemctl "${scope[@]}" enable --now "$unit"; then
        echo "enabled + started: $unit"
    else
        warn "could not enable/start $unit"
    fi
}

# start_bg <command> [args...]: detached start (like `cmd & disown`, but survives the terminal closing).
# Skips programs that are missing or already running. Output goes to /dev/null so the
# process doesn't keep the log pipe open.
start_bg() {
    local bin="$1" running=1
    if ! command -v "$bin" >/dev/null 2>&1; then
        warn "not found, skipping: $bin"
        return 0
    fi
    if (( $# > 1 )); then
        pgrep -f -- "$*" >/dev/null || running=0
    else
        pgrep -f -- "(^|/)${bin##*/}( |$)" >/dev/null || running=0
    fi
    if (( running )); then
        echo "already running: $*"
    elif setsid -f "$@" >/dev/null 2>&1; then
        echo "started: $*"
    else
        warn "failed to start: $*"
    fi
}

# ---------------------------------------------------------
# 0. Pre-flight checks
# ---------------------------------------------------------
(( EUID != 0 )) || die "Do not run as root (makepkg refuses it, and dotfiles would land in /root). Run as your normal user."
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux."
command -v sudo >/dev/null || die "sudo is required."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SCRIPT_DIR/.config" ]] || die "No .config directory next to the script ($SCRIPT_DIR). Run it from your dotfiles repo."

log "Checking network..."
curl -fsS --max-time 10 -o /dev/null https://archlinux.org || die "No internet connection."

log "Authenticating sudo (kept alive during install)..."
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) &
SUDO_PID=$!

# Use all cores when building AUR packages
export MAKEFLAGS="-j$(nproc)"

# ---------------------------------------------------------
# 1. pacman.conf: multilib (needed by Steam) + Chaotic-AUR
# ---------------------------------------------------------
log "Configuring pacman..."
need_multilib=0 need_chaotic=0
grep -q '^\[multilib\]' /etc/pacman.conf || need_multilib=1
if (( ! SKIP_CHAOTIC )); then grep -q '^\[chaotic-aur\]' /etc/pacman.conf || need_chaotic=1; fi

if (( need_multilib || need_chaotic )); then
    sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$STAMP"
else
    echo "pacman.conf already configured."
fi

if (( need_multilib )); then
    echo "Enabling [multilib] (required for Steam)..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    grep -q '^\[multilib\]' /etc/pacman.conf || warn "Could not enable [multilib]; enable it manually."
fi

if (( need_chaotic )); then
    echo "Adding Chaotic-AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U "${CONFIRM[@]}" \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi

# ---------------------------------------------------------
# 2. System upgrade + prerequisites + yay in ONE transaction
#    (always -Syu, never a bare -Sy; yay comes prebuilt from Chaotic-AUR)
# ---------------------------------------------------------
log "Updating system and installing prerequisites..."
PREREQS=(base-devel git rsync)
if (( SKIP_CHAOTIC )) || command -v yay >/dev/null; then
    sudo pacman -Syu --needed "${CONFIRM[@]}" "${PREREQS[@]}"
elif ! sudo pacman -Syu --needed "${CONFIRM[@]}" "${PREREQS[@]}" yay; then
    warn "yay is not available from the repos; building yay-bin instead."
    sudo pacman -Syu --needed "${CONFIRM[@]}" "${PREREQS[@]}"
fi

if ! command -v yay >/dev/null; then
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    ( cd "$tmp/yay-bin" && makepkg -si "${CONFIRM[@]}" )
    rm -rf "$tmp"
fi

# ---------------------------------------------------------
# 3. Packages (only missing ones, one transaction)
# ---------------------------------------------------------
# Remove the conflicting notification daemon (swaync replaces it)
if pacman -Qq dunst >/dev/null 2>&1; then
    log "Removing conflicting package: dunst"
    sudo pacman -Rns "${CONFIRM[@]}" dunst
    pkill -x dunst || true
fi

log "Installing packages..."
PACKAGES=(
    # Fonts
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common
    ttf-nerd-fonts-symbols-mono ttf-noto-nerd noto-fonts-cjk noto-fonts-emoji
    ttf-cascadia-code-nerd cantarell-fonts ttf-ms-fonts
    # Desktop / Hyprland ecosystem
    waybar fastfetch pavucontrol-qt swaync libnotify hyprsunset hypridle hyprlock
    playerctl hyprshot hyprpicker awww imagemagick rofi wl-clipboard cliphist
    matugen satty btop swayosd wlogout polkit-gnome network-manager-applet
    xdg-desktop-portal-gtk xdg-desktop-portal-hyprland archlinux-xdg-menu
    # Hardware control
    ddcutil i2c-tools
    # Shell / CLI (bash, less, git, base-devel, rsync are already covered by base/PREREQS)
    github-cli bash-completion starship
    # Theming
    qt6ct-kde nwg-look bibata-cursor-theme darkly-qt6 python-pywalfox
    # Apps
    ark onlyoffice-bin steam gamescope heroic-games-launcher-bin
)

# pacman -T prints only the packages that are NOT yet satisfied (exit 127 if any)
mapfile -t TO_INSTALL < <(pacman -T "${PACKAGES[@]}" || true)

FAILED=()
if (( ${#TO_INSTALL[@]} == 0 )); then
    echo "All packages already installed."
elif ! yay -S --needed "${CONFIRM[@]}" "${TO_INSTALL[@]}"; then
    warn "Bulk install failed; retrying packages one by one to isolate the culprit(s)..."
    for pkg in "${TO_INSTALL[@]}"; do
        yay -S --needed "${CONFIRM[@]}" "$pkg" || FAILED+=("$pkg")
    done
fi

# ---------------------------------------------------------
# 4. System permissions & configuration
# ---------------------------------------------------------
log "Applying system configuration..."
NEED_RELOGIN=0

# i2c access for ddcutil (monitor brightness)
if ! getent group i2c >/dev/null; then
    warn "i2c group does not exist; skipping usermod."
elif ! id -nG "$USER" | grep -qw i2c; then
    sudo usermod -aG i2c "$USER"
    NEED_RELOGIN=1
    echo "Added $USER to the i2c group."
fi
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
sudo modprobe i2c-dev 2>/dev/null || true

# Application menu (for Dolphin/Ark "open with" etc.)
if [[ -f /etc/xdg/menus/arch-applications.menu ]]; then
    sudo ln -sf /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu
else
    warn "arch-applications.menu not found."
fi

# ---------------------------------------------------------
# 5. Deploy dotfiles with ONE rsync (replaced files are backed up, nothing silently lost)
# ---------------------------------------------------------
log "Deploying dotfiles..."
BACKUP_DIR="$HOME/.dotfiles-backup/$STAMP"
SOURCES=()
for item in .config .local Pictures .bash_profile .bashrc; do
    if [[ -e "$SCRIPT_DIR/$item" ]]; then SOURCES+=("$item"); else warn "$item not found in repo; skipping."; fi
done

mkdir -p "$BACKUP_DIR"
# -R keeps each source's relative path, so .config -> ~/.config, .bashrc -> ~/.bashrc, and backups mirror the same layout
( cd "$SCRIPT_DIR" && rsync -aR --backup --backup-dir="$BACKUP_DIR" "${SOURCES[@]}" "$HOME/" )

# Make user scripts executable (only the ones that aren't yet)
if [[ -d "$HOME/.local/bin" ]]; then
    find "$HOME/.local/bin" -maxdepth 1 -type f ! -perm -u+x -exec chmod u+x {} +
fi

# Drop the backup dir if nothing was replaced
find "$BACKUP_DIR" -depth -type d -empty -delete 2>/dev/null || true
if [[ -d "$BACKUP_DIR" ]]; then echo "Replaced files were backed up to: $BACKUP_DIR"; fi

# ---------------------------------------------------------
# 6. Services that don't need a Hyprland session
# ---------------------------------------------------------
log "Enabling and starting services..."

# Refresh the font cache (only stale directories, so it stays fast)
fc-cache >/dev/null 2>&1 || warn "fc-cache failed."

# NetworkManager: skip only if ANOTHER network manager is the one enabled (avoid breaking existing networking)
if systemctl is-enabled --quiet NetworkManager.service 2>/dev/null \
   || ! systemctl is-enabled --quiet systemd-networkd.service iwd.service dhcpcd.service connman.service 2>/dev/null; then
    enable_now NetworkManager.service
else
    echo "Another network manager is enabled; leaving NetworkManager alone."
fi
enable_now swayosd-libinput-backend.service   # caps/num lock OSD backend

# User services (need a running systemd user session)
if systemctl --user show-environment >/dev/null 2>&1; then
    for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
        enable_now --user "$unit"
    done
else
    warn "No systemd user session available; user services will start at next login."
fi

# ---------------------------------------------------------
# 7. Hyprland session: wallpaper, theme, and exec-once programs
# ---------------------------------------------------------
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    log "Starting session programs..."
    # Scripts deployed to ~/.local/bin (wallset, hyprsunset.sh) must resolve by name, as in exec-once
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

    # Wallpaper daemon + initial theme first, so waybar/swaync start with the generated colors
    start_bg awww-daemon
    for _ in {1..10}; do pgrep -x awww-daemon >/dev/null && break; sleep 0.5; done
    if [[ -x "$HOME/.local/bin/wallset" ]]; then
        "$HOME/.local/bin/wallset" -n || warn "wallset failed; run it manually."
    fi

    # Export the session environment to systemd/D-Bus, then restart portals so they see it
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME \
        2>/dev/null || warn "dbus-update-activation-environment failed."
    systemctl --user try-restart xdg-desktop-portal-hyprland.service \
        xdg-desktop-portal-gtk.service xdg-desktop-portal.service 2>/dev/null || true

    # Mirrors the exec-once list in the Hyprland config
    start_bg swaync
    start_bg swayosd-server
    start_bg nm-applet
    start_bg waybar        # your config uses $bar; adjust if it is not waybar
    start_bg hyprsunset.sh init
    start_bg hyprsunset
    start_bg hypridle
    start_bg /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    start_bg wl-paste --type text  --watch cliphist store
    start_bg wl-paste --type image --watch cliphist store

    if hyprctl reload >/dev/null 2>&1; then echo "Reloaded Hyprland config."
    else warn "hyprctl reload failed."; fi
else
    echo "Not inside a Hyprland session: run 'wallset -n' after logging in; waybar, swaync, etc. start with Hyprland."
fi

# ---------------------------------------------------------
# 8. Summary & optional reboot
# ---------------------------------------------------------
log "Installation complete. Log: $LOG"
if (( ${#FAILED[@]} )); then warn "These packages failed to install: ${FAILED[*]}"; fi
if (( NEED_RELOGIN )); then echo "Services are already running; log out and back in (or reboot) to apply the i2c group change."; fi

if (( NO_REBOOT )); then
    echo "Skipping reboot (--no-reboot)."
elif (( ASSUME_YES )); then
    echo "Rebooting in 10 seconds (Ctrl+C to cancel)..."
    sleep 10
    systemctl reboot
else
    read -r -p "Reboot now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then systemctl reboot; fi
fi
