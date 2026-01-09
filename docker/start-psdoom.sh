#!/bin/bash
# Start psDoom

# Wait for X server and window manager to be ready
sleep 5

# Change to psdoom directory
cd /home/doom/.psdoom

# Start psdoom with proper settings
# -iwad: specify the WAD file location
# -fullscreen: run in fullscreen mode
exec /usr/local/bin/psdoom -iwad /home/doom/.psdoom/DOOM1.WAD -fullscreen
