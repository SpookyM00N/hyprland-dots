#!/usr/bin/env bash

set -u
set -o pipefail

# --- Color Definitions ---
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly ORANGE='\033[0;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# --- Get the absolute path of the repository ---
readonly REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

FAILED_PACKAGES=()

# --- Functions ---

print_header() {
    clear
    echo -e "${YELLOW}"
    echo "  _   _                 _                 _ "
    echo " | | | |_   _ _ __  _ _| | __ _ _ __   __| |"
    echo " | |_| | | | | '_ \| '_| |/ _\`| '_ \ / _\`|"
    echo " |  _  | |_| | |_) | | | | (_| | | | | (_| |"
    echo " |_| |_|\__, | .__/|_| |_|\__,_|_| |_|\__,_|"
    echo "        |___/|_|                                 "
    echo -e "          Dotfiles Installation Script${NC}"
    echo "-------------------------------------------------------"
}

check_root() {
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "${RED}[ERROR] Do not run this script as root.${NC}"
        exit 1
    fi
}

check_os() {
    if ! command -v pacman &> /dev/null; then
        echo -e "${RED}[ERROR] Pacman not found. This script requires an Arch-based system.${NC}"
        exit 1
    fi
}

setup_aur_helper() {
    if command -v yay &> /dev/null; then
        export AUR_HELPER="yay"
    elif command -v paru &> /dev/null; then
        export AUR_HELPER="paru"
    else
        echo -e "${YELLOW}Installing yay...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        export AUR_HELPER="yay"
    fi
}

backup_configs() {
    echo -e "${ORANGE}Preparing surgical backup...${NC}"
    local backup_dir="$HOME/hypr_dots_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local base_dirs=(".config" ".local" ".themes" "Pictures")
    
    for dir in "${base_dirs[@]}"; do
        if [[ -d "$REPO_DIR/$dir" ]]; then
            for item in "$REPO_DIR/$dir"/*; do
                local item_name=$(basename "$item")
                local target="$HOME/$dir/$item_name"
                
                # Only backup if the specific file/folder already exists on the system
                if [[ -e "$target" ]]; then
                    mkdir -p "$backup_dir/$dir"
                    cp -a "$target" "$backup_dir/$dir/" 2>/dev/null
                fi
            done
        fi
    done
    
    [[ -f "$HOME/.bashrc" ]] && cp -a "$HOME/.bashrc" "$backup_dir/"
    
    echo -e "${GREEN}Targeted backup saved to: $backup_dir${NC}"
    echo "-------------------------------------------------------"
}

install_hyprland_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"

    local deps=(
        archlinux-xdg-menu awww base-devel bash bash-completion bibata-cursor-theme
        cantarell-fonts cliphist darkly-qt6-git ddcutil fastfetch git github-cli
        hypridle hyprlock hyprpicker hyprshot hyprsunset imagemagick less libnotify
        matugen network-manager-applet noto-fonts-cjk noto-fonts-emoji nwg-look
        pavucontrol-qt playerctl polkit-gnome python-pywalfox qt6ct-kde rofi-wayland
        starship swaync ttf-cascadia-code-nerd ttf-jetbrains-mono
        ttf-jetbrains-mono-nerd ttf-ms-fonts ttf-nerd-fonts-symbols-common
        ttf-nerd-fonts-symbols-mono ttf-noto-nerd waybar wl-clipboard wlogout
        xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    )

    # Make sure rsync is installed for the deployment phase
    deps+=("rsync")

    # The AUR helper handles resolving official repos vs AUR automatically
    if ! "$AUR_HELPER" -S --needed --noconfirm "${deps[@]}"; then
        echo -e "${RED}Bulk install hit a snag. Isolating failures...${NC}"
        for pkg in "${deps[@]}"; do
            "$AUR_HELPER" -S --needed --noconfirm "$pkg" || FAILED_PACKAGES+=("$pkg")
        done
    fi
    echo "-------------------------------------------------------"
}

deploy_dotfiles() {
    echo -e "${YELLOW}Surgically deploying dotfiles...${NC}"
    local base_dirs=(".config" ".local" ".themes" "Pictures")

    for dir in "${base_dirs[@]}"; do
        if [[ -d "$REPO_DIR/$dir" ]]; then
            mkdir -p "$HOME/$dir"
            # rsync cleanly overwrites files without destroying entire directories
            rsync -a --no-perms "$REPO_DIR/$dir/" "$HOME/$dir/"
        fi
    done

    [[ -f "$REPO_DIR/.bashrc" ]] && cp -f "$REPO_DIR/.bashrc" "$HOME/.bashrc"
    
    echo -e "${GREEN}Dotfiles deployed!${NC}"
    echo "-------------------------------------------------------"
}

show_summary() {
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✔ INSTALLATION SUCCESSFUL!${NC}"
        echo "All packages and dotfiles were applied correctly."
    else
        echo -e "\n${ORANGE}${BOLD}⚠ INSTALLATION FINISHED WITH WARNINGS${NC}"
        echo -e "The following packages could not be installed:"
        for p in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}- $p${NC}"
        done
        echo -e "\n${YELLOW}Note:${NC} Check if package names changed in the Arch/AUR repos."
        echo "The rest of your configuration was deployed successfully."
    fi
}

# --- Main ---
print_header
check_root
check_os
setup_aur_helper
backup_configs
install_hyprland_dependencies
deploy_dotfiles
show_summary

# Ensure wallset is executable before running
chmod +x "$HOME/.local/bin/wallset" 2>/dev/null
sh "$HOME/.local/bin/wallset" -n
