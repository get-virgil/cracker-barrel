# Task Commands

Cracker Barrel uses [Task](https://taskfile.dev) as a task runner for convenient, organized command execution.

## Task Namespaces

Tasks are organized into logical namespaces:

- `kernel:*` - Kernel operations (get, download, build)
- `firecracker:*` - Testing kernels with Firecracker
- `clean:*` - Cleaning artifacts
- `signing:*` - PGP key management and signing
- `release:*` - CI release artifact management
- `dev:*` - Development utilities

## Listing Tasks

```bash
# See all available tasks
task --list

# Get detailed info about a specific task
task --summary kernel:build
```

## Kernel Operations

### Get Kernel (Smart)

Tries download first, builds if unavailable:

```bash
# Get latest stable kernel
task kernel:get

# Get specific version
task kernel:get KERNEL_VERSION=6.1

# Get for specific architecture
task kernel:get KERNEL_VERSION=6.1 ARCH=aarch64
```

### Download Kernel

Download pre-built from GitHub releases:

```bash
# Download latest stable
task kernel:download

# Download specific version
task kernel:download KERNEL_VERSION=6.1

# Download for ARM64
task kernel:download KERNEL_VERSION=6.1 ARCH=aarch64
```

Fails if release doesn't exist (no build fallback).

### Build Kernel

Build from source with verification:

```bash
# Build latest stable kernel
task kernel:build

# Build specific version
task kernel:build KERNEL_VERSION=6.1

# Build for ARM64
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64

# Build with medium verification (SHA256 only)
task kernel:build VERIFICATION_LEVEL=medium

# Build with disabled verification (for development)
task kernel:build VERIFICATION_LEVEL=disabled
```

## Testing

```bash
# Test kernel in Firecracker VM
task firecracker:test-kernel

# Test specific kernel version
task firecracker:test-kernel KERNEL_VERSION=6.1

# Test with specific Firecracker version
task firecracker:test-kernel FIRECRACKER_VERSION=v1.10.0
```

## Cleanup

```bash
# Remove all build artifacts and caches (~10GB+)
task clean

# Remove only kernel artifacts (keep Firecracker and rootfs)
task clean:kernel

# Remove specific kernel version
task clean:kernel VERSION=6.1

# Remove cached Firecracker binaries
task clean:firecracker

# Remove test rootfs
task clean:rootfs

# List all cached artifacts
task dev:list-artifacts
```

## Development Utilities

```bash
# Install dependencies (Ubuntu/Debian)
task dev:install-deps

# Install dependencies (Arch Linux)
task dev:i-use-arch-btw

# Install ARM64 cross-compilation tools (on x86_64 host)
task dev:install-arm-tools

# Install x86_64 cross-compilation tools (on ARM64 host)
task dev:install-x86-tools

# List all cached artifacts
task dev:list-artifacts
```

## Signing Operations

```bash
# Generate new signing key
task signing:generate-signing-key

# Sign artifacts
task signing:sign-artifacts

# Verify signed artifacts
task signing:verify-artifacts

# Rotate signing key
task signing:rotate

# Check key expiry
task signing:check-expiry

# Remove signing key
task signing:remove
```

## Release Management (CI)

These tasks are primarily for CI, but can be used locally:

```bash
# Consolidate multi-arch build artifacts
task release:consolidate-artifacts
```

## Task Variables

Tasks accept variables via `KEY=value` syntax:

| Variable | Description | Default |
|----------|-------------|---------|
| `KERNEL_VERSION` | Kernel version to build/download | Latest stable |
| `ARCH` | Target architecture (x86_64, aarch64) | Host arch |
| `VERIFICATION_LEVEL` | Verification level (high, medium, disabled) | high |
| `FIRECRACKER_VERSION` | Firecracker version for testing | Latest |
| `VERSION` | Version for cleanup operations | N/A |

## Examples

### Build and Test Workflow

```bash
# Install dependencies
task dev:install-deps

# Build latest kernel
task kernel:build

# Test it
task firecracker:test-kernel

# Clean up when done
task clean
```

### Cross-Compilation

```bash
# On x86_64 host, build ARM64 kernel
task dev:install-arm-tools
task kernel:build ARCH=aarch64
```

### Development Mode

```bash
# Build with disabled verification (keeps sources)
task kernel:build VERIFICATION_LEVEL=disabled

# Modify sources
vim build/linux-*/drivers/virtio/virtio_ring.c

# Rebuild
task kernel:build VERIFICATION_LEVEL=disabled
```

## Task vs Scripts

Task is a wrapper around shell scripts:

- **Task**: Convenient, organized, remembers patterns
- **Scripts**: Direct, flexible, full control

Both approaches work. Task is recommended for common workflows.

```bash
# Using Task
task kernel:build KERNEL_VERSION=6.1

# Using scripts directly
./scripts/kernel/build-kernel.sh --kernel 6.1
```

## Next Steps

- [Script Usage](script-usage.md) - Using scripts directly
- [Local Archive](local-archive.md) - Offline signed kernel archive
- [Development Mode](development-mode.md) - Modifying kernel sources
