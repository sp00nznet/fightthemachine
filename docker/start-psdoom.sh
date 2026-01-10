#!/bin/bash
# Start Fight the Machine (psDoom game engine)

# Wait for X server and window manager to be ready
sleep 5

# Change to game directory
cd /home/doom/.psdoom

# Start the game with proper settings
# -iwad: specify the WAD file location
# -fullscreen: run in fullscreen mode
exec /usr/local/bin/psdoom -iwad /home/doom/.psdoom/DOOM1.WAD -fullscreen
