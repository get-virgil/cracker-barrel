# Reference

Technical reference documentation for Cracker Barrel.

## Contents

```{toctree}
:maxdepth: 1

project-structure
security-model
verification-levels
kernel-config
how-it-works
```

- [Project Structure](project-structure.md) - Directory layout and organization
- [Security Model](security-model.md) - Verification and threat analysis
- [Verification Levels](verification-levels.md) - high/medium/disabled explained
- [Kernel Configuration](kernel-config.md) - Firecracker-optimized kernel config
- [How It Works](how-it-works.md) - Technical implementation details

## Quick Reference

### Supported Architectures

- **x86_64**: Intel/AMD 64-bit (kernel: `vmlinux-*`)
- **aarch64**: ARM 64-bit (kernel: `Image-*`)

### Verification Levels

| Level | PGP | SHA256 | Use Case |
|-------|-----|--------|----------|
| `high` | ✅ | ✅ | Production (default) |
| `medium` | ❌ | ✅ | No GPG available |
| `disabled` | ❌ | ❌ | Development only |

### File Naming

| Architecture | Kernel Binary | Config |
|--------------|---------------|--------|
| x86_64 | `vmlinux-VERSION-x86_64` | `config-VERSION-x86_64` |
| aarch64 | `Image-VERSION-aarch64` | `config-VERSION-aarch64` |

### Key Files

| File | Purpose |
|------|---------|
| `Taskfile.dist.yaml` | Root task runner configuration |
| `tasks/*/Taskfile.dist.yaml` | Namespace-specific tasks |
| `scripts/kernel/*.sh` | Kernel build/download scripts |
| `scripts/signing/*.sh` | PGP signing operations |
| `configs/microvm-kernel-*.config` | Firecracker kernel configs |
| `keys/signing-key.asc` | Public PGP signing key |

## Next Steps

Explore the detailed references above for technical deep-dives.
