#!/bin/bash

# Configuration
STATE_FILE="$HOME/.config/waybar/scripts/sunset_state"
DEFAULT_WARM=4500
NEUTRAL_TEMP=6500
STEP=500
MIN_TEMP=2000
MAX_TEMP=6500

# Icons
ICON_ON="󰛨"
ICON_OFF="󰛩"

# Initialize state file
if [ ! -f "$STATE_FILE" ]; then
    echo "enabled=0" > "$STATE_FILE"
    echo "warm_temp=$DEFAULT_WARM" >> "$STATE_FILE"
    echo "last_id=0" >> "$STATE_FILE"
fi

# Load current state
ENABLED=$(grep "enabled=" "$STATE_FILE" | cut -d'=' -f2)
WARM_TEMP=$(grep "warm_temp=" "$STATE_FILE" | cut -d'=' -f2)
LAST_ID=$(grep "last_id=" "$STATE_FILE" | cut -d'=' -f2)

apply_settings() {
    # Ensure hyprsunset is running
    if ! pgrep -x "hyprsunset" > /dev/null; then
        hyprsunset > /dev/null 2>&1 &
        sleep 0.2
    fi

    # Temperature Logic
    if [ "$ENABLED" -eq 1 ]; then
        hyprctl hyprsunset temperature "$WARM_TEMP" > /dev/null
        TITLE="Hyprsunset ON"
        MSG="Temperature: ${WARM_TEMP}K"
        ICON="weather-clear-night"
    else
        hyprctl hyprsunset temperature "$NEUTRAL_TEMP" > /dev/null
        TITLE="Hyprsunset OFF"
        MSG="Screen reset to ${NEUTRAL_TEMP}K"
        ICON="weather-clear"
    fi

    # NOTIFICATION LOGIC: 
    # Use -p to get ID. Use -r with LAST_ID. 
    # If LAST_ID is old/invalid, notify-send usually just creates a new one.
    NEW_ID=$(notify-send -p -r "$LAST_ID" -i "$ICON" "$TITLE" "$MSG")
    
    # If notify-send fails to return an ID (rare), keep the old one or set to 0
    [ -z "$NEW_ID" ] && NEW_ID=0

    # Save to file
    echo "enabled=$ENABLED" > "$STATE_FILE"
    echo "warm_temp=$WARM_TEMP" >> "$STATE_FILE"
    echo "last_id=$NEW_ID" >> "$STATE_FILE"
}

case $1 in
    toggle)
        ENABLED=$((1 - ENABLED))
        apply_settings
        ;;
    inc)
        WARM_TEMP=$((WARM_TEMP + STEP))
        [ "$WARM_TEMP" -gt "$MAX_TEMP" ] && WARM_TEMP=$MAX_TEMP
        ENABLED=1
        apply_settings
        ;;
    dec)
        WARM_TEMP=$((WARM_TEMP - STEP))
        [ "$WARM_TEMP" -lt "$MIN_TEMP" ] && WARM_TEMP=$MIN_TEMP
        ENABLED=1
        apply_settings
        ;;
    init)
        # On boot, we reset last_id to 0 so the first notification starts fresh
        sed -i 's/last_id=.*/last_id=0/' "$STATE_FILE"
        if ! pgrep -x "hyprsunset" > /dev/null; then
            hyprsunset > /dev/null 2>&1 &
            sleep 0.2
        fi
        [ "$ENABLED" -eq 1 ] && hyprctl hyprsunset temperature "$WARM_TEMP" > /dev/null || hyprctl hyprsunset temperature "$NEUTRAL_TEMP" > /dev/null
        ;;
    status)
        if [ "$ENABLED" -eq 1 ]; then
            echo "{\"text\": \"$ICON_ON\", \"tooltip\": \"Blue Light Filter: ACTIVE\nCurrent Temp: $WARM_TEMP K\", \"class\": \"on\"}"
        else
            echo "{\"text\": \"$ICON_OFF\", \"tooltip\": \"Blue Light Filter: INACTIVE\nSaved Preset: $WARM_TEMP K\", \"class\": \"off\"}"
        fi
        ;;
esac

