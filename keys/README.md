# Release Signing Keys

This directory contains the PGP keys used to sign Cracker Barrel kernel releases.

## Files

- `signing-key.asc` - **Public key** (committed to repo)
  - Used by users to verify kernel releases
  - Safe to distribute publicly

- `signing-key-private.asc` - **Private key** (gitignored, DO NOT COMMIT)
  - Used by CI to sign releases
  - Should only exist:
    - Temporarily during key generation
    - In GitHub Actions secrets as `SIGNING_KEY`
    - In secure offline backup

## Generating Keys

Run once per repository to generate signing keys:

```bash
task generate-signing-key
```

This will:
1. Generate a 4096-bit RSA key pair
2. Export public key to `keys/signing-key.asc`
3. Export private key to `keys/signing-key-private.asc`
4. Display key fingerprint and setup instructions

## Setup Process

1. Generate keys: `task generate-signing-key`
2. Add private key to GitHub: `gh secret set SIGNING_KEY < keys/signing-key-private.asc`
3. Update README.md with fingerprint
4. Commit public key: `git add keys/signing-key.asc README.md`
5. Delete private key: `rm keys/signing-key-private.asc`

## Security Model

- **Public key**: Committed to repo, distributed to users
- **Private key**: Never committed, stored only in GitHub Actions secrets
- **Chain of trust**:
  - kernel.org sources → verified with kernel.org PGP signature
  - Built kernels → signed with Cracker Barrel private key
  - Users → verify with Cracker Barrel public key

## Key Rotation

If the key needs to be rotated:
1. Generate new key with `task generate-signing-key` (backs up old key)
2. Update GitHub Actions secret
3. Update README.md with new fingerprint
4. Keep old public key in git history for verifying old releases
5. Document rotation in README.md
