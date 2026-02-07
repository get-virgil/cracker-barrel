#!/bin/bash
# Remove local signing key and keyring (destructive operation)
#
# This removes:
#   - .gnupg/ directory (local GPG keyring)
#   - keys/signing-key-private.asc (private key export)
#   - keys/signing-key.asc (public key export)
#   - Optionally: SIGNING_KEY from GitHub Actions (with double confirmation)
#
# This does NOT remove:
#   - keys/backups/ directory (all key backups are preserved for safety)
#   - keys/README.md (documentation)
#
# WARNING: This is destructive and cannot be undone.
#
# If gh CLI is available and SIGNING_KEY exists in GitHub Actions,
# you will be prompted (with double confirmation) to remove it.
#
# Use case: Key rotation, security incident response, or cleanup

set -euo pipefail

# First confirmation
echo "This will delete your local signing key and .gnupg directory."
echo "Continue? [y/N]"
read -r response1
if [[ ! "$response1" =~ ^[Yy]$ ]]; then
  echo "Cancelled"
  exit 0
fi

# Second confirmation
echo ""
echo "Are you absolutely sure? This cannot be undone. [y/N]"
read -r response2
if [[ ! "$response2" =~ ^[Yy]$ ]]; then
  echo "Cancelled"
  exit 0
fi

echo ""
echo "Removing signing keys..."
echo ""

# List what will be removed
echo "The following will be deleted:"
[ -d ".gnupg" ] && echo "  - .gnupg/ ($(du -sh .gnupg 2>/dev/null | cut -f1))"
[ -f "keys/signing-key-private.asc" ] && echo "  - keys/signing-key-private.asc"
[ -f "keys/signing-key.asc" ] && echo "  - keys/signing-key.asc"
echo ""

# Remove files
rm -rf .gnupg
rm -f keys/signing-key-private.asc
rm -f keys/signing-key.asc

echo "✓ Local signing keys removed"
echo ""

# Offer to remove GitHub secret if gh CLI is available
if command -v gh &>/dev/null; then
  if gh secret list --json name 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -q "^SIGNING_KEY$"; then
    echo "GitHub Actions SIGNING_KEY secret detected."
    echo ""
    echo "Remove SIGNING_KEY from GitHub Actions? [y/N]"
    read -r response3
    if [[ "$response3" =~ ^[Yy]$ ]]; then
      echo ""
      echo "WARNING: This will remove the secret from GitHub Actions."
      echo "Are you absolutely sure? [y/N]"
      read -r response4
      if [[ "$response4" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Removing SIGNING_KEY from GitHub Actions..."
        gh secret remove SIGNING_KEY
        echo "✓ SIGNING_KEY removed from GitHub Actions"
      else
        echo "Cancelled GitHub secret removal"
        echo ""
        echo "To remove manually later:"
        echo "  gh secret remove SIGNING_KEY"
      fi
    else
      echo "Skipped GitHub secret removal"
      echo ""
      echo "To remove manually later:"
      echo "  gh secret remove SIGNING_KEY"
    fi
  else
    echo "Note: SIGNING_KEY not found in GitHub Actions (nothing to remove)"
  fi
else
  echo "Note: gh CLI not available (skipping GitHub secret check)"
  echo "To remove manually if needed:"
  echo "  gh secret remove SIGNING_KEY"
fi
