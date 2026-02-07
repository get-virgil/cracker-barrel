# Development Mode

Modify kernel source code and rebuild with your changes using disabled verification mode.

## Overview

Development mode allows you to:

- Modify kernel source code freely
- Rebuild without re-downloading sources
- Experiment with kernel configurations
- Test patches before submission

This uses `verification-level=disabled` to preserve source trees between builds.

## Quick Start

```bash
# Build with disabled verification (keeps sources)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Modify source code
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild with your modifications
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

## How It Works

### Normal Build (`high` or `medium`)

With verification enabled:

1. Deletes `build/linux-*.tar.xz` (cached tarball)
2. Deletes `build/linux-*/` (extracted sources)
3. Downloads fresh tarball
4. Verifies sources (PGP + SHA256)
5. Extracts sources
6. Builds kernel

**Result**: Clean slate every build (security)

### Development Build (`disabled`)

With verification disabled:

1. Keeps `build/linux-*.tar.xz` (if present)
2. Keeps `build/linux-*/` (if present)
3. Uses cached sources
4. **Skips verification**
5. Builds kernel

**Result**: Preserves your modifications

## Workflow

### 1. Initial Build

```bash
# Build first time (downloads and extracts sources)
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

This creates:
```
build/
├── linux-6.1.tar.xz          # Cached tarball
└── linux-6.1/                # Extracted sources
    ├── drivers/
    ├── fs/
    ├── kernel/
    └── ...
```

### 2. Modify Sources

```bash
# Edit any source file
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Or apply a patch
cd build/linux-6.1
patch -p1 < ../../my-patch.patch
cd ../..
```

### 3. Rebuild

```bash
# Rebuild with your changes
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

The build system:
- Detects existing source tree
- Skips download/extraction
- Rebuilds with your modifications
- Outputs to `artifacts/`

### 4. Test

```bash
# Test your modified kernel
task firecracker:test-kernel KERNEL_VERSION=6.1
```

## Configuration Changes

### Modify Kernel Config

```bash
# Build once to get sources
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Navigate to source directory
cd build/linux-6.1

# Use menuconfig to modify configuration
make menuconfig

# Build with new config
cd ../..
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

### Use Custom Config

```bash
# Copy custom config
cp my-custom.config build/linux-6.1/.config

# Build with custom config
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

## Patch Development

### Creating Patches

```bash
# Make changes in source tree
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Create patch
cd build/linux-6.1
git diff > ../../my-changes.patch
cd ../..
```

### Applying Patches

```bash
# Apply patch to source tree
cd build/linux-6.1
patch -p1 < ../../my-patch.patch
cd ../..

# Rebuild
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

## Clean Slate

To start over with fresh sources:

```bash
# Remove source tree and cache
rm -rf build/linux-6.1*

# Next build will download fresh
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

## Security Considerations

**⚠️ Development mode disables all verification:**

- ❌ No PGP signature verification
- ❌ No SHA256 checksum verification
- ❌ Sources could be tampered with

**Only use development mode for:**
- Local experimentation
- Testing patches
- Kernel development
- Learning

**Never use development mode for:**
- Production kernels
- Distribution to others
- Published releases
- Security-critical systems

## Best Practices

### 1. Isolate Development Builds

Keep development builds separate from production:

```bash
# Development
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Production
./scripts/kernel/build-kernel.sh --kernel 6.1  # Uses 'high' by default
```

### 2. Document Changes

Track what you modified:

```bash
# Create a CHANGES file
echo "Modified virtio_ring.c to increase queue size" > build/linux-6.1/CHANGES
```

### 3. Test Thoroughly

Modified kernels may behave unexpectedly:

```bash
# Test boot
task firecracker:test-kernel KERNEL_VERSION=6.1

# Test specific functionality
# (your custom tests)
```

### 4. Return to Verified Builds

When done developing, rebuild with verification:

```bash
# Clean development build
rm -rf build/linux-6.1*

# Build verified version
task kernel:build KERNEL_VERSION=6.1
```

## Examples

### Example 1: Increase VirtIO Queue Size

```bash
# Build with disabled verification
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Modify queue size
vim build/linux-6.1/drivers/virtio/virtio_ring.c
# (change VRING_SIZE or similar)

# Rebuild
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Test
task firecracker:test-kernel KERNEL_VERSION=6.1
```

### Example 2: Enable Debug Symbols

```bash
# Build with disabled verification
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Enable debug config
cd build/linux-6.1
make menuconfig
# Navigate to: Kernel hacking -> Compile-time checks and compiler options
# Enable: Compile the kernel with debug info
cd ../..

# Rebuild
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

### Example 3: Test Upstream Patch

```bash
# Build sources
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Apply patch from mailing list
cd build/linux-6.1
wget https://lore.kernel.org/path/to/patch.patch
patch -p1 < patch.patch
cd ../..

# Rebuild and test
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
task firecracker:test-kernel KERNEL_VERSION=6.1
```

## Next Steps

- [Cross-Compilation](cross-compilation.md) - Build for different architectures
- [Testing](../../development/testing.md) - Advanced testing techniques
- [Kernel Configuration](../../reference/kernel-config.md) - Understanding the config
