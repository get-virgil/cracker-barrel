# Verifying Releases

**All kernel releases are PGP-signed.** We strongly recommend verifying signatures before using kernels in production.

## Why Verify?

Cryptographic verification ensures:

- ✅ Sources came from kernel.org (not tampered)
- ✅ Builds came from Cracker Barrel CI (not modified)
- ✅ Downloads weren't corrupted or replaced

Without verification, you're trusting:
- GitHub's infrastructure
- Network integrity during download
- CDN cache integrity

## Quick Verification

### Full Verification (Recommended)

```bash
# 1. Import Cracker Barrel release signing key (first time only)
curl -s https://raw.githubusercontent.com/get-virgil/cracker-barrel/master/keys/signing-key.asc | gpg --import

# Verify the key fingerprint matches (see below)
gpg --fingerprint releases@cracker-barrel.dev

# 2. Download kernel, checksums, and signature
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS.asc

# 3. Verify PGP signature on checksums
gpg --verify SHA256SUMS.asc SHA256SUMS
# Should show: "Good signature from Cracker Barrel Release Signing"

# 4. Verify download
sha256sum -c SHA256SUMS --ignore-missing
# Verifies: vmlinux-VERSION-x86_64.xz

# 5. Decompress kernel
xz -d vmlinux-VERSION-x86_64.xz

# 6. Verify kernel binary
sha256sum -c SHA256SUMS --ignore-missing
# Verifies: vmlinux-VERSION-x86_64
```

**Why two checksums?**
- `.xz` checksum: Verify download immediately when it finishes (supports streaming verification)
- Kernel binary checksum: Verify the actual kernel you're running on your system

### Checksum Only (Basic)

If you trust GitHub's infrastructure:

```bash
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS

sha256sum -c SHA256SUMS --ignore-missing  # Verify download
xz -d vmlinux-VERSION-x86_64.xz
sha256sum -c SHA256SUMS --ignore-missing  # Verify kernel binary
```

## Release Signing Key

**Cracker Barrel Release Signing Key:**
```
Key ID: [TO BE ADDED - Run 'task signing:generate-signing-key']
Fingerprint: [TO BE ADDED - Run 'task signing:generate-signing-key']
Email: releases@cracker-barrel.dev
```

**Important:** Always verify the fingerprint matches the value above when importing the key. This prevents key substitution attacks.

## Chain of Trust

Understanding the verification layers:

### Layer 1: PGP Signature (kernel.org autosigner)
- Verifies the PGP signature on `sha256sums.asc` from kernel.org
- Proves checksums file hasn't been tampered with
- Imports and validates kernel.org autosigner key
- Protects against CDN cache poisoning and compromised mirrors

### Layer 2: SHA256 Checksum
- Verifies kernel source tarball matches checksum from signed `sha256sums.asc`
- Verification happens **before extraction**, even for cached tarballs
- Protects against corrupted downloads and tampering

### Layer 3: Build Artifact Signing
- Pre-built kernels include SHA256 checksums in releases
- Checksums file is PGP-signed by Cracker Barrel release key
- Checksums for compressed files (`.xz`) enable immediate download verification
- Checksums for kernel binaries verify what you're running on your system

## What Verification Protects Against

**With full PGP verification:**
- ✅ CDN cache poisoning (malicious kernel sources)
- ✅ MITM attacks during download
- ✅ Tampered cached tarballs
- ✅ Corrupted downloads
- ✅ Compromised mirrors serving malicious content

**With checksum-only verification:**
- ✅ Corrupted downloads
- ✅ Transmission errors
- ⚠️ Trusts HTTPS to GitHub (no cryptographic proof)

**Without verification:**
- ❌ No protection against any tampering

## Verification in CI

All GitHub Actions builds use **maximum verification** (`high` level):

- Automated builds **never** bypass verification
- Builds fail-secure if checksums or PGP verification unavailable
- Workflow waits for kernel.org to update checksums (typically hours after kernel release)
- This ensures distributed kernels are always verified

**What users can trust:**
- All kernels in GitHub releases have been built from PGP-verified sources
- No kernel is ever released without passing full `high` verification
- CI never bypasses security checks
- CI uses the same build process as local development

## Troubleshooting Verification

See [User Guide > Troubleshooting](../user-guide/troubleshooting.md#source-verification-fails) for common verification issues and solutions.

## Next Steps

- [Security Model](../reference/security-model.md) - Detailed threat analysis
- [Verification Levels](../reference/verification-levels.md) - Understanding security trade-offs
- [Use with Firecracker](firecracker-usage.md) - Boot your verified kernel
