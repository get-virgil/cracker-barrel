# Troubleshooting

Common issues and solutions when using Cracker Barrel.

## Source Verification Fails

### Error: "gpg not found"

**Problem**: GPG is not installed on your system

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install gnupg

# Arch Linux
sudo pacman -S gnupg

# Or use medium verification (no PGP)
./scripts/kernel/build-kernel.sh --verification-level medium
```

### Error: "Failed to import autosigner key from any keyserver"

**Problem**: Cannot reach keyservers to import kernel.org's autosigner key

**Causes**:
- Firewall blocking keyserver ports (11371, 443)
- Proxy configuration issues
- Keyserver temporarily unavailable

**Solutions**:
```bash
# Try again later
./scripts/kernel/build-kernel.sh --kernel 6.1

# Check firewall/proxy settings
# Ensure outbound connections to keyservers are allowed

# Or use medium verification
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level medium
```

### Error: "PGP signature verification failed"

**Problem**: The `sha256sums.asc` file signature is invalid

**Severity**: 🚨 High - potential security issue

**Actions**:
1. Try downloading again (may be corrupted):
   ```bash
   rm build/sha256sums.asc
   ./scripts/kernel/build-kernel.sh --kernel 6.1
   ```

2. If problem persists, investigate before proceeding:
   - Check kernel.org status
   - Verify network integrity
   - Consider this a serious security concern

**Do NOT**:
- Bypass verification without understanding why it failed
- Use `--verification-level disabled` unless you understand the risk

### Error: "Checksum not found in sha256sums.asc"

**Problem**: Kernel version is too new - kernel.org hasn't updated checksums yet

**Timeline**:
- Usually happens within 15 minutes to a few hours after kernel release
- Example: 6.18.9 released Feb 6, 2026 at 9:00am, checksums available at 9:15am

**Solutions**:
```bash
# Best: Wait for checksums to be available
# Check kernel.org periodically

# Emergency only: Use disabled verification
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

### Error: "Checksum verification FAILED"

**Problem**: Downloaded tarball is corrupted or tampered with

**Actions**:
1. Remove the tarball:
   ```bash
   rm build/linux-*.tar.xz
   ```

2. Try downloading again:
   ```bash
   ./scripts/kernel/build-kernel.sh --kernel 6.1
   ```

3. If problem persists:
   - CDN may be serving corrupted files
   - Wait and retry later
   - Try different network connection

### Error: "Could not download checksums file from kernel.org"

**Problem**: Network connectivity issue or kernel.org is down

**Solutions**:
```bash
# Check internet connection
ping kernel.org

# Try again later
./scripts/kernel/build-kernel.sh --kernel 6.1

# Check kernel.org status
curl -I https://kernel.org/

# As last resort (local testing only): disable verification
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled
```

## Build Fails

### Error: "No space left on device"

**Problem**: Insufficient disk space (kernel builds require ~10GB)

**Solution**:
```bash
# Check available space
df -h

# Clean up old builds
task clean

# Remove specific version
rm -rf build/linux-6.1*
```

### Error: "gcc: command not found"

**Problem**: Build dependencies not installed

**Solution**:
```bash
# Install dependencies
task dev:install-deps

# Or manually (Ubuntu/Debian)
sudo apt-get install -y build-essential libncurses-dev bison flex \
    libssl-dev libelf-dev bc xz-utils wget curl
```

### Error: "make: *** [Makefile:1234] Error 2"

**Problem**: Kernel compilation failed

**Actions**:
1. Check full error output for specific issue
2. Ensure dependencies are installed:
   ```bash
   task dev:install-deps
   ```
3. Try cleaning and rebuilding:
   ```bash
   rm -rf build/ artifacts/
   task kernel:build
   ```
4. Check kernel version compatibility with configuration

### Error: "aarch64-linux-gnu-gcc: command not found"

**Problem**: Cross-compilation tools not installed

**Solution**:
```bash
# For ARM64 builds on x86_64 host
task dev:install-arm-tools

# For x86_64 builds on ARM64 host
task dev:install-x86-tools
```

## Testing Issues

### Error: "/dev/kvm: Permission denied"

**Problem**: User doesn't have permission to access KVM

**Solution**:
```bash
# Add user to kvm group
sudo usermod -aG kvm $USER

# Logout and login for changes to take effect

# Or run with sudo (not recommended)
sudo ./scripts/firecracker/test-kernel.sh
```

### Error: "/dev/kvm: No such file or directory"

**Problem**: KVM not available on system

**Causes**:
- Running in VM without nested virtualization
- Running on system without virtualization support
- KVM module not loaded

**Solutions**:
```bash
# Check if KVM module is loaded
lsmod | grep kvm

# Load KVM module (x86_64)
sudo modprobe kvm_intel  # For Intel CPUs
sudo modprobe kvm_amd    # For AMD CPUs

# Check BIOS/UEFI settings
# Ensure virtualization is enabled (Intel VT-x or AMD-V)
```

**Note**: GitHub Actions runners don't have KVM, so Firecracker tests must run locally.

### Error: "Kernel boot timeout"

**Problem**: Kernel doesn't boot or hangs

**Actions**:
1. Check kernel version compatibility
2. Verify correct architecture:
   ```bash
   file artifacts/vmlinux-6.1-x86_64
   # Should show: "Linux kernel x86 boot executable"
   ```
3. Try different kernel version:
   ```bash
   task firecracker:test-kernel KERNEL_VERSION=6.6
   ```
4. Check Firecracker version compatibility:
   ```bash
   task firecracker:test-kernel FIRECRACKER_VERSION=v1.10.0
   ```

## Download Issues

### Error: "404 Not Found" (GitHub Releases)

**Problem**: Kernel version not built yet

**Solution**:
```bash
# Request the build
# Visit: https://github.com/get-virgil/cracker-barrel/issues/new?template=build-request.yml

# Or build locally
task kernel:build KERNEL_VERSION=6.1
```

### Error: "Rate limit exceeded" (GitHub API)

**Problem**: Too many GitHub API requests

**Solution**:
```bash
# Set GitHub token (increases rate limit)
export GITHUB_TOKEN="your_token_here"
./scripts/kernel/download-kernel.sh

# Or wait for rate limit to reset (usually 1 hour)

# Or build locally instead
task kernel:build
```

## Ctrl-C Doesn't Work

### Error: Can't interrupt builds or tests

**Problem**: Terminal has signal generation disabled

**Check**:
```bash
stty -a | grep isig
# Should show: ... isig ...
# If shows: ... -isig ... (with dash), signals are disabled
```

**Solution**:
```bash
# Enable signal generation
stty isig

# Add to shell config for persistence
echo "stty isig" >> ~/.bashrc  # For Bash
echo "stty isig" >> ~/.zshrc   # For Zsh
```

## GitHub Actions Fails

### Error: "Permission denied" (Creating releases)

**Problem**: Workflow lacks required permissions

**Solution**: Ensure workflow has `contents: write`:
```yaml
permissions:
  contents: write
```

### Error: "Artifact upload fails"

**Problem**: Artifact size exceeds limits

**Limits**:
- 2GB per file for workflow artifacts
- 10GB total per workflow run

**Check**:
```bash
# Check artifact sizes
ls -lh artifacts/
```

### Error: "Task not found"

**Problem**: Task CLI failed to install

**Solution**: Check Task installation step in workflow:
```yaml
- name: Install Task
  run: sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

## General Tips

### Enable Debug Output

```bash
# For shell scripts
bash -x ./scripts/kernel/build-kernel.sh --kernel 6.1

# For Task
task --verbose kernel:build
```

### Check Logs

```bash
# GitHub Actions logs
# Go to Actions tab → Select workflow run → View logs

# Local build logs
# Captured in terminal output
```

### Clean Start

When in doubt, clean everything and start fresh:

```bash
# Remove all build artifacts
task clean

# Rebuild from scratch
task kernel:build KERNEL_VERSION=6.1
```

## Getting Help

If you're still stuck:

1. **Check existing issues**: [GitHub Issues](https://github.com/get-virgil/cracker-barrel/issues)
2. **Open a new issue**: Include:
   - Error message
   - Command you ran
   - Output logs
   - System information (OS, architecture)
3. **Review logs carefully**: Often the error message points to the exact issue

## Next Steps

- [Verification Levels](../reference/verification-levels.md) - Understanding security trade-offs
- [Security Model](../reference/security-model.md) - Verification process details
- [Development Prerequisites](../development/prerequisites.md) - Detailed dependency info
