# Fight the Machine - Docker Container with HTML5 Web Interface
# Access the game via browser at http://container-ip:6080

FROM debian:12-slim

LABEL maintainer="Fight the Machine Project"
LABEL description="Fight the Machine - Kill processes as DOOM monsters via HTML5 browser interface"

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV RESOLUTION=1024x768

# Enable non-free repository for doom-wad-shareware
RUN echo "deb http://deb.debian.org/debian bookworm main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free" >> /etc/apt/sources.list

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools for the game
    build-essential \
    git \
    # X11 and display
    xvfb \
    x11vnc \
    openbox \
    libx11-dev \
    libxext-dev \
    # noVNC for HTML5
    novnc \
    websockify \
    # Game dependencies
    libsdl1.2-dev \
    libsdl-mixer1.2-dev \
    libsdl-net1.2-dev \
    libpng-dev \
    # Process management
    supervisor \
    procps \
    python3 \
    # Networking and utilities
    net-tools \
    wget \
    curl \
    ca-certificates \
    # DOOM shareware WAD
    doom-wad-shareware \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create game user
RUN useradd -m -s /bin/bash doom && \
    echo "doom:doom" | chpasswd

# Clone and build psDoom game engine
WORKDIR /home/doom
RUN git clone https://github.com/sp00nznet/psdoom-src.git && \
    cd psdoom-src/xdoomsrc && \
    mkdir -p linux-x86 musserv/linux sndserv/linux xdoom/linux-x86 && \
    make linux-x86 && \
    cp xdoom/linux-x86/ps-xdoom /usr/local/bin/psdoom && \
    chmod +x /usr/local/bin/psdoom

# Setup DOOM WAD - create copies with names psdoom might recognize
RUN cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM1.WAD && \
    cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM.WAD

# Copy psdoom WAD files (xdoom.wad, psdoom1.wad, psdoom2.wad)
COPY wad/*.wad /usr/share/games/doom/

# Create directories for config and logs
RUN mkdir -p /var/log/supervisor /var/run

# Copy configuration files
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/start-psdoom.sh /usr/local/bin/start-psdoom.sh
COPY docker/start-vnc.sh /usr/local/bin/start-vnc.sh
COPY docker/process-respawner.py /usr/local/bin/process-respawner.py
COPY docker/openbox-rc.xml /home/doom/.config/openbox/rc.xml

# Make scripts executable
RUN chmod +x /usr/local/bin/start-psdoom.sh \
    /usr/local/bin/start-vnc.sh \
    /usr/local/bin/process-respawner.py

# Create openbox config directory
RUN mkdir -p /home/doom/.config/openbox && \
    chown -R doom:doom /home/doom/.config

# Create index.html redirect for noVNC
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale&scaling=local"></head></html>' > /usr/share/novnc/index.html

# Expose ports
# 5900 - VNC (optional direct access)
# 6080 - noVNC HTML5 interface
EXPOSE 5900 6080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
