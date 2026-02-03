#!/bin/bash

# --- Configuration ---
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/PC_wallpapers"
CACHE_DIR="$HOME/.cache"
BLUR_PATH="$CACHE_DIR/wall.blur"

# Transition settings
FPS=75
STEP=255
TYPE="center"

# --- Logic ---

# 1. Check directory
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Error" "Directory not found"
    exit 1
fi

# 2. Select Wallpaper
SELECTION=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" | sort | rofi -dmenu -theme $HOME/.config/rofi/clipboard.rasi -i -p "󰸉 Select Wallpaper")

[[ -z "$SELECTION" ]] && exit 0

FULL_PATH="$WALLPAPER_DIR/$SELECTION"

# 3. Apply Wallpaper
swww img "$FULL_PATH" \
    --transition-fps "$FPS" \
    --transition-step "$STEP" \
    --transition-type "$TYPE"

# 4. Create 720p blurred copy
# -thumbnail 1280x720^: Resizes to 720p height while maintaining aspect ratio
# -gravity center -extent 1280x720: Crops it perfectly to 720p if the aspect ratio differs
magick "$FULL_PATH" -thumbnail 1280x720^ -gravity center -extent 1280x720 -blur 0x12 "$BLUR_PATH"

notify-send "Wallpaper Updated" "Current: $SELECTION"
