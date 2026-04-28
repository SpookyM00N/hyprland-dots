#!/bin/sh -e

abort() {
    printf " \e[91m*\e[39m %s\n" "$*"
    exit 1
}

prompt() {
    printf " \e[92m*\e[39m %s" "$*"
}

# Privilege Check
if [ "$(id -u)" != "0" ]; then
     abort "Run as Root"
fi

prompt "Enable OS-Prober [y/N]: "
read -r OS_PROBER
[ "${OS_PROBER}" != "y" ] && OS_PROBER=No || OS_PROBER=Yes

prompt "Install Pre-configured Grub Theme[Y/n]: "
read -r GRUB_THEME
[ "${GRUB_THEME}" != "y" ] && GRUB_THEME=No GRUB_THEME_CHOICE=No || GRUB_THEME=Yes

if [ "${GRUB_THEME}" = "Yes" ]; then
    echo "    cat - Catppuccin Mocha
    brez - Breeze Theme (KDE)"

    prompt "Grub Theme Choice[cat|brez]: "
    read -r GRUB_THEME_CHOICE
    [ "${GRUB_THEME_CHOICE}" != "cat" ] && GRUB_THEME_CHOICE="Breeze" || GRUB_THEME_CHOICE="Catppuccin"
fi

echo ""
echo ""
printf "%-16s\t%-16s\n" "CONFIGURATION" "VALUE"
printf "%-16s\t%-16s\n" "OS Prober:" "${OS_PROBER}"
printf "%-16s\t%-16s\n" "Install Grub Theme:" "${GRUB_THEME}"
printf "%-16s\t%-16s\n" "Grub Theme Choice:" "${GRUB_THEME_CHOICE}"
echo ""

prompt "Proceed? [y/N]: "
read -r PROCEED
[ "${PROCEED}" != "y" ] && abort "User chose not to proceed. Exiting."

# Install Grub
if ! pacman -S --noconfirm --needed grub; then
    abort "Unable To Install Grub"
fi

# OS-Prober
if [ "${OS_PROBER}" = "Yes" ]; then
    pacman -S --needed --noconfirm os-prober
    sed -i "/GRUB_DISABLE_OS_PROBER=false/"'s/^#//' /etc/default/grub
fi

# Use Version Sort (To get Linux at top of the list)
sed -i "s/version_sort -r/version_sort -V/" /etc/grub.d/10_linux

# Display Distro Name on Load
sed -i "s/Loading Linux/Loading 'Arch Linux'/" /etc/grub.d/10_linux

# Grub Theme
if [ "${GRUB_THEME_CHOICE}" = "No"  ]; then
    echo "No Grub Theme Selected! skipped!"
elif [ "${GRUB_THEME_CHOICE}" = "Breeze" ]; then
    # Breeze Theme
    echo "Installing Breeze Grub Theme"
    pacman -S --needed --noconfirm breeze-grub

    THEME="\/usr\/share\/grub\/themes\/breeze\/theme.txt"
    sed -i -E "s/(#?)(GRUB_THEME=)(\"[^\"]*\")/\2\"$THEME\"/" /etc/default/grub

elif [ "${GRUB_THEME_CHOICE}" = "Catppuccin" ]; then
    # Catppuccin Theme
    echo "Installing Catppuccin Grub Theme"
    THEME="\/usr\/share\/grub\/themes\/catppuccin-mocha\/theme.txt"
    THEME_PATH="$(echo "$THEME" | sed -e 's/\\//g' -e 's/\/theme.txt//')"

    if [ -d "${THEME_PATH}" ]; then
        echo "${THEME_PATH} already exists!"
    else
        rm -rf /tmp/grub
        git clone https://github.com/catppuccin/grub.git --depth=1 /tmp/grub
        cp -rf /tmp/grub/src/catppuccin-mocha-grub-theme/ /usr/share/grub/themes/catppuccin-mocha/
        rm -rf /tmp/grub
        SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
        find "${SCRIPT_PATH}" -type f -name "background.png" -exec cp -f {} /usr/share/grub/themes/catppuccin-mocha/background.png \;
    fi

    sed -i -E "s/(#?)(GRUB_THEME=)(\"[^\"]*\")/\2\"$THEME\"/" /etc/default/grub
fi

# Restart MenuEntry to Grub
if grep -q "menuentry \"Restart\"" /etc/grub.d/40_custom; then
     echo "Restart Entry Already Exists."
else
echo '# Reboot
menuentry "Restart" {
     echo "System rebooting..."
     reboot
}' >>  /etc/grub.d/40_custom
fi

# Shutdown MenuEntry To Grub
if grep -q "menuentry \"Shutdown\"" /etc/grub.d/40_custom; then
     echo "Shutdown Entry Already Exists."
else
echo '# Shutdown
menuentry "Shutdown" {
     echo "System shutting down..."
     halt
}' >>  /etc/grub.d/40_custom
fi

# Generate Grub Config
grub-mkconfig -o /boot/grub/grub.cfg

