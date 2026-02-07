#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Verify PGP signatures on build artifacts
#
# This tests the complete verification workflow:
#   1. Import public key
#   2. Verify PGP signature on SHA256SUMS
#   3. Verify kernel checksums
#
# Works with both artifacts/ and release-artifacts/ directories.

set -euo pipefail

# Determine which directory to verify
if [ -d "release-artifacts" ] && [ -f "release-artifacts/SHA256SUMS.asc" ]; then
  TARGET_DIR="release-artifacts"
elif [ -d "artifacts" ] && [ -f "artifacts/SHA256SUMS.asc" ]; then
  TARGET_DIR="artifacts"
else
  echo "Error: No signed artifacts found."
  echo "Run 'task signing:sign-artifacts' first."
  exit 1
fi

echo "Verifying PGP signature on $TARGET_DIR/SHA256SUMS..."
echo ""

# Import public key
if [ -f "keys/signing-key.asc" ]; then
  gpg --import keys/signing-key.asc 2>/dev/null || true
fi

# Verify the signature
cd "$TARGET_DIR"
if gpg --verify SHA256SUMS.asc SHA256SUMS 2>&1; then
  echo ""
  echo "✓ PGP signature verification PASSED"
  echo ""

  # Two-stage verification: compressed (download integrity) + decompressed (build integrity)
  COMPRESSED_FAILED=0
  DECOMPRESSED_FAILED=0

  # Stage 1: Verify compressed kernels (download integrity)
  echo "Stage 1: Verifying compressed kernels (.xz files - download integrity)..."
  echo ""
  if sha256sum -c SHA256SUMS --ignore-missing 2>&1 | grep -E '\.xz:'; then
    echo ""
  else
    # No compressed files found - this is OK for backward compatibility
    echo "(No compressed kernel files found to verify)"
    echo ""
  fi

  # Check if any compressed files failed
  if sha256sum -c SHA256SUMS --ignore-missing 2>&1 | grep -E '\.xz:.*FAILED'; then
    COMPRESSED_FAILED=1
  fi

  # Stage 2: Verify decompressed kernels (build integrity)
  echo "Stage 2: Verifying decompressed kernels (build integrity)..."
  echo ""
  if sha256sum -c SHA256SUMS --ignore-missing 2>&1 | grep -vE '\.xz:'; then
    echo ""
  else
    # No decompressed files found - this might be an issue
    echo "(No decompressed kernel files found to verify)"
    echo ""
  fi

  # Check if any decompressed files failed
  if sha256sum -c SHA256SUMS --ignore-missing 2>&1 | grep -vE '\.xz:' | grep 'FAILED'; then
    DECOMPRESSED_FAILED=1
  fi

  # Overall result
  if [ $COMPRESSED_FAILED -eq 1 ] || [ $DECOMPRESSED_FAILED -eq 1 ]; then
    echo "✗ Checksum verification FAILED"
    if [ $COMPRESSED_FAILED -eq 1 ]; then
      echo "  - Compressed kernel verification failed (download may be corrupted)"
    fi
    if [ $DECOMPRESSED_FAILED -eq 1 ]; then
      echo "  - Decompressed kernel verification failed (build may be corrupted)"
    fi
    exit 1
  else
    echo "✓ All checksum verifications PASSED"
    echo ""
    echo "All verifications successful!"
  fi
else
  echo ""
  echo "✗ PGP signature verification FAILED"
  exit 1
fi
