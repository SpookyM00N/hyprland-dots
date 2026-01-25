#!/bin/bash

# Configuration
STEP=5
BUS=5 # REPLACE with your actual bus number from 'ddcutil detect'
STATE_FILE="/tmp/monitor_brightness"

# 1. Get or initialize current value
if [ ! -f "$STATE_FILE" ]; then
    ddcutil -b $BUS getvcp 10 -t | cut -d' ' -f4 > "$STATE_FILE"
fi
current=$(cat "$STATE_FILE")


# 2. Calculate new value instantly
if [ "$1" == "+" ]; then
    new=$(( current + STEP > 100 ? 100 : current + STEP ))
else
    new=$(( current - STEP < 0 ? 0 : current - STEP ))
fi


# 3. Save new value and update monitor in background
echo "$new" > "$STATE_FILE"

# Kill any pending ddcutil processes to prevent queuing/lag
pkill -f "ddcutil -b $BUS setvcp 10"

# Send the command
(ddcutil -b $BUS setvcp 10 $new &)
