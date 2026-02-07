# Key Management

Manage PGP signing keys: rotation, expiry checks, and removal.

## Key Rotation

Rotate the signing key periodically or when compromised.

### When to Rotate

- **Before expiry**: Rotate 30 days before key expires
- **Compromise**: Immediately if key is compromised
- **Policy**: Every 2 years (key expiration period)

### Rotation Process

```bash
# Rotate the key
task signing:rotate
```

This automatically:

1. Creates timestamped backup of current keys in `keys/backups/YYYY-MM-DD-HHMMSS/`
2. Generates new signing key
3. Prompts to update GitHub Actions secret
4. Displays new fingerprint for README update

### After Rotation

1. **Update README** with new fingerprint:
   ```bash
   vim README.md
   # Update fingerprint under "Cracker Barrel Release Signing Key"
   ```

2. **Commit new public key**:
   ```bash
   git add keys/signing-key.asc README.md
   git commit -m "Rotate release signing key"
   git push
   ```

3. **Keep old public key in history**:
   - Old releases were signed with old key
   - Users can verify old releases using git history
   - Don't delete old public key commits

4. **Add rotation note to README** (optional):
   ```markdown
   **Key Rotation History:**
   - 2026-02-06: Key rotated (see git history for previous key)
   ```

### Public Key History

The `keys/backups/` directory maintains historical keys:

```
keys/
├── signing-key.asc              # Current public key
├── backups/
│   ├── 2024-02-06-143022/
│   │   ├── signing-key.asc      # Old public key
│   │   └── signing-key-private.asc
│   └── 2025-02-06-091533/
│       ├── signing-key.asc
│       └── signing-key-private.asc
```

This enables:

- Auditable key rotation
- Verification of old releases
- Forensic investigation if needed

### UTC Timestamps

All backups use UTC timestamps for:

- Consistent timezone (CI runs UTC)
- Unambiguous ordering
- International coordination

## Checking Key Expiry

```bash
# Check when key expires
task signing:check-expiry
```

Output:

```
Key: Cracker Barrel Release Signing <releases@cracker-barrel.dev>
Expires: 2027-02-06
Days until expiry: 365

✓ Key valid for 365 days
```

Or if expiring soon:

```
Key: Cracker Barrel Release Signing <releases@cracker-barrel.dev>
Expires: 2026-03-08
Days until expiry: 28

⚠ Warning: Key expires in 28 days
   Consider rotating with: task signing:rotate
```

### Expiry Monitoring

Set up monitoring:

```bash
# Add to cron for weekly checks
# crontab -e
0 9 * * 1 cd /path/to/cracker-barrel && task signing:check-expiry
```

Or use GitHub Actions:

```yaml
# .github/workflows/check-key-expiry.yml
name: Check Key Expiry

on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly on Monday at 9 AM UTC

jobs:
  check-expiry:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check Key Expiry
        run: task signing:check-expiry
```

## Removing Signing Key

Remove the signing key from local GPG keyring:

```bash
task signing:remove
```

Use this to:

- Clean up after key rotation
- Reset local development environment
- Transfer maintainer responsibilities

**Warning**: This removes the key from your local GPG keyring. It does NOT remove:

- Public key from repository
- Private key from GitHub Actions secrets
- Backup keys

### After Removal

To restore the key from backup:

```bash
# Import private key from backup
gpg --import keys/backups/2026-02-06-143022/signing-key-private.asc

# Or from encrypted backup
gpg -d backup-signing-key.asc.gpg | gpg --import
```

## Security Best Practices

### Private Key Protection

1. **Never commit**: Private key must never be in git
2. **Secure backup**: Store encrypted backup offline
3. **Limited access**: Only authorized maintainers have access
4. **GitHub Actions only**: GitHub secret is the primary storage

### Public Key Management

1. **Commit immediately**: Public key should be in repo
2. **History preservation**: Never delete old public key commits
3. **README update**: Always update fingerprint after rotation
4. **Documentation**: Document rotation dates

### Backup Strategy

```bash
# Create encrypted backup
gpg --armor --export-secret-keys releases@cracker-barrel.dev > backup.asc

# Encrypt it
gpg --symmetric backup.asc

# Store backup.asc.gpg in:
# 1. Password manager (1Password, Bitwarden, etc.)
# 2. Encrypted USB drive (offline storage)
# 3. Secure cloud storage (encrypted at rest)

# Delete plaintext backup
shred -u backup.asc
```

### Multiple Backups

Store backups in multiple locations:

- **Primary**: Password manager
- **Secondary**: Encrypted USB drive
- **Tertiary**: Secure cloud storage (encrypted)

### Access Control

- **Limit maintainers**: Only necessary people have access
- **Audit access**: Log who accesses GitHub secrets
- **Rotate on departure**: Rotate key when maintainer leaves

## Incident Response

### Key Compromise

If private key is compromised:

1. **Immediate rotation**:
   ```bash
   task signing:rotate
   ```

2. **Update GitHub secret immediately**:
   ```bash
   gh secret set SIGNING_KEY < keys/signing-key-private.asc
   ```

3. **Announce compromise**:
   - Create GitHub issue
   - Update README with notice
   - Notify users via release notes

4. **Revoke old key**:
   ```bash
   gpg --edit-key releases@cracker-barrel.dev
   # revkey
   # save
   ```

5. **Re-sign recent releases**:
   ```bash
   # Re-sign with new key
   task signing:sign-artifacts
   # Create new GitHub release with new signatures
   ```

### Lost Key

If private key is lost but not compromised:

1. Restore from backup
2. If no backup exists, rotate key
3. Update documentation

## Audit Trail

The key management system provides audit trail:

- **Backups**: Timestamped backups in `keys/backups/`
- **Git history**: Public key changes tracked
- **README**: Rotation dates documented
- **Releases**: Old releases signed with old keys

This enables:

- Forensic investigation
- Verification of historical releases
- Proof of proper key management

## Next Steps

- [Signing Setup](signing-setup.md) - Initial key generation
- [CI Workflow](ci-workflow.md) - How CI uses signing keys
- [Verification](../getting-started/verification.md) - How users verify signatures
