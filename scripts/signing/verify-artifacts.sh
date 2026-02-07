#!/bin/bash
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
if [ -f "keys/cracker-barrel-release.asc" ]; then
  gpg --import keys/cracker-barrel-release.asc 2>/dev/null || true
fi

# Verify the signature
cd "$TARGET_DIR"
if gpg --verify SHA256SUMS.asc SHA256SUMS 2>&1; then
  echo ""
  echo "✓ PGP signature verification PASSED"
  echo ""
  echo "Now verifying kernel checksums..."
  echo ""

  # Verify checksums
  if sha256sum -c SHA256SUMS --ignore-missing 2>&1; then
    echo ""
    echo "✓ Checksum verification PASSED"
    echo ""
    echo "All verifications successful!"
  else
    echo ""
    echo "✗ Checksum verification FAILED"
    exit 1
  fi
else
  echo ""
  echo "✗ PGP signature verification FAILED"
  exit 1
fi
