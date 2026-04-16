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
readonly REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

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
        echo -e "${RED}[ERROR] Do not run this script as root or with sudo.${NC}"
        echo -e "The script will prompt for your password when needed."
        exit 1
    fi
}

check_os() {
    echo -e "Checking system compatibility..."
    # Robust check for any Arch-based distribution
    if command -v pacman &> /dev/null; then
        echo -e "${GREEN}[OK] Pacman-based system detected.${NC}"
    else
        echo -e "${RED}[ERROR] Pacman not found. This script only supports Arch-based distributions.${NC}"
        exit 1
    fi
    echo "-------------------------------------------------------"
}

backup_configs() {
    echo -e "${RED}${BOLD}!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!${NC}"
    echo -e "${ORANGE}This script will surgically update your configuration files."
    echo -e "A backup of your current setup will be created first.${NC}"
    echo -e "Backup location: ~/hypr_dots_backup_[timestamp]\n"

    read -rp "Do you want to create a backup now? (y/n): " backup_choice

    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        local backup_dir="$HOME/hypr_dots_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        echo -e "\n${YELLOW}Creating backup in $backup_dir...${NC}"
        local items_to_backup=(".config" ".local" ".bashrc")
        
        for item in "${items_to_backup[@]}"; do
            if [[ -e "$HOME/$item" ]]; then
                echo -e "  -> Backing up ~/$item..."
                cp -a "$HOME/$item" "$backup_dir/"
                
                # Exclude the repo directory itself if it's stored within a backed-up folder
                if [[ "$REPO_DIR" == "$HOME/$item"* ]]; then
                    local rel_path="${REPO_DIR#$HOME/}"
                    rm -rf "$backup_dir/$rel_path"
                fi
            fi
        done
        echo -e "${GREEN}Backup complete!${NC}"
    else
        echo -e "\n${RED}Proceeding WITHOUT backup in 3 seconds...${NC}"
        sleep 3
    fi
    echo "-------------------------------------------------------"
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
        echo -e "${ORANGE}No AUR helper found. Installing yay...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        local tmp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
        (cd "$tmp_dir/yay" && makepkg -si --noconfirm)
        rm -rf "$tmp_dir"
        export AUR_HELPER="yay"
    fi
    echo "-------------------------------------------------------"
}

install_hyprland_dependencies() {
    echo -e "${YELLOW}Categorizing and sorting dependencies...${NC}"

    local raw_deps=(
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common
        ttf-nerd-fonts-symbols-mono ttf-noto-nerd noto-fonts-cjk noto-fonts-emoji
        ttf-cascadia-code-nerd cantarell-fonts ttf-ms-fonts waybar fastfetch 
        pavucontrol swaync libnotify hyprsunset hypridle hyprlock playerctl 
        hyprshot hyprpicker awww imagemagick rofi-wayland wl-clipboard 
        cliphist matugen git base-devel github-cli less polkit-gnome 
        network-manager-applet ddcutil xdg-desktop-portal-gtk 
        xdg-desktop-portal-hyprland archlinux-xdg-menu bash bash-completion 
        starship wlogout qt6ct-kde nwg-look bibata-cursor-theme darkly 
        adw-gtk-theme python-pywalfox
    )

    # Ensure the dependency list itself is unique and sorted
    readarray -t deps < <(printf "%s\n" "${raw_deps[@]}" | sort -u)

    # Build an associative array of all official repository packages.
    # We use 'sort -u' on the pacman output to ensure each package is indexed only once.
    declare -A repo_cache
    while read -r pkg_name; do
        repo_cache["$pkg_name"]=1
    done < <(pacman -Slq | sort -u)

    local repo_pkgs=()
    local aur_pkgs=()

    for pkg in "${deps[@]}"; do
        if [[ ${repo_cache[$pkg]:-0} -eq 1 ]]; then
            repo_pkgs+=("$pkg")
        else
            aur_pkgs+=("$pkg")
        fi
    done

    # Output the categorization for verification
    echo -e "${GREEN}Official Repository Packages (${#repo_pkgs[@]}):${NC} $(IFS=', '; echo "${repo_pkgs[*]}")"
    echo -e "${ORANGE}AUR Packages (${#aur_pkgs[@]}):${NC} $(IFS=', '; echo "${aur_pkgs[*]}")"

    if [[ ${#repo_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing Official Repository Packages...${NC}"
        sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}"
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing AUR Packages with $AUR_HELPER...${NC}"
        "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"
    fi
    
    echo "-------------------------------------------------------"
}

deploy_dotfiles() {
    echo -e "${YELLOW}Surgically deploying dotfiles...${NC}"

    # Handle subdirectories in .config and .local
    local base_dirs=(".config" ".local")

    for dir in "${base_dirs[@]}"; do
        if [[ -d "$REPO_DIR/$dir" ]]; then
            echo -e "  -> Processing $dir content..."
            mkdir -p "$HOME/$dir"
            
            for source_path in "$REPO_DIR/$dir"/*; do
                local name=$(basename "$source_path")
                local target_path="$HOME/$dir/$name"

                # Only replace the specific subfolders found in the repo
                if [[ -e "$target_path" ]]; then
                    echo -e "     ${ORANGE}Updating $dir/$name...${NC}"
                    rm -rf "$target_path"
                fi
                
                cp -rf "$source_path" "$HOME/$dir/"
            done
        fi
    done

    # Handle individual dotfiles in the root of the repo
    local standalone_files=(".bashrc")

    for file in "${standalone_files[@]}"; do
        if [[ -f "$REPO_DIR/$file" ]]; then
            echo -e "  -> Updating $file..."
            cp -f "$REPO_DIR/$file" "$HOME/$file"
        fi
    done

    echo -e "${GREEN}Dotfiles deployed successfully!${NC}"
    echo "-------------------------------------------------------"
}

# --- Main Execution ---

print_header
check_root
check_os
backup_configs
setup_aur_helper
install_hyprland_dependencies
deploy_dotfiles

echo -e "\n${GREEN}${BOLD}INSTALLATION COMPLETE!${NC}"
echo -e "Please log out and log back in (or restart Hyprland) to apply changes."
