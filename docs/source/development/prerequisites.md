# Prerequisites

Before building kernels, install Task and build dependencies.

## Task (Task Runner)

Task is required for both local development and CI.

### Installation

Install using the official script:

```bash
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

### Add to PATH

If `~/.local/bin` is not in your PATH:

```bash
# Bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Verify Installation

```bash
task --version
# Should show: Task version: v3.x.x
```

## Build Dependencies

### Ubuntu/Debian

Using Task (recommended):

```bash
task dev:install-deps
```

Or manually:

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    xz-utils \
    wget \
    curl \
    gnupg \
    jq
```

### Arch Linux

Using Task:

```bash
task dev:i-use-arch-btw
```

Or manually:

```bash
sudo pacman -S --needed \
    base-devel \
    ncurses \
    bc \
    xz \
    wget \
    curl \
    gnupg \
    jq
```

## Package Details

| Package | Purpose |
|---------|---------|
| `build-essential` / `base-devel` | GCC, make, and core build tools |
| `libncurses-dev` / `ncurses` | For kernel menuconfig |
| `bison` | Parser generator for kernel build |
| `flex` | Lexical analyzer for kernel build |
| `libssl-dev` | For kernel crypto support |
| `libelf-dev` | For BPF and kernel module support |
| `bc` | Calculator for kernel build |
| `xz-utils` / `xz` | For kernel compression |
| `wget`, `curl` | For downloading sources |
| `gnupg` | For PGP signature verification |
| `jq` | For JSON parsing (kernel.org API) |

## GPG (Optional with Caveats)

**GnuPG is required for `high` verification (default):**

- **With GPG**: Full PGP + SHA256 verification
- **Without GPG**: Must use `--verification-level medium` (SHA256 only)

If you cannot install GPG, use medium verification:

```bash
task kernel:build VERIFICATION_LEVEL=medium
```

See [Verification Levels](../reference/verification-levels.md) for security implications.

## Cross-Compilation Tools (Optional)

For building kernels for different architectures than your host.

### For ARM64 on x86_64 Host

```bash
# Using Task
task dev:install-arm-tools

# Or manually (Ubuntu/Debian)
sudo apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu

# Or manually (Arch Linux)
sudo pacman -S aarch64-linux-gnu-gcc
```

### For x86_64 on ARM64 Host

```bash
# Using Task
task dev:install-x86-tools

# Or manually (Ubuntu/Debian)
sudo apt-get install -y \
    gcc-x86-64-linux-gnu \
    g++-x86-64-linux-gnu \
    binutils-x86-64-linux-gnu

# Or manually (Arch Linux)
sudo pacman -S x86_64-linux-gnu-gcc
```

## Firecracker (For Testing)

Not required for building, but needed for local testing.

Firecracker is automatically downloaded by the test script:

```bash
# Test script auto-downloads Firecracker
task firecracker:test-kernel
```

Or download manually:

```bash
# Linux x86_64
wget https://github.com/firecracker-microvm/firecracker/releases/latest/download/firecracker-v1.10.1-x86_64.tgz
tar xzf firecracker-v1.10.1-x86_64.tgz
sudo cp release-v1.10.1-x86_64/firecracker-v1.10.1-x86_64 /usr/local/bin/firecracker
sudo chmod +x /usr/local/bin/firecracker
```

**Requirements**: KVM support (`/dev/kvm` must be accessible)

## Disk Space

Ensure sufficient disk space:

- **Kernel source**: ~1GB per version
- **Build artifacts**: ~1GB per version (x2 for both architectures)
- **Compressed releases**: ~50-100MB per kernel
- **Working space**: ~10GB total recommended

Check available space:

```bash
df -h
```

## Verifying Setup

Check all dependencies are installed:

```bash
# Task
task --version

# Build tools
gcc --version
make --version

# Kernel build requirements
flex --version
bison --version
bc --version

# Verification tools
gpg --version
jq --version

# Cross-compilation (if installed)
aarch64-linux-gnu-gcc --version  # For ARM64 on x86_64
x86_64-linux-gnu-gcc --version   # For x86_64 on ARM64
```

## Next Steps

- [Building Kernels](building-kernels.md) - Build kernels from source
- [Testing](testing.md) - Test kernels with Firecracker
- [Troubleshooting](../user-guide/troubleshooting.md) - Common issues
