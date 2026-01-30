#!/bin/bash
# Build Fight the Machine QEMU VM Image - NO DOCKER REQUIRED
# Creates a minimal Alpine Linux VM with psDoom-ng, X11, VNC, and noVNC
#
# Usage: ./build-vm-image.sh
# Output: fightthemachine.qcow2

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_IMAGE="$SCRIPT_DIR/fightthemachine.qcow2"
ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"

echo "=========================================="
echo "Fight the Machine - VM Image Builder"
echo "=========================================="
echo ""

# Check dependencies
command -v qemu-img >/dev/null 2>&1 || { echo "Error: qemu-img is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required"; exit 1; }

# Need root for chroot
if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Use /mnt/scratch for temp files (has 900GB)
if [ -d /mnt/scratch ]; then
    WORK_DIR=$(mktemp -d -p /mnt/scratch)
else
    WORK_DIR=$(mktemp -d)
fi
ROOTFS_DIR="$WORK_DIR/rootfs"
trap "rm -rf $WORK_DIR" EXIT

# ============================================================================
# Step 1: Build psdoom-ng on the HOST (Debian) where SDL_net exists
# ============================================================================
echo "[1/7] Building psdoom-ng on host system..."

BUILD_DIR="$WORK_DIR/psdoom-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Check if build deps are installed, install if not
if ! pkg-config --exists sdl SDL_mixer SDL_net 2>/dev/null; then
    echo "Installing build dependencies..."
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        build-essential autoconf automake libtool pkg-config \
        libsdl1.2-dev libsdl-mixer1.2-dev libsdl-net1.2-dev libpng-dev
fi

# Download and build psdoom-ng
curl -fsSL https://github.com/orsonteodoro/psdoom-ng/archive/refs/heads/master.tar.gz | tar xz
cd psdoom-ng-master/trunk

# Apply the sudo cheat patch if it exists
if [ -f "$PROJECT_DIR/patches/add-sudo-cheat.sh" ]; then
    chmod +x "$PROJECT_DIR/patches/add-sudo-cheat.sh"
    "$PROJECT_DIR/patches/add-sudo-cheat.sh" src/doom/st_stuff.c || true
fi

./autogen.sh
./configure
touch src/psdoom-ng.desktop
make -j$(nproc) || true

# If make failed, try manual linking
if [ ! -f src/psdoom-ng ]; then
    cd src
    gcc -o psdoom-ng i_main.o i_system.o m_argv.o m_misc.o d_event.o d_iwad.o \
        d_loop.o d_mode.o deh_str.o i_cdmus.o i_endoom.o i_joystick.o i_scale.o i_sound.o \
        i_timer.o i_video.o i_videohr.o m_bbox.o m_cheat.o m_config.o m_controls.o m_fixed.o \
        sha1.o memio.o tables.o v_video.o w_checksum.o w_main.o w_wad.o w_file.o w_file_stdc.o \
        w_file_posix.o w_file_win32.o z_zone.o w_merge.o gusconf.o i_pcsound.o i_sdlsound.o \
        i_sdlmusic.o i_oplmusic.o midifile.o mus2mid.o aes_prng.o net_client.o net_common.o \
        net_dedicated.o net_gui.o net_io.o net_loop.o net_packet.o net_query.o net_sdl.o \
        net_server.o net_structrw.o deh_io.o deh_main.o deh_mapping.o deh_text.o \
        doom/libdoom.a ../textscreen/libtextscreen.a ../pcsound/libpcsound.a ../opl/libopl.a \
        -lSDL -lSDL_mixer -lSDL_net -lpng -lz -lm 2>/dev/null || true
    cd ..
fi

PSDOOM_BIN="$BUILD_DIR/psdoom-ng-master/trunk/src/psdoom-ng"
if [ ! -f "$PSDOOM_BIN" ]; then
    echo "ERROR: Failed to build psdoom-ng"
    exit 1
fi
echo "psdoom-ng built successfully"

# ============================================================================
# Step 2: Download and extract Alpine minirootfs
# ============================================================================
echo "[2/7] Downloading Alpine minirootfs..."
cd "$WORK_DIR"
ARCH="x86_64"
ROOTFS_URL="$ALPINE_MIRROR/v$ALPINE_VERSION/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION.0-$ARCH.tar.gz"
curl -fsSL "$ROOTFS_URL" -o alpine-minirootfs.tar.gz

echo "[3/7] Extracting rootfs..."
mkdir -p "$ROOTFS_DIR"
tar -xzf alpine-minirootfs.tar.gz -C "$ROOTFS_DIR"

# ============================================================================
# Step 3: Install packages in chroot
# ============================================================================
echo "[4/7] Setting up Alpine and installing packages..."
cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

mount --bind /dev "$ROOTFS_DIR/dev"
mount --bind /proc "$ROOTFS_DIR/proc"
mount --bind /sys "$ROOTFS_DIR/sys"

chroot "$ROOTFS_DIR" /bin/sh << 'CHROOT_EOF'
cat > /etc/apk/repositories << 'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.19/main
https://dl-cdn.alpinelinux.org/alpine/v3.19/community
EOF

apk update
apk add --no-cache \
    openrc dhcpcd \
    xvfb xorg-server x11vnc openbox xterm \
    novnc \
    sdl12-compat sdl_mixer libpng \
    supervisor procps python3 py3-pip \
    bash curl coreutils util-linux

pip3 install --break-system-packages websockify 2>/dev/null || pip3 install websockify || true

adduser -D -s /bin/bash doom
echo "doom:doom" | chpasswd

mkdir -p /usr/share/games/doom /var/log/supervisor /var/run /home/doom/.config/openbox /etc/supervisor/conf.d

# Download DOOM WAD
curl -fsSL -o /usr/share/games/doom/doom1.wad "https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad" || true
cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM1.WAD 2>/dev/null || true
cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM.WAD 2>/dev/null || true

rc-update add local default
rc-update add dhcpcd default

cat > /etc/fstab << 'EOF'
/dev/sda / ext4 defaults,noatime 0 1
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devtmpfs /dev devtmpfs defaults 0 0
EOF

echo "export DISPLAY=:0" >> /etc/profile
CHROOT_EOF

umount "$ROOTFS_DIR/sys" 2>/dev/null || true
umount "$ROOTFS_DIR/proc" 2>/dev/null || true
umount "$ROOTFS_DIR/dev" 2>/dev/null || true

# ============================================================================
# Step 4: Copy files into rootfs
# ============================================================================
echo "[5/7] Copying files..."

# Copy pre-built psdoom-ng binary
cp "$PSDOOM_BIN" "$ROOTFS_DIR/usr/local/bin/psdoom-ng"
chmod +x "$ROOTFS_DIR/usr/local/bin/psdoom-ng"

# Copy WAD files
cp "$PROJECT_DIR/wad/psdoom1.wad" "$ROOTFS_DIR/usr/share/games/doom/" 2>/dev/null || true
cp "$PROJECT_DIR/wad/psdoom2.wad" "$ROOTFS_DIR/usr/share/games/doom/" 2>/dev/null || true

# Copy config files
cp "$PROJECT_DIR/docker/supervisord.conf" "$ROOTFS_DIR/etc/supervisor/conf.d/" 2>/dev/null || true
cp "$PROJECT_DIR/docker/process-respawner.py" "$ROOTFS_DIR/usr/local/bin/" 2>/dev/null || true
cp "$PROJECT_DIR/docker/openbox-rc.xml" "$ROOTFS_DIR/home/doom/.config/openbox/rc.xml" 2>/dev/null || true
cp "$SCRIPT_DIR/vm-init.sh" "$ROOTFS_DIR/etc/local.d/vm-init.start" 2>/dev/null || true

chmod +x "$ROOTFS_DIR/usr/local/bin/process-respawner.py" 2>/dev/null || true
chmod +x "$ROOTFS_DIR/etc/local.d/vm-init.start" 2>/dev/null || true

# noVNC redirect
mkdir -p "$ROOTFS_DIR/usr/share/novnc"
echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale"></head></html>' > "$ROOTFS_DIR/usr/share/novnc/index.html"

# ============================================================================
# Step 5: Create disk image using tar + genext2fs (no mount needed)
# ============================================================================
echo "[6/7] Creating disk image..."

# Install genext2fs if not present
if ! command -v genext2fs &>/dev/null; then
    apt-get install -y --no-install-recommends genext2fs || {
        echo "Installing genext2fs from source..."
        cd "$WORK_DIR"
        curl -fsSL https://github.com/bestouff/genext2fs/archive/refs/tags/v1.5.0.tar.gz | tar xz
        cd genext2fs-1.5.0
        ./configure && make && make install
    }
fi

# Calculate rootfs size and add 50% headroom
ROOTFS_SIZE_KB=$(du -sk "$ROOTFS_DIR" | cut -f1)
ROOTFS_SIZE_MB=$((ROOTFS_SIZE_KB / 1024))
IMAGE_BLOCKS=$(( (ROOTFS_SIZE_KB * 3 / 2) ))  # 1.5x size for headroom
echo "Rootfs size: ${ROOTFS_SIZE_MB}MB, creating image with $((IMAGE_BLOCKS / 1024))MB"

RAW_IMAGE="$WORK_DIR/disk.raw"
genext2fs -d "$ROOTFS_DIR" -b "$IMAGE_BLOCKS" -L fightthemachine "$RAW_IMAGE"

# ============================================================================
# Step 6: Convert to QCOW2
# ============================================================================
echo "[7/7] Converting to QCOW2..."
rm -f "$OUTPUT_IMAGE"
qemu-img convert -f raw -O qcow2 -c "$RAW_IMAGE" "$OUTPUT_IMAGE"

FINAL_SIZE=$(du -h "$OUTPUT_IMAGE" | cut -f1)

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Output: $OUTPUT_IMAGE"
echo "Size: $FINAL_SIZE"
echo ""
