#!/bin/bash
#
# Hyprsunset Toggle Script
# ------------------------
# This script toggles Hyprsunset between a warm color temperature (night mode)
# and a neutral color temperature (day mode). It also provides a JSON status
# output suitable for Waybar or similar status bars.
#
# Functions:
# - init_state     : Creates a state file if it doesn't exist.
# - start_hyprsunset: Restarts hyprsunset with a given color temperature.
# - toggle         : Switches between warm and neutral modes and updates state.
# - status         : Prints the current state in JSON format.
#
# Usage:
#   ./hyprsunset.sh -t   # Toggle Hyprsunset ON/OFF
#   ./hyprsunset.sh -s   # Show current status (Waybar-compatible JSON)
#

STATE_FILE="$HOME/.cache/hyprsunset_state"
PID_FILE="$HOME/.cache/hyprsunset.pid"

WARM_TEMP=4500
NEUTRAL_TEMP=6500

init_state() {
    [ ! -f "$STATE_FILE" ] && echo "off" > "$STATE_FILE"
}

start_hyprsunset() {
    local temp="$1"

    # If already running, stop it gracefully
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
            wait "$PID" 2>/dev/null
        fi
    fi

    # Start new hyprsunset instance
    hyprsunset -t "$temp" &
    echo $! > "$PID_FILE"
}

toggle() {
    init_state
    STATE=$(cat "$STATE_FILE")

    if [ "$STATE" = "off" ]; then
        start_hyprsunset "$WARM_TEMP"
        echo "on" > "$STATE_FILE"
    else
        start_hyprsunset "$NEUTRAL_TEMP"
        echo "off" > "$STATE_FILE"
    fi
}

status() {
    init_state
    STATE=$(cat "$STATE_FILE")

    if [ "$STATE" = "on" ]; then
        echo '{"text":"󰈈","class":"active","tooltip":"Hyprsunset ON (smooth)\nClick to turn OFF"}'
    else
        echo '{"text":"","class":"inactive","tooltip":"Hyprsunset OFF (smooth)\nClick to turn ON"}'
    fi
}

case "$1" in
    -s) status ;;
    -t) toggle ;;
    *)
        echo "Usage: $0 -s | -t"
        exit 1
        ;;
esac
