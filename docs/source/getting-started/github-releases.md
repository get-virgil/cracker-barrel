# Using GitHub Releases

The fastest way to get Firecracker-compatible kernels is to download pre-built binaries from GitHub releases.

## Quick Start

Visit the [Releases](https://github.com/get-virgil/cracker-barrel/releases) page to download pre-built kernels.

Each release includes:

- `vmlinux-{version}-x86_64.xz` - x86_64 kernel (compressed)
- `Image-{version}-aarch64.xz` - aarch64 kernel (compressed)
- `config-{version}-x86_64` - x86_64 kernel configuration
- `config-{version}-aarch64` - aarch64 kernel configuration
- `SHA256SUMS` - Checksums of decompressed kernels
- `SHA256SUMS.asc` - PGP signature of SHA256SUMS

## Download and Use

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

Replace `VERSION` with your desired kernel version (e.g., `6.18.9`).

### With Full Verification (Recommended)

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

## Chain of Trust

Understanding what verification protects:

1. Kernel sources verified with kernel.org autosigner PGP signature
2. Kernel sources verified with SHA256 checksums from kernel.org
3. Built kernels signed with Cracker Barrel release key
4. Users verify with Cracker Barrel public key

This ensures:
- ✅ Sources came from kernel.org (not tampered)
- ✅ Builds came from Cracker Barrel CI (not modified)
- ✅ Downloads weren't corrupted or replaced

## Automated Builds

Cracker Barrel builds kernels automatically:

- **Daily Schedule**: Runs at 2 AM UTC
- **Latest Stable**: Automatically detects and builds the latest stable kernel from kernel.org
- **Community Requests**: Users can request specific versions via GitHub issues

See [User Guide > GitHub Workflow](../user-guide/github-workflow/index.md) for more details on automated builds and requesting specific versions.

## Next Steps

- [Verify your download](verification.md) - Learn about the verification process
- [Use with Firecracker](firecracker-usage.md) - Boot your kernel in a microVM
- [Request a build](../user-guide/github-workflow/requesting-builds.md) - Need a specific kernel version?
