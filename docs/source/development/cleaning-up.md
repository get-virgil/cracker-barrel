# Cleaning Up

Remove build artifacts, caches, and temporary files to free disk space.

## Quick Cleanup

```bash
# Remove all artifacts and caches (~10GB+)
task clean
```

## Cleanup Options

### Clean Everything

```bash
# Remove all build artifacts and caches
task clean
```

Removes:
- `build/` - Kernel sources and build artifacts (~10GB)
- `artifacts/` - Built kernels and configs (~1GB)
- `bin/` - Downloaded Firecracker binaries (~50MB)

### Clean Kernels Only

```bash
# Remove only kernel artifacts (keep Firecracker and rootfs)
task clean:kernel
```

Removes:
- `artifacts/vmlinux-*` - x86_64 kernels
- `artifacts/Image-*` - aarch64 kernels
- `artifacts/config-*` - Kernel configs
- `build/linux-*` - Kernel sources and build artifacts

Keeps:
- `bin/firecracker-*` - Firecracker binaries
- `artifacts/test-rootfs.ext4` - Test rootfs

### Clean Specific Version

```bash
# Remove specific kernel version
task clean:kernel VERSION=6.1
```

Removes:
- `artifacts/vmlinux-6.1-*`
- `artifacts/Image-6.1-*`
- `artifacts/config-6.1-*`
- `build/linux-6.1*`

### Clean Firecracker

```bash
# Remove cached Firecracker binaries
task clean:firecracker
```

Removes:
- `bin/firecracker-*` - All Firecracker versions

### Clean Test Rootfs

```bash
# Remove test rootfs
task clean:rootfs
```

Removes:
- `artifacts/test-rootfs.ext4`

Note: Rootfs is automatically recreated on next test.

## Manual Cleanup

### Remove All Artifacts

```bash
# Remove everything
rm -rf build/ artifacts/ bin/
```

### Remove Specific Files

```bash
# Remove specific kernel
rm -f artifacts/vmlinux-6.1-x86_64*
rm -f artifacts/Image-6.1-aarch64*
rm -f artifacts/config-6.1-*

# Remove kernel sources
rm -rf build/linux-6.1*

# Remove Firecracker binaries
rm -rf bin/
```

### Remove Test Rootfs

```bash
rm -f artifacts/test-rootfs.ext4
```

## Disk Space Management

### Check Disk Usage

```bash
# List all artifacts with sizes
task dev:list-artifacts

# Or manually
du -h artifacts/ build/ bin/
```

### Typical Disk Usage

Per kernel version:

- **Source tarball**: ~150MB compressed
- **Extracted sources**: ~1GB
- **Build artifacts**: ~500MB
- **Compressed kernel**: ~50MB
- **Uncompressed kernel**: ~100MB

Total per version (both architectures): ~2GB

### Free Up Space

If running low on disk space:

```bash
# Remove old kernel versions
task clean:kernel VERSION=6.1

# Remove all kernel sources (keep built kernels)
rm -rf build/

# Remove everything except latest kernel
# (requires manual selection)
ls artifacts/
rm -f artifacts/vmlinux-6.1-*  # Old version
# Keep artifacts/vmlinux-6.18.9-*  # Latest
```

## Cleaning Local Archive

The local archive (`archive/`) is git-ignored and not cleaned by default.

### Clean Archive

```bash
# Remove specific version from archive
rm -rf archive/6.1.75

# Remove all archived kernels
rm -rf archive/*

# Keep archive structure, remove kernels
find archive/ -name "*.xz" -delete
```

See [Local Archive](../user-guide/local-workflow/local-archive.md) for details.

## Cleaning After Development

After kernel development, clean sources:

```bash
# Remove modified sources
rm -rf build/linux-6.1*

# Rebuild clean version
task kernel:build KERNEL_VERSION=6.1
```

## Automated Cleanup

Create cleanup scripts for regular maintenance:

```bash
#!/bin/bash
# cleanup.sh - Remove kernels older than 30 days

DAYS=30

find artifacts/ -name "vmlinux-*" -mtime +${DAYS} -delete
find artifacts/ -name "Image-*" -mtime +${DAYS} -delete
find build/ -type d -name "linux-*" -mtime +${DAYS} -exec rm -rf {} +

echo "Cleaned up artifacts older than ${DAYS} days"
```

## Pre-Commit Cleanup

Before committing changes:

```bash
# Ensure clean working directory
task clean

# Verify nothing to commit
git status
```

Note: Build artifacts and caches are git-ignored automatically.

## CI Cleanup

GitHub Actions automatically cleans up after each run. No manual cleanup needed for CI artifacts.

For workflow artifacts (stored for 90 days):

```bash
# List workflow artifacts
gh run list --workflow=build-kernel.yml

# Download artifacts
gh run download <run-id>

# Artifacts expire automatically after 90 days
```

## Troubleshooting Cleanup

### Permission Denied

If cleanup fails with permission errors:

```bash
# Check file ownership
ls -la build/ artifacts/

# Fix ownership
sudo chown -R $USER:$USER build/ artifacts/

# Try cleanup again
task clean
```

### Disk Still Full

After cleanup, disk still full:

```bash
# Check actual disk usage
df -h

# Find large files
du -h -d 1 | sort -h

# Check Docker if used
docker system df
docker system prune

# Check system logs
sudo journalctl --disk-usage
sudo journalctl --vacuum-size=100M
```

## Next Steps

- [List Artifacts](../user-guide/local-workflow/task-commands.md#development-utilities) - See what's cached
- [Local Archive](../user-guide/local-workflow/local-archive.md) - Archive management
- [Building Kernels](building-kernels.md) - Rebuild after cleanup
