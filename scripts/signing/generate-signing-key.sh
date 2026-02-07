#!/bin/bash
# Generate PGP signing key for kernel releases (first-time setup)
#
# This creates:
#   - Private key stored locally in .gnupg/ (gitignored)
#   - Public key exported to keys/cracker-barrel-release.asc (committed)
#   - Private key exported to keys/cracker-barrel-release-private.asc (gitignored)
#   - Initial backup in keys/backups/initial-*
#
# Environment variables:
#   SIGNING_KEY_NAME   - Key owner name (default: "Cracker Barrel Release Signing")
#   SIGNING_KEY_EMAIL  - Key email (default: "me@kazatron.com")
#   SIGNING_KEY_EXPIRY - Key expiration (default: "1y")
#                        Format: 0=never, <n>=days, <n>w=weeks, <n>m=months, <n>y=years

set -euo pipefail

# Default values
SIGNING_KEY_NAME="${SIGNING_KEY_NAME:-Cracker Barrel Release Signing}"
SIGNING_KEY_EMAIL="${SIGNING_KEY_EMAIL:-me@kazatron.com}"
SIGNING_KEY_EXPIRY="${SIGNING_KEY_EXPIRY:-1y}"

echo "Checking for existing local signing key..."
echo ""

# Check if local key already exists
if [ -d ".gnupg" ] || [ -f "keys/cracker-barrel-release.asc" ]; then
  echo "Error: Local signing key already exists"
  echo ""
  echo "Options:"
  echo "  - Use 'task signing:rotate' to rotate keys"
  echo "  - Use 'task signing:remove-signing-key' to remove existing key first"
  exit 1
fi

echo "Generating PGP signing key for Cracker Barrel releases..."
echo ""

# Create directories
mkdir -p .gnupg keys
chmod 700 .gnupg

# Generate key batch configuration
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

# Get the key ID
KEY_ID=$(gpg --homedir .gnupg --list-keys --with-colons | grep '^pub' | cut -d: -f5)

# Export public key
gpg --homedir .gnupg --armor --export "$KEY_ID" > keys/cracker-barrel-release.asc

# Export private key (for GitHub Actions secret)
gpg --homedir .gnupg --armor --export-secret-keys "$KEY_ID" > keys/cracker-barrel-release-private.asc

# Create initial backup
BACKUP_DIR="keys/backups/initial-$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r .gnupg "$BACKUP_DIR/"
cp keys/cracker-barrel-release.asc "$BACKUP_DIR/"
cp keys/cracker-barrel-release-private.asc "$BACKUP_DIR/"

echo ""
echo "✓ Signing key generated successfully!"
echo "✓ Initial backup created: $BACKUP_DIR"
echo ""
echo "Key ID: $KEY_ID"
echo ""
echo "Fingerprint:"
gpg --homedir .gnupg --fingerprint "$KEY_ID"
echo ""

# Prompt to add to GitHub (only if gh CLI is available)
if command -v gh &>/dev/null; then
  echo "Add SIGNING_KEY to GitHub Actions? [y/N]"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    # Check if secret already exists in GitHub
    if gh secret list --json name 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -q "^SIGNING_KEY$"; then
      echo ""
      echo "Error: SIGNING_KEY already exists in GitHub Actions secrets"
      echo "Use 'task signing:rotate' to rotate keys instead"
      exit 1
    fi

    echo ""
    echo "Adding SIGNING_KEY to GitHub Actions..."
    gh secret set SIGNING_KEY < keys/cracker-barrel-release-private.asc
    echo "✓ SIGNING_KEY added to GitHub Actions"
  else
    echo "Skipped GitHub Actions setup"
    echo ""
    echo "To add manually later:"
    echo "  gh secret set SIGNING_KEY < keys/cracker-barrel-release-private.asc"
  fi
else
  echo "Note: gh CLI not available (skipping GitHub setup)"
  echo ""
  echo "To add to GitHub manually later:"
  echo "  gh secret set SIGNING_KEY < keys/cracker-barrel-release-private.asc"
fi

echo ""
echo "Next steps:"
echo "  1. Update README.md with the public key fingerprint above"
echo "  2. Commit the public key:"
echo "     git add keys/cracker-barrel-release.asc README.md"
echo "  3. Securely delete private key after uploading to GitHub:"
echo "     rm keys/cracker-barrel-release-private.asc"
echo ""
echo "Public key: keys/cracker-barrel-release.asc (commit this)"
echo "Private key: keys/cracker-barrel-release-private.asc (DO NOT COMMIT)"
