#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Print functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Parse command line arguments
KERNEL_VERSION_ARG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel)
            KERNEL_VERSION_ARG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --kernel VERSION"
            echo ""
            echo "Check if kernel.org has published checksums for a specific kernel version"
            echo ""
            echo "Options:"
            echo "  --kernel VERSION    Kernel version to check (required)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Exit codes:"
            echo "  0 - Checksums are available"
            echo "  1 - Checksums are not available yet"
            echo "  2 - Error occurred (network, invalid version, etc.)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
    esac
done

# Validate kernel version provided
if [ -z "$KERNEL_VERSION_ARG" ]; then
    echo "Error: --kernel VERSION is required" >&2
    echo "Use --help for usage information" >&2
    exit 2
fi

KERNEL_VERSION="$KERNEL_VERSION_ARG"
info "Checking if kernel $KERNEL_VERSION is released and has checksums..."

# Step 1: Verify the kernel exists in releases.json
info "Checking if kernel $KERNEL_VERSION exists in kernel.org releases..."
RELEASES_JSON=$(curl -s https://www.kernel.org/releases.json)
if [ -z "$RELEASES_JSON" ]; then
    echo "Error: Could not fetch releases.json from kernel.org" >&2
    exit 2
fi

# Check if this exact version appears in any release
if ! echo "$RELEASES_JSON" | jq -e ".releases[] | select(.version == \"$KERNEL_VERSION\")" > /dev/null 2>&1; then
    echo "Error: Kernel version $KERNEL_VERSION not found in kernel.org releases" >&2
    echo "This version does not exist. Check https://www.kernel.org for valid versions." >&2
    echo "checksums_available=false" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 2  # Hard fail - invalid version
fi

info "✓ Kernel $KERNEL_VERSION exists in kernel.org releases"

# Step 2: Check if checksums are available
# Extract major version for download URL
MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)

# Set checksums URL
CHECKSUMS_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/sha256sums.asc"
TEMP_DIR=$(mktemp -d)
CHECKSUMS_FILE="$TEMP_DIR/sha256sums.asc"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Download checksums file
info "Checking if checksums are published..."
if ! wget -q -O "$CHECKSUMS_FILE" "$CHECKSUMS_URL" 2>/dev/null; then
    warn "Could not download checksums file from $CHECKSUMS_URL"
    warn "The kernel exists in releases.json but checksums haven't been published yet"
    warn "This usually happens within a few hours of a release"
    echo "checksums_available=false" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 1  # Soft fail - timing issue
fi

# Check if the specific kernel version is in the checksums file
TARBALL_NAME="linux-${KERNEL_VERSION}.tar.xz"
if grep -q -w "$TARBALL_NAME" "$CHECKSUMS_FILE"; then
    info "✓ Checksums are available for $TARBALL_NAME"
    info ""
    info "Summary: Kernel $KERNEL_VERSION is fully available for building"
    echo "checksums_available=true" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
else
    warn "Checksums file exists but does not contain entry for $TARBALL_NAME"
    warn "The kernel was released but checksums haven't been published yet"
    warn "This usually happens within a few hours of the release"
    echo "checksums_available=false" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 1  # Soft fail - timing issue
fi
