#!/bin/bash
# Fight the Machine - VM Init Script
# Starts all services when the VM boots
#
# This script is called by OpenRC on boot

set -e

export DISPLAY=:0
export RESOLUTION=${RESOLUTION:-1024x768}
export HOME=/home/doom

LOG_DIR="/var/log/fightthemachine"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/init.log"
}

log "=========================================="
log "Fight the Machine - VM Starting"
log "=========================================="

# Start Xvfb (virtual framebuffer)
log "Starting Xvfb..."
Xvfb :0 -screen 0 ${RESOLUTION}x24 &
sleep 2

# Start openbox window manager
log "Starting openbox..."
su - doom -c "DISPLAY=:0 openbox &"
sleep 2

# Start x11vnc
log "Starting x11vnc..."
x11vnc -display :0 -nopw -listen 0.0.0.0 -xkb -noshm -forever -shared -rfbport 5900 &
sleep 1

# Start noVNC/websockify
log "Starting noVNC..."
websockify --web /usr/share/novnc 6080 localhost:5900 &
sleep 1

# Start process respawner
log "Starting process respawner..."
python3 /usr/local/bin/process-respawner.py &
sleep 1

# Start psDoom-ng
log "Starting psDoom-ng..."
su - doom -c "DISPLAY=:0 PSDOOMKILLCMD='/bin/kill -9' /usr/local/bin/psdoom-ng \
    -iwad /usr/share/games/doom/doom1.wad \
    -window -geometry 640x400w \
    -psallusers -nopslev -nomonsters" &

log "=========================================="
log "All services started!"
log "Access via: http://localhost:6080"
log "=========================================="

# Keep the script running (init process)
exec tail -f /dev/null
