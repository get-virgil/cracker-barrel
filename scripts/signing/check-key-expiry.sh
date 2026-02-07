#!/bin/bash
# Check if signing key expires soon
#
# Exit codes:
#   0 - Key is valid for >60 days or never expires
#   1 - Key expires in ≤60 days or has already expired
#   2 - No key found or error checking expiration
#
# This is useful for CI/CD pipelines to catch expiring keys early.
# Run this script regularly (e.g., daily) to get advance warning.

set -euo pipefail

# Check if key exists
if [ ! -f "keys/cracker-barrel-release.asc" ]; then
  echo "Error: No signing key found (keys/cracker-barrel-release.asc)"
  exit 2
fi

# Import the public key temporarily
TEMP_GNUPG=$(mktemp -d)
trap "rm -rf $TEMP_GNUPG" EXIT

gpg --homedir "$TEMP_GNUPG" --import keys/cracker-barrel-release.asc 2>/dev/null

# Get key expiration info
KEY_INFO=$(gpg --homedir "$TEMP_GNUPG" --list-keys --with-colons 2>/dev/null | grep '^pub')

if [ -z "$KEY_INFO" ]; then
  echo "Error: Could not read key information"
  exit 2
fi

# Extract expiration timestamp (field 7)
EXPIRY_TIMESTAMP=$(echo "$KEY_INFO" | cut -d: -f7)

# Check if key never expires (empty timestamp)
if [ -z "$EXPIRY_TIMESTAMP" ] || [ "$EXPIRY_TIMESTAMP" = "0" ]; then
  echo "✓ Signing key never expires"
  exit 0
fi

# Calculate days until expiration
CURRENT_TIMESTAMP=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_TIMESTAMP - $CURRENT_TIMESTAMP) / 86400 ))

# Format expiration date for display
EXPIRY_DATE=$(date -d "@$EXPIRY_TIMESTAMP" +"%Y-%m-%d" 2>/dev/null || date -r "$EXPIRY_TIMESTAMP" +"%Y-%m-%d" 2>/dev/null)

if [ $DAYS_UNTIL_EXPIRY -le 0 ]; then
  echo "✗ WARNING: Signing key has EXPIRED!"
  echo "  Expired on: $EXPIRY_DATE"
  echo "  Days overdue: $((-$DAYS_UNTIL_EXPIRY))"
  echo ""
  echo "Action required: Rotate the signing key immediately"
  echo "  task signing:rotate"
  exit 1
elif [ $DAYS_UNTIL_EXPIRY -le 60 ]; then
  echo "⚠ WARNING: Signing key expires soon!"
  echo "  Expires on: $EXPIRY_DATE"
  echo "  Days remaining: $DAYS_UNTIL_EXPIRY"
  echo ""
  echo "Action recommended: Rotate the signing key before expiration"
  echo "  task signing:rotate"
  exit 1
else
  echo "✓ Signing key is valid"
  echo "  Expires on: $EXPIRY_DATE"
  echo "  Days remaining: $DAYS_UNTIL_EXPIRY"
  exit 0
fi
