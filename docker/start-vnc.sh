#!/bin/bash
# Start X11VNC server

# Wait for X server to be ready
sleep 2

# Start x11vnc with no password, shared mode, forever (don't exit when client disconnects)
exec /usr/bin/x11vnc \
    -display :0 \
    -nopw \
    -listen 0.0.0.0 \
    -xkb \
    -ncache 10 \
    -ncache_cr \
    -forever \
    -shared \
    -rfbport 5900
