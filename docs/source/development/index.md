# Development Guide

This guide covers building, testing, and developing Cracker Barrel locally.

## Getting Started

```{toctree}
:maxdepth: 1

prerequisites
building-kernels
downloading-kernels
testing
cleaning-up
```

- [Prerequisites](prerequisites.md) - Install Task and dependencies
- [Building Kernels](building-kernels.md) - Detailed build process
- [Downloading Kernels](downloading-kernels.md) - Download workflow details
- [Testing](testing.md) - Test kernels with Firecracker
- [Cleaning Up](cleaning-up.md) - Managing artifacts and caches

## Quick Start

```bash
# 1. Install dependencies
task dev:install-deps

# 2. Build or download kernel
task kernel:get

# 3. Test with Firecracker
task firecracker:test-kernel

# 4. Clean up
task clean
```

## Development Workflows

### Local Build Workflow

For kernel development and experimentation:

1. [Install prerequisites](prerequisites.md)
2. [Build from source](building-kernels.md)
3. [Test locally](testing.md)
4. [Iterate and rebuild](../user-guide/local-workflow/development-mode.md)

### Quick Test Workflow

For testing pre-built kernels:

1. [Download kernel](downloading-kernels.md)
2. [Test with Firecracker](testing.md)

### CI/CD Workflow

For automated pipelines:

1. [Integrate releases](../user-guide/github-workflow/ci-integration.md)
2. [Verify kernels](../getting-started/verification.md)
3. Run your tests

## Next Steps

Start with [Prerequisites](prerequisites.md) to set up your development environment.
