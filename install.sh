#!/usr/bin/env bash

# Exit immediately if a command fails, uninitialized variables are used,
# or a command in a pipeline fails.
set -euo pipefail

# --- Color Definitions ---
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly ORANGE='\033[0;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# --- Get the absolute path of the repository ---
# This ensures we know exactly where the user cloned the script
readonly REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# --- Functions ---

print_header() {
    clear
    echo -e "${YELLOW}"
    echo "  _   _                      _                 _ "
    echo " | | | |_   _ _ __  _ __ ___| | __ _ _ __   __| |"
    echo " | |_| | | | | '_ \| '__/ _ \ |/ _\` | '_ \ / _\` |"
    echo " |  _  | |_| | |_) | | |  __/ | (_| | | | | (_| |"
    echo " |_| |_|\__, | .__/|_|  \___|_|\__,_|_| |_|\__,_|"
    echo "        |___/|_|                                 "
    echo -e "          Dotfiles Installation Script${NC}"
    echo "-------------------------------------------------------"
}

check_root() {
    # Building packages from the AUR cannot be done as root.
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "${RED}[ERROR] Do not run this script as root or with sudo.${NC}"
        echo -e "The script will prompt for your password when needed."
        exit 1
    fi
}

check_os() {
    echo -e "Checking system compatibility..."
    if grep -q 'ID=arch' /etc/os-release 2>/dev/null; then
        echo -e "${GREEN}[OK] Arch Linux detected.${NC}"
    else
        echo -e "${RED}[ERROR] This script currently only supports Arch Linux.${NC}"
        exit 1
    fi
    echo "-------------------------------------------------------"
}

backup_configs() {
    echo -e "${RED}${BOLD}!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!${NC}"
    echo -e "${ORANGE}This script will overwrite your existing configs."
    echo -e "It is highly recommended to create a backup of:"
    echo -e "  - ~/.config"
    echo -e "  - ~/.local"
    echo -e "  - ~/.bashrc${NC}"
    echo -e "${RED}${BOLD}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}\n"

    read -rp "Do you want to create a backup now? (y/n): " backup_choice

    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        local backup_dir="$HOME/hypr_dots_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        echo -e "\n${YELLOW}Creating backup in $backup_dir...${NC}"
        local items_to_backup=(".config" ".local" ".bashrc")
        
        for item in "${items_to_backup[@]}"; do
            if [[ -e "$HOME/$item" ]]; then
                echo -e "  -> Backing up ~/$item..."
                # Copy the user's actual home directory folder
                cp -a "$HOME/$item" "$backup_dir/"
                
                # Safety check: If the user cloned the repo inside the folder we just backed up,
                # remove the cloned repo from the backup directory to prevent recursion/bloat.
                if [[ "$REPO_DIR" == "$HOME/$item"* ]]; then
                    local rel_path="${REPO_DIR#$HOME/}"
                    rm -rf "$backup_dir/$rel_path"
                fi
            else
                echo -e "  -> Skipping ~/$item (not found)"
            fi
        done
        echo -e "${GREEN}Backup complete!${NC}"
    else
        echo -e "\n${RED}Proceeding WITHOUT backup in 3 seconds...${NC}"
        sleep 3
    fi
    echo "-------------------------------------------------------"
}

install_aur_helper_logic() {
    local helper=$1
    local repo_url="https://aur.archlinux.org/${helper}.git"
    
    echo -e "${YELLOW}Installing ${helper}...${NC}"
    sudo pacman -S --needed --noconfirm base-devel git
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone "$repo_url" "$tmp_dir/$helper"
    
    (
        cd "$tmp_dir/$helper"
        makepkg -si --noconfirm
    )
    rm -rf "$tmp_dir"
}

setup_aur_helper() {
    echo -e "${YELLOW}Checking for AUR helper...${NC}"

    if command -v yay &> /dev/null; then
        export AUR_HELPER="yay"
        echo -e "${GREEN}[OK] 'yay' detected.${NC}"
    elif command -v paru &> /dev/null; then
        export AUR_HELPER="paru"
        echo -e "${GREEN}[OK] 'paru' detected.${NC}"
    else
        echo -e "${ORANGE}No AUR helper found. Please select one to install:${NC}"
        PS3="Please enter your choice (1 or 2): "
        local options=("yay" "paru")
        
        select opt in "${options[@]}"; do
            case $opt in
                "yay"|"paru")
                    export AUR_HELPER="$opt"
                    install_aur_helper_logic "$opt"
                    break
                    ;;
                *) echo -e "${RED}Invalid option $REPLY. Try again.${NC}";;
            esac
        done
    fi
    echo "-------------------------------------------------------"
}

install_hyprland_dependencies() {
    echo -e "${YELLOW}Preparing to install dependencies...${NC}"

    # Master list of dependencies
    local deps=(
        # Fonts
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common
        ttf-nerd-fonts-symbols-mono ttf-noto-nerd noto-fonts-cjk noto-fonts-emoji
        ttf-cascadia-code-nerd cantarell-fonts ttf-ms-fonts
        # Apps & Tools
        waybar fastfetch pavucontrol swaync libnotify hyprsunset hypridle
        hyprlock playerctl hyprshot hyprpicker awww imagemagick rofi-wayland
        wl-clipboard cliphist matugen
        # Management
        git base-devel stow github-cli less
        # System
        polkit-gnome network-manager-applet ddcutil xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland archlinux-xdg-menu
        # Shell & Theme
        bash bash-completion starship wlogout qt6ct-kde nwg-look 
        bibata-cursor-theme darkly adw-gtk-theme python-pywalfox
    )

    local repo_pkgs=()
    local aur_pkgs=()

    echo -e "Sorting packages into Official Repos and AUR..."
    for pkg in "${deps[@]}"; do
        if pacman -Si "$pkg" &> /dev/null; then
            repo_pkgs+=("$pkg")
        else
            aur_pkgs+=("$pkg")
        fi
    done

    echo -e "${GREEN}Found ${#repo_pkgs[@]} repo packages.${NC}"
    echo -e "${ORANGE}Found ${#aur_pkgs[@]} AUR packages.${NC}"

    if [[ ${#repo_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing Official Repository Packages...${NC}"
        sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}"
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing AUR Packages with $AUR_HELPER...${NC}"
        "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"
    fi

    echo -e "${GREEN}All dependencies installed successfully!${NC}"
    echo "-------------------------------------------------------"
}

# --- Main Execution ---

print_header
check_root
check_os
backup_configs
setup_aur_helper
install_hyprland_dependencies

echo -e "\n${GREEN}${BOLD}Setup phase complete!${NC}"

