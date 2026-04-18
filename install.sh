#!/usr/bin/env bash

# set -u: error on undefined variables
# set -o pipefail: catch errors in pipes
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

# Global array to track failed packages
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
    if command -v pacman &> /dev/null; then
        echo -e "${GREEN}[OK] Pacman-based system detected.${NC}"
    else
        echo -e "${RED}[ERROR] Pacman not found. Exiting.${NC}"
        exit 1
    fi
}

backup_configs() {
    echo -e "${ORANGE}Preparing backup...${NC}"
    local backup_dir="$HOME/hypr_dots_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local items=(".config" ".local" ".bashrc")
    for item in "${items[@]}"; do
        if [[ -e "$HOME/$item" ]]; then
            cp -a "$HOME/$item" "$backup_dir/" 2>/dev/null
        fi
    done
    echo -e "${GREEN}Backup saved to: $backup_dir${NC}"
    echo "-------------------------------------------------------"
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

install_hyprland_dependencies() {
    echo -e "${YELLOW}Categorizing dependencies...${NC}"

    local raw_deps=(
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common
        ttf-nerd-fonts-symbols-mono ttf-noto-nerd noto-fonts-cjk noto-fonts-emoji
        ttf-cascadia-code-nerd cantarell-fonts ttf-ms-fonts waybar fastfetch 
        pavucontrol-qt swaync libnotify hyprsunset hypridle hyprlock playerctl 
        hyprshot hyprpicker awww imagemagick rofi-wayland wl-clipboard 
        cliphist matugen git base-devel github-cli less polkit-gnome 
        network-manager-applet ddcutil xdg-desktop-portal-gtk 
        xdg-desktop-portal-hyprland archlinux-xdg-menu bash bash-completion 
        starship wlogout qt6ct-kde nwg-look bibata-cursor-theme darkly-qt6-git 
        python-pywalfox
    )

    readarray -t deps < <(printf "%s\n" "${raw_deps[@]}" | sort -u)

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

    # --- Official Repo Install ---
    if [[ ${#repo_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing Official Packages...${NC}"
        # We don't use -e here so we can catch failures
        if ! sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}"; then
            echo -e "${RED}Some official packages failed. Attempting individual installs...${NC}"
            for p in "${repo_pkgs[@]}"; do
                sudo pacman -S --needed --noconfirm "$p" || FAILED_PACKAGES+=("$p (Repo)")
            done
        fi
    fi

    # --- AUR Install ---
    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Installing AUR Packages...${NC}"
        if ! "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"; then
            echo -e "${RED}Some AUR packages failed. Attempting individual installs...${NC}"
            for p in "${aur_pkgs[@]}"; do
                "$AUR_HELPER" -S --needed --noconfirm "$p" || FAILED_PACKAGES+=("$p (AUR)")
            done
        fi
    fi
    echo "-------------------------------------------------------"
}

deploy_dotfiles() {
    echo -e "${YELLOW}Surgically deploying dotfiles...${NC}"
    local base_dirs=(".config" ".local" ".themes" "Pictures")

    for dir in "${base_dirs[@]}"; do
        if [[ -d "$REPO_DIR/$dir" ]]; then
            mkdir -p "$HOME/$dir"
            for source_path in "$REPO_DIR/$dir"/*; do
                local name=$(basename "$source_path")
                local target_path="$HOME/$dir/$name"
                [[ -e "$target_path" ]] && rm -rf "$target_path"
                cp -rf "$source_path" "$HOME/$dir/"
            done
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
        echo -e "\n${YELLOW}Note:${NC} They might have been renamed or are temporarily unavailable."
        echo "The rest of your configuration was deployed successfully."
    fi
}

# --- Main ---
print_header
check_root
check_os
backup_configs
setup_aur_helper
install_hyprland_dependencies
deploy_dotfiles
show_summary

sh $HOME/.local/bin/wallset -n
