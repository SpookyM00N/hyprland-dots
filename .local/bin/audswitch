#!/bin/bash

# 1. Get raw list of names and descriptions
raw_list=$(pactl list sinks | grep -E "Description:|Name:" | cut -d' ' -f2- | sed 'N;s/\n/|/')

# 2. Clean the descriptions using sed to keep only keywords
clean_list=$(echo "$raw_list" | sed -e 's/alsa_output[^|]*|//g' \
                                     -e 's/analog-stereo//g' \
                                     -e 's/iec958-stereo//g' \
                                     -e 's/_/ /g' \
                                     -e 's/Family High Definition Audio Controller//g' \
                                     -e 's/  */ /g') # Collapse multiple spaces

# 3. Present cleaned list to user
selected_line=$(echo "$clean_list" | rofi -dmenu -theme $HOME/.config/rofi/audio-switch.rasi -i -p "Select Audio Device:" -l 10)

[[ -z "$selected_line" ]] && exit

# 4. We need the ORIGINAL name to actually switch. 
# We find the original name by matching the cleaned line back to the raw list.
index=$(echo "$clean_list" | grep -nF "$selected_line" | cut -d: -f1)
real_name=$(echo "$raw_list" | sed -n "${index}p" | cut -d'|' -f1)

# 5. Apply the switch
pactl set-default-sink "$real_name"

# Move active streams
for input in $(pactl list short sink-inputs | cut -f1); do
    pactl move-sink-input "$input" "$real_name"
done

notify-send "Audio Switched" "Active Device: $selected_line" -i audio-speakers
