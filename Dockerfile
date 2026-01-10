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

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools for the game
    build-essential \
    git \
    autoconf \
    automake \
    # X11 and display
    xvfb \
    x11vnc \
    openbox \
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
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create game user
RUN useradd -m -s /bin/bash doom && \
    echo "doom:doom" | chpasswd

# Clone and build psDoom game engine
WORKDIR /home/doom
RUN git clone https://github.com/sp00nznet/psdoom-src.git && \
    cd psdoom-src && \
    autoreconf -i && \
    ./configure && \
    make && \
    cp src/psdoom /usr/local/bin/ && \
    chmod +x /usr/local/bin/psdoom

# Download DOOM shareware WAD
RUN mkdir -p /home/doom/.psdoom && \
    (wget -q -O /home/doom/.psdoom/DOOM1.WAD "https://archive.org/download/doom-wad-shareware/DOOM1.WAD" || \
     wget -q -O /home/doom/.psdoom/DOOM1.WAD "https://www.ibiblio.org/pub/historic-linux/distributions/slackware/slackware-3.0/games/doom/doom1.wad") && \
    chown -R doom:doom /home/doom

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

# Expose ports
# 5900 - VNC (optional direct access)
# 6080 - noVNC HTML5 interface
EXPOSE 5900 6080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
