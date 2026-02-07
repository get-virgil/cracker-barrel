# Testing Kernels

Test kernels locally using Firecracker to verify they boot correctly.

## Quick Start

```bash
# Test latest stable kernel
task firecracker:test-kernel

# Test specific version
task firecracker:test-kernel KERNEL_VERSION=6.1
```

## Requirements

- **KVM support**: `/dev/kvm` must be accessible
- **Permissions**: User must be in `kvm` group or run with sudo

### Checking KVM Support

```bash
# Check if KVM device exists
ls -l /dev/kvm

# Check if KVM module loaded
lsmod | grep kvm

# Check permissions
groups | grep kvm
```

### Setting Up Permissions

```bash
# Add user to kvm group
sudo usermod -aG kvm $USER

# Logout and login for changes to take effect

# Verify
groups | grep kvm
```

## Test Process

The `test-kernel.sh` script performs these steps:

1. **Architecture Detection**: Auto-detect your system architecture
2. **Kernel Check**: Build kernel if not found
3. **Firecracker Download**: Download Firecracker binary if needed
4. **Rootfs Creation**: Create minimal test rootfs
5. **VM Configuration**: Configure Firecracker via REST API
6. **Boot**: Boot the kernel in Firecracker VM
7. **Verification**: Wait for clean shutdown (max 60 seconds)
8. **Result**: Success if VM boots and shuts down cleanly

## Using Task

### Basic Testing

```bash
# Test latest stable kernel
task firecracker:test-kernel

# Test specific kernel version
task firecracker:test-kernel KERNEL_VERSION=6.1

# Test with specific Firecracker version
task firecracker:test-kernel FIRECRACKER_VERSION=v1.10.0
```

### Combined Options

```bash
# Test specific kernel with specific Firecracker
task firecracker:test-kernel \
    KERNEL_VERSION=6.1 \
    FIRECRACKER_VERSION=v1.10.0
```

## Using Scripts Directly

```bash
# Basic test
./scripts/firecracker/test-kernel.sh

# With options
./scripts/firecracker/test-kernel.sh \
    --kernel 6.1 \
    --firecracker v1.10.0
```

### Script Options

| Option | Description | Default |
|--------|-------------|---------|
| `--kernel VERSION` | Kernel version to test | Latest stable |
| `--firecracker VERSION` | Firecracker version to use | Latest |

## Test Rootfs

The test creates a minimal rootfs with an init script:

```bash
#!/bin/sh
echo "✓ Kernel booted successfully"
poweroff -f
```

This rootfs is created automatically and cached in `artifacts/test-rootfs.ext4`.

### Manual Rootfs Creation

```bash
# Create fresh test rootfs
./scripts/firecracker/create-test-rootfs.sh

# Output: artifacts/test-rootfs.ext4
```

## VM Configuration

The test configures a minimal Firecracker VM:

- **vCPUs**: 1
- **Memory**: 128MB
- **Storage**: Test rootfs (ext4)
- **Network**: None (not needed for boot test)

## Test Output

### Successful Test

```
Booting kernel 6.1 in Firecracker...
✓ Kernel booted successfully
VM shut down cleanly
Test passed!
```

Exit code: 0

### Failed Test

```
Booting kernel 6.1 in Firecracker...
Error: VM failed to boot
Timeout after 60 seconds
Test failed!
```

Exit code: 1

## Test Failures

### Common Issues

#### Permission Denied (`/dev/kvm`)

```bash
# Add user to kvm group
sudo usermod -aG kvm $USER

# Logout and login
```

#### KVM Not Available

```bash
# Check if KVM module loaded
lsmod | grep kvm

# Load KVM module
sudo modprobe kvm_intel  # Intel
sudo modprobe kvm_amd    # AMD

# Enable in BIOS/UEFI
# Virtualization must be enabled (VT-x/AMD-V)
```

#### Boot Timeout

Possible causes:

1. **Kernel incompatibility**: Try different kernel version
2. **Firecracker incompatibility**: Try different Firecracker version
3. **Wrong architecture**: Ensure kernel matches host architecture
4. **Configuration issue**: Check kernel config

```bash
# Try different kernel version
task firecracker:test-kernel KERNEL_VERSION=6.6

# Try different Firecracker version
task firecracker:test-kernel FIRECRACKER_VERSION=v1.9.0

# Check kernel architecture
file artifacts/vmlinux-6.1-x86_64
# Should match host architecture
```

See [Troubleshooting](../user-guide/troubleshooting.md#testing-issues) for more solutions.

## Testing Modified Kernels

After modifying kernel sources:

```bash
# Build modified kernel
task kernel:build KERNEL_VERSION=6.1 VERIFICATION_LEVEL=disabled

# Test it
task firecracker:test-kernel KERNEL_VERSION=6.1
```

See [Development Mode](../user-guide/local-workflow/development-mode.md) for kernel modification workflow.

## CI Testing

GitHub Actions runners do not have KVM support, so Firecracker boot tests cannot run in CI.

**CI performs**:
- ✅ Kernel compilation
- ✅ Artifact compression
- ✅ Checksum generation

**CI skips**:
- ❌ Firecracker boot tests

**Solution**: Test locally or use self-hosted runners with KVM.

## Advanced Testing

### Test Multiple Versions

```bash
#!/bin/bash
VERSIONS=(6.1 6.6 6.18)

for VERSION in "${VERSIONS[@]}"; do
    echo "Testing kernel $VERSION..."
    if task firecracker:test-kernel KERNEL_VERSION=$VERSION; then
        echo "✓ $VERSION passed"
    else
        echo "✗ $VERSION failed"
    fi
done
```

### Test Both Architectures

```bash
# On x86_64 host
task kernel:build KERNEL_VERSION=6.1 ARCH=x86_64
task firecracker:test-kernel KERNEL_VERSION=6.1  # Tests x86_64

# Transfer aarch64 kernel to ARM64 machine for testing
# Cannot test aarch64 on x86_64 host
```

### Custom Test Rootfs

For advanced testing scenarios:

```bash
# Create custom rootfs with your test scripts
# (manually or with debootstrap, buildroot, etc.)

# Configure Firecracker to use your rootfs
# (modify test-kernel.sh or use Firecracker directly)
```

## Manual Firecracker Testing

For more control, use Firecracker directly:

```bash
# Start Firecracker API server
firecracker --api-sock /tmp/firecracker.sock

# In another terminal, configure via API
curl --unix-socket /tmp/firecracker.sock -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "boot_source": {
      "kernel_image_path": "artifacts/vmlinux-6.1-x86_64",
      "boot_args": "console=ttyS0 reboot=k panic=1"
    },
    "drives": [{
      "drive_id": "rootfs",
      "path_on_host": "artifacts/test-rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }],
    "machine_config": {
      "vcpu_count": 1,
      "mem_size_mib": 128
    }
  }' \
  http://localhost/boot

# Start VM
curl --unix-socket /tmp/firecracker.sock -X PUT \
  http://localhost/actions \
  -d '{"action_type": "InstanceStart"}'
```

See [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker/blob/main/docs/api_requests/actions.md) for details.

## Next Steps

- [Cleaning Up](cleaning-up.md) - Remove test artifacts
- [Development Mode](../user-guide/local-workflow/development-mode.md) - Test modified kernels
- [Troubleshooting](../user-guide/troubleshooting.md) - Solve test issues
- [Firecracker Docs](https://github.com/firecracker-microvm/firecracker) - Learn more about Firecracker
