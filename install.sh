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

# Pre-populated with core Wayland/Hyprland ecosystem components
# Add any missing specific dependencies to this array
PACKAGES=(
    ttf-jetbrains-mono 2.304-2
    ttf-jetbrains-mono-nerd 3.4.0-1
    ttf-nerd-fonts-symbols-common 3.4.0-1
    ttf-nerd-fonts-symbols-mono 3.4.0-1
    ttf-noto-nerd 3.4.0-1
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
    darkly
    python-pywalfox
)

yay -S --needed "${PACKAGES[@]}" --noconfirm


# ---------------------------------------------------------
# 3. Move Dotfiles
# ---------------------------------------------------------
echo "==> Deploying dotfiles..."

# Ensure we are working from the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create target directories if they don't exist
mkdir -p "$HOME/.config" "$HOME/.local" "$HOME/.themes" "$HOME/Pictures"

# Copy directories
# Using rsync to merge folders cleanly without overwriting entirely unrelated files
echo "Copying to ~/.config..."
cp -r .config/* "$HOME/.config/" 2>/dev/null || true

echo "Copying to ~/.local..."
cp -r .local/* "$HOME/.local/" 2>/dev/null || true

echo "Copying to ~/.themes..."
cp -r .themes/* "$HOME/.themes/" 2>/dev/null || true

echo "Copying to ~/Pictures..."
cp -r Pictures/* "$HOME/Pictures/" 2>/dev/null || true

# Ensure the wallset script is executable
if [ -f "$HOME/.local/bin/wallset" ]; then
    chmod +x "$HOME/.local/bin/wallset"
fi


# ---------------------------------------------------------
# 4. Start awww-daemon & Run wallset
# ---------------------------------------------------------
chmod +x $HOME/.local/bin/*

echo "==> Initializing wallpaper daemon..."

# Note: If this script is run from a TTY (outside of a Wayland session), 
# awww-daemon might fail to start. It will succeed if run from within Hyprland.
if [ "$WAYLAND_DISPLAY" ]; then
    awww-daemon &
    
    # Give the daemon a moment to initialize before calling the wallset script
    sleep 2 
    
    if [ -f "$HOME/.local/bin/wallset" ]; then
        sh "$HOME/.local/bin/wallset" -n
    else
        echo "Warning: wallset script not found in $HOME/.local/bin/"
    fi
else
    echo "Notice: Not currently in a Wayland session. Skipping awww-daemon execution."
fi

# ---------------------------------------------------------
# 5. Setting-up somethings
# ---------------------------------------------------------

sudo usermod -aG i2c $USER
sudo ln -sf /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu

# ---------------------------------------------------------
# 6. Reboot
# ---------------------------------------------------------
echo "==> Installation Complete!"
echo "System will reboot in 5 seconds. Press Ctrl+C to cancel the reboot."

sleep 5
systemctl reboot
