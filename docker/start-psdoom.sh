#!/bin/bash
# Start Fight the Machine (psdoom-ng game engine)

# Wait for X server and window manager to be ready
sleep 5

# Export environment for process killing
export PSDOOMKILLCMD="/bin/kill -9"

# Start psdoom-ng with proper settings
# -iwad: specify the base DOOM WAD file
# -file: load psdoom process WAD addon
# -window: run in windowed mode for VNC
exec /usr/local/bin/psdoom-ng \
    -iwad /usr/share/games/doom/doom1.wad \
    -file /usr/share/games/doom/psdoom1.wad \
    -window
