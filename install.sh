#!/usr/bin/env bash
# Hyprland dotfiles installer for a fresh Arch Linux install.
# Usage: ./install.sh [--yes] [--no-reboot]
#   --yes          unattended: pass --noconfirm to pacman/yay, add Chaotic-AUR without asking, auto-reboot after countdown
#   --no-reboot    never reboot at the end

set -Eeuo pipefail

# ---------------------------------------------------------
# Options, logging, helpers
# ---------------------------------------------------------
ASSUME_YES=0 NO_REBOOT=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)       ASSUME_YES=1 ;;
        --no-reboot)    NO_REBOOT=1 ;;
        -h|--help)      sed -n '2,5p' "$0"; exit 0 ;;
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

# enable_now [--user] <unit>...: enable + start every listed unit that exists, in ONE systemctl call
enable_now() {
    local scope=() as_root=(sudo) units=() u
    if [[ $1 == --user ]]; then scope=(--user); as_root=(); shift; fi
    for u in "$@"; do
        if systemctl "${scope[@]}" cat "$u" >/dev/null 2>&1; then units+=("$u")
        else echo "unit not found, skipping: $u"; fi
    done
    if (( ${#units[@]} == 0 )); then return 0; fi
    if "${as_root[@]}" systemctl "${scope[@]}" enable --now "${units[@]}"; then
        echo "enabled + started: ${units[*]}"
    else
        warn "could not enable/start: ${units[*]}"
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
# 1. pacman.conf: Chaotic-AUR (optional, asked once)
# ---------------------------------------------------------
log "Configuring pacman..."
USE_CHAOTIC=0
if grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    USE_CHAOTIC=1
    echo "Chaotic-AUR already configured."
else
    ans=y
    if (( ! ASSUME_YES )); then
        read -r -p "Add the Chaotic-AUR repo (prebuilt AUR packages, much faster installs)? [Y/n] " ans || ans=y
    fi
    if [[ $ans =~ ^[Nn] ]]; then
        echo "Skipping Chaotic-AUR; AUR packages will be built from source."
    else
        USE_CHAOTIC=1
        echo "Adding Chaotic-AUR..."
        sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$STAMP"
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U "${CONFIRM[@]}" \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
fi

# ---------------------------------------------------------
# 2. System upgrade + prerequisites + yay in ONE transaction
#    (always -Syu, never a bare -Sy; yay comes prebuilt from Chaotic-AUR)
# ---------------------------------------------------------
log "Updating system and installing prerequisites..."
PREREQS=(base-devel git rsync)
if (( ! USE_CHAOTIC )) || command -v yay >/dev/null; then
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
    ttf-cascadia-code-nerd cantarell-fonts
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
    ark
)

# pacman -T prints only the packages that are NOT yet satisfied (exit 127 if any)
mapfile -t TO_INSTALL < <(pacman -T "${PACKAGES[@]}" || true)

# Split into packages available in the sync repos (official + Chaotic if enabled) and AUR-only ones.
# Repo packages go through ONE pacman transaction (single prompt, installed even if an AUR build fails);
# AUR packages go through yay afterwards, batched into one install prompt.
REPO_PKGS=(); AUR_PKGS=()
if (( ${#TO_INSTALL[@]} )); then
    mapfile -t REPO_PKGS < <(pacman -Slq | grep -Fxf <(printf '%s\n' "${TO_INSTALL[@]}") || true)
    mapfile -t AUR_PKGS  < <(printf '%s\n' "${TO_INSTALL[@]}" | grep -Fxvf <(printf '%s\n' "${REPO_PKGS[@]}") || true)
fi

FAILED=()
if (( ${#TO_INSTALL[@]} == 0 )); then
    echo "All packages already installed."
fi

if (( ${#REPO_PKGS[@]} )); then
    echo "Installing ${#REPO_PKGS[@]} repo packages in one transaction..."
    if ! sudo pacman -S --needed "${CONFIRM[@]}" "${REPO_PKGS[@]}"; then
        # Retry individually, without re-prompting: the list was already approved above
        warn "Repo transaction failed; retrying packages one by one to isolate the culprit(s)..."
        for pkg in "${REPO_PKGS[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" || FAILED+=("$pkg")
        done
    fi
fi

if (( ${#AUR_PKGS[@]} )); then
    echo "Building/installing ${#AUR_PKGS[@]} AUR packages: ${AUR_PKGS[*]}"
    # --batchinstall: build everything first, then install with a single pacman call (one prompt)
    if ! yay -S --needed --batchinstall "${CONFIRM[@]}" "${AUR_PKGS[@]}"; then
        warn "AUR install failed; retrying packages one by one to isolate the culprit(s)..."
        for pkg in "${AUR_PKGS[@]}"; do
            yay -S --needed --noconfirm "$pkg" || FAILED+=("$pkg")
        done
    fi
fi

# ---------------------------------------------------------
# 4. System permissions & configuration
# ---------------------------------------------------------
log "Applying system configuration..."
NEED_RELOGIN=0

# i2c access for ddcutil (monitor brightness)
if ! getent group i2c >/dev/null; then
    warn "i2c group does not exist; skipping usermod."
else
    # Check /etc/group (not `id`, which only reflects the current login session), so re-runs don't repeat usermod
    if [[ ",$(getent group i2c | cut -d: -f4)," != *",$USER,"* ]]; then
        sudo usermod -aG i2c "$USER"
        echo "Added $USER to the i2c group."
    fi
    if ! id -nG | grep -qw i2c; then NEED_RELOGIN=1; fi
fi
if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null; fi
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
for item in .config .local .themes Pictures .bashrc; do
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

# System units. NetworkManager is skipped only if ANOTHER network manager is the one enabled
# (avoids breaking existing networking). swayosd backend = caps/num lock OSD.
SYSTEM_UNITS=(swayosd-libinput-backend.service)
if systemctl is-enabled --quiet NetworkManager.service 2>/dev/null \
   || ! systemctl is-enabled --quiet systemd-networkd.service iwd.service dhcpcd.service connman.service 2>/dev/null; then
    SYSTEM_UNITS+=(NetworkManager.service)
else
    echo "Another network manager is enabled; leaving NetworkManager alone."
fi
enable_now "${SYSTEM_UNITS[@]}"

# User units (need a running systemd user session)
if systemctl --user show-environment >/dev/null 2>&1; then
    enable_now --user pipewire.socket pipewire-pulse.socket wireplumber.service
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
    for _ in {1..20}; do awww query >/dev/null 2>&1 && break; sleep 0.25; done   # ready = socket answers
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
    read -r -p "Reboot now? [y/N] " ans || ans=n
    if [[ "$ans" =~ ^[Yy]$ ]]; then systemctl reboot; fi
fi
