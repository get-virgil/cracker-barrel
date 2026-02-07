# Cross-Compilation

Build kernels for different architectures than your host machine.

## Supported Architectures

Cracker Barrel supports:

- **x86_64**: Intel/AMD 64-bit processors
- **aarch64**: ARM 64-bit processors (AWS Graviton, Raspberry Pi, etc.)

## Quick Start

### On x86_64 Host → Build ARM64

```bash
# Install cross-compilation tools
task dev:install-arm-tools

# Build ARM64 kernel
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64
```

### On ARM64 Host → Build x86_64

```bash
# Install cross-compilation tools
task dev:install-x86-tools

# Build x86_64 kernel
task kernel:build KERNEL_VERSION=6.1 ARCH=x86_64
```

## Installing Cross-Compilation Tools

### Ubuntu/Debian

#### For ARM64 on x86_64

```bash
# Using Task
task dev:install-arm-tools

# Or manually
sudo apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu
```

#### For x86_64 on ARM64

```bash
# Using Task
task dev:install-x86-tools

# Or manually
sudo apt-get install -y \
    gcc-x86-64-linux-gnu \
    g++-x86-64-linux-gnu \
    binutils-x86-64-linux-gnu
```

### Arch Linux

```bash
# For ARM64 on x86_64
sudo pacman -S aarch64-linux-gnu-gcc

# For x86_64 on ARM64
sudo pacman -S x86_64-linux-gnu-gcc
```

## Building for Different Architectures

### Using Task

```bash
# Auto-detect host architecture (default)
task kernel:build

# Explicitly specify target architecture
task kernel:build ARCH=x86_64
task kernel:build ARCH=aarch64

# Specific version for specific architecture
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64
```

### Using Scripts

```bash
# Build for x86_64
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch x86_64

# Build for ARM64
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch aarch64
```

## Build Output

Cross-compiled kernels are placed in `artifacts/` with architecture-specific names:

```
artifacts/
├── vmlinux-6.1-x86_64         # x86_64 kernel
├── vmlinux-6.1-x86_64.xz      # x86_64 compressed
├── config-6.1-x86_64          # x86_64 config
├── Image-6.1-aarch64          # ARM64 kernel
├── Image-6.1-aarch64.xz       # ARM64 compressed
└── config-6.1-aarch64         # ARM64 config
```

**Note the different naming:**
- x86_64: `vmlinux-*`
- aarch64: `Image-*`

## Configuration Differences

Each architecture uses its own Firecracker-optimized configuration:

- `configs/microvm-kernel-x86_64.config` - x86_64 configuration
- `configs/microvm-kernel-aarch64.config` - ARM64 configuration

These configs are architecture-specific and automatically selected based on `--arch`.

## Testing Cross-Compiled Kernels

### On Host Architecture

You can only test kernels for your host architecture:

```bash
# On x86_64 host
task firecracker:test-kernel KERNEL_VERSION=6.1 ARCH=x86_64  # ✅ Works

# On x86_64 host
task firecracker:test-kernel KERNEL_VERSION=6.1 ARCH=aarch64  # ❌ Fails (wrong arch)
```

### On Target Architecture

Transfer the kernel to target architecture for testing:

```bash
# Build on x86_64 host
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64

# Copy to ARM64 machine
scp artifacts/Image-6.1-aarch64.xz user@arm-machine:

# Test on ARM64 machine
ssh user@arm-machine
xz -d Image-6.1-aarch64.xz
./scripts/firecracker/test-kernel.sh --kernel 6.1
```

## Build Matrix (Both Architectures)

Build for both architectures in one command:

```bash
# Build x86_64
task kernel:build KERNEL_VERSION=6.1 ARCH=x86_64

# Build aarch64
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64
```

Or with a shell script:

```bash
#!/bin/bash
KERNEL_VERSION=6.1

for ARCH in x86_64 aarch64; do
    task kernel:build KERNEL_VERSION=$KERNEL_VERSION ARCH=$ARCH
done
```

This is exactly how CI builds both architectures in parallel.

## Verification Across Architectures

Kernel source verification is architecture-independent:

```bash
# Same source tarball for all architectures
# Verification happens once, builds for each arch

task kernel:build KERNEL_VERSION=6.1 ARCH=x86_64  # Verifies sources
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64  # Uses verified sources
```

## Common Issues

### Missing Cross-Compiler

**Error**: `aarch64-linux-gnu-gcc: command not found`

**Solution**: Install cross-compilation tools:
```bash
task dev:install-arm-tools  # For ARM64
task dev:install-x86-tools  # For x86_64
```

### Wrong Architecture Kernel

**Error**: Kernel won't boot or Firecracker rejects it

**Solution**: Ensure you built for correct architecture:
```bash
# Check kernel file name
ls artifacts/

# x86_64 should be: vmlinux-*-x86_64
# aarch64 should be: Image-*-aarch64
```

### Config Mismatch

**Error**: Build fails with config errors

**Solution**: Architecture-specific configs are auto-selected. Don't manually copy configs between architectures.

## CI Cross-Compilation

GitHub Actions builds both architectures in parallel:

```yaml
strategy:
  matrix:
    arch: [x86_64, aarch64]

steps:
  - name: Build kernel
    run: task kernel:build KERNEL_VERSION=6.1 ARCH=${{ matrix.arch }}
```

Both builds run simultaneously, completing in ~30-45 minutes total.

## Next Steps

- [Development Mode](development-mode.md) - Modify kernel sources
- [Testing](../../development/testing.md) - Advanced testing techniques
- [CI Workflow](../../maintainer-guide/ci-workflow.md) - How CI builds both architectures
