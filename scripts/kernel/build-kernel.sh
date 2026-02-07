#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
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
    info "Interrupted! Cleaning up build process..."
    # Kill all processes in the current process group
    # This kills make and all its child processes (gcc, etc.)
    kill -KILL -$$ 2>/dev/null || true
    exit 130
}

# Set up trap for SIGINT (Ctrl-C)
trap cleanup_on_interrupt INT

# Import kernel.org autosigner GPG key if not present
import_autosigner_key() {
    # Check if gpg is available
    if ! command -v gpg &> /dev/null; then
        if [ "$VERIFICATION_LEVEL" = "high" ]; then
            error "gpg not found. Install gpg or use --verification-level medium\n  On Ubuntu/Debian: sudo apt-get install gnupg"
        fi
        return 1
    fi

    # Check if key is already imported
    if gpg --list-keys "$AUTOSIGNER_KEY_ID" &>/dev/null; then
        return 0
    fi

    info "Importing kernel.org autosigner GPG key..."
    info "  Key ID: $AUTOSIGNER_KEY_ID"
    info "  Fingerprint: $AUTOSIGNER_KEY_FINGERPRINT"

    # Try multiple keyservers
    KEYSERVERS=(
        "hkps://keyserver.ubuntu.com"
        "hkps://keys.openpgp.org"
        "hkps://pgp.mit.edu"
    )

    for keyserver in "${KEYSERVERS[@]}"; do
        info "  Trying keyserver: $keyserver"
        if gpg --keyserver "$keyserver" --recv-keys "$AUTOSIGNER_KEY_ID" &>/dev/null; then
            info "✓ Autosigner key imported successfully"

            # Verify the fingerprint matches
            # Modern GPG output format: fingerprint is on line after "pub"
            IMPORTED_FP=$(gpg --fingerprint "$AUTOSIGNER_KEY_ID" 2>/dev/null | awk '/^pub/{getline; print}' | tr -d ' ')
            EXPECTED_FP=$(echo "$AUTOSIGNER_KEY_FINGERPRINT" | tr -d ' ')

            if [ "$IMPORTED_FP" != "$EXPECTED_FP" ]; then
                warn "Fingerprint mismatch! Expected: $AUTOSIGNER_KEY_FINGERPRINT"
                warn "                      Got:      $IMPORTED_FP"
                error "Key fingerprint verification failed - possible key substitution attack"
            fi

            return 0
        fi
    done

    if [ "$VERIFICATION_LEVEL" = "high" ]; then
        error "Failed to import autosigner key from any keyserver\n  Use --verification-level medium to proceed without PGP verification"
    fi
    return 1
}

# Parse command line arguments
ARCH=""
KERNEL_VERSION_ARG=""
VERIFICATION_LEVEL="high"  # high, medium, or disabled

# Kernel.org autosigner key (signs sha256sums.asc)
AUTOSIGNER_KEY_ID="632D3A06589DA6B1"
AUTOSIGNER_KEY_FINGERPRINT="B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1"

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
        --verification-level)
            VERIFICATION_LEVEL="$2"
            if [[ ! "$VERIFICATION_LEVEL" =~ ^(high|medium|disabled)$ ]]; then
                error "Invalid verification level: $VERIFICATION_LEVEL\n  Must be: high, medium, or disabled"
            fi
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Build Firecracker-compatible Linux kernel from source"
            echo ""
            echo "Options:"
            echo "  --kernel VERSION               Kernel version to build (default: latest stable)"
            echo "  --arch ARCH                    Target architecture (default: auto-detect)"
            echo "  --verification-level LEVEL     Set verification level (default: high)"
            echo "                                   high     - PGP signature + SHA256 (strongest, default)"
            echo "                                   medium   - SHA256 only (for systems without GPG)"
            echo "                                   disabled - No verification (kernel too new, emergency only)"
            echo "  -h, --help                     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                        # Build latest stable"
            echo "  $0 --kernel 6.1                           # Build kernel 6.1"
            echo "  $0 --kernel 6.1 --arch aarch64            # Build for ARM64"
            echo "  $0 --verification-level medium            # Skip PGP (systems without GPG)"
            echo "  $0 --verification-level disabled          # Skip all verification (emergency)"
            echo ""
            echo "Verification Levels:"
            echo "  high     - Verify PGP signature on checksums file + verify SHA256 of tarball"
            echo "             Protects against: CDN cache poisoning, MITM attacks, tampering"
            echo "             Requires: gpg installed, internet access to keyservers"
            echo "             Use when: Building for production (default, recommended)"
            echo ""
            echo "  medium   - Verify SHA256 checksum only, skip PGP signature verification"
            echo "             Protects against: Corrupted downloads, accidental tampering"
            echo "             Trusts: HTTPS connection to kernel.org"
            echo "             Use when: GPG not available, or acceptable risk for local testing"
            echo ""
            echo "  disabled - No verification whatsoever, keeps cached sources"
            echo "             Protects against: Nothing"
            echo "             Use when: Kernel just released and checksums not yet available"
            echo "             Example: 6.18.9 released but kernel.org hasn't updated sha256sums.asc"
            echo "             Development: Keeps build/linux-* for source modifications"
            echo "             WARNING: Only use when you accept the security risks"
            exit 0
            ;;
        *)
            error "Unknown option: $1\nUse --help for usage information"
            ;;
    esac
done

BUILD_DIR="build"
ARTIFACTS_DIR="artifacts"

# Validate architecture
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    error "Unsupported architecture: $ARCH\n  Supported: x86_64, aarch64"
fi

# Create directories
mkdir -p "$ARTIFACTS_DIR" "$BUILD_DIR"

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

info "Building kernel from source for architecture: $ARCH"

# Check for required build tools
info "Checking for required build tools..."
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

# Extract major version for download URL
MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)

# Set kernel source URL
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_TARBALL="$BUILD_DIR/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_SRC_DIR="$BUILD_DIR/linux-${KERNEL_VERSION}"

# Delete cached source when verification is enabled (security: always use fresh sources)
if [ "$VERIFICATION_LEVEL" != "disabled" ]; then
    if [ -f "$KERNEL_TARBALL" ] || [ -d "$KERNEL_SRC_DIR" ]; then
        info "Deleting cached source (verification enabled - using fresh sources)"
        rm -f "$KERNEL_TARBALL"
        rm -rf "$KERNEL_SRC_DIR"
    fi
fi

# Download kernel source if not already present
if [ ! -f "$KERNEL_TARBALL" ]; then
    info "Downloading kernel source from $KERNEL_URL..."
    wget -q --show-progress -O "$KERNEL_TARBALL" "$KERNEL_URL" || error "Failed to download kernel source"
    info "Kernel source downloaded successfully"
else
    info "Kernel source already downloaded"
fi

# Verify kernel source based on verification level
if [ "$VERIFICATION_LEVEL" = "disabled" ]; then
    warn "Verification disabled - proceeding without any security checks"
    warn "  The kernel source tarball has NOT been verified"
    warn "  Only use this for testing or when kernel is too new for checksums"
else
    info "Downloading checksums file for verification..."
    CHECKSUMS_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/sha256sums.asc"
    CHECKSUMS_FILE="$BUILD_DIR/sha256sums.asc"

    if ! wget -q -O "$CHECKSUMS_FILE" "$CHECKSUMS_URL" 2>/dev/null; then
        error "Could not download checksums file from kernel.org\n  Use --verification-level disabled to proceed anyway (not recommended)"
    fi

    # PGP verification (only for 'high' level)
    if [ "$VERIFICATION_LEVEL" = "high" ]; then
        info "Verifying PGP signature on checksums file..."

        # Import autosigner key if needed
        if ! import_autosigner_key; then
            warn "Could not import autosigner key, skipping PGP verification"
        else
            # Verify the signature
            GPG_OUTPUT=$(gpg --verify "$CHECKSUMS_FILE" 2>&1)
            GPG_STATUS=$?

            if [ $GPG_STATUS -eq 0 ]; then
                # Check for "Good signature"
                if echo "$GPG_OUTPUT" | grep -q "Good signature"; then
                    info "✓ PGP signature verification passed"
                    info "  Signed by: Kernel.org checksum autosigner <autosigner@kernel.org>"
                else
                    error "PGP signature verification failed\n  The checksums file may have been tampered with\n$GPG_OUTPUT"
                fi
            else
                error "PGP signature verification failed\n$GPG_OUTPUT"
            fi
        fi
    elif [ "$VERIFICATION_LEVEL" = "medium" ]; then
        info "Skipping PGP verification (verification-level: medium)"
        info "  Trusting HTTPS connection to kernel.org for checksums file"
    fi

    # SHA256 checksum verification (for both 'high' and 'medium' levels)
    info "Verifying kernel source checksum..."

    # Extract the checksum for our specific kernel version
    TARBALL_NAME="linux-${KERNEL_VERSION}.tar.xz"
    EXPECTED_HASH=$(grep -w "$TARBALL_NAME" "$CHECKSUMS_FILE" | awk '{print $1}' || true)

    if [ -z "$EXPECTED_HASH" ]; then
        error "Checksum not found in sha256sums.asc for $TARBALL_NAME\n  Kernel may be too new and not yet in checksums file.\n  Use --verification-level disabled to proceed anyway (not recommended)"
    fi

    # Verify the tarball checksum
    ACTUAL_HASH=$(sha256sum "$KERNEL_TARBALL" | awk '{print $1}')

    if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
        info "✓ Checksum verification passed"
        info "  Expected: $EXPECTED_HASH"
        info "  Actual:   $ACTUAL_HASH"
    else
        error "Checksum verification FAILED!\n  Expected: $EXPECTED_HASH\n  Actual:   $ACTUAL_HASH\n  The tarball may be corrupted or tampered with.\n  Remove $KERNEL_TARBALL and try again."
    fi

    # Clean up checksums file
    rm -f "$CHECKSUMS_FILE"
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

# Compress kernel with xz (keep decompressed copy for signing)
info "Compressing kernel with xz (this may take a while)..."
xz -9 -k -T0 "$ARTIFACTS_DIR/$OUTPUT_NAME" || error "Failed to compress kernel"
info "Kernel compressed successfully"

# Generate SHA256 checksum of compressed kernel
info "Generating SHA256 checksum of compressed kernel..."
(cd "$ARTIFACTS_DIR" && sha256sum "${OUTPUT_NAME}.xz" > "${OUTPUT_NAME}.xz.sha256")

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
