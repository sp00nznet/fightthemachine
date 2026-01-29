#!/bin/bash
# Build Fight the Machine QEMU VM Image
# Creates a minimal Alpine Linux VM with psDoom-ng, X11, VNC, and noVNC
#
# Usage: ./build-vm-image.sh
# Output: fightthemachine.qcow2 (~100MB)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_IMAGE="$SCRIPT_DIR/fightthemachine.qcow2"
ALPINE_VERSION="3.19"
IMAGE_SIZE="512M"

echo "=========================================="
echo "Fight the Machine - VM Image Builder"
echo "=========================================="
echo ""

# Check dependencies
command -v docker >/dev/null 2>&1 || { echo "Error: docker is required"; exit 1; }
command -v qemu-img >/dev/null 2>&1 || { echo "Error: qemu-img is required"; exit 1; }

# Clean up any previous builds
rm -f "$OUTPUT_IMAGE" "$SCRIPT_DIR/rootfs.tar"

echo "[1/5] Building Alpine rootfs with Docker..."

# Build the Alpine rootfs using Docker
docker build -t fightthemachine-alpine -f "$SCRIPT_DIR/Dockerfile.alpine" "$PROJECT_DIR"

# Export the rootfs as a tarball
CONTAINER_ID=$(docker create fightthemachine-alpine)
docker export "$CONTAINER_ID" > "$SCRIPT_DIR/rootfs.tar"
docker rm "$CONTAINER_ID" >/dev/null

echo "[2/5] Creating QCOW2 disk image..."

# Create a raw disk image
RAW_IMAGE="$SCRIPT_DIR/disk.raw"
qemu-img create -f raw "$RAW_IMAGE" "$IMAGE_SIZE"

# Create partition table and ext4 filesystem
# Use a loopback device (requires root)
if [ "$(id -u)" -ne 0 ]; then
    echo "Note: Creating image without partitioning (single ext4 filesystem)"
    # Create ext4 filesystem directly on the image
    mkfs.ext4 -F -L fightthemachine "$RAW_IMAGE"
else
    # With root, we can create proper partitions
    parted -s "$RAW_IMAGE" mklabel msdos
    parted -s "$RAW_IMAGE" mkpart primary ext4 1MiB 100%
    parted -s "$RAW_IMAGE" set 1 boot on

    LOOP_DEV=$(losetup --find --show --partscan "$RAW_IMAGE")
    mkfs.ext4 -F -L fightthemachine "${LOOP_DEV}p1"
    MOUNT_POINT=$(mktemp -d)
    mount "${LOOP_DEV}p1" "$MOUNT_POINT"
fi

echo "[3/5] Installing rootfs to disk image..."

# Mount and extract rootfs
MOUNT_POINT="${MOUNT_POINT:-$(mktemp -d)}"
if [ "$(id -u)" -ne 0 ]; then
    # Use fuse2fs for non-root mounting (if available) or use sudo
    if command -v fuse2fs >/dev/null 2>&1; then
        fuse2fs "$RAW_IMAGE" "$MOUNT_POINT"
        tar -xf "$SCRIPT_DIR/rootfs.tar" -C "$MOUNT_POINT"
        fusermount -u "$MOUNT_POINT"
    else
        echo "Extracting rootfs (may need sudo)..."
        sudo mount -o loop "$RAW_IMAGE" "$MOUNT_POINT"
        sudo tar -xf "$SCRIPT_DIR/rootfs.tar" -C "$MOUNT_POINT"
        sudo umount "$MOUNT_POINT"
    fi
else
    tar -xf "$SCRIPT_DIR/rootfs.tar" -C "$MOUNT_POINT"
    umount "$MOUNT_POINT"
    losetup -d "$LOOP_DEV" 2>/dev/null || true
fi

rmdir "$MOUNT_POINT" 2>/dev/null || true

echo "[4/5] Installing bootloader..."

# For simple direct-kernel boot, we skip the bootloader and boot with -kernel
# This avoids complexity of installing GRUB in the image

echo "[5/5] Converting to QCOW2 format..."

# Convert to QCOW2 with compression
qemu-img convert -f raw -O qcow2 -c "$RAW_IMAGE" "$OUTPUT_IMAGE"

# Clean up
rm -f "$RAW_IMAGE" "$SCRIPT_DIR/rootfs.tar"

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
