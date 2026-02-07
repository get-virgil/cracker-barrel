# Downloading Kernels

Download pre-built kernels from GitHub releases using the download script.

## Quick Start

```bash
# Download latest stable kernel
task kernel:download

# Download specific version
task kernel:download KERNEL_VERSION=6.1
```

## Download Process

The `download-kernel.sh` script performs these steps:

1. **Version Detection**: Fetch latest stable from kernel.org (or use specified version)
2. **Cache Check**: Skip if kernel already exists locally
3. **Release Check**: Verify release exists on GitHub
4. **Download**: Fetch compressed kernel from GitHub releases
5. **Checksum Verification**: Verify SHA256 checksum
6. **Decompression**: Decompress kernel
7. **Output**: Place kernel in `artifacts/` directory

**Important**: Fails if release doesn't exist (no build fallback).

## Using Task

### Basic Downloads

```bash
# Download latest stable kernel (auto-detect architecture)
task kernel:download

# Download specific version
task kernel:download KERNEL_VERSION=6.1

# Download for specific architecture
task kernel:download ARCH=x86_64
task kernel:download ARCH=aarch64
```

### Combined Options

```bash
# Download specific version for ARM64
task kernel:download KERNEL_VERSION=6.1 ARCH=aarch64
```

## Using Scripts Directly

```bash
# Basic download
./scripts/kernel/download-kernel.sh

# With options
./scripts/kernel/download-kernel.sh \
    --kernel 6.1 \
    --arch x86_64
```

### Script Options

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to download | Latest stable |
| `--arch ARCH` | Target architecture (x86_64, aarch64) | Host arch |

## Download vs Build

Two strategies for getting kernels:

### Download (`kernel:download`)

- ✅ Fast (no compilation)
- ✅ Pre-verified by CI
- ❌ Requires internet
- ❌ Fails if release doesn't exist

**Best for**: Production use, quick testing, CI/CD

### Build (`kernel:build`)

- ❌ Slow (15-30 minutes)
- ✅ Works offline (after initial download)
- ✅ Enables source modifications
- ✅ Always available

**Best for**: Kernel development, custom configs, airgapped environments

### Smart Get (`kernel:get`)

Tries download first, builds if unavailable:

```bash
task kernel:get KERNEL_VERSION=6.1
```

This is the recommended default approach.

## What Gets Downloaded

For each kernel version and architecture:

```
artifacts/
├── vmlinux-6.1-x86_64.xz      # Compressed kernel (from GitHub)
├── config-6.1-x86_64           # Configuration (from GitHub)
└── SHA256SUMS                  # Checksums (from GitHub)
```

After decompression:

```
artifacts/
├── vmlinux-6.1-x86_64         # Uncompressed kernel
├── vmlinux-6.1-x86_64.xz      # Compressed kernel (kept)
├── config-6.1-x86_64           # Configuration
└── SHA256SUMS                  # Checksums
```

## Checksum Verification

The download script automatically verifies checksums:

```bash
# Download includes checksum verification
task kernel:download KERNEL_VERSION=6.1

# Manual verification
cd artifacts
sha256sum -c SHA256SUMS --ignore-missing
```

For full PGP verification:

```bash
# Download signature file
wget https://github.com/get-virgil/cracker-barrel/releases/download/v6.1/SHA256SUMS.asc

# Verify signature
gpg --verify SHA256SUMS.asc SHA256SUMS
```

See [Getting Started > Verification](../getting-started/verification.md) for complete verification process.

## Release Availability

Not all kernel versions have pre-built releases:

- **Daily builds**: Latest stable kernel built at 2 AM UTC
- **Community requests**: Specific versions requested via issues
- **Manual triggers**: Maintainer-triggered builds

To check if a release exists:

```bash
# Check releases page
open https://github.com/get-virgil/cracker-barrel/releases

# Or use gh CLI
gh release list --repo get-virgil/cracker-barrel
```

If release doesn't exist, either:

1. [Request a build](../user-guide/github-workflow/requesting-builds.md)
2. [Build locally](building-kernels.md)

## Download Failures

### Release Not Found

If download fails with 404:

```bash
# Check if release exists
gh release view v6.1 --repo get-virgil/cracker-barrel

# If not, request it or build locally
task kernel:build KERNEL_VERSION=6.1
```

### Checksum Mismatch

If checksum verification fails:

```bash
# Remove corrupted download
rm artifacts/vmlinux-6.1-x86_64.xz

# Try again
task kernel:download KERNEL_VERSION=6.1

# If still fails, might be GitHub issue - build locally
task kernel:build KERNEL_VERSION=6.1
```

### Rate Limiting

GitHub API rate limits may affect downloads:

```bash
# Set GitHub token (increases rate limit)
export GITHUB_TOKEN="your_token_here"
task kernel:download

# Or wait for rate limit reset (usually 1 hour)

# Or build locally
task kernel:build
```

## Multi-Architecture Downloads

Download for both architectures:

```bash
# Download x86_64
task kernel:download KERNEL_VERSION=6.1 ARCH=x86_64

# Download aarch64
task kernel:download KERNEL_VERSION=6.1 ARCH=aarch64
```

Or with a loop:

```bash
for ARCH in x86_64 aarch64; do
    task kernel:download KERNEL_VERSION=6.1 ARCH=$ARCH
done
```

## Incremental Downloads

The download system is idempotent:

```bash
# First download: Fetches from GitHub
task kernel:download KERNEL_VERSION=6.1

# Second download: Skips (already exists)
task kernel:download KERNEL_VERSION=6.1
# Output: "Kernel 6.1 already exists, skipping"
```

To force re-download:

```bash
# Remove existing kernel
rm artifacts/vmlinux-6.1-x86_64*

# Re-download
task kernel:download KERNEL_VERSION=6.1
```

## Offline Usage

After downloading once, you can work offline:

```bash
# Download kernels while online
task kernel:download KERNEL_VERSION=6.1
task kernel:download KERNEL_VERSION=6.6

# Later, offline, kernels are already available
ls artifacts/
# vmlinux-6.1-x86_64
# vmlinux-6.6-x86_64
```

For true offline workflow, use [Local Archive](../user-guide/local-workflow/local-archive.md).

## Next Steps

- [Testing](testing.md) - Test downloaded kernels
- [Verification](../getting-started/verification.md) - Full PGP verification
- [Building](building-kernels.md) - Build if download unavailable
- [GitHub Releases](../user-guide/github-workflow/automated-releases.md) - Understanding releases
