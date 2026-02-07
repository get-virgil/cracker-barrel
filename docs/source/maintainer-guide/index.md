# Maintainer Guide

This guide is for repository maintainers who manage releases, signing keys, and CI/CD workflows.

## Contents

```{toctree}
:maxdepth: 1

signing-setup
key-management
ci-workflow
```

- [Signing Setup](signing-setup.md) - Initial PGP signing key setup
- [Key Management](key-management.md) - Key rotation and maintenance
- [CI Workflow](ci-workflow.md) - GitHub Actions workflow details

## Overview

Maintainers are responsible for:

1. **Release Signing**: Generate and manage PGP signing keys
2. **Key Security**: Rotate keys, check expiry, secure private keys
3. **CI/CD**: Configure GitHub Actions, manage secrets
4. **Community**: Review build requests, manage bans

## Quick Reference

### First Time Setup

```bash
# Generate signing key
task signing:generate-signing-key

# Add key to GitHub Actions (prompted automatically)

# Update README with fingerprint

# Commit public key
git add keys/signing-key.asc README.md
git commit -m "Add release signing key"
git push
```

### Regular Operations

```bash
# Sign artifacts
task signing:sign-artifacts

# Verify signatures
task signing:verify-artifacts

# Check key expiry
task signing:check-expiry

# Rotate key (when needed)
task signing:rotate
```

## Security Responsibilities

As a maintainer, you handle sensitive operations:

- **Private Signing Key**: Never commit or share
- **GitHub Secrets**: Manage `SIGNING_KEY` secret
- **Key Rotation**: Rotate keys before expiry
- **Backup**: Securely backup private keys

## Next Steps

Start with [Signing Setup](signing-setup.md) for initial configuration.
