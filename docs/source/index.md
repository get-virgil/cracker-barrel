# Cracker Barrel Documentation

Welcome to the Cracker Barrel documentation.

Automated builder for Firecracker-compatible Linux kernels. This project builds the latest stable Linux kernel daily with optimized configurations for AWS Firecracker microVMs.

## Quick Links

- [GitHub Repository](https://github.com/get-virgil/cracker-barrel)
- [Latest Release](https://github.com/get-virgil/cracker-barrel/releases/latest)
- [Request a Build](https://github.com/get-virgil/cracker-barrel/issues/new?template=build-request.yml)

## Getting Started

Choose your path based on your use case:

- **Using pre-built kernels?** Start with [GitHub Releases](getting-started/github-releases.md)
- **Building locally?** Start with [Local Builds](getting-started/local-builds.md)
- **Need verification details?** Read [Verification](getting-started/verification.md)

```{toctree}
:maxdepth: 2
:caption: Getting Started

getting-started/index
getting-started/github-releases
getting-started/local-builds
getting-started/verification
getting-started/firecracker-usage
```

## User Guide

Comprehensive guides for both GitHub-based and local-only workflows.

```{toctree}
:maxdepth: 2
:caption: User Guide

user-guide/index
user-guide/github-workflow/requesting-builds
user-guide/github-workflow/automated-releases
user-guide/github-workflow/ci-integration
user-guide/local-workflow/task-commands
user-guide/local-workflow/script-usage
user-guide/local-workflow/local-archive
user-guide/local-workflow/development-mode
user-guide/local-workflow/cross-compilation
user-guide/troubleshooting
```

## Development

For contributors and developers building kernels locally.

```{toctree}
:maxdepth: 2
:caption: Development

development/index
development/prerequisites
development/building-kernels
development/downloading-kernels
development/testing
development/cleaning-up
```

## Maintainer Guide

For repository maintainers managing releases and signing keys.

```{toctree}
:maxdepth: 2
:caption: Maintainer Guide

maintainer-guide/index
maintainer-guide/signing-setup
maintainer-guide/key-management
maintainer-guide/ci-workflow
```

## Reference

Technical reference documentation.

```{toctree}
:maxdepth: 2
:caption: Reference

reference/index
reference/project-structure
reference/security-model
reference/verification-levels
reference/kernel-config
reference/how-it-works
```

## Contributing

```{toctree}
:maxdepth: 1
:caption: Contributing

contributing
```

## Features

- **Daily Automated Builds**: GitHub Actions workflow runs daily to build the latest stable kernel
- **Multi-Architecture Support**: Builds for both x86_64 and aarch64 (ARM64)
- **Firecracker-Optimized**: Uses official Firecracker kernel configurations for minimal, fast-booting kernels
- **GitHub Releases**: Automatically publishes built kernels as GitHub releases with checksums
- **Cryptographic Verification**: PGP signature + SHA256 checksum verification of all kernel sources
- **Secure by Default**: Builds fail if verification unavailable - no unverified builds ever released
- **Local-First Workflow**: Task-based build system - CI runs the same commands you run locally
- **Community Build Requests**: Request specific kernel versions via GitHub issues

## License

This project is licensed under the Apache License 2.0. See the LICENSE.md file for details.

The Linux kernel itself is licensed under GPL-2.0.

## Acknowledgments

- Kernel configurations based on [Firecracker's official guest configs](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs)
- Built with GitHub Actions
- Inspired by the need for automated, reproducible Firecracker kernel builds
