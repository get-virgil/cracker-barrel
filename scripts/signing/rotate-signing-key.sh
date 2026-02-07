#!/bin/bash
# Rotate signing key (generates new key and updates GitHub)
#
# This will:
#   1. Create timestamped backup of current keys
#   2. Save old public key to keys/history/YYYY-MM-DD-HHMMSS.asc (committed)
#   3. Generate new signing key
#   4. Display new key fingerprint for README update
#   5. Optionally update GitHub Actions SIGNING_KEY secret (if gh CLI available)
#
# Environment variables:
#   SIGNING_KEY_NAME   - Key owner name (default: "Cracker Barrel Release Signing")
#   SIGNING_KEY_EMAIL  - Key email (default: "me@kazatron.com")
#   SIGNING_KEY_EXPIRY - Key expiration (default: "1y")
#                        Format: 0=never, <n>=days, <n>w=weeks, <n>m=months, <n>y=years
#
# Old key remains in keyring for verifying old releases.
# Works locally without GitHub - GitHub integration is optional.

set -euo pipefail

# Default values
SIGNING_KEY_NAME="${SIGNING_KEY_NAME:-Cracker Barrel Release Signing}"
SIGNING_KEY_EMAIL="${SIGNING_KEY_EMAIL:-me@kazatron.com}"
SIGNING_KEY_EXPIRY="${SIGNING_KEY_EXPIRY:-1y}"

echo "Rotating signing key..."
echo ""
echo "Creating backup of current keys..."

# Create timestamped backup directory
TIMESTAMP=$(date -u +%Y-%m-%d-%H%M%S)
BACKUP_DIR="keys/backups/${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

# Backup current keys
if [ -d ".gnupg" ]; then
  cp -r .gnupg "$BACKUP_DIR/"
  echo "  ✓ Backed up .gnupg/"
fi

if [ -f "keys/signing-key.asc" ]; then
  cp keys/signing-key.asc "$BACKUP_DIR/"
  echo "  ✓ Backed up keys/signing-key.asc"

  # Save old public key to history (committed to git for audit trail)
  mkdir -p keys/history
  cp keys/signing-key.asc "keys/history/${TIMESTAMP}.asc"
  echo "  ✓ Old public key saved to history: keys/history/${TIMESTAMP}.asc (UTC)"
fi

if [ -f "keys/signing-key-private.asc" ]; then
  cp keys/signing-key-private.asc "$BACKUP_DIR/"
  echo "  ✓ Backed up keys/signing-key-private.asc"
fi

echo ""
echo "Backup created: $BACKUP_DIR"
echo ""
echo "Generating new signing key..."

# Generate new key batch configuration
mkdir -p .gnupg
chmod 700 .gnupg

cat > .gnupg/keygen.batch <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${SIGNING_KEY_NAME}
Name-Email: ${SIGNING_KEY_EMAIL}
Expire-Date: ${SIGNING_KEY_EXPIRY}
%commit
EOF

# Generate the key
gpg --homedir .gnupg --batch --generate-key .gnupg/keygen.batch

# Get the new key ID (the most recently created one)
KEY_ID=$(gpg --homedir .gnupg --list-keys --with-colons | grep '^pub' | cut -d: -f5 | tail -1)

# Export new public key (overwrites old one)
gpg --homedir .gnupg --armor --export "$KEY_ID" > keys/signing-key.asc

# Export new private key (overwrites old one)
gpg --homedir .gnupg --armor --export-secret-keys "$KEY_ID" > keys/signing-key-private.asc

echo ""
echo "✓ New signing key generated successfully!"
echo ""
echo "New Key ID: $KEY_ID"
echo ""
echo "New Fingerprint:"
gpg --homedir .gnupg --fingerprint "$KEY_ID"
echo ""

# Check if gh CLI is available and GitHub secret exists
if command -v gh &>/dev/null; then
  if gh secret list --json name 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -q "^SIGNING_KEY$"; then
    echo "Update GitHub Actions SIGNING_KEY secret with new key? [y/N]"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      echo ""
      echo "Updating SIGNING_KEY in GitHub Actions..."
      gh secret set SIGNING_KEY < keys/signing-key-private.asc
      echo "✓ SIGNING_KEY updated in GitHub Actions"
    else
      echo "Skipped GitHub Actions update"
    fi
  else
    echo "Note: SIGNING_KEY not found in GitHub Actions (skipping GitHub update)"
  fi
else
  echo "Note: gh CLI not available (skipping GitHub update)"
fi

echo ""
echo "To update GitHub secret manually later:"
echo "  gh secret set SIGNING_KEY < keys/signing-key-private.asc"

echo ""
echo "All keys in keyring (old and new):"
gpg --homedir .gnupg --list-keys
echo ""
echo "Next steps:"
echo "  1. Update README.md with the new public key fingerprint above"
echo "  2. Commit the new public key and old key history:"
echo "     git add keys/signing-key.asc keys/history/ README.md"
echo "  3. Securely delete private key after uploading to GitHub:"
echo "     rm keys/signing-key-private.asc"
echo ""
echo "Old key saved to: keys/history/${TIMESTAMP}.asc (commit this)"
echo "Backup location: $BACKUP_DIR"
