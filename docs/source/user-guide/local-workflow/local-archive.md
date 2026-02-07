# Local Archive

When you sign artifacts locally with `task signing:sign-artifacts`, they're automatically archived to `archive/{version}/` (git-ignored). This creates a local mirror of what gets published to GitHub releases, enabling fully local-first development.

## Overview

The local archive provides:

- **Offline Development**: Keep all signed kernels locally without GitHub dependency
- **Fast Access**: Instantly access any previously built kernel
- **Testing**: Test release structure locally before publishing
- **Mirrors Releases**: Exact same file layout as GitHub releases

## Archive Structure

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

## Index File

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

## Creating Archive Entries

### Via Task

```bash
# Build kernel
task kernel:build KERNEL_VERSION=6.1

# Sign artifacts (creates archive entry)
task signing:sign-artifacts
```

### Via Scripts

```bash
# Build kernel
./scripts/kernel/build-kernel.sh --kernel 6.1

# Sign artifacts (creates archive entry)
export SIGNING_KEY="$(cat keys/signing-key-private.asc)"
./scripts/signing/sign-artifacts.sh
```

## Using the Archive

### List Available Kernels

```bash
# View index
cat archive/index.json | jq

# List all versions for x86_64
cat archive/index.json | jq '.x86_64 | keys'

# List all versions for aarch64
cat archive/index.json | jq '.aarch64 | keys'
```

### Access Archived Kernels

```bash
# Find kernel path
KERNEL_PATH=$(cat archive/index.json | jq -r '.x86_64["6.18.9"]')

# Use the kernel
xz -d -c archive/${KERNEL_PATH} > vmlinux-6.18.9-x86_64
firecracker --kernel-path vmlinux-6.18.9-x86_64 ...
```

### Verify Archived Kernels

```bash
# Navigate to version directory
cd archive/6.18.9

# Verify signature
gpg --verify SHA256SUMS.asc SHA256SUMS

# Decompress and verify checksum
xz -d vmlinux-6.18.9-x86_64.xz
sha256sum -c SHA256SUMS --ignore-missing
```

## Archive Management

### Location

The archive directory is git-ignored and lives at the repository root:

```
/home/kazw/Projects/cracker-barrel/master/archive/
```

### Disk Space

Each kernel version (both architectures) takes approximately:

- Compressed: ~100MB
- With configs and checksums: ~105MB

Plan accordingly for multiple versions.

### Cleanup

```bash
# Remove specific version
rm -rf archive/6.18.8

# Remove all archived kernels
rm -rf archive/*

# Rebuild index
task signing:sign-artifacts  # Will recreate index on next sign
```

## Offline Workflow

The local archive enables completely offline development:

1. **Build kernels locally**:
   ```bash
   task kernel:build KERNEL_VERSION=6.1
   task kernel:build KERNEL_VERSION=6.6
   task kernel:build KERNEL_VERSION=6.18
   ```

2. **Sign and archive**:
   ```bash
   task signing:sign-artifacts
   ```

3. **Work offline**:
   - No GitHub required
   - All kernels available locally
   - Full verification possible

4. **Distribute via alternative means**:
   - USB drives
   - Internal network shares
   - Private artifact repositories

## Integration with CI

The archive structure mirrors GitHub releases exactly. You can:

1. Test release structure locally before pushing
2. Use local archive as a staging area
3. Sync local archive to private artifact storage
4. Replace GitHub releases with internal hosting

## Next Steps

- [Task Commands](task-commands.md) - Commands for managing archive
- [Development Mode](development-mode.md) - Building custom kernels
- [Signing Setup](../../maintainer-guide/signing-setup.md) - Setting up signing keys
