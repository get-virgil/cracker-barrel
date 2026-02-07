# Getting Started

Cracker Barrel provides Firecracker-optimized Linux kernels through two main workflows:

## Choose Your Path

### GitHub Releases (Recommended for Most Users)

Download pre-built, cryptographically signed kernels from GitHub releases. This is the fastest way to get started and requires no build tools.

**Best for:**
- Running Firecracker microVMs in production
- Quick testing and development
- CI/CD pipelines that need verified kernels

See [Using GitHub Releases](github-releases.md) to get started.

### Local Builds (For Kernel Development)

Build kernels from source on your local machine. Gives you full control over the build process and enables kernel modifications.

**Best for:**
- Kernel development and experimentation
- Offline/airgapped environments
- Custom kernel configurations
- Learning about kernel builds

See [Building Locally](local-builds.md) to get started.

## Next Steps

```{toctree}
:maxdepth: 1

github-releases
local-builds
verification
firecracker-usage
```

No matter which path you choose, we **strongly recommend** reading [Verifying Releases](verification.md) to understand how to cryptographically verify your kernels.
