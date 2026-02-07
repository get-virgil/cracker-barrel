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

# Trap handler for clean interrupt
cleanup_on_interrupt() {
    echo ""
    info "Interrupted! Cleaning up..."
    exit 130
}

# Set up trap for SIGINT (Ctrl-C)
trap cleanup_on_interrupt INT

# Parse command line arguments
ARCH=""
KERNEL_VERSION_ARG=""
GITHUB_REPO="get-virgil/cracker-barrel"

# Auto-detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel)
            KERNEL_VERSION_ARG="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Download pre-built Firecracker-compatible Linux kernel from GitHub releases"
            echo ""
            echo "Options:"
            echo "  --kernel VERSION    Kernel version to download (default: latest stable)"
            echo "  --arch ARCH         Target architecture (default: auto-detect)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Download latest stable"
            echo "  $0 --kernel 6.1                 # Download kernel 6.1"
            echo "  $0 --kernel 6.1 --arch aarch64  # Download ARM64 kernel"
            exit 0
            ;;
        *)
            error "Unknown option: $1\nUse --help for usage information"
            ;;
    esac
done

ARTIFACTS_DIR="artifacts"

# Validate architecture
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    error "Unsupported architecture: $ARCH\n  Supported: x86_64, aarch64"
fi

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

# Determine kernel version
if [ -n "$KERNEL_VERSION_ARG" ]; then
    KERNEL_VERSION="$KERNEL_VERSION_ARG"
    info "Using provided kernel version: $KERNEL_VERSION"
else
    # Fetch latest stable kernel version
    info "Fetching latest stable kernel version from kernel.org..."
    KERNEL_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
    if [ -z "$KERNEL_VERSION" ] || [ "$KERNEL_VERSION" = "null" ]; then
        error "Failed to fetch kernel version from kernel.org"
    fi
    info "Latest stable kernel version: $KERNEL_VERSION"
fi

# Determine output paths
if [ "$ARCH" = "x86_64" ]; then
    KERNEL_FILENAME="vmlinux-${KERNEL_VERSION}-${ARCH}"
else
    KERNEL_FILENAME="Image-${KERNEL_VERSION}-${ARCH}"
fi
KERNEL_PATH="$ARTIFACTS_DIR/$KERNEL_FILENAME"

# Check if kernel already exists locally
if [ -f "$KERNEL_PATH" ]; then
    info "Kernel already exists: $KERNEL_PATH"
    info "Kernel ready: $KERNEL_PATH"
    exit 0
fi

if [ -f "${KERNEL_PATH}.xz" ]; then
    info "Compressed kernel already exists: ${KERNEL_PATH}.xz"
    info "Kernel ready: ${KERNEL_PATH}.xz"
    exit 0
fi

# Download from GitHub releases
info "Downloading kernel from GitHub releases..."

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${KERNEL_VERSION}/${KERNEL_FILENAME}.xz"
CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/v${KERNEL_VERSION}/${KERNEL_FILENAME}.sha256"

# Try to download compressed kernel and checksum
if ! curl -L -f -o "${KERNEL_PATH}.xz" "$DOWNLOAD_URL" 2>/dev/null; then
    error "Failed to download kernel from GitHub releases\n  Release may not exist for version ${KERNEL_VERSION}\n  Use 'task kernel:build' to build from source"
fi

if ! curl -L -f -o "${KERNEL_PATH}.sha256" "$CHECKSUM_URL" 2>/dev/null; then
    warn "Failed to download checksum file, skipping verification"
    info "Downloaded kernel from GitHub releases"
    info "Kernel ready: ${KERNEL_PATH}.xz"
    exit 0
fi

info "Downloaded kernel from GitHub releases"
info "Decompressing kernel (keeping compressed copy)..."
xz -d -k "${KERNEL_PATH}.xz"

info "Verifying checksum..."
if (cd "$ARTIFACTS_DIR" && sha256sum -c "${KERNEL_FILENAME}.sha256" 2>/dev/null); then
    info "✓ Checksum verification passed"
    rm -f "${KERNEL_PATH}.sha256"
    info "Kernel ready: $KERNEL_PATH"
    exit 0
else
    error "Checksum verification failed\n  Downloaded kernel may be corrupted\n  File removed, please try again"
fi
