# Project Structure

Directory layout and file organization of the Cracker Barrel repository.

## Root Directory

```
.
├── .github/                  # GitHub configuration
├── configs/                  # Kernel configurations
├── keys/                     # PGP signing keys
├── scripts/                  # Build and automation scripts
├── tasks/                    # Task runner configurations
├── Taskfile.dist.yaml        # Root task runner
├── README.md                 # Main documentation
└── LICENSE.md                # Apache 2.0 license
```

## GitHub Workflows

```
.github/
└── workflows/
    └── build-kernel.yml      # Automated kernel build workflow
```

**Purpose**: CI/CD automation for building and releasing kernels

## Kernel Configurations

```
configs/
├── microvm-kernel-x86_64.config    # x86_64 Firecracker config
└── microvm-kernel-aarch64.config   # aarch64 Firecracker config
```

**Source**: Based on [Firecracker's official microvm-kernel configs](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs)

**Version**: 6.1 configs, updated via `make olddefconfig` for newer kernels

## Signing Keys

```
keys/
├── signing-key.asc           # Public signing key (committed)
├── signing-key-private.asc   # Private key (gitignored, DO NOT COMMIT)
├── backups/                  # Historical key backups (gitignored)
│   └── YYYY-MM-DD-HHMMSS/
│       ├── signing-key.asc
│       └── signing-key-private.asc
└── README.md                 # Key management documentation
```

**Security**: Only public key is committed. Private key stored in GitHub Actions secrets and maintainer backups.

## Scripts

```
scripts/
├── kernel/
│   ├── build-kernel.sh       # Build kernels from source
│   └── download-kernel.sh    # Download pre-built kernels
├── firecracker/
│   ├── create-test-rootfs.sh # Create minimal test rootfs
│   └── test-kernel.sh        # End-to-end kernel testing
└── signing/
    ├── sign-artifacts.sh     # Sign artifacts with PGP
    ├── verify-artifacts.sh   # Verify PGP signatures
    ├── generate-signing-key.sh     # Generate new signing key
    ├── rotate-signing-key.sh       # Rotate signing key
    ├── check-key-expiry.sh         # Check key expiration
    └── remove-signing-key.sh       # Remove signing key
```

**Design**: Scripts are standalone and can be called directly or via Task

## Task Configurations

```
tasks/
├── kernel/Taskfile.dist.yaml      # kernel:* tasks
├── firecracker/Taskfile.dist.yaml # firecracker:* tasks
├── clean/Taskfile.dist.yaml       # clean:* tasks
├── signing/Taskfile.dist.yaml     # signing:* tasks
├── release/Taskfile.dist.yaml     # release:* tasks (CI)
└── dev/Taskfile.dist.yaml         # dev:* tasks
```

**Organization**: Namespace-based task organization for logical grouping

## Build Artifacts (gitignored)

```
build/                        # Build artifacts (gitignored)
├── linux-*.tar.xz            # Cached kernel source tarballs
├── linux-*/                  # Extracted kernel sources
└── sha256sums.asc            # PGP-signed checksums from kernel.org
```

**Behavior**:

- With verification enabled: Deleted before each build
- With verification disabled: Preserved for development

## Output Artifacts (gitignored)

```
artifacts/                    # Built kernels (gitignored)
├── vmlinux-VERSION-x86_64         # x86_64 kernel (uncompressed)
├── vmlinux-VERSION-x86_64.xz      # x86_64 kernel (compressed)
├── config-VERSION-x86_64          # x86_64 configuration
├── Image-VERSION-aarch64          # aarch64 kernel (uncompressed)
├── Image-VERSION-aarch64.xz       # aarch64 kernel (compressed)
├── config-VERSION-aarch64         # aarch64 configuration
├── SHA256SUMS                     # Checksums (decompressed binaries)
├── SHA256SUMS.asc                 # PGP signature of checksums
├── test-rootfs.ext4               # Test rootfs for Firecracker
└── signing-key.asc                # Copy of public key
```

**Purpose**: Final build outputs, ready for release or testing

## Local Archive (gitignored)

```
archive/                      # Local signed kernel archive (gitignored)
├── index.json                # Kernel version index
└── VERSION/
    ├── vmlinux-VERSION-x86_64.xz
    ├── Image-VERSION-aarch64.xz
    ├── config-VERSION-x86_64
    ├── config-VERSION-aarch64
    ├── SHA256SUMS
    ├── SHA256SUMS.asc
    └── signing-key.asc
```

**Purpose**: Local mirror of GitHub releases for offline workflow

## Cached Binaries (gitignored)

```
bin/                          # Downloaded binaries (gitignored)
└── firecracker-*             # Firecracker binaries for testing
```

**Purpose**: Cached Firecracker binaries to avoid repeated downloads

## File Naming Conventions

### Kernel Binaries

- **x86_64**: `vmlinux-VERSION-ARCH`
- **aarch64**: `Image-VERSION-ARCH`

Example:
- `vmlinux-6.18.9-x86_64`
- `Image-6.18.9-aarch64`

### Compressed Kernels

Add `.xz` extension:
- `vmlinux-6.18.9-x86_64.xz`
- `Image-6.18.9-aarch64.xz`

### Configurations

- `config-VERSION-ARCH`

Example:
- `config-6.18.9-x86_64`
- `config-6.18.9-aarch64`

## Gitignore Patterns

Critical gitignored paths:

```gitignore
# Build artifacts
build/
artifacts/
bin/

# Local archive
archive/

# Private signing key
keys/signing-key-private.asc
keys/backups/

# GPG directory
.gnupg/
```

**Security**: Private keys and build artifacts never committed

## Task Namespaces

| Namespace | Purpose | Examples |
|-----------|---------|----------|
| `kernel:*` | Kernel operations | `kernel:get`, `kernel:build` |
| `firecracker:*` | Testing | `firecracker:test-kernel` |
| `clean:*` | Cleanup | `clean`, `clean:kernel` |
| `signing:*` | Key management | `signing:generate-signing-key` |
| `release:*` | CI operations | `release:consolidate-artifacts` |
| `dev:*` | Development utils | `dev:install-deps` |

## CI Artifacts

GitHub Actions workflow artifacts (temporary, 90 days):

- `kernel-x86_64/` - x86_64 build artifacts
- `kernel-aarch64/` - aarch64 build artifacts

These are consolidated and published to GitHub Releases.

## Next Steps

- [How It Works](how-it-works.md) - Technical implementation details
- [Development Guide](../development/index.md) - Using the project structure
