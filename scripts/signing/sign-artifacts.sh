#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

# Sign kernel artifacts with PGP key
# For local testing: Signs artifacts in artifacts/
# For CI: Signs artifacts in release-artifacts/ (after consolidation)
#
# After signing, automatically archives signed artifacts to archive/{version}/
# for local-first development (git-ignored)

# Determine which directory to sign
if [ -d "release-artifacts" ] && [ -f "release-artifacts/SHA256SUMS" ]; then
    TARGET_DIR="release-artifacts"
elif [ -d "artifacts" ]; then
    TARGET_DIR="artifacts"
else
    echo "Error: No artifacts directory found"
    exit 1
fi

echo "Signing artifacts in $TARGET_DIR/..."

# Generate SHA256SUMS if it doesn't exist (local workflow)
cd "$TARGET_DIR"
if [ ! -f "SHA256SUMS" ]; then
    rm -f SHA256SUMS

    # Calculate checksums of both decompressed and compressed kernels
    # This provides two-stage verification: compressed (download) + decompressed (build)
    shopt -s nullglob

    # First, add checksums for decompressed kernels
    for file in vmlinux-* Image-*; do
        if [ -f "$file" ] && [[ ! "$file" =~ \.(xz|sha256)$ ]]; then
            sha256sum "$file" >> SHA256SUMS
        fi
    done

    # Then, add checksums for compressed kernels (.xz files)
    for file in vmlinux-*.xz Image-*.xz; do
        if [ -f "$file" ]; then
            sha256sum "$file" >> SHA256SUMS
        fi
    done

    shopt -u nullglob

    if [ ! -f "SHA256SUMS" ]; then
        echo "Error: No kernels found to sign"
        exit 1
    fi

    echo "SHA256SUMS created:"
    cat SHA256SUMS
fi

# Initialize GPG_OPTS
GPG_OPTS=""

# Import key from environment variable if set (CI)
if [ -n "${SIGNING_KEY:-}" ]; then
    echo "$SIGNING_KEY" | gpg --batch --import
    KEY_ID=$(gpg --list-keys --with-colons | grep '^pub' | cut -d: -f5 | tail -1)
# Otherwise use local key
elif [ -d "../.gnupg" ]; then
    KEY_ID=$(gpg --homedir ../.gnupg --list-keys --with-colons | grep '^pub' | cut -d: -f5 | tail -1)
    GPG_OPTS="--homedir ../.gnupg"
else
    echo "Error: No signing key found."
    echo "Local: Run 'task signing:generate-signing-key' first"
    echo "CI: Set SIGNING_KEY environment variable"
    exit 1
fi

echo "Signing SHA256SUMS with key: $KEY_ID"

# Sign the SHA256SUMS file
gpg $GPG_OPTS --batch --yes --default-key "$KEY_ID" --detach-sign --armor SHA256SUMS

echo ""
echo "✓ SHA256SUMS.asc created"
ls -lh SHA256SUMS*

# Archive signed artifacts locally (local-first philosophy)
cd ..
echo ""
echo "Archiving signed artifacts..."

# Extract kernel version from filenames
KERNEL_VERSION=""
shopt -s nullglob
for file in "$TARGET_DIR"/vmlinux-* "$TARGET_DIR"/Image-*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        # Extract version: vmlinux-6.18.9-x86_64.xz -> 6.18.9
        if [[ "$filename" =~ (vmlinux|Image)-([0-9]+\.[0-9]+\.[0-9]+)- ]]; then
            KERNEL_VERSION="${BASH_REMATCH[2]}"
            break
        fi
    fi
done
shopt -u nullglob

if [ -z "$KERNEL_VERSION" ]; then
    echo "Warning: Could not detect kernel version from artifacts"
    echo "Skipping local archive"
else
    ARCHIVE_DIR="archive/${KERNEL_VERSION}"
    mkdir -p "$ARCHIVE_DIR"

    # Copy all signed artifacts
    cp -v "$TARGET_DIR"/* "$ARCHIVE_DIR/" 2>/dev/null || true

    # Include public key (like in releases)
    if [ -f "keys/signing-key.asc" ]; then
        cp -v keys/signing-key.asc "$ARCHIVE_DIR/"
    fi

    echo ""
    echo "✓ Artifacts archived to: $ARCHIVE_DIR"
    echo "Archive contents:"
    ls -lh "$ARCHIVE_DIR"

    # Update archive index
    echo ""
    echo "Updating archive index..."
    INDEX_FILE="archive/index.json"

    # Initialize index if it doesn't exist
    if [ ! -f "$INDEX_FILE" ]; then
        echo '{"x86_64": {}, "aarch64": {}}' > "$INDEX_FILE"
    fi

    # Detect architectures in this archive and find kernel files
    for arch in x86_64 aarch64; do
        # Find the compressed kernel file for this architecture
        KERNEL_FILE=""
        if [ "$arch" = "x86_64" ]; then
            KERNEL_FILE=$(ls "$ARCHIVE_DIR"/vmlinux-*-${arch}.xz 2>/dev/null | head -1)
        else
            KERNEL_FILE=$(ls "$ARCHIVE_DIR"/Image-*-${arch}.xz 2>/dev/null | head -1)
        fi

        if [ -n "$KERNEL_FILE" ]; then
            # Get relative path from archive/ directory
            KERNEL_BASENAME=$(basename "$KERNEL_FILE")
            KERNEL_PATH="${KERNEL_VERSION}/${KERNEL_BASENAME}"

            # Add version and path to arch object
            CURRENT_INDEX=$(cat "$INDEX_FILE")
            UPDATED_INDEX=$(echo "$CURRENT_INDEX" | jq --arg arch "$arch" --arg version "$KERNEL_VERSION" --arg path "$KERNEL_PATH" \
                '.[$arch][$version] = $path')
            echo "$UPDATED_INDEX" > "$INDEX_FILE"
            echo "  ✓ Added $KERNEL_VERSION to $arch index"
        fi
    done

    echo ""
    echo "Archive index summary:"
    X86_COUNT=$(cat "$INDEX_FILE" | jq '.x86_64 | keys | length')
    ARM_COUNT=$(cat "$INDEX_FILE" | jq '.aarch64 | keys | length')
    echo "  x86_64: $X86_COUNT kernels"
    echo "  aarch64: $ARM_COUNT kernels"
fi
