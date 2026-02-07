# Using with Firecracker

Once you have a kernel (downloaded or built), you can use it with AWS Firecracker microVMs.

## Quick Start

```bash
# Download the kernel for your architecture
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz

# Decompress
xz -d vmlinux-VERSION-x86_64.xz

# Verify integrity
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing

# Use with Firecracker
firecracker --kernel-path vmlinux-VERSION-x86_64 ...
```

Replace `VERSION` with your kernel version (e.g., `6.18.9`).

## Testing Locally

Cracker Barrel includes a test script to validate kernels boot correctly:

```bash
# Test latest stable kernel with latest Firecracker
./scripts/firecracker/test-kernel.sh

# Test specific kernel version
./scripts/firecracker/test-kernel.sh --kernel 6.1

# Test with specific Firecracker version
./scripts/firecracker/test-kernel.sh --kernel 6.10 --firecracker v1.10.0
```

**Using Task:**

```bash
task firecracker:test-kernel
task firecracker:test-kernel KERNEL_VERSION=6.1
```

### What the Test Does

The test script:
1. Auto-detects your architecture (x86_64 or aarch64)
2. Builds the kernel if not found
3. Downloads Firecracker binary
4. Creates a minimal test rootfs
5. Boots the kernel in a Firecracker VM
6. Verifies clean shutdown within 60 seconds

**Requirements**: KVM support (`/dev/kvm` must be accessible)

### Why Not in CI?

GitHub Actions runners do not have KVM/nested virtualization support, so Firecracker boot tests cannot run in CI. All kernels are built and compressed in CI, but boot testing must be done locally or on infrastructure with KVM access.

## Kernel Configuration

All kernels are built with Firecracker-optimized configurations including:

### Virtualization & Guest Support
- KVM guest support with paravirtualization
- PVH boot protocol support
- Hypervisor guest detection

### Essential Drivers
- VirtIO block device (storage)
- VirtIO network (networking)
- VirtIO console (serial/console)
- VirtIO balloon (memory management)
- Serial 8250 console
- Virtual RNG device

### Security Features
- SECCOMP (system call filtering)
- SELinux (mandatory access control)
- Page table isolation (Meltdown mitigation)
- Retpoline (Spectre mitigation)
- Stack protector

### Storage & Filesystem
- ext4 filesystem
- squashfs (compressed read-only)
- NFS client
- iSCSI support
- Loop device support

### Performance Optimizations
- SMP support (up to 64 CPUs)
- Transparent huge pages
- I/O throttling and budgeting
- Server-optimized preemption

See [Reference > Kernel Configuration](../reference/kernel-config.md) for complete details.

## Architecture Support

Cracker Barrel builds kernels for:

- **x86_64**: Intel/AMD 64-bit processors
- **aarch64**: ARM 64-bit processors (AWS Graviton, etc.)

Each release includes binaries for both architectures.

## Next Steps

- [Kernel Configuration Details](../reference/kernel-config.md) - Full config breakdown
- [Testing Guide](../development/testing.md) - Advanced testing scenarios
- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker) - Official Firecracker docs
