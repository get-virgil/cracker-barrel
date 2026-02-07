# Building Locally

Build Firecracker-compatible kernels from source on your local machine. This gives you full control and enables offline workflows.

## Prerequisites

Before building, you'll need:

1. **Task Runner**: The project uses [Task](https://taskfile.dev) for unified local/CI workflows
2. **Build Dependencies**: Kernel compilation tools (gcc, make, etc.)

See [Development > Prerequisites](../development/prerequisites.md) for detailed installation instructions.

## Quick Start with Task

If you have Task installed:

```bash
# Install dependencies
task dev:install-deps

# Get latest kernel (smart: download or build)
task kernel:get

# Test kernel in Firecracker VM
task firecracker:test-kernel

# See all available tasks
task --list
```

## Build Methods

### Smart Get (Recommended)

Tries to download first, builds if unavailable:

```bash
# Get latest stable kernel
task kernel:get

# Get specific version
task kernel:get KERNEL_VERSION=6.1
```

### Download Only

Download pre-built kernels from GitHub releases:

```bash
# Download latest stable
task kernel:download

# Download specific version
task kernel:download KERNEL_VERSION=6.1
```

**Note:** Fails if the release doesn't exist (no build fallback).

### Build from Source

Always builds from source with fresh verification:

```bash
# Build latest stable kernel
task kernel:build

# Build specific version for ARM64
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64

# Build with disabled verification (for development)
task kernel:build VERIFICATION_LEVEL=disabled
```

## Verification Levels

Kernel builds support three security levels:

- **`high` (default)**: PGP signature + SHA256 checksum verification
- **`medium`**: SHA256 checksum only (no PGP)
- **`disabled`**: No verification (emergency/development only)

```bash
# Medium verification (no GPG required)
task kernel:build VERIFICATION_LEVEL=medium

# Disabled (allows source modifications)
task kernel:build VERIFICATION_LEVEL=disabled
```

See [Reference > Verification Levels](../reference/verification-levels.md) for detailed security implications.

## Development Workflow

When modifying kernel source code:

```bash
# Build with disabled verification (keeps sources)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Modify source code
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild with your modifications
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

With `disabled` verification, the build system:
- Keeps cached source tarballs
- Doesn't delete the extracted source tree
- Allows rebuilding with modifications

See [User Guide > Local Workflow > Development Mode](../user-guide/local-workflow/development-mode.md) for more details.

## Direct Script Usage

You can also use the shell scripts directly:

```bash
# Download pre-built kernel
./scripts/kernel/download-kernel.sh --kernel 6.1

# Build from source
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch x86_64

# Build for ARM64
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch aarch64
```

Task is recommended as it provides convenient shortcuts, but the scripts work independently.

## Local-First Philosophy

Task commands are **exactly** what runs in CI:

- **Local**: `task dev:install-deps` → `task kernel:build`
- **CI**: `task dev:install-deps` → `task kernel:build`

This ensures:
- ✅ CI behavior is reproducible locally
- ✅ Testing locally = testing CI
- ✅ No CI-specific scripts to maintain
- ✅ Easy to debug CI failures

## Next Steps

- [Prerequisites](../development/prerequisites.md) - Install Task and dependencies
- [Building Kernels](../development/building-kernels.md) - Detailed build process
- [Local Workflow Guide](../user-guide/local-workflow/index.md) - Advanced local operations
- [Testing](../development/testing.md) - Test kernels with Firecracker
