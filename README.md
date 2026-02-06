# Cracker Barrel

Automated builder for Firecracker-compatible Linux kernels. This project builds the latest stable Linux kernel daily with optimized configurations for AWS Firecracker microVMs.

## Features

- **Daily Automated Builds**: GitHub Actions workflow runs daily to build the latest stable kernel
- **Multi-Architecture Support**: Builds for both x86_64 and aarch64 (ARM64)
- **Firecracker-Optimized**: Uses official Firecracker kernel configurations for minimal, fast-booting kernels
- **GitHub Releases**: Automatically publishes built kernels as GitHub releases with checksums
- **Idempotent**: Skips builds if a release already exists for the current kernel version

## Quick Start

### Download Pre-Built Kernels

Visit the [Releases](../../releases) page to download pre-built kernels. Each release includes:

- `vmlinux-{version}-x86_64.xz` - x86_64 kernel (compressed)
- `Image-{version}-aarch64.xz` - aarch64 kernel (compressed)
- `config-{version}-x86_64` - x86_64 kernel configuration
- `config-{version}-aarch64` - aarch64 kernel configuration
- `SHA256SUMS` - Checksums of decompressed kernels

### Using with Firecracker

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

## Building Locally

### Prerequisites

Install build dependencies:

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  build-essential \
  libncurses-dev \
  bison \
  flex \
  libssl-dev \
  libelf-dev \
  bc \
  wget \
  xz-utils \
  jq

# For aarch64 cross-compilation
sudo apt-get install -y gcc-aarch64-linux-gnu
```

### Build Script

Run the build script with your desired architecture:

```bash
# Build for x86_64
./build-kernel.sh x86_64

# Build for aarch64
./build-kernel.sh aarch64
```

The script will:
1. Fetch the latest stable kernel version from kernel.org
2. Download and extract kernel source
3. Apply Firecracker-compatible configuration
4. Build the kernel
5. Compress with xz
6. Generate SHA256 checksums
7. Place artifacts in `artifacts/` directory

## Kernel Configuration

Kernel configurations are based on Firecracker's official guest configs and include:

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

## GitHub Actions Workflow

The workflow (`.github/workflows/build-kernel.yml`) performs the following:

1. **Check Version** - Fetches latest stable kernel from kernel.org (or uses provided version)
2. **Check Existing Release** - Skips build if release already exists
3. **Build Matrix** - Builds for both x86_64 and aarch64 in parallel
4. **Test Matrix** - Tests both kernels by booting minimal VMs with Firecracker v1.14.1
   - x86_64 tests run on standard ubuntu-latest runners
   - aarch64 tests run natively on ubuntu-24.04-arm runners (free for public repos)
   - Test rootfs is cached using the script hash (only rebuilt when `create-test-rootfs.sh` changes)
   - Each kernel must successfully boot and shut down cleanly
5. **Create Release** - Publishes artifacts to GitHub Releases (only if all tests pass)

### Manual Trigger

#### Via GitHub UI

You can manually trigger a build from the Actions tab in GitHub:

1. Go to the "Actions" tab
2. Select "Build Firecracker-Compatible Kernel"
3. Click "Run workflow"
4. Optionally specify a kernel version (e.g., `6.18.8`)
   - Leave empty to build the latest stable version
   - Specify a version to build a specific kernel release

#### Via GitHub CLI

Use the `gh` CLI to trigger builds from the command line:

```bash
# Build latest stable kernel
gh workflow run build-kernel.yml

# Build a specific kernel version
gh workflow run build-kernel.yml -f kernel_version=6.18.8

# Monitor the workflow run
gh run list --workflow=build-kernel.yml --limit 5
gh run watch
```

### Schedule

By default, the workflow runs daily at 2 AM UTC. You can modify the cron schedule in `.github/workflows/build-kernel.yml`:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Change this line
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── build-kernel.yml              # GitHub Actions workflow
├── configs/
│   ├── microvm-kernel-x86_64.config      # Firecracker config for x86_64
│   └── microvm-kernel-aarch64.config     # Firecracker config for aarch64
├── build-kernel.sh                       # Main build script
├── create-test-rootfs.sh                 # Test rootfs creation script
└── README.md                             # This file
```

## How It Works

### Kernel Version Detection

The project uses kernel.org's JSON API to fetch the latest stable kernel version:

```bash
curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version'
```

### Configuration Management

Kernel configurations are based on Firecracker's official microvm-kernel configs:
- Source: https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs
- Version: 6.1 (updated for newer kernels via `make olddefconfig`)

### Compression & Checksums

- Kernels are compressed with xz at maximum compression (`-9`)
- SHA256 checksums are calculated from **decompressed** kernel binaries
- This allows users to verify integrity after decompression

## Troubleshooting

### Build Fails

If the build fails, check:
- All dependencies are installed
- Sufficient disk space (kernel builds require ~10GB)
- Kernel configuration is compatible with the kernel version

### GitHub Actions Fails

Common issues:
- **Permission denied**: Ensure the workflow has `contents: write` permission
- **Rate limiting**: GitHub API rate limits may affect release checks
- **Artifact upload fails**: Check artifact size limits (workflow artifacts have a 2GB limit per file)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Areas for Improvement

- [ ] Support for longterm kernels (e.g., 6.6.x LTS)
- [ ] Custom kernel configuration options
- [ ] Additional architectures (e.g., RISC-V)
- [x] Integration tests with Firecracker
- [ ] Build time optimizations
- [ ] Extended boot tests with virtio device verification

## License

This project is licensed under the MIT License. The Linux kernel itself is licensed under GPL-2.0.

## References

- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker)
- [Firecracker Kernel Policy](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md)
- [Kernel.org](https://kernel.org)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)

## Acknowledgments

- Kernel configurations based on [Firecracker's official guest configs](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs)
- Built with GitHub Actions
- Inspired by the need for automated, reproducible Firecracker kernel builds
