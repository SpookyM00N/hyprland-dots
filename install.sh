#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting Hyprland Dotfiles Installation..."

# ---------------------------------------------------------
# 1. System Update & Setup Chaotic-AUR + yay
# ---------------------------------------------------------
echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Setting up Chaotic-AUR..."
if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm
else
    echo "Chaotic-AUR is already configured."
fi

echo "==> Installing yay..."
sudo pacman -S --needed base-devel git --noconfirm
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
else
    echo "yay is already installed."
fi

# ---------------------------------------------------------
# 2. Install Required Packages
# ---------------------------------------------------------
echo "==> Installing packages..."

PACKAGES=(
    ttf-jetbrains-mono
    ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols-common
    ttf-nerd-fonts-symbols-mono
    ttf-noto-nerd
    noto-fonts-cjk
    noto-fonts-emoji
    ttf-cascadia-code-nerd
    cantarell-fonts
    ttf-ms-fonts
    waybar
    fastfetch
    pavucontrol-qt
    swaync
    libnotify
    hyprsunset
    hypridle
    hyprlock
    playerctl
    hyprshot
    hyprpicker
    awww
    imagemagick
    rofi
    wl-clipboard
    cliphist
    matugen
    satty
    btop
    git
    base-devel
    github-cli
    less
    polkit-gnome
    network-manager-applet
    ddcutil
    i2c-tools
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    archlinux-xdg-menu
    bash
    bash-completion
    starship
    wlogout
    qt6ct-kde
    nwg-look
    bibata-cursor-theme
    darkly-qt6
    python-pywalfox
)

yay -S --needed "${PACKAGES[@]}" --noconfirm

# ---------------------------------------------------------
# 3. System Permissions & Configuration
# ---------------------------------------------------------
echo "==> Applying system configurations..."

# Add user to i2c group (ensures group exists first)
if grep -q "^i2c:" /etc/group; then
    sudo usermod -aG i2c "$USER"
    echo "Added $USER to i2c group."
else
    echo "Warning: i2c group does not exist. Skipping usermod."
fi

# Link arch-applications menu
if [ -f "/etc/xdg/menus/arch-applications.menu" ]; then
    sudo ln -sf /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu
    echo "Linked arch-applications.menu to applications.menu."
else
    echo "Warning: arch-applications.menu not found."
fi

# ---------------------------------------------------------
# 4. Move Dotfiles
# ---------------------------------------------------------
echo "==> Deploying dotfiles..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p "$HOME/.config" "$HOME/.local" "$HOME/.themes" "$HOME/Pictures"

echo "Copying directories..."
cp -r .config/* "$HOME/.config/" 2>/dev/null || true
cp -r .local/* "$HOME/.local/" 2>/dev/null || true
cp -r .themes/* "$HOME/.themes/" 2>/dev/null || true
cp -r Pictures/* "$HOME/Pictures/" 2>/dev/null || true

echo "Copying .bashrc..."
if [ -f ".bashrc" ]; then
    cp .bashrc "$HOME/.bashrc"
fi

# Ensure the wallset script is executable
if [ -f "$HOME/.local/bin/wallset" ]; then
    chmod +x "$HOME/.local/bin/wallset"
fi

# ---------------------------------------------------------
# 5. Start awww-daemon & Run wallset
# ---------------------------------------------------------
echo "==> Initializing wallpaper daemon..."

if [ "$WAYLAND_DISPLAY" ]; then
    if pgrep -x "awww-daemon" > /dev/null; then
        echo "awww-daemon is already running."
    else
        echo "Starting awww-daemon..."
        awww-daemon &
        sleep 2
    fi
    
    if [ -f "$HOME/.local/bin/wallset" ]; then
        sh "$HOME/.local/bin/wallset" -n
    fi
else
    echo "Notice: Wayland session not detected. Skipping daemon launch."
fi

# ---------------------------------------------------------
# 6. Reboot
# ---------------------------------------------------------
echo "==> Installation Complete!"
echo "System will reboot in 5 seconds..."

sleep 5
systemctl reboot
