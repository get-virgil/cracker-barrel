#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

# Create minimal test rootfs for Firecracker boot testing
# This rootfs boots the kernel and immediately shuts down

OUTPUT_FILE="${1:-artifacts/test-rootfs.ext4}"
SIZE_MB=50
TEMP_DIR=""
MOUNT_DIR=""

# Trap handler for clean interrupt
cleanup_on_interrupt() {
    echo ""
    echo "[INFO] Interrupted! Cleaning up..."
    # Unmount if we have a mount directory
    if [ -n "$MOUNT_DIR" ] && mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        echo "[INFO] Unmounting filesystem..."
        sudo umount "$MOUNT_DIR" 2>/dev/null || sudo umount -f "$MOUNT_DIR" 2>/dev/null || true
    fi
    # Clean up temp directory
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    exit 130
}

# Set up trap for SIGINT (Ctrl-C)
trap cleanup_on_interrupt INT

echo "Creating minimal test rootfs for Firecracker boot testing..."
echo "  Output: ${OUTPUT_FILE}"
echo "  Size: ${SIZE_MB}MB"

# Check if rootfs already exists
if [ -f "${OUTPUT_FILE}" ]; then
    echo "Test rootfs already exists: ${OUTPUT_FILE}"
    echo "Delete it first if you want to recreate it: rm ${OUTPUT_FILE}"
    exit 0
fi

# Create artifacts directory if it doesn't exist
mkdir -p "$(dirname "${OUTPUT_FILE}")"

# Create empty ext4 image
echo "Creating ${SIZE_MB}MB ext4 filesystem image..."
dd if=/dev/zero of="${OUTPUT_FILE}" bs=1M count=0 seek=${SIZE_MB} 2>/dev/null
mkfs.ext4 -F "${OUTPUT_FILE}" >/dev/null 2>&1

# Mount the image
TEMP_DIR=$(mktemp -d)
MOUNT_DIR="${TEMP_DIR}/mnt"
mkdir -p "${MOUNT_DIR}"

echo "Mounting rootfs..."
sudo mount -o loop "${OUTPUT_FILE}" "${MOUNT_DIR}"

# Create directory structure
echo "Creating directory structure..."
sudo mkdir -p "${MOUNT_DIR}"/{bin,dev,proc,sys,etc}

# Create minimal init script
echo "Creating init script..."
cat << 'EOF' | sudo tee "${MOUNT_DIR}/init" > /dev/null
#!/bin/sh
# Minimal init script for Firecracker boot testing
# This script boots the kernel and immediately shuts down

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Print success message
echo "=========================================="
echo "Kernel boot test PASSED!"
echo "Kernel version: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "=========================================="

# Shut down cleanly
poweroff -f
EOF

sudo chmod +x "${MOUNT_DIR}/init"

# Unmount and cleanup
echo "Unmounting rootfs..."
sudo umount "${MOUNT_DIR}"
rm -rf "${TEMP_DIR}"

echo "Test rootfs created successfully: ${OUTPUT_FILE}"
