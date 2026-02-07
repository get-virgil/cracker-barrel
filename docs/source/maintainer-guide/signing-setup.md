# Signing Setup

Initial setup for PGP signing of release artifacts.

## Overview

All kernel releases are PGP-signed to ensure authenticity. This guide covers one-time setup for repository maintainers.

## Prerequisites

- Repository write access
- GPG installed locally
- GitHub Actions permissions

## Step 1: Generate Signing Key

```bash
task signing:generate-signing-key
```

This creates:

- `.gnupg/` - GPG home directory (gitignored)
- `keys/signing-key.asc` - **Public key** (commit this)
- `keys/signing-key-private.asc` - **Private key** (DO NOT COMMIT)

### Key Properties

The generated key has:

- **Type**: RSA 4096-bit
- **Name**: Cracker Barrel Release Signing
- **Email**: releases@cracker-barrel.dev
- **Expiration**: 2 years
- **Usage**: Signing only (not encryption)

### Output

The task displays:

```
✓ Signing key generated successfully

Public key: keys/signing-key.asc
Private key: keys/signing-key-private.asc

Key fingerprint: XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX

IMPORTANT:
- Commit keys/signing-key.asc (public key)
- DO NOT commit keys/signing-key-private.asc (private key)
- Backup private key securely
- Add private key to GitHub Actions secrets
```

## Step 2: Add Key to GitHub Actions

The task automatically prompts to add the key to GitHub Actions:

```
Would you like to add the signing key to GitHub Actions now? [y/N]
```

If you answer **yes**:

- Requires `gh` CLI installed and authenticated
- Automatically creates `SIGNING_KEY` secret
- Uses the generated private key

If you answer **no**, add manually:

```bash
# Via gh CLI
gh secret set SIGNING_KEY < keys/signing-key-private.asc

# Via GitHub UI
# 1. Go to Settings → Secrets and variables → Actions
# 2. Click "New repository secret"
# 3. Name: SIGNING_KEY
# 4. Value: (paste contents of keys/signing-key-private.asc)
# 5. Click "Add secret"
```

## Step 3: Update README

Copy the key fingerprint from the output and update `README.md`:

```markdown
**Cracker Barrel Release Signing Key:**
```
Key ID: [Paste key ID here]
Fingerprint: [Paste fingerprint here]
Email: releases@cracker-barrel.dev
```
```

Replace the `[TO BE ADDED]` placeholders.

## Step 4: Commit Public Key

```bash
# Add public key and updated README
git add keys/signing-key.asc README.md

# Commit
git commit -m "Add release signing key"

# Push
git push
```

## Step 5: Secure Private Key

**Important**: The private key is sensitive.

### Backup

```bash
# Create encrypted backup
gpg --armor --export-secret-keys releases@cracker-barrel.dev > backup-signing-key.asc

# Encrypt backup
gpg --symmetric backup-signing-key.asc

# Store backup-signing-key.asc.gpg securely
# - Password manager
# - Encrypted USB drive
# - Secure cloud storage (encrypted)
```

### Delete Local Copy

```bash
# Remove private key from repository
rm keys/signing-key-private.asc

# Verify it's gitignored
cat .gitignore | grep signing-key-private.asc
```

The key now exists only in:

1. GitHub Actions secrets (for CI)
2. Your secure backup

## Step 6: Test Signing

Verify the setup works:

```bash
# Build a test kernel
task kernel:build KERNEL_VERSION=6.1

# Sign artifacts
task signing:sign-artifacts

# Verify signature
task signing:verify-artifacts
```

Expected output:

```
✓ gpg: Good signature from "Cracker Barrel Release Signing <releases@cracker-barrel.dev>"
✓ Signature verified successfully
```

## Verification

Ensure setup is correct:

### Public Key Committed

```bash
# Check public key exists in repo
git ls-files keys/signing-key.asc
# Should show: keys/signing-key.asc
```

### Private Key Not Committed

```bash
# Ensure private key is NOT in repo
git ls-files keys/signing-key-private.asc
# Should show: (nothing)

# Check it's gitignored
cat .gitignore | grep signing-key-private.asc
# Should show: keys/signing-key-private.asc
```

### GitHub Secret Configured

```bash
# List secrets (requires gh CLI)
gh secret list

# Should show:
# SIGNING_KEY  Updated YYYY-MM-DD
```

### README Updated

```bash
# Check README has fingerprint
grep -A 3 "Cracker Barrel Release Signing Key" README.md

# Should show fingerprint, not [TO BE ADDED]
```

## Troubleshooting

### GPG Command Not Found

```bash
# Install GPG
sudo apt-get install gnupg  # Ubuntu/Debian
sudo pacman -S gnupg        # Arch Linux
```

### Key Already Exists

If a key already exists:

```bash
# List existing keys
gpg --list-secret-keys releases@cracker-barrel.dev

# Remove existing key
task signing:remove

# Generate new key
task signing:generate-signing-key
```

### Cannot Add Secret to GitHub

If `gh` CLI fails:

1. Ensure authenticated: `gh auth login`
2. Ensure repository access: `gh repo view`
3. Check permissions: Requires write access to secrets

Or add manually via GitHub UI.

## Next Steps

- [Key Management](key-management.md) - Key rotation and maintenance
- [Verify Artifacts](../getting-started/verification.md) - User verification process
- [CI Workflow](ci-workflow.md) - How CI uses the signing key
