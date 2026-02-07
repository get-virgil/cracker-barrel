# Script Usage

Use Cracker Barrel's scripts directly without Task. This gives you full control and flexibility.

## Kernel Scripts

The project provides two separate scripts for different workflows.

### Download Pre-Built Kernels

The `download-kernel.sh` script downloads pre-built kernels from GitHub releases:

```bash
# Download latest stable kernel
./scripts/kernel/download-kernel.sh

# Download specific kernel version
./scripts/kernel/download-kernel.sh --kernel 6.1

# Download for specific architecture
./scripts/kernel/download-kernel.sh --kernel 6.1 --arch aarch64
```

**What it does:**
1. Fetch the latest stable version from kernel.org (or use provided version)
2. Check if kernel already exists locally (skip if present)
3. Download compressed kernel from GitHub releases
4. Verify checksum of downloaded kernel
5. Decompress kernel
6. **Fails if release not available** (no build fallback)

### Build from Source

The `build-kernel.sh` script builds kernels from source:

```bash
# Build latest stable kernel
./scripts/kernel/build-kernel.sh

# Build specific kernel version
./scripts/kernel/build-kernel.sh --kernel 6.1

# Build for specific architecture
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch aarch64

# Medium verification (SHA256 only, no PGP)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level medium

# Disabled verification (emergency only)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

**What it does:**
1. Fetch the latest stable version from kernel.org (or use provided version)
2. Check if kernel already built locally (skip if present)
3. **Delete cached sources when verification enabled** (security: fresh sources)
   - `high` or `medium`: Deletes `build/linux-*.tar.xz` and `build/linux-*/`
   - `disabled`: Keeps cache (allows source modifications for development)
4. Download kernel source tarball
5. **Verify source based on `--verification-level`:**
   - `high` (default): PGP signature + SHA256 checksum
   - `medium`: SHA256 checksum only
   - `disabled`: Skip all verification
6. Extract kernel source only after verification passes
7. Apply Firecracker-compatible configuration
8. Build the kernel
9. Compress with xz
10. Generate SHA256 checksums
11. Place artifacts in `artifacts/` directory

## Testing Scripts

### Test Kernel with Firecracker

```bash
# Test latest stable kernel with latest Firecracker
./scripts/firecracker/test-kernel.sh

# Test specific kernel version
./scripts/firecracker/test-kernel.sh --kernel 6.1

# Test with specific Firecracker version
./scripts/firecracker/test-kernel.sh --kernel 6.10 --firecracker v1.10.0
```

**What it does:**
1. Auto-detect your architecture (x86_64 or aarch64)
2. Build the kernel if not found
3. Download Firecracker binary
4. Create a minimal test rootfs
5. Boot the kernel in a Firecracker VM
6. Verify clean shutdown within 60 seconds

**Requirements**: KVM support (`/dev/kvm` must be accessible)

### Create Test Rootfs

```bash
# Create minimal test rootfs
./scripts/firecracker/create-test-rootfs.sh
```

Creates a minimal ext4 rootfs with an init script for testing.

## Signing Scripts

### Sign Artifacts

```bash
# Sign artifacts with PGP
./scripts/signing/sign-artifacts.sh
```

Requires `SIGNING_KEY` environment variable with the private key.

### Verify Artifacts

```bash
# Verify PGP signatures
./scripts/signing/verify-artifacts.sh
```

### Generate Signing Key

```bash
# Generate new signing key
./scripts/signing/generate-signing-key.sh
```

### Rotate Signing Key

```bash
# Rotate signing key (backup old, generate new)
./scripts/signing/rotate-signing-key.sh
```

### Check Key Expiry

```bash
# Check key expiration
./scripts/signing/check-key-expiry.sh
```

### Remove Signing Key

```bash
# Remove signing key from local GPG
./scripts/signing/remove-signing-key.sh
```

## Script Options Summary

### build-kernel.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to build | Latest stable |
| `--arch ARCH` | Target architecture | Host arch |
| `--verification-level LEVEL` | high/medium/disabled | high |

### download-kernel.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to download | Latest stable |
| `--arch ARCH` | Target architecture | Host arch |

### test-kernel.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to test | Latest stable |
| `--firecracker VERSION` | Firecracker version to use | Latest |

## Examples

### Full Local Build Workflow

```bash
# Build kernel
./scripts/kernel/build-kernel.sh --kernel 6.1

# Test it
./scripts/firecracker/test-kernel.sh --kernel 6.1

# Sign it (if you have a signing key)
export SIGNING_KEY="$(cat keys/signing-key-private.asc)"
./scripts/signing/sign-artifacts.sh

# Verify signature
./scripts/signing/verify-artifacts.sh
```

### Development Workflow

```bash
# Build with disabled verification (keeps sources)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Modify source code
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild with your modifications
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

### Cross-Compilation

```bash
# Build ARM64 kernel on x86_64 host
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch aarch64

# Note: Requires cross-compilation tools installed
# sudo apt-get install gcc-aarch64-linux-gnu
```

## Environment Variables

Scripts respect these environment variables:

| Variable | Description | Scripts |
|----------|-------------|---------|
| `SIGNING_KEY` | Private PGP signing key | sign-artifacts.sh |
| `KERNEL_ORG_URL` | kernel.org base URL | build-kernel.sh |
| `GITHUB_TOKEN` | GitHub API token for rate limits | download-kernel.sh |

## Exit Codes

All scripts follow standard Unix exit codes:

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Verification failed
- `4`: Build failed

## Next Steps

- [Task Commands](task-commands.md) - Using Task for convenience
- [Development Mode](development-mode.md) - Modifying kernel sources
- [Local Archive](local-archive.md) - Signed artifact archive
