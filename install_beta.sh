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
ASSUME_YES=0
NO_REBOOT=0
SKIP_CHAOTIC=0
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
(( ASSUME_YES )) && CONFIRM=(--noconfirm)

LOG="$HOME/hypr-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SUDO_PID=""
cleanup() { [[ -n "$SUDO_PID" ]] && kill "$SUDO_PID" 2>/dev/null || true; }
trap cleanup EXIT
trap 'die "Failed at line $LINENO: $BASH_COMMAND (log: $LOG)"' ERR

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

# ---------------------------------------------------------
# 1. pacman.conf: multilib (needed by Steam) + Chaotic-AUR
# ---------------------------------------------------------
log "Configuring pacman..."
BACKUP_CONF="/etc/pacman.conf.bak.$(date +%Y%m%d)"
[[ -f "$BACKUP_CONF" ]] || sudo cp /etc/pacman.conf "$BACKUP_CONF"

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "Enabling [multilib] (required for Steam)..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    grep -q '^\[multilib\]' /etc/pacman.conf || warn "Could not enable [multilib]; enable it manually."
fi

if (( ! SKIP_CHAOTIC )); then
    if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
        echo "Adding Chaotic-AUR..."
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U "${CONFIRM[@]}" \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    else
        echo "Chaotic-AUR already configured."
    fi
fi

# ---------------------------------------------------------
# 2. Full system upgrade (single sync+upgrade, never a bare -Sy)
# ---------------------------------------------------------
log "Updating system..."
sudo pacman -Syu "${CONFIRM[@]}"

# ---------------------------------------------------------
# 3. yay (prebuilt from Chaotic-AUR when available, else build yay-bin)
# ---------------------------------------------------------
log "Setting up yay..."
sudo pacman -S --needed "${CONFIRM[@]}" base-devel git rsync curl
if ! command -v yay >/dev/null; then
    if pacman -Si yay >/dev/null 2>&1; then
        sudo pacman -S --needed "${CONFIRM[@]}" yay
    else
        tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        ( cd "$tmp/yay-bin" && makepkg -si "${CONFIRM[@]}" )
        rm -rf "$tmp"
    fi
else
    echo "yay is already installed."
fi

# Use all cores when building AUR packages
export MAKEFLAGS="-j$(nproc)"

# ---------------------------------------------------------
# 4. Remove conflicting notification daemon (dunst) before swaync
# ---------------------------------------------------------
log "Checking for conflicting packages (dunst)..."
if pacman -Q dunst >/dev/null 2>&1; then
    sudo pacman -Rns "${CONFIRM[@]}" dunst
    pkill -x dunst 2>/dev/null || true
    echo "dunst removed."
else
    echo "dunst not installed."
fi

# ---------------------------------------------------------
# 5. Packages (deduplicated, only missing ones, one transaction)
# ---------------------------------------------------------
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
    # Shell / CLI
    git base-devel github-cli less bash bash-completion starship rsync
    # Theming
    qt6ct-kde nwg-look bibata-cursor-theme darkly-qt6 python-pywalfox
    # Apps
    ark onlyoffice-bin steam gamescope heroic-games-launcher-bin
)

# pacman -T prints only the packages that are NOT yet satisfied (exit 127 if any)
mapfile -t TO_INSTALL < <(printf '%s\n' "${PACKAGES[@]}" | sort -u | xargs pacman -T || true)

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
# 6. System permissions & configuration
# ---------------------------------------------------------
log "Applying system configuration..."

# i2c access for ddcutil (monitor brightness)
if getent group i2c >/dev/null; then
    id -nG "$USER" | grep -qw i2c || { sudo usermod -aG i2c "$USER"; echo "Added $USER to i2c group (re-login required)."; }
else
    warn "i2c group does not exist; skipping usermod."
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
# 7. Deploy dotfiles (existing files are backed up, nothing silently lost)
# ---------------------------------------------------------
log "Deploying dotfiles..."
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

deploy() {  # deploy <src-dir-name> <dest-dir>
    local name="$1" dest="$2"
    if [[ ! -d "$SCRIPT_DIR/$name" ]]; then
        warn "$name not found in repo; skipping."
        return 0
    fi
    mkdir -p "$dest" "$BACKUP_DIR/$name"
    rsync -a --backup --backup-dir="$BACKUP_DIR/$name" "$SCRIPT_DIR/$name/" "$dest/"
    echo "Deployed $name -> $dest"
}

deploy .config   "$HOME/.config"
deploy .local    "$HOME/.local"
deploy .themes   "$HOME/.themes"
deploy Pictures  "$HOME/Pictures"

if [[ -f "$SCRIPT_DIR/.bashrc" ]]; then
    [[ -f "$HOME/.bashrc" ]] && ! cmp -s "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc" && cp -a "$HOME/.bashrc" "$BACKUP_DIR/.bashrc"
    cp "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
fi

# Make user scripts executable
[[ -d "$HOME/.local/bin" ]] && find "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod +x {} +

# Drop the backup dir if nothing was replaced
find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true
[[ -d "$BACKUP_DIR" ]] && echo "Replaced files were backed up to: $BACKUP_DIR"

# ---------------------------------------------------------
# 8. Wallpaper daemon + initial theme (needs a running Wayland session)
# ---------------------------------------------------------
log "Initializing wallpaper..."
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if ! pgrep -x awww-daemon >/dev/null; then
        setsid -f awww-daemon >/dev/null 2>&1
        for _ in {1..10}; do pgrep -x awww-daemon >/dev/null && break; sleep 0.5; done
    fi
    if [[ -x "$HOME/.local/bin/wallset" ]]; then
        "$HOME/.local/bin/wallset" -n || warn "wallset failed; run it manually after login."
    fi
else
    echo "No Wayland session detected; run 'wallset -n' after logging into Hyprland."
fi

# ---------------------------------------------------------
# 9. Summary & optional reboot
# ---------------------------------------------------------
log "Installation complete. Log: $LOG"
if (( ${#FAILED[@]} )); then
    warn "These packages failed to install: ${FAILED[*]}"
fi

if (( NO_REBOOT )); then
    echo "Skipping reboot (--no-reboot). Reboot to apply group and module changes."
elif (( ASSUME_YES )); then
    echo "Rebooting in 10 seconds (Ctrl+C to cancel)..."
    sleep 10
    systemctl reboot
else
    read -r -p "Reboot now? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] && systemctl reboot || echo "Reboot later to apply changes."
fi
