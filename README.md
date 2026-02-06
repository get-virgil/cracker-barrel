# Cracker Barrel

Automated builder for Firecracker-compatible Linux kernels. This project builds the latest stable Linux kernel daily with optimized configurations for AWS Firecracker microVMs.

## Features

- **Daily Automated Builds**: GitHub Actions workflow runs daily to build the latest stable kernel
- **Multi-Architecture Support**: Builds for both x86_64 and aarch64 (ARM64)
- **Firecracker-Optimized**: Uses official Firecracker kernel configurations for minimal, fast-booting kernels
- **GitHub Releases**: Automatically publishes built kernels as GitHub releases with checksums
- **Smart Caching**: `get-kernel.sh` tries to download pre-built kernels first, only building if necessary
- **Cryptographic Verification**: PGP signature + SHA256 checksum verification of all kernel sources
- **Secure by Default**: Builds fail if verification unavailable - no unverified builds ever released
- **Configurable Security**: Three verification levels (high/medium/disabled) for different use cases
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

### Quick Start with Task

If you have [Task](https://taskfile.dev) installed:

```bash
# Install dependencies
task install-deps

# Get latest kernel (download or build)
task get-kernel

# Test kernel in Firecracker VM
task test-kernel

# Clean all artifacts
task clean

# See all available tasks
task --list
```

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
  jq \
  gnupg

# For aarch64 cross-compilation
sudo apt-get install -y gcc-aarch64-linux-gnu
```

**Note:** `gnupg` is required for PGP signature verification (default `high` security level). If you cannot install GPG, use `--verification-level medium` to skip PGP verification.

### Get Kernel Script

The `get-kernel.sh` script tries to download pre-built kernels from GitHub releases, falling back to building from source if needed:

```bash
# Get latest stable kernel (download or build)
./get-kernel.sh

# Get specific kernel version
./get-kernel.sh --kernel 6.1

# Force building from source (skip download)
./get-kernel.sh --kernel 6.1 --force-build

# Get for specific architecture
./get-kernel.sh --kernel 6.1 --arch aarch64

# Medium verification (SHA256 only, no PGP)
./get-kernel.sh --kernel 6.1 --verification-level medium

# Disabled verification (emergency only)
./get-kernel.sh --kernel 6.1 --verification-level disabled

# Legacy positional syntax (still supported, always builds)
./get-kernel.sh x86_64          # Build latest for x86_64
./get-kernel.sh x86_64 6.1      # Build specific version
./get-kernel.sh aarch64 6.1     # Build for aarch64
```

The script will:
1. Use provided kernel version, or fetch the latest stable from kernel.org
2. Check if kernel already exists locally (skip if present)
3. Try to download pre-built kernel from GitHub releases (unless `--force-build`)
4. Verify checksum after download
5. Fall back to building from source if:
   - Download fails or release doesn't exist
   - Checksum verification fails
   - `--force-build` flag is used
6. When building from source:
   - Download kernel source (or use cached tarball)
   - **Verify source based on `--verification-level`:**
     - `high` (default): PGP signature + SHA256 checksum
     - `medium`: SHA256 checksum only
     - `disabled`: Skip all verification
   - Extract kernel source only after verification passes
   - Apply Firecracker-compatible configuration
   - Build the kernel
   - Compress with xz
   - Generate SHA256 checksums
7. Place artifacts in `artifacts/` directory

### Using Task (Recommended)

[Task](https://taskfile.dev) is a task runner that provides convenient shortcuts:

```bash
# Get kernel (equivalent to ./get-kernel.sh)
task get-kernel

# Get specific version
task get-kernel KERNEL_VERSION=6.1

# Force build from source
task get-kernel FORCE_BUILD=true

# Build for different architecture
task get-kernel KERNEL_VERSION=6.1 ARCH=aarch64

# Test kernel
task test-kernel

# List all tasks
task --list
```

All Task commands are wrappers around the shell scripts, so you can use either approach.

## Security

### Verification Model

This project implements multi-layer verification to protect against supply chain attacks:

**Layer 1: PGP Signature Verification (kernel.org autosigner)**
- Verifies the PGP signature on `sha256sums.asc` from kernel.org
- Proves checksums file hasn't been tampered with
- Imports and validates kernel.org autosigner key (B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1)
- Protects against CDN cache poisoning and compromised mirrors

**Layer 2: SHA256 Checksum Verification**
- Verifies kernel source tarball matches checksum from signed `sha256sums.asc`
- Verification happens **before extraction**, even for cached tarballs
- Protects against corrupted downloads and tampering

**Layer 3: Build Artifact Verification (GitHub releases)**
- Pre-built kernels include SHA256 checksums in releases
- Users can verify downloaded kernels before use
- Checksums calculated from decompressed binaries

### Verification Levels

Choose your security posture with `--verification-level`:

**`high` (Default - Strongest Security):**
```bash
./get-kernel.sh                    # Default: high verification
task get-kernel                    # Default: high verification
```
- ✅ Verifies PGP signature on `sha256sums.asc`
- ✅ Verifies SHA256 checksum of kernel tarball
- **Protects against:** CDN poisoning, MITM attacks, tampering, corrupted downloads
- **Requires:** GPG installed, internet access to keyservers
- **Use when:** Building for production, distribution, or any trusted use

**`medium` (SHA256 Only):**
```bash
./get-kernel.sh --verification-level medium
task get-kernel VERIFICATION_LEVEL=medium
```
- ⚠️ Skips PGP signature verification
- ✅ Verifies SHA256 checksum only
- **Protects against:** Corrupted downloads, accidental tampering
- **Trusts:** HTTPS connection to kernel.org for checksums file integrity
- **Use when:** Systems without GPG, or acceptable risk for local testing
- **Note:** An attacker compromising kernel.org's CDN could replace both tarball and checksums file with matching malicious versions

**`disabled` (No Verification - Emergency Only):**
```bash
./get-kernel.sh --verification-level disabled
task get-kernel VERIFICATION_LEVEL=disabled
```
- ❌ No verification whatsoever
- **Protects against:** Nothing
- **Use when:** Kernel just released and kernel.org hasn't updated `sha256sums.asc` yet
- **Example scenario:** 6.18.9 released on Feb 6, 2026 at 9am, but checksums file not updated until 9:15am - need `disabled` to build in that 15-minute window
- **WARNING:** Only use temporarily when you understand and accept the security risks

### CI/CD Security

**GitHub Actions builds always use `high` verification:**
- Automated builds **never** bypass verification
- Builds fail-secure if checksums or PGP verification unavailable
- Workflow waits for kernel.org to update checksums (typically hours after kernel release)
- This ensures distributed kernels are always verified

### Threat Model

**Attacks Prevented (high verification):**
- ✅ CDN cache poisoning (malicious kernel sources)
- ✅ MITM attacks during download
- ✅ Tampered cached tarballs
- ✅ Corrupted downloads
- ✅ Compromised mirrors serving malicious content

**Attack Surface:**
- Trusts kernel.org's autosigner key (verified via fingerprint B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1)
- Trusts keyserver infrastructure for GPG key distribution
- Trusts GitHub's infrastructure for release hosting
- Local build environment assumed secure

### Developer Signature Verification

For even stronger assurance, verify individual developer signatures:
- Download `.tar.sign` files from kernel.org
- Verify against developer keys (Linus Torvalds, Greg KH, Sasha Levin, etc.)
- See [kernel.org/signature.html](https://kernel.org/signature.html) for complete guide
- The `sha256sums.asc` approach verifies kernel.org's infrastructure; developer signatures verify the original release

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

## Testing

### Local Testing with Firecracker

Test kernels locally using the `test-kernel.sh` script:

```bash
# Test latest stable kernel with latest Firecracker
./test-kernel.sh

# Test specific kernel version
./test-kernel.sh --kernel 6.1

# Test with specific Firecracker version
./test-kernel.sh --kernel 6.10 --firecracker v1.10.0
```

The test script will:
1. Auto-detect your architecture (x86_64 or aarch64)
2. Build the kernel if not found
3. Download Firecracker binary
4. Create a minimal test rootfs
5. Boot the kernel in a Firecracker VM
6. Verify clean shutdown within 60 seconds

**Requirements**: KVM support (`/dev/kvm` must be accessible)

### Why Not in CI?

GitHub Actions runners do not have KVM/nested virtualization support, so Firecracker boot tests cannot run in CI. All kernels are built and compressed in CI, but boot testing must be done locally or on infrastructure with KVM access.

## GitHub Actions Workflow

The workflow (`.github/workflows/build-kernel.yml`) performs the following:

1. **Check Version** - Fetches latest stable kernel from kernel.org (or uses provided version)
2. **Check Existing Release** - Skips build if release already exists
3. **Build Matrix** - Builds for both x86_64 and aarch64 in parallel
   - **Security**: Always uses `high` verification level (PGP + SHA256)
   - Imports kernel.org autosigner GPG key
   - Verifies PGP signature on `sha256sums.asc`
   - Verifies SHA256 checksum of kernel tarball
   - Builds fail if any verification step fails (fail-secure by design)
4. **Create Release** - Publishes verified artifacts to GitHub Releases

**Important:** If a new kernel version is released and the workflow fails with verification errors, this is expected and correct behavior. The workflow will succeed once kernel.org updates their `sha256sums.asc` file (typically within hours of kernel release). This fail-secure behavior ensures distributed kernels are always cryptographically verified.

**What users can trust:**
- All kernels in GitHub releases have been built from PGP-verified sources
- No kernel is ever released without passing full `high` verification
- CI never bypasses security checks

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
├── get-kernel.sh                         # Get kernel (download or build)
├── create-test-rootfs.sh                 # Test rootfs creation script
├── test-kernel.sh                        # End-to-end kernel testing script
├── Taskfile.dist.yaml                    # Task runner definitions
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

### Source Verification

Kernel source tarballs undergo multi-layer verification before extraction (based on `--verification-level`):

**Default (`high` level) - Strongest Security:**

1. Downloads `sha256sums.asc` from kernel.org (PGP-signed checksums file)
2. **Imports kernel.org autosigner GPG key** from keyserver (if not already present)
   - Key ID: 632D3A06589DA6B1
   - Fingerprint: B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1
   - Verifies fingerprint matches expected value to prevent key substitution
3. **Verifies PGP signature** on `sha256sums.asc`
   - Cryptographic proof the checksums file is authentic from kernel.org
   - Protects against CDN cache poisoning and compromised mirrors
4. Extracts the SHA256 hash for the specific kernel version
5. Calculates the actual hash of the local tarball (cached or freshly downloaded)
6. Compares expected vs actual - **build fails** if mismatch
7. Only proceeds to extraction after both PGP and SHA256 verification pass

**Medium verification (`--verification-level medium`):**
- Skips steps 2-3 (PGP verification)
- Still performs SHA256 checksum verification (steps 1, 4-7)
- Trusts HTTPS connection to kernel.org

**Disabled verification (`--verification-level disabled`):**
- Skips all verification steps
- Only use when kernel too new and checksums unavailable

**Critical security properties:**
- **Always re-verify:** Cached tarballs are treated as untrusted and re-verified every time. This prevents attacks where a previously-downloaded tarball is replaced with a malicious version.
- **Fail-secure:** If verification fails or is unavailable, the build stops immediately. Better to fail than build from unverified sources.
- **Cryptographic proof:** PGP signatures provide cryptographic assurance that checksums come from kernel.org's autosigner, not an attacker.

**For even stronger assurance:** Verify individual developer signatures (.tar.sign files) against keys from Linus Torvalds, Greg Kroah-Hartman, etc. See [kernel.org/signature.html](https://kernel.org/signature.html) for complete guide.

### Testing Workflow

The `test-kernel.sh` script validates kernels by:
1. Creating a minimal rootfs with an init script that prints success and shuts down
2. Configuring a Firecracker VM via its REST API (1 vCPU, 128MB RAM)
3. Booting the kernel and waiting for clean shutdown (max 60 seconds)
4. Success = VM boots and shuts down cleanly
5. Failure = VM hangs, crashes, or timeout exceeded

## Cleaning Up

### Using Task

```bash
# Remove all build artifacts and caches (~10GB+)
task clean

# Remove only kernel artifacts (keep Firecracker and rootfs)
task clean-kernel

# Remove specific kernel version
task clean-kernel VERSION=6.1

# Remove cached Firecracker binaries
task clean-firecracker

# Remove test rootfs
task clean-rootfs

# List all cached artifacts
task list-artifacts
```

### Manual Cleanup

```bash
# Remove all build artifacts and caches
rm -rf build/ artifacts/ bin/

# Remove specific kernel version
rm -f artifacts/vmlinux-6.1-x86_64* artifacts/Image-6.1-aarch64*

# Remove all cached Firecracker binaries
rm -rf bin/

# Remove test rootfs (will be recreated on next test)
rm -f artifacts/test-rootfs.ext4
```

## Troubleshooting

### Source Verification Fails

**Error: "gpg not found"**
- GPG is not installed on your system
- Install GPG: `sudo apt-get install gnupg` (Ubuntu/Debian)
- Or use medium verification: `./get-kernel.sh --verification-level medium`

**Error: "Failed to import autosigner key from any keyserver"**
- Cannot reach keyservers to import kernel.org's autosigner key
- Check firewall/proxy settings
- Try again later
- Or use medium verification: `./get-kernel.sh --verification-level medium`

**Error: "PGP signature verification failed"**
- The `sha256sums.asc` file signature is invalid
- This could indicate tampering or a corrupted download
- Try downloading again
- If problem persists, this is a serious security concern - investigate before proceeding

**Error: "Checksum not found in sha256sums.asc"**
- Kernel version is too new - kernel.org hasn't updated checksums yet
- Usually happens within 15 minutes to a few hours after kernel release
- Example: 6.18.9 released Feb 6, 2026 at 9:00am, checksums available at 9:15am
- Wait for checksums to be available, or use `--verification-level disabled` (emergency only)

**Error: "Checksum verification FAILED"**
- Downloaded tarball is corrupted or tampered with
- Remove the tarball: `rm build/linux-*.tar.xz`
- Try downloading again: `./get-kernel.sh --kernel <version>`
- If problem persists, the CDN may be serving corrupted files - wait and retry

**Error: "Could not download checksums file from kernel.org"**
- Network connectivity issue or kernel.org is down
- Check your internet connection
- Try again later
- As a last resort (local testing only): use `--verification-level disabled`

### Build Fails

If the build fails, check:
- All dependencies are installed
- Sufficient disk space (kernel builds require ~10GB)
- Kernel configuration is compatible with the kernel version
- Try cleaning and rebuilding: `rm -rf build/ artifacts/ && ./get-kernel.sh --force-build`

### Can't Interrupt with Ctrl-C

If Ctrl-C doesn't stop builds or tests:
- Ensure `stty isig` is enabled in your terminal (check with `stty -a | grep isig`)
- Add `stty isig` to your shell config (`~/.bashrc`, `~/.zshrc`, etc.)
- Terminal setting `-isig` disables signal generation for Ctrl-C

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
- [x] Integration tests with Firecracker (available locally via `test-kernel.sh`, not in CI due to KVM requirements)
- [ ] Build time optimizations
- [ ] Extended boot tests with virtio device verification
- [ ] CI testing on infrastructure with KVM support (e.g., self-hosted runners)

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
