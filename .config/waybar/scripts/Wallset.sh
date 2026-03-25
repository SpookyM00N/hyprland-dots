#!/bin/bash

# --- Configuration ---
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/PC_wallpapers"
CACHE_DIR="$HOME/.cache"
BLUR_PATH="$CACHE_DIR/wall.blur"
CURRENT_WALL_FILE="$WALLPAPER_DIR/.current_wall"
ROFI_THEME="$HOME/.config/rofi/Wallselect.rasi"

# Transition Settings
FPS=75
STEP=120  # Visible animation speed
TYPES=("center" "wipe" "wave" "grow" "outer")
TYPE=${TYPES[$RANDOM % ${#TYPES[@]}]}

# --- Functions ---

# Function to apply wallpaper, colors, and blur
apply_wallpaper() {
    local file="$1"
    local full_path="$WALLPAPER_DIR/$file"

    if [[ -z "$file" ]] || [[ ! -f "$full_path" ]]; then
        notify-send "Wallpaper Error" "File not found: $file"
        exit 1
    fi

    # 1. Set wallpaper with swww
    swww img "$full_path" \
        --transition-fps "$FPS" \
        --transition-step "$STEP" \
        --transition-type "$TYPE"

    # 2. Wallpaper based color schemes with matugen
    matugen image "$full_path" -m dark --prefer "saturation" -t "scheme-vibrant" -r "triangle" 

    # 3. Create blurred copy for Waybar/Lockscreen (720p)
    magick "$full_path" -thumbnail 1280x720^ -gravity center -extent 1280x720 -blur 0x12 -strip "$BLUR_PATH"

    # 4. Save state & Notify
    echo "$file" > "$CURRENT_WALL_FILE"
    
    # Optional: Reload Waybar to pick up new colors
    killall -SIGUSR2 waybar
    
    notify-send -t 2000 "󰸉 Wallpaper Updated" "$file"
}

# Get list of wallpapers into an array
get_wallpapers() {
    mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" | sort)
}

# Find index of current wallpaper
get_current_index() {
    if [[ ! -f "$CURRENT_WALL_FILE" ]]; then
        echo 0
        return
    fi
    local current=$(cat "$CURRENT_WALL_FILE")
    for i in "${!WALLPAPERS[@]}"; do
        if [[ "${WALLPAPERS[$i]}" == "$current" ]]; then
            echo "$i"
            return
        fi
    done
    echo 0
}

# --- Logic ---

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Error" "Wallpaper directory not found"
    exit 1
fi

case "$1" in
    -s|--select)
        # Rofi Selection Mode with Thumbnails Fix
        FILE_LIST=""
        while IFS= read -r file; do
            # The secret sauce: \0icon\x1f tells Rofi to use the full path as an icon [cite: 2]
            FILE_LIST+="${file}\0icon\x1f${WALLPAPER_DIR}/${file}\n"
        done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" | sort)

        SELECTION=$(echo -e "$FILE_LIST" | rofi -dmenu -theme "$ROFI_THEME")
        
        [[ -z "$SELECTION" ]] && exit 0
        apply_wallpaper "$SELECTION"
        ;;

    -n|--next)
        get_wallpapers
        IDX=$(get_current_index)
        NEXT_IDX=$(( (IDX + 1) % ${#WALLPAPERS[@]} ))
        apply_wallpaper "${WALLPAPERS[$NEXT_IDX]}"
        ;;

    -p|--prev)
        get_wallpapers
        IDX=$(get_current_index)
        PREV_IDX=$(( (IDX - 1 + ${#WALLPAPERS[@]}) % ${#WALLPAPERS[@]} ))
        apply_wallpaper "${WALLPAPERS[$PREV_IDX]}"
        ;;

    *)
        echo "Usage: $0 {-s|-n|-p}"
        exit 1
        ;;
esac
