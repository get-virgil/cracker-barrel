# How It Works

Technical implementation details of Cracker Barrel's kernel building and verification process.

## Kernel Version Detection

Uses kernel.org's JSON API to fetch the latest stable kernel version:

```bash
curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version'
```

**API Response** (example):
```json
{
  "latest_stable": {
    "version": "6.18.9",
    "moniker": "stable"
  },
  "releases": [...]
}
```

## Source Verification Process

### High Verification Flow

```
1. Download sha256sums.asc from kernel.org
   ↓
2. Import kernel.org autosigner GPG key
   - Key ID: 632D3A06589DA6B1
   - Fingerprint: B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1
   - Verify fingerprint matches hardcoded value
   ↓
3. Verify PGP signature
   gpg --verify sha256sums.asc
   ↓
4. Extract SHA256 for linux-VERSION.tar.xz
   grep "linux-${VERSION}.tar.xz" sha256sums.asc
   ↓
5. Calculate actual hash
   sha256sum build/linux-${VERSION}.tar.xz
   ↓
6. Compare hashes
   [expected] == [actual] ?
   ├─ Yes → Continue to extraction
   └─ No  → Fail build (security!)
   ↓
7. Extract sources
   tar xf build/linux-${VERSION}.tar.xz -C build/
```

### Medium Verification Flow

```
1. Download sha256sums.asc from kernel.org (HTTPS)
   ↓
2. Skip PGP verification
   ↓
3. Extract SHA256 for linux-VERSION.tar.xz
   ↓
4. Calculate actual hash
   ↓
5. Compare hashes
   ↓
6. Extract sources (if match)
```

### Disabled Verification Flow

```
1. Download tarball
   ↓
2. Extract immediately (no verification)
   ↓
3. Preserve cache for rebuilds
```

## Configuration Management

### Config Selection

```bash
if [ "$ARCH" = "x86_64" ]; then
    CONFIG_FILE="configs/microvm-kernel-x86_64.config"
elif [ "$ARCH" = "aarch64" ]; then
    CONFIG_FILE="configs/microvm-kernel-aarch64.config"
fi
```

### Config Application

```bash
# Copy config to source
cp "$CONFIG_FILE" build/linux-${VERSION}/.config

# Update config for new kernel
cd build/linux-${VERSION}
make olddefconfig  # Apply new defaults

# Build
make -j$(nproc)
```

**`olddefconfig`**: Automatically answers new config options with defaults, preserving existing choices.

## Compression & Checksums

### Kernel Compression

```bash
# x86_64
xz -9 -c artifacts/vmlinux-${VERSION}-x86_64 > artifacts/vmlinux-${VERSION}-x86_64.xz

# aarch64
xz -9 -c artifacts/Image-${VERSION}-aarch64 > artifacts/Image-${VERSION}-aarch64.xz
```

**Options**:
- `-9`: Maximum compression
- `-c`: Write to stdout

### Checksum Generation

```bash
cd artifacts/

# Generate checksums for decompressed binaries
sha256sum vmlinux-${VERSION}-x86_64 Image-${VERSION}-aarch64 > SHA256SUMS

# Sign checksums
gpg --detach-sign --armor --output SHA256SUMS.asc SHA256SUMS
```

**Why decompressed?**: Users verify after decompression, so checksums match what they use.

## Testing Workflow

### Test Rootfs Creation

```bash
# Create empty ext4 image
dd if=/dev/zero of=test-rootfs.ext4 bs=1M count=50
mkfs.ext4 test-rootfs.ext4

# Mount and populate
mkdir -p /tmp/rootfs
mount test-rootfs.ext4 /tmp/rootfs

# Create init script
cat > /tmp/rootfs/init <<'EOF'
#!/bin/sh
echo "✓ Kernel booted successfully"
poweroff -f
EOF
chmod +x /tmp/rootfs/init

# Create necessary directories
mkdir -p /tmp/rootfs/{bin,sbin,etc,proc,sys,dev}

# Unmount
umount /tmp/rootfs
```

### Firecracker Boot Test

```bash
# Start Firecracker API server
firecracker --api-sock /tmp/firecracker.sock &

# Configure VM via API
curl --unix-socket /tmp/firecracker.sock -X PUT \
  http://localhost/boot \
  -d '{
    "kernel_image_path": "artifacts/vmlinux-VERSION-x86_64",
    "boot_args": "console=ttyS0 reboot=k panic=1",
    "initrd_path": null
  }'

curl --unix-socket /tmp/firecracker.sock -X PUT \
  http://localhost/drives/rootfs \
  -d '{
    "drive_id": "rootfs",
    "path_on_host": "artifacts/test-rootfs.ext4",
    "is_root_device": true,
    "is_read_only": false
  }'

curl --unix-socket /tmp/firecracker.sock -X PUT \
  http://localhost/machine-config \
  -d '{
    "vcpu_count": 1,
    "mem_size_mib": 128
  }'

# Start VM
curl --unix-socket /tmp/firecracker.sock -X PUT \
  http://localhost/actions \
  -d '{"action_type": "InstanceStart"}'

# Wait for clean shutdown (max 60 seconds)
wait $FIRECRACKER_PID
```

## CI/CD Pipeline

### Build Matrix Execution

```yaml
strategy:
  matrix:
    arch: [x86_64, aarch64]
```

**Parallel execution**:
- Both architectures build simultaneously
- Total time ≈ single build time
- GitHub Actions provides separate runners

### Artifact Consolidation

```bash
# Download artifacts from matrix builds
mkdir -p artifacts/
mv kernel-x86_64/* artifacts/
mv kernel-aarch64/* artifacts/

# Generate combined checksums
cd artifacts/
sha256sum vmlinux-*-x86_64 Image-*-aarch64 > SHA256SUMS
```

### Release Publication

```bash
gh release create "v${VERSION}" \
  --title "Kernel ${VERSION}" \
  --notes "Automated build of Linux ${VERSION} for Firecracker" \
  artifacts/vmlinux-${VERSION}-x86_64.xz \
  artifacts/Image-${VERSION}-aarch64.xz \
  artifacts/config-${VERSION}-x86_64 \
  artifacts/config-${VERSION}-aarch64 \
  artifacts/SHA256SUMS \
  artifacts/SHA256SUMS.asc \
  keys/signing-key.asc
```

## Local Archive Management

### Index Structure

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

### Index Updates

```bash
# Read existing index
INDEX=$(cat archive/index.json)

# Add new entry
INDEX=$(echo "$INDEX" | jq \
  ".${ARCH}.\"${VERSION}\" = \"${VERSION}/${KERNEL_FILE}\"")

# Write updated index
echo "$INDEX" > archive/index.json
```

## Signing Key Management

### Key Generation

```bash
# Generate signing key
gpg --batch --generate-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: Cracker Barrel Release Signing
Name-Email: releases@cracker-barrel.dev
Expire-Date: 2y
EOF
```

**Properties**:
- RSA 4096-bit (strong)
- Signing only (not encryption)
- 2-year expiration
- No passphrase (CI usage)

### Key Rotation

```bash
# Create timestamped backup
TIMESTAMP=$(date -u +%Y-%m-%d-%H%M%S)
mkdir -p keys/backups/${TIMESTAMP}
cp keys/signing-key.asc keys/backups/${TIMESTAMP}/
cp keys/signing-key-private.asc keys/backups/${TIMESTAMP}/

# Generate new key
gpg --batch --generate-key ...

# Export new keys
gpg --armor --export releases@cracker-barrel.dev > keys/signing-key.asc
gpg --armor --export-secret-keys releases@cracker-barrel.dev > keys/signing-key-private.asc
```

**UTC timestamps**: Consistent timezone for CI and international teams.

## Performance Optimizations

### Parallel Compilation

```bash
make -j$(nproc)
```

Uses all available CPU cores.

### Cache Efficiency

```bash
# Source cache (with verification disabled)
build/linux-${VERSION}.tar.xz    # Reused
build/linux-${VERSION}/          # Reused

# Build cache
build/linux-${VERSION}/.o files  # Incremental builds
```

### Download Caching

```bash
# Firecracker binaries
bin/firecracker-${VERSION}  # Downloaded once

# Test rootfs
artifacts/test-rootfs.ext4  # Created once
```

## Error Handling

### Fail-Fast Verification

```bash
verify_checksum() {
    expected=$(grep "linux-${VERSION}.tar.xz" sha256sums.asc | awk '{print $1}')
    actual=$(sha256sum "build/linux-${VERSION}.tar.xz" | awk '{print $1}')

    if [ "$expected" != "$actual" ]; then
        echo "ERROR: Checksum mismatch!" >&2
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        exit 3
    fi
}
```

**Exit codes**:
- 0: Success
- 1: General error
- 2: Invalid arguments
- 3: Verification failed

### Idempotent Checks

```bash
# Skip if already built
if [ -f "artifacts/vmlinux-${VERSION}-${ARCH}" ]; then
    echo "Kernel ${VERSION} already built, skipping"
    exit 0
fi
```

## Next Steps

- [Security Model](security-model.md) - Threat analysis
- [Verification Levels](verification-levels.md) - Verification details
- [Building Kernels](../development/building-kernels.md) - Build process
