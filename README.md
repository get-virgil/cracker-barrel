# Cracker Barrel

Automated builder for Firecracker-compatible Linux kernels. Daily builds of the latest stable kernel, optimized for AWS Firecracker microVMs.

**📖 [Full Documentation](https://get-virgil.github.io/cracker-barrel)**

## Features

- **Daily Automated Builds** - Latest stable kernel from kernel.org
- **Multi-Architecture** - x86_64 and ARM64 (aarch64) support
- **Firecracker-Optimized** - Minimal, fast-booting kernel configurations
- **Cryptographically Verified** - PGP + SHA256 verification of all sources
- **GitHub Releases** - Pre-built kernels with checksums and signatures

## Quick Start

### Download Pre-Built Kernels

Visit the [Releases](../../releases) page to download pre-built kernels:

```bash
# Download kernel (replace VERSION with actual version, e.g., 6.18.9)
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS

# Decompress and verify
xz -d vmlinux-VERSION-x86_64.xz
sha256sum -c SHA256SUMS --ignore-missing

# Use with Firecracker
firecracker --kernel-path vmlinux-VERSION-x86_64 ...
```

### Request a Kernel Build

Don't see the version you need? [Request a build](../../issues/new?template=build-request.yml) and we'll build it automatically.

## Verifying Releases

**All kernel releases are PGP-signed.** We strongly recommend verifying signatures:

```bash
# 1. Import Cracker Barrel release signing key (first time only)
curl -s https://raw.githubusercontent.com/get-virgil/cracker-barrel/master/keys/signing-key.asc | gpg --import

# Verify the key fingerprint matches (see below)
gpg --fingerprint me@kazatron.com

# 2. Download kernel, checksums, and signature
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS.asc

# 3. Verify PGP signature on checksums
gpg --verify SHA256SUMS.asc SHA256SUMS
# Should show: "Good signature from Cracker Barrel Release Signing"

# 4. Decompress kernel
xz -d vmlinux-VERSION-x86_64.xz

# 5. Verify kernel checksum
sha256sum -c SHA256SUMS --ignore-missing
```

**Cracker Barrel Release Signing Key:**
```
Key ID: 7E7E22A24A116FBD
Fingerprint: F060 03AB F17F FF1D 4F24  F875 7E7E 22A2 4A11 6FBD
Email: me@kazatron.com
Expires: 2026-02-17 (Alpha key - 10 day expiry for testing rotation)
```

**Chain of Trust:**
1. Kernel sources verified with kernel.org autosigner PGP signature
2. Kernel sources verified with SHA256 checksums from kernel.org
3. Built kernels signed with Cracker Barrel release key
4. Users verify with Cracker Barrel public key

This ensures sources came from kernel.org and builds weren't tampered with.

## Building Locally

Install [Task](https://taskfile.dev) and build dependencies:

```bash
# Install Task
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# Install build dependencies
task dev:install-deps

# Get latest kernel (download or build)
task kernel:get

# Build specific version
task kernel:get KERNEL_VERSION=6.1

# Test kernel in Firecracker VM (requires KVM)
task firecracker:test-kernel

# See all available tasks
task --list
```

For detailed build instructions, security verification levels, and advanced usage, see the [full documentation](https://get-virgil.github.io/cracker-barrel).

## Documentation

- **[Getting Started](https://get-virgil.github.io/cracker-barrel/getting-started.html)** - Downloading and using kernels
- **[Building Locally](https://get-virgil.github.io/cracker-barrel/building.html)** - Build from source
- **[Security](https://get-virgil.github.io/cracker-barrel/security.html)** - Verification and threat model
- **[Configuration](https://get-virgil.github.io/cracker-barrel/configuration.html)** - Kernel configuration details
- **[CI/CD](https://get-virgil.github.io/cracker-barrel/ci-cd.html)** - GitHub Actions workflow
- **[Maintainer Guide](https://get-virgil.github.io/cracker-barrel/maintainer.html)** - Setting up signing keys

## Project Structure

```
.github/workflows/     # GitHub Actions workflows
configs/               # Firecracker kernel configurations
keys/                  # PGP signing keys
scripts/               # Build, signing, and testing scripts
tasks/                 # Task runner configurations
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

See the [full documentation](https://get-virgil.github.io/cracker-barrel) for development guidelines.

## License

Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.

The Linux kernel itself is licensed under GPL-2.0.

## References

- [Full Documentation](https://get-virgil.github.io/cracker-barrel)
- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker)
- [Kernel.org](https://kernel.org)
