# Cracker Barrel

Automated builder for Firecracker-compatible Linux kernels. This project builds the latest stable Linux kernel daily with optimized configurations for AWS Firecracker microVMs.

## Features

- **Daily Automated Builds**: GitHub Actions workflow runs daily to build the latest stable kernel
- **Multi-Architecture Support**: Builds for both x86_64 and aarch64 (ARM64)
- **Firecracker-Optimized**: Uses official Firecracker kernel configurations for minimal, fast-booting kernels
- **GitHub Releases**: Automatically publishes built kernels as GitHub releases with checksums
- **Separate Download & Build**: `download-kernel.sh` downloads pre-built kernels, `build-kernel.sh` builds from source
- **Cryptographic Verification**: PGP signature + SHA256 checksum verification of all kernel sources
- **Secure by Default**: Builds fail if verification unavailable - no unverified builds ever released
- **Configurable Security**: Three verification levels (high/medium/disabled) for different use cases
- **Local-First Workflow**: Task-based build system - CI runs the same commands you run locally
- **Idempotent**: Skips builds if a release already exists for the current kernel version

## Quick Start

### Request a Kernel Build

Don't see the kernel version you need? **Open an issue to request a build!**

[🔨 Request Kernel Build](../../issues/new?template=build-request.yml)

- Select "Kernel Build Request" template
- Enter the kernel version (e.g., 6.1.75)
- Submit the issue
- Automated validation and build process kicks in
- Download from releases once complete

**Important:**
- Only stable kernel versions from kernel.org are accepted
- Invalid requests are tracked (5 invalid requests = automatic ban)
- Check https://kernel.org first to verify the version exists

### Download Pre-Built Kernels

Visit the [Releases](../../releases) page to download pre-built kernels. Each release includes:

- `vmlinux-{version}-x86_64.xz` - x86_64 kernel (compressed)
- `Image-{version}-aarch64.xz` - aarch64 kernel (compressed)
- `config-{version}-x86_64` - x86_64 kernel configuration
- `config-{version}-aarch64` - aarch64 kernel configuration
- `SHA256SUMS` - Checksums of decompressed kernels
- `SHA256SUMS.asc` - PGP signature of SHA256SUMS

### Verifying Releases

**All kernel releases are PGP-signed.** We strongly recommend verifying signatures before use:

```bash
# 1. Import Cracker Barrel release signing key (first time only)
curl -s https://raw.githubusercontent.com/get-virgil/cracker-barrel/master/keys/signing-key.asc | gpg --import

# Verify the key fingerprint matches (see below)
gpg --fingerprint releases@cracker-barrel.dev

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
Key ID: [TO BE ADDED - Run 'task signing:generate-signing-key']
Fingerprint: [TO BE ADDED - Run 'task signing:generate-signing-key']
Email: releases@cracker-barrel.dev
```

**Chain of Trust:**
1. Kernel sources verified with kernel.org autosigner PGP signature
2. Kernel sources verified with SHA256 checksums from kernel.org
3. Built kernels signed with Cracker Barrel release key
4. Users verify with Cracker Barrel public key

This ensures:
- ✅ Sources came from kernel.org (not tampered)
- ✅ Builds came from Cracker Barrel CI (not modified)
- ✅ Downloads weren't corrupted or replaced

### Quick Start Without Verification

If you trust GitHub's infrastructure and don't need PGP verification:

```bash
# Download kernel and checksums
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-VERSION-x86_64.xz
wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS

# Decompress and verify checksum
xz -d vmlinux-VERSION-x86_64.xz
sha256sum -c SHA256SUMS --ignore-missing
```

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
task dev:install-deps

# Get latest kernel (download or build)
task kernel:get

# Test kernel in Firecracker VM
task firecracker:test-kernel

# Clean all artifacts
task clean

# See all available tasks
task --list
```

### Prerequisites

**1. Install Task (task runner):**

Task is required for both local development and CI. Install it using the official script:

```bash
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

Add `~/.local/bin` to your PATH if needed.

**2. Install build dependencies:**

```bash
# Ubuntu/Debian - Using task runner (recommended)
task dev:install-deps

# Arch Linux (for the best developers)
task dev:i-use-arch-btw

# For cross-compilation (optional)
task dev:install-arm-tools   # ARM64 on x86_64 host
task dev:install-x86-tools   # x86_64 on ARM64 host
```

**Package list:** See `task --summary dev:install-deps` or `task --summary dev:i-use-arch-btw` for the complete list.

**Note:** `gnupg` is required for PGP signature verification (default `high` security level). If you cannot install GPG, use `--verification-level medium` to skip PGP verification.

### Kernel Scripts

The project provides two separate scripts for different workflows:

#### Download Pre-Built Kernels

The `download-kernel.sh` script downloads pre-built kernels from GitHub releases:

```bash
# Download latest stable kernel
./scripts/kernel/download-kernel.sh

# Download specific kernel version
./scripts/kernel/download-kernel.sh --kernel 6.1

# Download for specific architecture
./scripts/kernel/download-kernel.sh --kernel 6.1 --arch aarch64
```

The script will:
1. Fetch the latest stable version from kernel.org (or use provided version)
2. Check if kernel already exists locally (skip if present)
3. Download compressed kernel from GitHub releases
4. Verify checksum of downloaded kernel
5. Decompress kernel
6. **Fails if release not available** (no build fallback)

#### Build from Source

The `build-kernel.sh` script builds kernels from source:

```bash
# Build latest stable kernel
./scripts/kernel/build-kernel.sh

# Build specific kernel version
./scripts/kernel/build-kernel.sh --kernel 6.1

# Build for specific architecture
./scripts/kernel/build-kernel.sh --kernel 6.1 --arch aarch64

# Medium verification (SHA256 only, no PGP)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level medium

# Disabled verification (emergency only)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

The script will:
1. Fetch the latest stable version from kernel.org (or use provided version)
2. Check if kernel already built locally (skip if present)
3. **Delete cached sources when verification enabled** (security: fresh sources)
   - `high` or `medium`: Deletes `build/linux-*.tar.xz` and `build/linux-*/`
   - `disabled`: Keeps cache (allows source modifications for development)
4. Download kernel source tarball
5. **Verify source based on `--verification-level`:**
   - `high` (default): PGP signature + SHA256 checksum
   - `medium`: SHA256 checksum only
   - `disabled`: Skip all verification
6. Extract kernel source only after verification passes
7. Apply Firecracker-compatible configuration
8. Build the kernel
9. Compress with xz
10. Generate SHA256 checksums
11. Place artifacts in `artifacts/` directory

**Development workflow with source modifications:**
```bash
# Build with disabled verification (keeps sources)
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Modify source code
vim build/linux-6.1/drivers/virtio/virtio_ring.c

# Rebuild with your modifications
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

### Using Task (Recommended)

[Task](https://taskfile.dev) is a task runner that provides convenient shortcuts.

**Tasks are organized into namespaces:**
- `kernel:*` - Kernel operations (get, download, build)
- `firecracker:*` - Testing kernels with Firecracker
- `clean:*` - Cleaning artifacts
- `signing:*` - PGP key management and signing
- `release:*` - CI release artifact management
- `dev:*` - Development utilities

**Kernel task workflow:**
- `kernel:get` - Smart: tries download, builds if unavailable (recommended)
- `kernel:download` - Download only: fails if pre-built not available
- `kernel:build` - Build from source: always uses fresh sources when verifying

```bash
# Get kernel (smart: download or build)
task kernel:get

# Get specific version
task kernel:get KERNEL_VERSION=6.1

# Download only (fails if not available)
task kernel:download

# Download specific version
task kernel:download KERNEL_VERSION=6.1

# Build from source (deletes cache unless verification=disabled)
task kernel:build

# Build specific version for ARM64
task kernel:build KERNEL_VERSION=6.1 ARCH=aarch64

# Build with disabled verification (allows source modifications for development)
task kernel:build VERIFICATION_LEVEL=disabled

# Test kernel
task firecracker:test-kernel

# List all tasks
task --list
```

All Task commands are wrappers around the shell scripts, so you can use either approach.

## Local Archive

When you sign artifacts locally with `task signing:sign-artifacts`, they're automatically archived to `archive/{version}/` (git-ignored). This creates a local mirror of what gets published to GitHub releases, enabling fully local-first development.

### Archive Structure

```
archive/
├── index.json              # Quick lookup of available kernels per architecture
├── 6.18.9/
│   ├── vmlinux-6.18.9-x86_64.xz
│   ├── Image-6.18.9-aarch64.xz
│   ├── config-6.18.9-x86_64
│   ├── config-6.18.9-aarch64
│   ├── SHA256SUMS
│   ├── SHA256SUMS.asc
│   └── signing-key.asc                   # Public key (same as releases)
├── 6.18.8/
│   └── ...
└── ...
```

### Index File

The `archive/index.json` file tracks kernel versions and their file paths for each architecture:

```json
{
  "x86_64": {
    "6.18.9": "6.18.9/vmlinux-6.18.9-x86_64.xz",
    "6.18.8": "6.18.8/vmlinux-6.18.8-x86_64.xz"
  },
  "aarch64": {
    "6.18.9": "6.18.9/Image-6.18.9-aarch64.xz",
    "6.18.8": "6.18.8/Image-6.18.8-aarch64.xz"
  }
}
```

The index is automatically updated when you sign new artifacts.

### Benefits

- **Offline Development**: Keep all signed kernels locally without GitHub dependency
- **Fast Access**: Instantly access any previously built kernel
- **Testing**: Test release structure locally before publishing
- **Mirrors Releases**: Exact same file layout as GitHub releases

The archive directory is automatically populated when you run `task signing:sign-artifacts` and requires no manual management.

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
./scripts/kernel/build-kernel.sh                    # Default: high verification
task kernel:build              # Default: high verification
```
- ✅ Verifies PGP signature on `sha256sums.asc`
- ✅ Verifies SHA256 checksum of kernel tarball
- **Protects against:** CDN poisoning, MITM attacks, tampering, corrupted downloads
- **Requires:** GPG installed, internet access to keyservers
- **Use when:** Building for production, distribution, or any trusted use

**`medium` (SHA256 Only):**
```bash
./scripts/kernel/build-kernel.sh --verification-level medium
task kernel:get VERIFICATION_LEVEL=medium
```
- ⚠️ Skips PGP signature verification
- ✅ Verifies SHA256 checksum only
- **Protects against:** Corrupted downloads, accidental tampering
- **Trusts:** HTTPS connection to kernel.org for checksums file integrity
- **Use when:** Systems without GPG, or acceptable risk for local testing
- **Note:** An attacker compromising kernel.org's CDN could replace both tarball and checksums file with matching malicious versions

**`disabled` (No Verification - Emergency Only):**
```bash
./scripts/kernel/build-kernel.sh --verification-level disabled
task kernel:get VERIFICATION_LEVEL=disabled
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
./scripts/firecracker/test-kernel.sh

# Test specific kernel version
./scripts/firecracker/test-kernel.sh --kernel 6.1

# Test with specific Firecracker version
./scripts/firecracker/test-kernel.sh --kernel 6.10 --firecracker v1.10.0
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

The workflow (`.github/workflows/build-kernel.yml`) uses **Task for unified local/CI workflows**.

### Workflow Steps

1. **Check Version** - Fetches latest stable kernel from kernel.org (or uses provided version)
2. **Check Existing Release** - Skips build if release already exists
3. **Build Matrix** - Builds for both x86_64 and aarch64 in parallel
   - Installs Task CLI using official install script
   - Runs `task dev:install-deps` (same command you use locally)
   - Runs `task kernel:build` with kernel version and architecture
   - **Security**: Always uses `high` verification level (PGP + SHA256)
   - Imports kernel.org autosigner GPG key
   - Verifies PGP signature on `sha256sums.asc`
   - Verifies SHA256 checksum of kernel tarball
   - Builds fail if any verification step fails (fail-secure by design)
4. **Create Release** - Consolidates and signs artifacts
   - Runs `task release:consolidate-artifacts` to merge multi-arch builds
   - Runs `task signing:sign-artifacts` with `SIGNING_KEY` secret
   - Publishes verified artifacts to GitHub Releases

### Local-First Philosophy

The CI workflow uses the exact same commands you run locally:
- **Local**: `task dev:install-deps` → `task kernel:build`
- **CI**: `task dev:install-deps` → `task kernel:build`

This ensures:
- ✅ CI behavior is reproducible locally
- ✅ Testing locally = testing CI
- ✅ No CI-specific scripts to maintain
- ✅ Easy to debug CI failures

**Important:** If a new kernel version is released and the workflow fails with verification errors, this is expected and correct behavior. The workflow will succeed once kernel.org updates their `sha256sums.asc` file (typically within hours of kernel release). This fail-secure behavior ensures distributed kernels are always cryptographically verified.

**What users can trust:**
- All kernels in GitHub releases have been built from PGP-verified sources
- No kernel is ever released without passing full `high` verification
- CI never bypasses security checks
- CI uses the same build process as local development

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

## Community Build Requests

Users can request specific kernel versions by opening a GitHub issue. The system automatically validates requests and triggers builds.

### How It Works

1. **Submit Request**: Open an issue using the "Kernel Build Request" template
2. **Automatic Validation**: The system checks if the version exists on kernel.org
3. **Build Trigger**: Valid requests trigger the build workflow automatically
4. **Release**: Built kernels are published to GitHub releases

### Request Process

```bash
# Via GitHub UI
1. Go to Issues → New Issue
2. Select "Kernel Build Request"
3. Enter kernel version (e.g., 6.1.75)
4. Submit

# Via GitHub CLI
gh issue create --template build-request.yml \
  --title "[BUILD] Kernel version: 6.1.75"
```

### Validation Rules

**Valid requests:**
- ✅ Version exists on kernel.org (verified via releases.json API)
- ✅ Version not already built and released
- ✅ User has fewer than 5 invalid requests

**Invalid requests:**
- ❌ Version doesn't exist on kernel.org
- ❌ Typo in version number
- ❌ Non-numeric characters

### Rate Limiting & Bans

To prevent abuse, invalid requests are tracked:

- Each user can submit up to **5 invalid requests**
- After 5 invalid requests, the user is **automatically banned**
- Banned users' future build requests are immediately closed
- Invalid request count is tracked via GitHub issue labels

**Ban criteria:**
- 5+ issues labeled `invalid-kernel-version` from the same user

**Warning system:**
- Request 4/5: Warning message in issue comment
- Request 5/5: Automatic ban with notification

### Response Types

**Valid request (version exists):**
```
✅ Build Triggered
Kernel version 6.1.75 build has been triggered.
[Link to workflow runs]
```

**Already exists:**
```
ℹ️ Release Already Exists
Kernel version 6.1.75 has already been built.
[Link to release]
```

**Invalid version:**
```
❌ Invalid Kernel Version
The requested kernel version 6.1.999 does not exist on kernel.org.
Invalid requests: 1/5
```

**User banned:**
```
🚫 User Banned
User has been automatically banned for exceeding the invalid build request limit.
Invalid requests: 5/5
```

### Checking Kernel Versions

Before requesting, verify the version exists:

```bash
# Check kernel.org releases
curl -s https://www.kernel.org/releases.json | jq '.releases[] | .version'

# Or visit kernel.org directly
open https://kernel.org
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
├── keys/
│   ├── signing-key.asc                   # Public signing key (committed)
│   └── README.md                         # Key management documentation
├── scripts/
│   ├── kernel/
│   │   ├── build-kernel.sh               # Build kernels from source
│   │   └── download-kernel.sh            # Download pre-built kernels
│   ├── firecracker/
│   │   ├── create-test-rootfs.sh         # Test rootfs creation script
│   │   └── test-kernel.sh                # End-to-end kernel testing script
│   └── signing/
│       ├── sign-artifacts.sh             # Sign artifacts with PGP
│       ├── verify-artifacts.sh           # Verify PGP signatures
│       ├── generate-signing-key.sh       # Generate new signing key
│       ├── rotate-signing-key.sh         # Rotate signing key
│       ├── check-key-expiry.sh           # Check key expiration
│       └── remove-signing-key.sh         # Remove signing key
├── tasks/
│   ├── kernel/Taskfile.dist.yaml         # Kernel building tasks
│   ├── firecracker/Taskfile.dist.yaml    # Firecracker testing tasks
│   ├── clean/Taskfile.dist.yaml          # Cleanup tasks
│   ├── signing/Taskfile.dist.yaml        # PGP signing and key management
│   ├── release/Taskfile.dist.yaml        # CI release tasks
│   └── dev/Taskfile.dist.yaml            # Development utilities
├── Taskfile.dist.yaml                    # Root task runner (includes all task groups)
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
- Or use medium verification: `./scripts/kernel/build-kernel.sh --verification-level medium`

**Error: "Failed to import autosigner key from any keyserver"**
- Cannot reach keyservers to import kernel.org's autosigner key
- Check firewall/proxy settings
- Try again later
- Or use medium verification: `./scripts/kernel/build-kernel.sh --verification-level medium`

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
- Try downloading again: `./scripts/kernel/download-kernel.sh --kernel <version>` or build from source: `./scripts/kernel/build-kernel.sh --kernel <version>`
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
- Try cleaning and rebuilding: `rm -rf build/ artifacts/ && ./scripts/kernel/build-kernel.sh`

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

## Maintainer Guide

### Setting Up Release Signing

**One-time setup for repository maintainers:**

1. **Generate the signing key:**
   ```bash
   task signing:generate-signing-key
   ```

   This creates:
   - `.gnupg/` - GPG home directory (gitignored)
   - `keys/signing-key.asc` - Public key (commit this)
   - `keys/signing-key-private.asc` - Private key (DO NOT COMMIT)

   The task will prompt you to add the key to GitHub Actions automatically.

2. **Update README.md with key fingerprint:**
   - Copy the fingerprint from the `task signing:generate-signing-key` output
   - Replace the `[TO BE ADDED]` placeholders in the "Verifying Releases" section

3. **Commit the public key:**
   ```bash
   git add keys/signing-key.asc README.md
   git commit -m "Add release signing key"
   git push
   ```

4. **Secure the private key:**
   - Back up `keys/signing-key-private.asc` to secure location
   - Delete local copy: `rm keys/signing-key-private.asc`
   - Key is now only in GitHub Actions secrets and your backup

**Testing the signing workflow:**

Before pushing changes, test signing and verification locally:
```bash
# Build a kernel
task kernel:get KERNEL_VERSION=6.1

# Sign the artifacts
task signing:sign-artifacts

# Verify the signature
task signing:verify-artifacts
```

This ensures the signing key and verification process work correctly.

**Key rotation:**

If the signing key needs to be rotated:
```bash
# Rotate the key (creates backup and generates new key)
task signing:rotate
```

This will:
- Create timestamped backup of current keys in `keys/backups/YYYY-MM-DD-HHMMSS/`
- Generate new signing key
- Optionally update GitHub Actions secret automatically
- Display new fingerprint for README update

After rotation:
1. Update README with new fingerprint
2. Commit new public key
3. Keep old public key in repo history for verifying old releases
4. Add note to README about key rotation date

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

This project is licensed under the Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.

The Linux kernel itself is licensed under GPL-2.0.

## References

- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker)
- [Firecracker Kernel Policy](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md)
- [Kernel.org](https://kernel.org)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)

## Acknowledgments

- Kernel configurations based on [Firecracker's official guest configs](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs)
- Built with GitHub Actions
- Inspired by the need for automated, reproducible Firecracker kernel builds
