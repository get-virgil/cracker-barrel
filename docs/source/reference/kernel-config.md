# Kernel Configuration

Firecracker-optimized Linux kernel configuration details.

## Overview

Kernel configurations are based on Firecracker's official microvm-kernel configs, optimized for minimal, fast-booting kernels in AWS Firecracker microVMs.

**Source**: [Firecracker guest configs](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs)

**Base Version**: 6.1 configs, updated via `make olddefconfig` for newer kernels

## Configuration Files

- `configs/microvm-kernel-x86_64.config` - x86_64 configuration
- `configs/microvm-kernel-aarch64.config` - aarch64 configuration

Automatically selected based on target architecture.

## Key Features

### Virtualization & Guest Support

- KVM guest support with paravirtualization
- PVH boot protocol support
- Hypervisor guest detection
- Optimized for microVM environments

### Essential Drivers

**VirtIO Devices**:
- VirtIO block device (storage)
- VirtIO network (networking)
- VirtIO console (serial/console)
- VirtIO balloon (memory management)
- VirtIO RNG (random number generation)

**Other Devices**:
- Serial 8250 console
- Virtual RNG device

### Security Features

- **SECCOMP**: System call filtering
- **SELinux**: Mandatory access control
- **Page table isolation**: Meltdown mitigation
- **Retpoline**: Spectre mitigation
- **Stack protector**: Buffer overflow protection

### Storage & Filesystem

- **ext4**: Primary filesystem
- **squashfs**: Compressed read-only filesystem
- **NFS client**: Network filesystem support
- **iSCSI**: Block storage protocol
- **Loop device**: Loopback block device

### Performance Optimizations

- **SMP support**: Up to 64 CPUs
- **Transparent huge pages**: Memory optimization
- **I/O throttling and budgeting**: QoS controls
- **Server-optimized preemption**: Throughput-focused scheduling

## Minimal Configuration Philosophy

Firecracker configs are **minimal** by design:

- ✅ Includes only what's needed for microVMs
- ❌ Excludes hardware drivers (USB, GPU, sound, etc.)
- ❌ Excludes desktop features
- ❌ Excludes unnecessary filesystems

**Result**: Fast boot times, small kernel size, reduced attack surface

## Configuration Updates

When building for newer kernels:

1. Start with base 6.1 config
2. Run `make olddefconfig`
3. Applies new defaults for new options
4. Preserves existing choices

This ensures compatibility across kernel versions.

## Viewing Configuration

```bash
# View x86_64 config
cat configs/microvm-kernel-x86_64.config

# View aarch64 config
cat configs/microvm-kernel-aarch64.config

# After building, view actual config used
cat artifacts/config-6.18.9-x86_64
```

## Customizing Configuration

### Using menuconfig

```bash
# Build with disabled verification (keeps sources)
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Navigate to source
cd build/linux-6.1

# Use menuconfig
make menuconfig

# Navigate menu, make changes, save

# Rebuild
cd ../..
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

### Applying Custom Config

```bash
# Copy custom config
cp my-custom.config build/linux-6.1/.config

# Build
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled
```

### Saving Custom Config

```bash
# After customization
cp build/linux-6.1/.config my-custom.config

# Or save to configs/
cp build/linux-6.1/.config configs/microvm-kernel-custom-x86_64.config
```

## Configuration Comparison

### vs. Default Kernel Config

**Default kernel config** (`make defconfig`):
- General-purpose configuration
- Includes hardware drivers
- Larger kernel size
- Slower boot times

**Firecracker microvm config**:
- microVM-specific
- Minimal hardware support
- Smaller kernel size
- Fast boot times (< 1 second)

### vs. Cloud Init Config

**Cloud init configs**: Designed for traditional cloud VMs

**Firecracker configs**: Optimized for lightweight microVMs

Key differences:
- No initramfs required
- Direct kernel boot
- Minimal overhead

## Important Config Options

### Required for Firecracker

These options are essential:

```
CONFIG_VIRTIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
```

Without these, Firecracker VMs won't boot or function properly.

### Security-Critical

These options provide security features:

```
CONFIG_SECCOMP=y
CONFIG_SECURITY=y
CONFIG_PAGE_TABLE_ISOLATION=y
CONFIG_RETPOLINE=y
CONFIG_STACKPROTECTOR=y
```

Disabling these reduces security.

### Performance-Related

These affect performance:

```
CONFIG_SMP=y
CONFIG_NR_CPUS=64
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_BLK_CGROUP=y
```

## Architecture Differences

### x86_64 Specific

```
CONFIG_X86_64=y
CONFIG_HYPERVISOR_GUEST=y
CONFIG_PARAVIRT=y
CONFIG_KVM_GUEST=y
```

### aarch64 Specific

```
CONFIG_ARM64=y
CONFIG_ARCH_VIRT=y
CONFIG_VIRTUALIZATION=y
```

## Testing Configuration Changes

After modifying configuration:

```bash
# Build with custom config
task kernel:build VERIFICATION_LEVEL=disabled

# Test boot
task firecracker:test-kernel

# If boot succeeds, configuration is likely valid
```

## Configuration Maintenance

### Updating for New Kernels

When new kernel versions are released:

1. Base configs usually work with newer kernels
2. `make olddefconfig` applies new defaults
3. Test boot with Firecracker
4. Update configs/ if needed

### Tracking Changes

Configuration changes are tracked in git:

```bash
# View config history
git log -- configs/

# View specific changes
git diff HEAD~1 configs/microvm-kernel-x86_64.config
```

## Next Steps

- [Building Kernels](../development/building-kernels.md) - Build with configs
- [Development Mode](../user-guide/local-workflow/development-mode.md) - Customize configs
- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker) - Learn about Firecracker
