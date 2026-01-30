#!/bin/bash
# Build Fight the Machine QEMU VM Image - NO DOCKER REQUIRED
# Creates a minimal Alpine Linux VM with psDoom-ng, X11, VNC, and noVNC
#
# Uses Alpine minirootfs tarball - no Docker needed
#
# Usage: ./build-vm-image.sh
# Output: fightthemachine.qcow2 (~150MB)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_IMAGE="$SCRIPT_DIR/fightthemachine.qcow2"
ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
IMAGE_SIZE="512M"

echo "=========================================="
echo "Fight the Machine - VM Image Builder"
echo "(No Docker Required)"
echo "=========================================="
echo ""

# Check dependencies
command -v qemu-img >/dev/null 2>&1 || { echo "Error: qemu-img is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required"; exit 1; }

# Need root for chroot and loop mounting
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges for chroot operations."
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

WORK_DIR=$(mktemp -d)
ROOTFS_DIR="$WORK_DIR/rootfs"
trap "rm -rf $WORK_DIR" EXIT

echo "[1/6] Downloading Alpine minirootfs..."
ARCH="x86_64"
ROOTFS_URL="$ALPINE_MIRROR/v$ALPINE_VERSION/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION.0-$ARCH.tar.gz"
curl -fsSL "$ROOTFS_URL" -o "$WORK_DIR/alpine-minirootfs.tar.gz"

echo "[2/6] Extracting rootfs..."
mkdir -p "$ROOTFS_DIR"
tar -xzf "$WORK_DIR/alpine-minirootfs.tar.gz" -C "$ROOTFS_DIR"

echo "[3/6] Setting up Alpine and installing packages..."
# Set up DNS in chroot
cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

# Mount necessary filesystems for chroot
mount --bind /dev "$ROOTFS_DIR/dev"
mount --bind /proc "$ROOTFS_DIR/proc"
mount --bind /sys "$ROOTFS_DIR/sys"

# Install packages in chroot
chroot "$ROOTFS_DIR" /bin/sh << 'CHROOT_EOF'
# Set up repositories
cat > /etc/apk/repositories << 'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.19/main
https://dl-cdn.alpinelinux.org/alpine/v3.19/community
EOF

# Update and install packages
apk update
apk add --no-cache \
    openrc \
    dhcpcd \
    xvfb \
    xorg-server \
    x11vnc \
    openbox \
    xterm \
    novnc \
    py3-numpy \
    sdl12-compat \
    sdl_mixer \
    libpng \
    supervisor \
    procps \
    python3 \
    py3-pip \
    bash \
    curl \
    coreutils \
    util-linux

# Install websockify via pip
pip3 install --break-system-packages websockify || pip3 install websockify

# Install build dependencies for psdoom-ng
apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    pkgconf \
    sdl12-compat-dev \
    sdl_mixer-dev \
    libpng-dev \
    libx11-dev \
    libxext-dev

# Build psdoom-ng
cd /tmp
git clone --depth 1 https://github.com/orsonteodoro/psdoom-ng.git
cd psdoom-ng/trunk
./autogen.sh
./configure --disable-sdlnet
touch src/psdoom-ng.desktop
make -j$(nproc) -k || true

# If binary wasn't created, try linking manually
if [ ! -f src/psdoom-ng ]; then
    cd src
    gcc -o psdoom-ng i_main.o i_system.o m_argv.o m_misc.o d_event.o d_iwad.o \
        d_loop.o d_mode.o deh_str.o i_cdmus.o i_endoom.o i_joystick.o i_scale.o i_sound.o \
        i_timer.o i_video.o i_videohr.o m_bbox.o m_cheat.o m_config.o m_controls.o m_fixed.o \
        sha1.o memio.o tables.o v_video.o w_checksum.o w_main.o w_wad.o w_file.o w_file_stdc.o \
        w_file_posix.o w_file_win32.o z_zone.o w_merge.o gusconf.o i_pcsound.o i_sdlsound.o \
        i_sdlmusic.o i_oplmusic.o midifile.o mus2mid.o aes_prng.o \
        deh_io.o deh_main.o deh_mapping.o deh_text.o \
        doom/libdoom.a ../textscreen/libtextscreen.a ../pcsound/libpcsound.a ../opl/libopl.a \
        -lSDL -lSDL_mixer -lpng -lz -lm
    cd ..
fi

cp src/psdoom-ng /usr/local/bin/
chmod +x /usr/local/bin/psdoom-ng

# Clean up build dependencies
apk del build-base git autoconf automake libtool pkgconf \
    sdl12-compat-dev sdl_mixer-dev libpng-dev libx11-dev libxext-dev
rm -rf /tmp/psdoom-ng /root/.cache /var/cache/apk/*

# Create doom user
adduser -D -s /bin/bash doom
echo "doom:doom" | chpasswd

# Create directories
mkdir -p /usr/share/games/doom
mkdir -p /var/log/supervisor /var/run /home/doom/.config/openbox /etc/supervisor/conf.d

# Download DOOM shareware WAD
curl -fsSL -o /usr/share/games/doom/doom1.wad \
    "https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM1.WAD
cp /usr/share/games/doom/doom1.wad /usr/share/games/doom/DOOM.WAD

# Configure services
rc-update add local default
rc-update add dhcpcd default

# Set up fstab
cat > /etc/fstab << 'EOF'
LABEL=fightthemachine / ext4 defaults,noatime 0 1
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devtmpfs /dev devtmpfs defaults 0 0
EOF

# Configure inittab for autologin
sed -i 's|^tty1::respawn:/sbin/getty.*|tty1::respawn:/bin/login -f root|' /etc/inittab

# Set environment
echo "export DISPLAY=:0" >> /etc/profile
echo "export RESOLUTION=1024x768" >> /etc/profile
CHROOT_EOF

echo "[4/6] Copying configuration files..."
# Copy WAD files
cp "$PROJECT_DIR/wad/psdoom1.wad" "$ROOTFS_DIR/usr/share/games/doom/"
cp "$PROJECT_DIR/wad/psdoom2.wad" "$ROOTFS_DIR/usr/share/games/doom/"

# Copy config files
cp "$PROJECT_DIR/docker/supervisord.conf" "$ROOTFS_DIR/etc/supervisor/conf.d/"
cp "$PROJECT_DIR/docker/process-respawner.py" "$ROOTFS_DIR/usr/local/bin/"
cp "$PROJECT_DIR/docker/openbox-rc.xml" "$ROOTFS_DIR/home/doom/.config/openbox/rc.xml"
cp "$SCRIPT_DIR/vm-init.sh" "$ROOTFS_DIR/etc/local.d/vm-init.start"

chmod +x "$ROOTFS_DIR/usr/local/bin/process-respawner.py"
chmod +x "$ROOTFS_DIR/etc/local.d/vm-init.start"
chown -R 1000:1000 "$ROOTFS_DIR/home/doom/.config"

# Create noVNC index redirect
mkdir -p "$ROOTFS_DIR/usr/share/novnc"
echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale"></head></html>' > "$ROOTFS_DIR/usr/share/novnc/index.html"

# Unmount chroot filesystems
umount "$ROOTFS_DIR/sys" || true
umount "$ROOTFS_DIR/proc" || true
umount "$ROOTFS_DIR/dev" || true

echo "[5/6] Creating disk image..."
RAW_IMAGE="$WORK_DIR/disk.raw"
qemu-img create -f raw "$RAW_IMAGE" "$IMAGE_SIZE"
mkfs.ext4 -F -L fightthemachine "$RAW_IMAGE"

# Mount and copy rootfs
MOUNT_POINT="$WORK_DIR/mnt"
mkdir -p "$MOUNT_POINT"
mount -o loop "$RAW_IMAGE" "$MOUNT_POINT"
cp -a "$ROOTFS_DIR"/* "$MOUNT_POINT/"
umount "$MOUNT_POINT"

echo "[6/6] Converting to QCOW2..."
rm -f "$OUTPUT_IMAGE"
qemu-img convert -f raw -O qcow2 -c "$RAW_IMAGE" "$OUTPUT_IMAGE"

# Get final size
FINAL_SIZE=$(du -h "$OUTPUT_IMAGE" | cut -f1)

echo ""
echo "=========================================="
echo "VM Image Build Complete!"
echo "=========================================="
echo "Output: $OUTPUT_IMAGE"
echo "Size: $FINAL_SIZE"
echo ""
echo "Test with:"
echo "  qemu-system-x86_64 -m 512M -hda $OUTPUT_IMAGE \\"
echo "    -netdev user,id=net0,hostfwd=tcp::6080-:6080 \\"
echo "    -device virtio-net,netdev=net0 -nographic"
echo ""
