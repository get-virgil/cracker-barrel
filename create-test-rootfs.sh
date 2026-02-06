#!/bin/bash
set -euo pipefail

# Create minimal test rootfs for Firecracker boot testing
# This rootfs boots the kernel and immediately shuts down

OUTPUT_FILE="${1:-test-rootfs.ext4}"
SIZE_MB=50

echo "Creating minimal test rootfs for Firecracker boot testing..."
echo "  Output: ${OUTPUT_FILE}"
echo "  Size: ${SIZE_MB}MB"

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
