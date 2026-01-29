# Fight the Machine - Docker Container with HTML5 Web Interface
# Access the game via browser at http://container-ip:6080
# Uses psdoom-ng (based on stable Chocolate Doom engine)

# =============================================================================
# Stage 1: Build psdoom-ng
# =============================================================================
FROM debian:12-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Enable non-free repository
RUN echo "deb http://deb.debian.org/debian bookworm main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free" >> /etc/apt/sources.list

# Install build dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libsdl1.2-dev \
    libsdl-mixer1.2-dev \
    libsdl-net1.2-dev \
    libpng-dev \
    libx11-dev \
    libxext-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy patch script
COPY patches/add-sudo-cheat.sh /tmp/add-sudo-cheat.sh
RUN chmod +x /tmp/add-sudo-cheat.sh

# Clone and build psdoom-ng
WORKDIR /build
RUN git clone --depth 1 https://github.com/orsonteodoro/psdoom-ng.git && \
    /tmp/add-sudo-cheat.sh /build/psdoom-ng/trunk/src/doom/st_stuff.c && \
    cd psdoom-ng/trunk && \
    ./autogen.sh && \
    ./configure && \
    (make -j$(nproc) || true)

# =============================================================================
# Stage 2: Runtime image (minimal)
# =============================================================================
FROM debian:12-slim

LABEL maintainer="Fight the Machine Project"
LABEL description="Fight the Machine - Kill processes as DOOM monsters via HTML5 browser interface"

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV RESOLUTION=1024x768

# Enable non-free repository for doom-wad-shareware
RUN echo "deb http://deb.debian.org/debian bookworm main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free" >> /etc/apt/sources.list

# Install runtime dependencies only (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # X11 and display
    xvfb \
    x11vnc \
    openbox \
    libx11-6 \
    libxext6 \
    # noVNC for HTML5
    novnc \
    websockify \
    # SDL runtime libraries (not -dev)
    libsdl1.2debian \
    libsdl-mixer1.2 \
    libsdl-net1.2 \
    libpng16-16 \
    # Process management
    supervisor \
    procps \
    python3 \
    # Networking and utilities
    net-tools \
    curl \
    # DOOM shareware WAD
    doom-wad-shareware \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create game user
RUN useradd -m -s /bin/bash doom && \
    echo "doom:doom" | chpasswd

# Copy built binary from builder stage
COPY --from=builder /build/psdoom-ng/trunk/src/psdoom-ng /usr/local/bin/psdoom-ng
RUN chmod +x /usr/local/bin/psdoom-ng

# Setup DOOM WAD - create copies with uppercase names
RUN cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM1.WAD && \
    cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM.WAD

# Copy psdoom WAD files
COPY wad/psdoom1.wad wad/psdoom2.wad /usr/share/games/doom/

# Create directories for config and logs
RUN mkdir -p /var/log/supervisor /var/run /home/doom/.config/openbox

# Copy configuration files
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/start-psdoom.sh /usr/local/bin/start-psdoom.sh
COPY docker/start-vnc.sh /usr/local/bin/start-vnc.sh
COPY docker/process-respawner.py /usr/local/bin/process-respawner.py
COPY docker/openbox-rc.xml /home/doom/.config/openbox/rc.xml

# Make scripts executable and set ownership
RUN chmod +x /usr/local/bin/start-psdoom.sh \
    /usr/local/bin/start-vnc.sh \
    /usr/local/bin/process-respawner.py && \
    chown -R doom:doom /home/doom/.config

# Create index.html redirect for noVNC
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale&scaling=local"></head></html>' > /usr/share/novnc/index.html

# Expose ports
EXPOSE 5900 6080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
