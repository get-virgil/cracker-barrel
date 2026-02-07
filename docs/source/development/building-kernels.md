# Building Kernels

Build Firecracker-compatible kernels from source with cryptographic verification.

## Quick Start

```bash
# Build latest stable kernel
task kernel:build

# Build specific version
task kernel:build KERNEL_VERSION=6.1
```

## Build Process

The `build-kernel.sh` script (wrapped by Task) performs these steps:

1. **Version Detection**: Fetch latest stable from kernel.org (or use specified version)
2. **Cache Check**: Skip if kernel already built
3. **Source Cleanup**: Delete cached sources (when verification enabled)
4. **Download**: Fetch kernel source tarball from kernel.org
5. **Verification**: Verify PGP signature + SHA256 checksum
6. **Extraction**: Extract source only after verification passes
7. **Configuration**: Apply Firecracker-compatible config
8. **Compilation**: Build the kernel
9. **Compression**: Compress with xz
10. **Checksums**: Generate SHA256 checksums
11. **Output**: Place artifacts in `artifacts/` directory

## Using Task

### Basic Builds

```bash
# Build latest stable kernel (auto-detect architecture)
task kernel:build

# Build specific version
task kernel:build KERNEL_VERSION=6.1

# Build for specific architecture
task kernel:build ARCH=x86_64
task kernel:build ARCH=aarch64
```

### With Verification Levels

```bash
# High verification (default): PGP + SHA256
task kernel:build

# Medium verification: SHA256 only
task kernel:build VERIFICATION_LEVEL=medium

# Disabled verification: No verification (development only)
task kernel:build VERIFICATION_LEVEL=disabled
```

### Combined Options

```bash
# Build specific version for ARM64 with medium verification
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64 VERIFICATION_LEVEL=medium
```

## Using Scripts Directly

For more control, use the script directly:

```bash
# Basic build
./scripts/kernel/build-kernel.sh

# With options
./scripts/kernel/build-kernel.sh \
    --kernel 6.1 \
    --arch x86_64 \
    --verification-level high
```

### Script Options

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to build | Latest stable |
| `--arch ARCH` | Target architecture (x86_64, aarch64) | Host arch |
| `--verification-level LEVEL` | high/medium/disabled | high |

## Verification Levels

### `high` (Default - Strongest Security)

```bash
task kernel:build
```

- ✅ Verifies PGP signature on `sha256sums.asc`
- ✅ Verifies SHA256 checksum of kernel tarball
- **Protects against**: CDN poisoning, MITM attacks, tampering, corrupted downloads
- **Requires**: GPG installed, internet access to keyservers
- **Use when**: Building for production, distribution, or any trusted use

### `medium` (SHA256 Only)

```bash
task kernel:build VERIFICATION_LEVEL=medium
```

- ⚠️ Skips PGP signature verification
- ✅ Verifies SHA256 checksum only
- **Protects against**: Corrupted downloads, accidental tampering
- **Trusts**: HTTPS connection to kernel.org for checksums file integrity
- **Use when**: Systems without GPG, or acceptable risk for local testing

### `disabled` (No Verification - Emergency Only)

```bash
task kernel:build VERIFICATION_LEVEL=disabled
```

- ❌ No verification whatsoever
- **Protects against**: Nothing
- **Use when**: Kernel just released and kernel.org hasn't updated checksums yet
- **WARNING**: Only use temporarily when you understand and accept the security risks

See [Reference > Verification Levels](../reference/verification-levels.md) for detailed security analysis.

## Source Cache Behavior

### With Verification Enabled (`high` or `medium`)

The build system **deletes cached sources** for security:

```bash
# These directories are deleted before each build
build/linux-*.tar.xz      # Cached tarball
build/linux-*/            # Extracted sources
```

This ensures:
- Fresh sources every build
- No risk of tampered cached sources
- Cryptographic verification always happens

### With Verification Disabled (`disabled`)

The build system **preserves cached sources**:

```bash
# These directories are kept between builds
build/linux-*.tar.xz      # Cached tarball (reused)
build/linux-*/            # Extracted sources (preserved)
```

This enables:
- Kernel source modifications
- Faster rebuilds
- Development workflow

See [User Guide > Development Mode](../user-guide/local-workflow/development-mode.md) for details.

## Build Output

After building, artifacts are placed in `artifacts/`:

```
artifacts/
├── vmlinux-6.1-x86_64         # x86_64 kernel (uncompressed)
├── vmlinux-6.1-x86_64.xz      # x86_64 kernel (compressed)
├── config-6.1-x86_64          # x86_64 configuration
├── Image-6.1-aarch64          # ARM64 kernel (uncompressed)
├── Image-6.1-aarch64.xz       # ARM64 kernel (compressed)
└── config-6.1-aarch64         # ARM64 configuration
```

**Note**: x86_64 uses `vmlinux-*`, ARM64 uses `Image-*`.

## Build Time

Approximate build times:

- **x86_64 kernel**: 15-30 minutes (4-8 cores)
- **aarch64 kernel**: 15-30 minutes (4-8 cores)
- **Both architectures**: 15-30 minutes (parallel build)

## Incremental Builds

The build system is idempotent:

```bash
# First build: Downloads and builds
task kernel:build KERNEL_VERSION=6.1

# Second build: Skips (already exists)
task kernel:build KERNEL_VERSION=6.1
# Output: "Kernel 6.1 already built, skipping"
```

To force rebuild:

```bash
# Remove existing kernel
rm artifacts/vmlinux-6.1-x86_64*

# Rebuild
task kernel:build KERNEL_VERSION=6.1
```

## Multi-Architecture Builds

Build for both architectures sequentially:

```bash
# Build x86_64
task kernel:build KERNEL_VERSION=6.1 ARCH=x86_64

# Build aarch64
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64
```

Or with a loop:

```bash
for ARCH in x86_64 aarch64; do
    task kernel:build KERNEL_VERSION=6.1 ARCH=$ARCH
done
```

See [User Guide > Cross-Compilation](../user-guide/local-workflow/cross-compilation.md) for cross-compilation setup.

## Build Failures

If build fails, check:

1. **Dependencies installed**: `task dev:install-deps`
2. **Sufficient disk space**: `df -h` (~10GB needed)
3. **Kernel version valid**: Check [kernel.org](https://kernel.org)
4. **Configuration compatible**: Try different kernel version

See [Troubleshooting](../user-guide/troubleshooting.md) for detailed solutions.

## Configuration

Kernel configurations are based on Firecracker's official microvm-kernel configs:

- `configs/microvm-kernel-x86_64.config` - x86_64
- `configs/microvm-kernel-aarch64.config` - aarch64

Configs are automatically applied during build. See [Reference > Kernel Configuration](../reference/kernel-config.md) for details.

## Development Builds

For kernel development with source modifications:

```bash
# Build with disabled verification (keeps sources)
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Modify sources
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

See [User Guide > Development Mode](../user-guide/local-workflow/development-mode.md) for complete development workflow.

## Next Steps

- [Testing](testing.md) - Test your built kernel
- [Verification Levels](../reference/verification-levels.md) - Security analysis
- [Development Mode](../user-guide/local-workflow/development-mode.md) - Modify kernel sources
- [Cross-Compilation](../user-guide/local-workflow/cross-compilation.md) - Build for different architectures
