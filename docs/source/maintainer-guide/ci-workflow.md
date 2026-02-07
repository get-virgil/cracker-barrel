# CI Workflow

Understanding the GitHub Actions build and release workflow.

## Workflow Overview

The `.github/workflows/build-kernel.yml` workflow automates kernel building and release publishing.

### Triggers

The workflow runs on:

1. **Schedule**: Daily at 2 AM UTC
   ```yaml
   schedule:
     - cron: '0 2 * * *'
   ```

2. **Manual dispatch**: Via GitHub UI or `gh` CLI
   ```yaml
   workflow_dispatch:
     inputs:
       kernel_version:
         description: 'Kernel version to build (e.g., 6.18.8)'
         required: false
   ```

3. **Issue-based triggers**: Community build requests (separate workflow)

## Workflow Steps

### 1. Check Version

```yaml
- name: Get kernel version
  run: |
    if [ -n "${{ github.event.inputs.kernel_version }}" ]; then
      echo "KERNEL_VERSION=${{ github.event.inputs.kernel_version }}" >> $GITHUB_ENV
    else
      VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
      echo "KERNEL_VERSION=$VERSION" >> $GITHUB_ENV
    fi
```

Determines which kernel to build:

- Manual trigger: Uses specified version
- Scheduled run: Uses latest stable from kernel.org

### 2. Check Existing Release

```yaml
- name: Check if release exists
  id: check_release
  run: |
    if gh release view "v$KERNEL_VERSION" > /dev/null 2>&1; then
      echo "exists=true" >> $GITHUB_OUTPUT
    else
      echo "exists=false" >> $GITHUB_OUTPUT
    fi
```

Skips build if release already exists (idempotent behavior).

### 3. Build Matrix

```yaml
strategy:
  matrix:
    arch: [x86_64, aarch64]
```

Builds both architectures in parallel:

```yaml
- name: Install Task
  run: sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

- name: Install dependencies
  run: task dev:install-deps

- name: Build kernel
  run: task kernel:build KERNEL_VERSION=${{ env.KERNEL_VERSION }} ARCH=${{ matrix.arch }}
```

**Security**: Always uses `high` verification (PGP + SHA256).

### 4. Upload Artifacts

```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: kernel-${{ matrix.arch }}
    path: artifacts/
```

Uploads build artifacts for consolidation step.

### 5. Create Release

After both builds complete:

```yaml
- name: Download artifacts
  uses: actions/download-artifact@v4

- name: Consolidate artifacts
  run: task release:consolidate-artifacts

- name: Sign artifacts
  env:
    SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
  run: task signing:sign-artifacts

- name: Create GitHub Release
  run: |
    gh release create "v$KERNEL_VERSION" \
      --title "Kernel $KERNEL_VERSION" \
      --notes "..." \
      artifacts/*
```

## Local-First Philosophy

The CI workflow uses **exact same commands** as local development:

| Operation | Local | CI |
|-----------|-------|-----|
| Install deps | `task dev:install-deps` | `task dev:install-deps` |
| Build kernel | `task kernel:build` | `task kernel:build` |
| Sign artifacts | `task signing:sign-artifacts` | `task signing:sign-artifacts` |

This ensures:

- ✅ CI behavior is reproducible locally
- ✅ Testing locally = testing CI
- ✅ No CI-specific scripts to maintain
- ✅ Easy to debug CI failures

## Security Guarantees

### Verification

All automated builds use `high` verification:

```yaml
- name: Build kernel
  run: task kernel:build VERIFICATION_LEVEL=high
```

This ensures:

- PGP signature verification of kernel sources
- SHA256 checksum verification
- Build fails if verification unavailable (fail-secure)

### Fail-Secure Behavior

If kernel.org hasn't updated checksums:

```
✗ Checksum not found in sha256sums.asc
Build failed
```

Workflow will:

- ❌ NOT bypass verification
- ❌ NOT use `disabled` verification
- ✅ Wait for next scheduled run
- ✅ Succeed once checksums available

### Signing

All releases are PGP-signed:

```yaml
- name: Sign artifacts
  env:
    SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
  run: task signing:sign-artifacts
```

Uses the `SIGNING_KEY` secret set during [Signing Setup](signing-setup.md).

## Manual Triggers

### Via GitHub UI

1. Go to **Actions** tab
2. Select "Build Firecracker-Compatible Kernel"
3. Click "Run workflow"
4. Optionally specify kernel version
5. Click "Run workflow" button

### Via GitHub CLI

```bash
# Build latest stable
gh workflow run build-kernel.yml

# Build specific version
gh workflow run build-kernel.yml -f kernel_version=6.18.8

# Monitor run
gh run watch
```

## Build Timeline

Typical build timeline:

- **Start**: Workflow triggered
- **+1 min**: Dependencies installed
- **+2 min**: Source verification (may take longer if keyserver slow)
- **+3-30 min**: Parallel builds (x86_64 + aarch64)
- **+31 min**: Artifact consolidation
- **+32 min**: Signing
- **+33 min**: Release created

Total: ~30-45 minutes

## Troubleshooting CI

### Build Fails with Verification Error

**Expected if kernel just released:**

```
Error: Checksum not found in sha256sums.asc
```

**Solution**: Wait for kernel.org to update checksums (typically hours after release).

### Workflow Skips Build

```
Release v6.18.9 already exists, skipping build
```

**Solution**: This is correct (idempotent). Delete release to rebuild:

```bash
gh release delete v6.18.9
gh workflow run build-kernel.yml -f kernel_version=6.18.9
```

### Artifact Upload Fails

```
Error: Artifact size exceeds limit
```

**Causes**:

- Workflow artifacts limited to 2GB per file
- Kernel + sources might exceed limit

**Solution**:

- Don't upload source directories
- Only upload compressed kernels
- Check `actions/upload-artifact` paths

### Signing Fails

```
Error: SIGNING_KEY secret not found
```

**Solution**: Ensure `SIGNING_KEY` secret is configured:

```bash
gh secret set SIGNING_KEY < keys/signing-key-private.asc
```

### Release Creation Fails

```
Error: Resource not accessible by integration
```

**Solution**: Ensure workflow has `contents: write` permission:

```yaml
permissions:
  contents: write
```

## Workflow Customization

### Change Schedule

Edit `.github/workflows/build-kernel.yml`:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Change this
```

Examples:

- `0 */6 * * *` - Every 6 hours
- `0 0 * * 0` - Weekly (Sunday midnight)
- `0 12 1 * *` - Monthly (1st day noon)

### Add Architectures

Add to matrix:

```yaml
strategy:
  matrix:
    arch: [x86_64, aarch64, riscv64]  # Add more
```

Requires:

- Cross-compilation tools
- Firecracker config for architecture
- Kernel config adjustments

### Custom Build Steps

Add steps before/after build:

```yaml
- name: Custom pre-build step
  run: |
    # Your custom logic
    echo "Preparing build..."

- name: Build kernel
  run: task kernel:build

- name: Custom post-build step
  run: |
    # Your custom logic
    echo "Build complete!"
```

## Monitoring

### View Workflow Runs

```bash
# List recent runs
gh run list --workflow=build-kernel.yml --limit 10

# View specific run
gh run view <run-id>

# Download logs
gh run view <run-id> --log
```

### Workflow Status Badge

Add to README:

```markdown
[![Build Kernel](https://github.com/get-virgil/cracker-barrel/actions/workflows/build-kernel.yml/badge.svg)](https://github.com/get-virgil/cracker-barrel/actions/workflows/build-kernel.yml)
```

### Notifications

Enable GitHub notifications for workflow failures:

1. Settings → Notifications
2. Enable "Actions" notifications
3. Get notified on failures

## Next Steps

- [Signing Setup](signing-setup.md) - Configure release signing
- [Key Management](key-management.md) - Manage signing keys
- [Automated Releases](../user-guide/github-workflow/automated-releases.md) - User-facing release docs
