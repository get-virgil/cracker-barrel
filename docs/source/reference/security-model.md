# Security Model

Comprehensive verification model and threat analysis for Cracker Barrel.

## Overview

Cracker Barrel implements multi-layer verification to protect against supply chain attacks and ensure kernel authenticity.

## Verification Layers

### Layer 1: PGP Signature (kernel.org autosigner)

**Purpose**: Verify kernel sources are authentic from kernel.org

**Process**:
1. Downloads `sha256sums.asc` from kernel.org (PGP-signed checksums file)
2. Imports kernel.org autosigner GPG key from keyserver (if not present)
   - Key ID: `632D3A06589DA6B1`
   - Fingerprint: `B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1`
3. Verifies fingerprint matches expected value (prevents key substitution)
4. Verifies PGP signature on `sha256sums.asc`

**Protects Against**:
- ✅ CDN cache poisoning
- ✅ Compromised mirrors serving malicious tarballs
- ✅ MITM attacks during download
- ✅ Tampered checksums file

**Trust Assumptions**:
- kernel.org autosigner key is authentic
- Keyserver infrastructure is not compromised
- Hardcoded fingerprint is correct

### Layer 2: SHA256 Checksum

**Purpose**: Verify kernel tarball matches expected checksum

**Process**:
1. Extracts SHA256 hash for specific kernel version from `sha256sums.asc`
2. Calculates actual hash of downloaded/cached tarball
3. Compares expected vs actual
4. Build fails if mismatch

**When Executed**:
- **Always** before extraction
- Even for cached tarballs (treats cache as untrusted)

**Protects Against**:
- ✅ Corrupted downloads
- ✅ Tampered cached tarballs
- ✅ Transmission errors
- ✅ Partial downloads

**Trust Assumptions**:
- SHA256 algorithm is cryptographically secure
- Checksums in `sha256sums.asc` are correct (verified by Layer 1)

### Layer 3: Build Artifact Signing

**Purpose**: Verify built kernels are from Cracker Barrel CI

**Process**:
1. Generates SHA256SUMS for decompressed kernels
2. Signs SHA256SUMS with Cracker Barrel release key
3. Publishes `SHA256SUMS.asc` to GitHub Releases
4. Users verify signature before use

**Protects Against**:
- ✅ Modified GitHub releases
- ✅ Corrupted downloads from GitHub
- ✅ Unauthorized release uploads

**Trust Assumptions**:
- Cracker Barrel release key is authentic
- GitHub release infrastructure is secure
- Users properly verify signatures

## Threat Model

### In-Scope Threats

**Supply Chain Attacks:**
- ✅ Compromised CDN serving malicious kernel sources
- ✅ MITM attack modifying kernel downloads
- ✅ Tampered cached sources
- ✅ Malicious GitHub release uploads

**Infrastructure Compromise:**
- ✅ Compromised mirror serving malicious kernels
- ✅ GitHub cache poisoning
- ✅ Corrupted downloads

**Insider Threats:**
- ✅ Malicious maintainer attempting to bypass verification
- ✅ Compromised CI attempting to release unverified kernels

### Out-of-Scope Threats

**Kernel.org Compromise:**
- ❌ kernel.org autosigner key compromised
- ❌ Linus Torvalds/Greg KH keys compromised
- ❌ Kernel source itself is malicious

**Cryptographic Breaks:**
- ❌ SHA256 collision attack
- ❌ RSA 4096-bit break
- ❌ PGP implementation vulnerability

**Local Environment:**
- ❌ Compromised build machine
- ❌ Malicious compiler
- ❌ Modified system libraries

**Physical Access:**
- ❌ Physical tampering with hardware
- ❌ Cold boot attacks
- ❌ Hardware backdoors

### Attack Scenarios

#### Scenario 1: CDN Cache Poisoning

**Attack**: Attacker poisons CDN cache with malicious kernel tarball

**Protection**:
1. PGP signature verification fails (checksums don't match)
2. Build fails before extraction
3. No malicious code executed

**Result**: ✅ Attack prevented

#### Scenario 2: MITM Attack

**Attack**: Network attacker modifies kernel download in transit

**Protection**:
1. SHA256 checksum mismatch detected
2. Build fails before extraction
3. No malicious code executed

**Result**: ✅ Attack prevented

#### Scenario 3: Compromised Mirror

**Attack**: Mirror serves malicious kernel with matching filename

**Protection**:
1. PGP signature on checksums proves authenticity
2. Checksum mismatch detected
3. Build fails

**Result**: ✅ Attack prevented

#### Scenario 4: Tampered Cached Tarball

**Attack**: Attacker modifies cached tarball in `build/` directory

**Protection**:
1. Cached tarball re-verified before use
2. SHA256 mismatch detected
3. Build fails

**Result**: ✅ Attack prevented

#### Scenario 5: Malicious GitHub Release

**Attack**: Attacker uploads modified kernel to GitHub releases

**Protection**:
1. User verifies PGP signature on `SHA256SUMS.asc`
2. Signature verification fails (not signed by Cracker Barrel)
3. User rejects download

**Result**: ✅ Attack prevented (requires user verification)

#### Scenario 6: Compromised CI

**Attack**: Attacker compromises CI to bypass verification

**Protection**:
1. CI hardcoded to use `high` verification
2. No environment variable or input can change this
3. Build fails if verification unavailable

**Result**: ✅ Attack prevented by fail-secure design

## Fail-Secure Design

**Principle**: When in doubt, fail the build

**Implementation**:
- Verification failures → Build fails
- Missing checksums → Build fails
- Unavailable keyservers → Build fails
- PGP signature invalid → Build fails

**Never**:
- ❌ Bypass verification automatically
- ❌ Fall back to `disabled` verification
- ❌ Warn and continue without verification

**CI Enforcement**:
- CI always uses `high` verification
- No way to override (hardcoded)
- Builds wait for checksums to be available

## Trust Chain

```
Kernel Developers (Linus, Greg KH, etc.)
    ↓
    Sign kernel releases with developer keys
    ↓
kernel.org Autosigner
    ↓
    Signs sha256sums.asc with autosigner key
    ↓
Cracker Barrel CI
    ↓
    Verifies signatures, builds kernels
    ↓
Cracker Barrel Release Key
    ↓
    Signs SHA256SUMS of built kernels
    ↓
Users
    ↓
    Verify signatures before use
```

Each step provides cryptographic proof of authenticity.

## Verification Levels Comparison

| Feature | high | medium | disabled |
|---------|------|--------|----------|
| **PGP Verification** | ✅ Yes | ❌ No | ❌ No |
| **SHA256 Verification** | ✅ Yes | ✅ Yes | ❌ No |
| **CDN Poisoning** | ✅ Protected | ⚠️ Vulnerable | ❌ Vulnerable |
| **MITM Attack** | ✅ Protected | ⚠️ Vulnerable | ❌ Vulnerable |
| **Corrupted Download** | ✅ Protected | ✅ Protected | ❌ Vulnerable |
| **Tampered Cache** | ✅ Protected | ✅ Protected | ❌ Vulnerable |
| **Requirements** | GPG, keyservers | None | None |
| **Use Case** | Production | No GPG available | Development only |

See [Verification Levels](verification-levels.md) for detailed analysis.

## Security Recommendations

### For Production

1. **Always use `high` verification**:
   ```bash
   task kernel:build  # Defaults to high
   ```

2. **Verify downloaded releases**:
   ```bash
   gpg --verify SHA256SUMS.asc SHA256SUMS
   sha256sum -c SHA256SUMS --ignore-missing
   ```

3. **Verify key fingerprints**:
   ```bash
   gpg --fingerprint releases@cracker-barrel.dev
   # Ensure matches documented fingerprint
   ```

### For Development

1. **Use `high` for initial build**:
   ```bash
   task kernel:build KERNEL_VERSION=6.1
   ```

2. **Only use `disabled` for source modifications**:
   ```bash
   task kernel:build VERIFICATION_LEVEL=disabled
   # Make modifications
   task kernel:build VERIFICATION_LEVEL=disabled
   ```

3. **Return to `high` before distribution**:
   ```bash
   rm -rf build/
   task kernel:build KERNEL_VERSION=6.1
   ```

### For Maintainers

1. **Secure signing key**:
   - Encrypted backups in multiple locations
   - Never commit private key
   - Rotate before expiry

2. **Monitor CI**:
   - Ensure all builds use `high` verification
   - No environment bypasses
   - Fail-secure on errors

3. **Key rotation**:
   - Rotate every 2 years
   - Document rotation in README
   - Keep historical keys for verification

## Additional Security Measures

### Developer Signature Verification

For maximum assurance, verify developer signatures:

```bash
# Download .tar.sign file
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.9.tar.sign

# Verify developer signature
gpg --verify linux-6.18.9.tar.sign linux-6.18.9.tar.xz
```

See [kernel.org/signature.html](https://kernel.org/signature.html) for complete guide.

### Reproducible Builds

Cracker Barrel uses:
- Fixed Firecracker configs (committed to git)
- Specific kernel versions (no "latest" aliasing)
- Documented build process (Task commands)

This enables independent verification of builds.

## Limitations

### What Verification Does NOT Protect Against

- **Kernel bugs**: Verification proves authenticity, not correctness
- **Zero-days**: Unknown vulnerabilities in Linux kernel
- **Misconfigurations**: Improper Firecracker or VM configuration
- **Application vulnerabilities**: Bugs in your application code

### Trusted Components

Verification trusts:
- kernel.org infrastructure
- Keyserver infrastructure
- GitHub infrastructure (for releases)
- GPG implementation
- SHA256 algorithm

If any of these are compromised, security may be affected.

## Next Steps

- [Verification Levels](verification-levels.md) - Detailed level comparison
- [How It Works](how-it-works.md) - Implementation details
- [Verification Guide](../getting-started/verification.md) - User verification process
