#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if architecture is provided
if [ $# -ne 1 ]; then
    error "Usage: $0 <architecture>\n  Supported architectures: x86_64, aarch64"
fi

ARCH=$1
BUILD_DIR="build"
ARTIFACTS_DIR="artifacts"

# Validate architecture
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    error "Unsupported architecture: $ARCH\n  Supported: x86_64, aarch64"
fi

info "Building kernel for architecture: $ARCH"

# Check for required tools
info "Checking for required tools..."
if ! command -v make &> /dev/null; then
    error "make not found. Please install build-essential"
fi

if ! command -v gcc &> /dev/null; then
    error "gcc not found. Please install build-essential"
fi

if [ "$ARCH" = "aarch64" ]; then
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        error "aarch64-linux-gnu-gcc not found.\n  Please install: sudo apt-get install gcc-aarch64-linux-gnu"
    fi
fi

# Create build and artifacts directories
mkdir -p "$BUILD_DIR" "$ARTIFACTS_DIR"

# Fetch latest stable kernel version
info "Fetching latest stable kernel version from kernel.org..."
KERNEL_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
if [ -z "$KERNEL_VERSION" ]; then
    error "Failed to fetch kernel version from kernel.org"
fi
info "Latest stable kernel version: $KERNEL_VERSION"

# Extract major version for download URL
MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)

# Set kernel source URL
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_TARBALL="$BUILD_DIR/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_SRC_DIR="$BUILD_DIR/linux-${KERNEL_VERSION}"

# Download kernel source if not already present
if [ ! -f "$KERNEL_TARBALL" ]; then
    info "Downloading kernel source from $KERNEL_URL..."
    wget -q --show-progress -O "$KERNEL_TARBALL" "$KERNEL_URL" || error "Failed to download kernel source"
    info "Kernel source downloaded successfully"
else
    info "Kernel source already downloaded, skipping..."
fi

# Extract kernel source
if [ ! -d "$KERNEL_SRC_DIR" ]; then
    info "Extracting kernel source..."
    tar -xf "$KERNEL_TARBALL" -C "$BUILD_DIR" || error "Failed to extract kernel source"
    info "Kernel source extracted successfully"
else
    info "Kernel source already extracted, skipping..."
fi

# Apply Firecracker kernel configuration
info "Applying Firecracker kernel configuration for $ARCH..."
CONFIG_FILE="configs/microvm-kernel-${ARCH}.config"
if [ ! -f "$CONFIG_FILE" ]; then
    error "Configuration file not found: $CONFIG_FILE"
fi

cp "$CONFIG_FILE" "$KERNEL_SRC_DIR/.config" || error "Failed to copy kernel config"
cd "$KERNEL_SRC_DIR"

# Update config for new kernel version
info "Running make olddefconfig to update config..."
if [ "$ARCH" = "aarch64" ]; then
    make olddefconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- || error "Failed to update kernel config"
else
    make olddefconfig || error "Failed to update kernel config"
fi

# Build the kernel
info "Building kernel (this may take a while)..."
START_TIME=$(date +%s)

if [ "$ARCH" = "x86_64" ]; then
    KERNEL_IMAGE="vmlinux"
    make -j"$(nproc)" vmlinux || error "Kernel build failed"
elif [ "$ARCH" = "aarch64" ]; then
    KERNEL_IMAGE="arch/arm64/boot/Image"
    make -j"$(nproc)" Image ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- || error "Kernel build failed"
fi

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
info "Kernel built successfully in ${BUILD_TIME} seconds"

# Move back to project root
cd - > /dev/null

# Prepare artifacts
info "Preparing release artifacts..."

# Output kernel file paths
if [ "$ARCH" = "x86_64" ]; then
    KERNEL_BINARY="$KERNEL_SRC_DIR/vmlinux"
    OUTPUT_NAME="vmlinux-${KERNEL_VERSION}-x86_64"
else
    KERNEL_BINARY="$KERNEL_SRC_DIR/arch/arm64/boot/Image"
    OUTPUT_NAME="Image-${KERNEL_VERSION}-aarch64"
fi

# Copy kernel binary to artifacts directory
cp "$KERNEL_BINARY" "$ARTIFACTS_DIR/$OUTPUT_NAME" || error "Failed to copy kernel binary"

# Generate SHA256 checksum of decompressed kernel
info "Generating SHA256 checksum of decompressed kernel..."
(cd "$ARTIFACTS_DIR" && sha256sum "$OUTPUT_NAME" > "${OUTPUT_NAME}.sha256")

# Compress kernel with xz
info "Compressing kernel with xz (this may take a while)..."
xz -9 -T0 "$ARTIFACTS_DIR/$OUTPUT_NAME" || error "Failed to compress kernel"
info "Kernel compressed successfully"

# Copy kernel config
cp "$KERNEL_SRC_DIR/.config" "$ARTIFACTS_DIR/config-${KERNEL_VERSION}-${ARCH}" || error "Failed to copy kernel config"

# List artifacts
info "Artifacts created:"
ls -lh "$ARTIFACTS_DIR"/ | grep -E "${KERNEL_VERSION}-${ARCH}"

# Output summary
echo ""
info "===== Build Summary ====="
info "Kernel Version: $KERNEL_VERSION"
info "Architecture: $ARCH"
info "Build Time: ${BUILD_TIME} seconds"
info "Artifacts Directory: $ARTIFACTS_DIR/"
echo ""
info "Build completed successfully!"
