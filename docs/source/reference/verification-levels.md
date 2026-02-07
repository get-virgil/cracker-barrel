# Verification Levels

Detailed comparison of verification levels: high, medium, and disabled.

## Overview

Cracker Barrel supports three verification levels for building kernels, each with different security trade-offs.

## Level Comparison

| Aspect | high (default) | medium | disabled |
|--------|----------------|--------|----------|
| **PGP Signature** | ✅ Verified | ❌ Skipped | ❌ Skipped |
| **SHA256 Checksum** | ✅ Verified | ✅ Verified | ❌ Skipped |
| **Source Cache Deleted** | ✅ Yes | ✅ Yes | ❌ No (preserved) |
| **Requires GPG** | ✅ Yes | ❌ No | ❌ No |
| **Requires Keyservers** | ✅ Yes | ❌ No | ❌ No |
| **CI Verification** | ✅ Always | ❌ Never | ❌ Never |

## High Verification (Default)

```bash
task kernel:build  # Defaults to high
task kernel:build VERIFICATION_LEVEL=high
```

### What It Does

1. Downloads `sha256sums.asc` from kernel.org
2. Imports kernel.org autosigner GPG key
3. Verifies PGP signature on `sha256sums.asc`
4. Extracts SHA256 hash for kernel version
5. Calculates actual hash of tarball
6. Compares hashes (fails if mismatch)
7. Only extracts after both verifications pass

### Protects Against

- ✅ CDN cache poisoning
- ✅ MITM attacks during download
- ✅ Tampered cached tarballs
- ✅ Corrupted downloads
- ✅ Compromised mirrors

### Requirements

- GPG installed (`gnupg` package)
- Internet access to keyservers (first time only)
- kernel.org `sha256sums.asc` available

### Use When

- Building for production
- Building for distribution
- Any trusted/critical use
- CI/CD builds (always)

### Failure Modes

**"gpg not found"**:
- Install GPG or use `medium` verification

**"Failed to import autosigner key"**:
- Keyserver unreachable
- Check firewall/proxy
- Try again later or use `medium`

**"PGP signature verification failed"**:
- Serious security concern
- Investigate before proceeding
- Do NOT bypass without understanding

**"Checksum not found in sha256sums.asc"**:
- Kernel too new, checksums not ready
- Wait for kernel.org to update
- Emergency only: use `disabled`

## Medium Verification

```bash
task kernel:build VERIFICATION_LEVEL=medium
```

### What It Does

1. Downloads `sha256sums.asc` from kernel.org (via HTTPS)
2. **Skips PGP verification**
3. Extracts SHA256 hash for kernel version
4. Calculates actual hash of tarball
5. Compares hashes (fails if mismatch)

### Protects Against

- ✅ Corrupted downloads
- ✅ Transmission errors
- ✅ Partial downloads
- ⚠️ Tampered cache (if checksums trusted)

### Does NOT Protect Against

- ❌ CDN poisoning (attacker controls checksums too)
- ❌ MITM attacks (attacker modifies tarball + checksums)
- ❌ Compromised mirrors (serve matching malicious pair)

### Security Model

**Trusts**: HTTPS connection to kernel.org for checksums

**Attack Scenario**:
- Attacker compromises kernel.org CDN
- Replaces both tarball AND checksums file
- Both have matching malicious versions
- `medium` verification passes

### Requirements

- None (no GPG needed)
- Internet access to kernel.org

### Use When

- Systems without GPG
- Acceptable risk for local testing
- Development environments
- GPG not installable (policy restrictions)

### Trade-offs

**Pros**:
- No GPG dependency
- Simpler setup
- Still catches corruption

**Cons**:
- Trusts HTTPS alone
- Vulnerable to sophisticated attacks
- Not suitable for production

## Disabled Verification

```bash
task kernel:build VERIFICATION_LEVEL=disabled
```

### What It Does

1. Downloads tarball
2. **Skips all verification**
3. Extracts immediately
4. Preserves cache between builds

### Protects Against

- ❌ Nothing

### Source Cache Behavior

With `disabled`, sources are preserved:

```bash
# First build
task kernel:build VERIFICATION_LEVEL=disabled
# Downloads and extracts to build/linux-6.1/

# Modify sources
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild
task kernel:build VERIFICATION_LEVEL=disabled
# Uses existing build/linux-6.1/ (preserves modifications)
```

### Use When

- Kernel development with source modifications
- Kernel just released (checksums unavailable)
- Offline development after initial download
- Testing experimental patches

### Use Cases

**Development Workflow**:
```bash
# Initial build
task kernel:build VERIFICATION_LEVEL=disabled

# Modify sources
vim build/linux-6.1/drivers/foo.c

# Rebuild with changes
task kernel:build VERIFICATION_LEVEL=disabled

# Test
task firecracker:test-kernel
```

**Emergency Build** (kernel too new):
```bash
# Kernel 6.18.10 just released, checksums not ready
task kernel:build KERNEL_VERSION=6.18.10 VERIFICATION_LEVEL=disabled

# Wait for checksums
sleep 3600

# Rebuild with verification
rm -rf build/linux-6.18.10*
task kernel:build KERNEL_VERSION=6.18.10
```

### Never Use For

- ❌ Production kernels
- ❌ Distribution to others
- ❌ Published releases
- ❌ Security-critical systems
- ❌ CI/CD builds

### Warnings

**Security**:
- No cryptographic guarantees
- Complete trust in download source
- Vulnerable to all attacks

**Integrity**:
- No corruption detection
- No tampering detection
- No authenticity proof

## Recommendation Matrix

| Scenario | Recommended Level | Rationale |
|----------|-------------------|-----------|
| Production deployment | `high` | Maximum security required |
| CI/CD builds | `high` | Hardcoded, no exceptions |
| Distribution to users | `high` | Users depend on verification |
| Local testing | `high` or `medium` | `high` if GPG available |
| No GPG available | `medium` | Better than nothing |
| Kernel development | `disabled` | Need source preservation |
| Kernel too new | Wait or `disabled` | Temporary until checksums ready |
| Airgapped environment | `high` then `disabled` | Verify once, then work offline |

## CI Enforcement

GitHub Actions **always** uses `high` verification:

```yaml
# Hardcoded in workflow
- name: Build kernel
  run: task kernel:build VERIFICATION_LEVEL=high
```

**Why**:
- No exceptions for convenience
- Fail-secure by design
- Ensures all releases are verified

**Result**:
- Builds may fail temporarily (kernel too new)
- This is correct behavior
- Wait for kernel.org to update checksums

## Switching Levels

### Start Strict, Relax Temporarily

```bash
# Production build (verified)
task kernel:build KERNEL_VERSION=6.1

# Development (modify sources)
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
vim build/linux-6.1/...
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Back to production (clean slate)
rm -rf build/linux-6.1*
task kernel:build KERNEL_VERSION=6.1
```

### Development to Production

```bash
# Development phase
task kernel:build VERIFICATION_LEVEL=disabled
# ...modifications and testing...

# Production build (fresh sources)
task clean
task kernel:build  # Uses high by default
```

## Best Practices

1. **Default to `high`**: Always start with maximum verification
2. **Document exceptions**: If using `medium` or `disabled`, document why
3. **Temporary only**: Use `disabled` temporarily, return to `high`
4. **Never in CI**: CI must always use `high`
5. **Verify downloads**: Users should always verify PGP signatures

## Next Steps

- [Security Model](security-model.md) - Threat analysis
- [Building Kernels](../development/building-kernels.md) - Build process
- [Development Mode](../user-guide/local-workflow/development-mode.md) - Using disabled verification
