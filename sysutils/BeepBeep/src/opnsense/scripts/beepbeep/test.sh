#!/bin/sh

# Beep beep - Test Beep
# Plays the currently configured start beep for testing

CONFIG_FILE="/usr/local/etc/BeepBeep/beepbeep.conf"
BEEPS_DIR="/usr/local/etc/BeepBeep/beeps"

# Read a value from the INI-style config file
read_config() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^${key}=" "$CONFIG_FILE" | head -1 | cut -d'=' -f2-
    fi
}

if [ ! -f "$CONFIG_FILE" ]; then
    echo "{\"status\": \"error\", \"message\": \"Configuration file not found. Please save settings first.\"}"
    exit 1
fi

start_beep=$(read_config "start_beep")
start_custom=$(read_config "start_beep_custom")

case "$start_beep" in
    none)
        echo "{\"status\": \"ok\", \"message\": \"No beep configured (silent mode).\"}"
        exit 0
        ;;
    custom)
        beep_file="$start_custom"
        ;;
    *)
        beep_file="${BEEPS_DIR}/${start_beep}"
        ;;
esac

if [ -z "$beep_file" ] || [ ! -f "$beep_file" ]; then
    echo "{\"status\": \"error\", \"message\": \"Beep file not found: $beep_file\"}"
    exit 1
fi

if [ -c /dev/speaker ]; then
    cat "$beep_file" > /dev/speaker 2>/dev/null
    echo "{\"status\": \"ok\", \"message\": \"Test beep played successfully.\"}"
else
    echo "{\"status\": \"error\", \"message\": \"Speaker device /dev/speaker not available.\"}"
fi
