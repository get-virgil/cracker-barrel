#!/bin/bash
set -euo pipefail

# Sign kernel artifacts with PGP key
# For local testing: Signs artifacts in artifacts/
# For CI: Signs artifacts in release-artifacts/ (after consolidation)

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

    # Calculate checksums of decompressed kernels
    shopt -s nullglob
    for file in vmlinux-* Image-*; do
        if [ -f "$file" ] && [[ ! "$file" =~ \.(xz|sha256)$ ]]; then
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
