#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

# Test Firecracker-compatible kernels by booting them in a Firecracker VM
# This script orchestrates the full workflow: build, download Firecracker, test boot

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Trap handler for clean interrupt
cleanup_on_interrupt() {
    echo ""
    info "Interrupted! Cleaning up..."
    # Kill Firecracker if running
    if [ -n "${FIRECRACKER_PID:-}" ] && kill -0 "$FIRECRACKER_PID" 2>/dev/null; then
        kill -9 "$FIRECRACKER_PID" 2>/dev/null || true
    fi
    # Remove socket
    rm -f /tmp/firecracker-test.sock 2>/dev/null || true
    exit 130
}

trap cleanup_on_interrupt INT

# Parse command line arguments
KERNEL_VERSION=""
FIRECRACKER_VERSION=""
FORCE_BUILD=false
VERIFICATION_LEVEL="high"

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        --firecracker)
            FIRECRACKER_VERSION="$2"
            shift 2
            ;;
        --force-build)
            FORCE_BUILD=true
            shift
            ;;
        --verification-level)
            VERIFICATION_LEVEL="$2"
            if [[ ! "$VERIFICATION_LEVEL" =~ ^(high|medium|disabled)$ ]]; then
                error "Invalid verification level: $VERIFICATION_LEVEL\\nMust be: high, medium, or disabled"
            fi
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Test Firecracker-compatible kernels by booting them in Firecracker VMs"
            echo ""
            echo "Options:"
            echo "  --kernel VERSION               Kernel version to test (default: latest stable)"
            echo "  --firecracker VERSION          Firecracker version to use (default: latest release)"
            echo "  --force-build                  Force building kernel from source instead of downloading"
            echo "  --verification-level LEVEL     Set verification level (default: high)"
            echo "                                   high     - PGP + SHA256 (strongest)"
            echo "                                   medium   - SHA256 only (no GPG needed)"
            echo "                                   disabled - No verification (emergency only)"
            echo "  -h, --help                     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                            # Test latest stable kernel"
            echo "  $0 --kernel 6.1                               # Test kernel 6.1"
            echo "  $0 --kernel 6.10 --firecracker v1.10.0        # Specific versions"
            echo "  $0 --force-build                              # Force build from source"
            echo "  $0 --verification-level medium                # Skip PGP verification"
            echo "  $0 --verification-level disabled              # Skip all verification"
            exit 0
            ;;
        *)
            error "Unknown option: $1\nUse --help for usage information"
            ;;
    esac
done

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    KERNEL_NAME="vmlinux"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
    KERNEL_NAME="Image"
else
    error "Unsupported architecture: $ARCH\n  Supported: x86_64, aarch64"
fi

info "Detected host architecture: $ARCH"

# Determine kernel version
if [ -z "$KERNEL_VERSION" ]; then
    info "Fetching latest stable kernel version from kernel.org..."
    KERNEL_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
    if [ -z "$KERNEL_VERSION" ] || [ "$KERNEL_VERSION" = "null" ]; then
        error "Failed to fetch latest kernel version"
    fi
    info "Latest stable kernel version: $KERNEL_VERSION"
else
    info "Using specified kernel version: $KERNEL_VERSION"
fi

# Determine Firecracker version
if [ -z "$FIRECRACKER_VERSION" ]; then
    info "Fetching latest Firecracker release from GitHub..."
    FIRECRACKER_VERSION=$(curl -s https://api.github.com/repos/firecracker-microvm/firecracker/releases/latest | jq -r '.tag_name')
    if [ -z "$FIRECRACKER_VERSION" ] || [ "$FIRECRACKER_VERSION" = "null" ]; then
        warn "Failed to fetch latest Firecracker release, using v1.14.1"
        FIRECRACKER_VERSION="v1.14.1"
    else
        info "Latest Firecracker release: $FIRECRACKER_VERSION"
    fi
else
    # Ensure version has 'v' prefix
    if [[ ! "$FIRECRACKER_VERSION" =~ ^v ]]; then
        FIRECRACKER_VERSION="v${FIRECRACKER_VERSION}"
    fi
    info "Using specified Firecracker version: $FIRECRACKER_VERSION"
fi

# Construct kernel path
if [ "$ARCH" = "x86_64" ]; then
    KERNEL_FILENAME="vmlinux-${KERNEL_VERSION}-${ARCH}"
else
    KERNEL_FILENAME="Image-${KERNEL_VERSION}-${ARCH}"
fi
KERNEL_PATH="artifacts/${KERNEL_FILENAME}"

info "Target kernel: $KERNEL_PATH"

# Get kernel (download or build if needed)
if [ ! -f "$KERNEL_PATH" ] && [ ! -f "${KERNEL_PATH}.xz" ]; then
    info "Kernel not found, getting kernel ${KERNEL_VERSION} for ${ARCH}..."
    GET_KERNEL_OPTS="--kernel $KERNEL_VERSION --arch $ARCH --verification-level $VERIFICATION_LEVEL"
    [ "$FORCE_BUILD" = true ] && GET_KERNEL_OPTS="$GET_KERNEL_OPTS --force-build"
    ./get-kernel.sh $GET_KERNEL_OPTS
elif [ "$FORCE_BUILD" = true ]; then
    info "Forcing kernel rebuild..."
    rm -f "$KERNEL_PATH" "${KERNEL_PATH}.xz" "${KERNEL_PATH}.sha256" 2>/dev/null || true
    GET_KERNEL_OPTS="--kernel $KERNEL_VERSION --arch $ARCH --force-build --verification-level $VERIFICATION_LEVEL"
    ./get-kernel.sh $GET_KERNEL_OPTS
fi

# Decompress kernel if compressed
if [ ! -f "$KERNEL_PATH" ] && [ -f "${KERNEL_PATH}.xz" ]; then
    info "Decompressing kernel..."
    xz -d "${KERNEL_PATH}.xz"
    success "Kernel decompressed"
fi

# Final validation that kernel exists
if [ ! -f "$KERNEL_PATH" ]; then
    error "Kernel not found: $KERNEL_PATH"
fi

info "Testing kernel: $KERNEL_PATH"

# Check for KVM support
if [ ! -e /dev/kvm ]; then
    error "KVM not available (/dev/kvm not found)\n  This test requires KVM support to run Firecracker VMs"
fi

if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
    error "KVM device not accessible\n  Run: sudo chmod 666 /dev/kvm"
fi

success "KVM available and accessible"

# Download Firecracker
FIRECRACKER_BIN="bin/firecracker-${FIRECRACKER_VERSION}-${ARCH}"

if [ -f "$FIRECRACKER_BIN" ]; then
    info "Using cached Firecracker: $FIRECRACKER_BIN"
else
    info "Downloading Firecracker ${FIRECRACKER_VERSION} for ${ARCH}..."
    mkdir -p bin

    DOWNLOAD_URL="https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-${ARCH}.tgz"
    TARBALL_PATH="bin/firecracker-${FIRECRACKER_VERSION}-${ARCH}.tgz"

    info "Downloading from: $DOWNLOAD_URL"
    curl -L -o "$TARBALL_PATH" "$DOWNLOAD_URL" || error "Failed to download Firecracker ${FIRECRACKER_VERSION}"

    # Extract binary
    tar -xzf "$TARBALL_PATH" -C bin --strip-components=1 "release-${FIRECRACKER_VERSION}-${ARCH}/firecracker-${FIRECRACKER_VERSION}-${ARCH}"

    # Make executable
    chmod +x "$FIRECRACKER_BIN"

    # Cleanup tarball
    rm -f "$TARBALL_PATH"

    success "Downloaded Firecracker to: $FIRECRACKER_BIN"
fi

# Verify Firecracker works
FIRECRACKER_VER_OUTPUT=$("$FIRECRACKER_BIN" --version | head -1)
info "Firecracker version: $FIRECRACKER_VER_OUTPUT"

# Create test rootfs
ROOTFS_PATH="artifacts/test-rootfs.ext4"
if [ ! -f "$ROOTFS_PATH" ]; then
    info "Creating test rootfs..."
    ./create-test-rootfs.sh "$ROOTFS_PATH"
fi
info "Using test rootfs: $ROOTFS_PATH"

# Test kernel boot in Firecracker
info "Starting Firecracker VM boot test..."

# Clean up any existing socket
rm -f /tmp/firecracker-test.sock

# Start Firecracker in background
"$FIRECRACKER_BIN" --api-sock /tmp/firecracker-test.sock >/dev/null 2>&1 &
FIRECRACKER_PID=$!
info "Firecracker PID: $FIRECRACKER_PID"

# Wait for socket to be ready
info "Waiting for API socket..."
for i in {1..10}; do
    if [ -S /tmp/firecracker-test.sock ]; then
        success "API socket ready"
        break
    fi
    sleep 0.5
done

if [ ! -S /tmp/firecracker-test.sock ]; then
    error "API socket not available after 5 seconds"
fi

# Configure boot source
info "Configuring boot source..."
curl -s -X PUT \
    --unix-socket /tmp/firecracker-test.sock \
    http://localhost/boot-source \
    -H 'Content-Type: application/json' \
    -d "{
        \"kernel_image_path\": \"$(pwd)/${KERNEL_PATH}\",
        \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off init=/init\"
    }" || error "Failed to configure boot source"

# Configure rootfs drive
info "Configuring rootfs drive..."
curl -s -X PUT \
    --unix-socket /tmp/firecracker-test.sock \
    http://localhost/drives/rootfs \
    -H 'Content-Type: application/json' \
    -d "{
        \"drive_id\": \"rootfs\",
        \"path_on_host\": \"$(pwd)/${ROOTFS_PATH}\",
        \"is_root_device\": true,
        \"is_read_only\": false
    }" || error "Failed to configure rootfs"

# Configure machine
info "Configuring machine..."
curl -s -X PUT \
    --unix-socket /tmp/firecracker-test.sock \
    http://localhost/machine-config \
    -H 'Content-Type: application/json' \
    -d '{
        "vcpu_count": 1,
        "mem_size_mib": 128
    }' || error "Failed to configure machine"

# Start VM
info "Starting VM..."
curl -s -X PUT \
    --unix-socket /tmp/firecracker-test.sock \
    http://localhost/actions \
    -H 'Content-Type: application/json' \
    -d '{
        "action_type": "InstanceStart"
    }' || error "Failed to start VM"

info "Waiting for VM to boot and shutdown (max 60s)..."

# Wait for VM to boot and shutdown
for i in {1..60}; do
    if ! kill -0 "$FIRECRACKER_PID" 2>/dev/null; then
        echo ""
        success "=========================================="
        success "VM booted and shut down cleanly!"
        success "Kernel ${KERNEL_PATH} boot test PASSED"
        success "=========================================="
        FIRECRACKER_PID=""
        exit 0
    fi
    echo -n "."
    sleep 1
done

# Timeout
echo ""
error "=========================================="
error "VM did not shut down within timeout"
error "Kernel ${KERNEL_PATH} boot test FAILED"
error "=========================================="
