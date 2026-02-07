# Automated Releases

Cracker Barrel automatically builds the latest stable kernel daily.

## Daily Build Schedule

- **Schedule**: Runs at 2 AM UTC daily
- **Target**: Latest stable kernel from kernel.org
- **Idempotent**: Skips build if release already exists

## Build Process

The GitHub Actions workflow:

1. **Check Version** - Fetches latest stable kernel from kernel.org
2. **Check Existing Release** - Skips build if release already exists
3. **Build Matrix** - Builds for both x86_64 and aarch64 in parallel
4. **Create Release** - Consolidates and signs artifacts

### Build Matrix (Parallel)

Both architectures build simultaneously:

- **x86_64 Build**
  - Installs dependencies via Task
  - Verifies kernel sources (PGP + SHA256)
  - Builds with Firecracker config
  - Compresses with xz
  - Uploads artifacts

- **aarch64 Build**
  - Same process for ARM64

### Release Creation

After both builds complete:

1. Downloads artifacts from both builds
2. Generates SHA256SUMS for decompressed kernels
3. Signs SHA256SUMS with release key
4. Publishes to GitHub Releases

## Security Guarantees

**All automated builds:**

- ✅ Use `high` verification (PGP + SHA256)
- ✅ Never bypass verification
- ✅ Fail-secure if verification unavailable
- ✅ Wait for kernel.org checksums (hours after release)
- ✅ PGP-sign all release artifacts

**What this means:**

- No kernel is ever released without full cryptographic verification
- CI never takes shortcuts for convenience
- Same security as building locally with `high` verification

## Manual Triggers

### Via GitHub UI

1. Go to the "Actions" tab
2. Select "Build Firecracker-Compatible Kernel"
3. Click "Run workflow"
4. Optionally specify a kernel version (e.g., `6.18.8`)
   - Leave empty to build the latest stable version
   - Specify a version to build a specific kernel release

### Via GitHub CLI

```bash
# Build latest stable kernel
gh workflow run build-kernel.yml

# Build a specific kernel version
gh workflow run build-kernel.yml -f kernel_version=6.18.8

# Monitor the workflow run
gh run list --workflow=build-kernel.yml --limit 5
gh run watch
```

## Build Failures

### Expected Failures

**Verification Unavailable:**

If a new kernel version is released and the workflow fails with verification errors, this is expected and correct behavior. The workflow will succeed once kernel.org updates their `sha256sums.asc` file (typically within hours of kernel release).

This fail-secure behavior ensures distributed kernels are always cryptographically verified.

**Example scenario:**
- 9:00 AM: Kernel 6.18.9 released
- 9:05 AM: Build workflow runs
- 9:05 AM: Fails (kernel.org checksums not ready)
- 9:45 AM: Build workflow runs again
- 9:45 AM: Succeeds (kernel.org updated checksums)

### Unexpected Failures

- **Dependency issues**: Task or build tools failed to install
- **Disk space**: Kernel builds require ~10GB
- **GitHub API rate limits**: Affects release checks
- **Artifact upload**: Check artifact size limits (2GB per file)

Check the workflow logs for specific error messages.

## Customizing the Schedule

Want a different build schedule? Modify `.github/workflows/build-kernel.yml`:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Change this line
```

Cron format: `minute hour day month weekday`

Examples:
- `0 */6 * * *` - Every 6 hours
- `0 0 * * 0` - Weekly (Sunday at midnight)
- `0 12 1 * *` - Monthly (1st of month at noon)

## Next Steps

- [Request a Build](requesting-builds.md) - Need a specific version now?
- [CI/CD Integration](ci-integration.md) - Use releases in your pipelines
- [Maintainer Guide > CI Workflow](../../maintainer-guide/ci-workflow.md) - Technical CI details
