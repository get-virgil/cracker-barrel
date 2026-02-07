# Contributing

Contributions are welcome! This guide helps you get started contributing to Cracker Barrel.

## Ways to Contribute

### Report Issues

Found a bug or have a feature request?

- [Open an issue](https://github.com/get-virgil/cracker-barrel/issues/new)
- Include relevant details (error messages, system info, steps to reproduce)
- Check existing issues first to avoid duplicates

### Request Kernel Builds

Need a specific kernel version?

- [Request a build](https://github.com/get-virgil/cracker-barrel/issues/new?template=build-request.yml)
- See [Requesting Builds](user-guide/github-workflow/requesting-builds.md) for details

### Submit Pull Requests

Want to contribute code?

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## Development Setup

### Prerequisites

```bash
# Install Task
sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# Install dependencies
task dev:install-deps
```

See [Development > Prerequisites](development/prerequisites.md) for details.

### Local Testing

```bash
# Build a kernel
task kernel:build KERNEL_VERSION=6.1

# Test it
task firecracker:test-kernel KERNEL_VERSION=6.1
```

See [Development > Testing](development/testing.md) for details.

## Areas for Improvement

### High Priority

- [ ] Support for longterm kernels (e.g., 6.6.x LTS)
- [ ] Extended boot tests with virtio device verification
- [ ] CI testing on infrastructure with KVM support

### Medium Priority

- [ ] Custom kernel configuration options
- [ ] Additional architectures (e.g., RISC-V)
- [ ] Build time optimizations
- [ ] Documentation improvements

### Low Priority

- [ ] Alternative compression formats (zstd, lz4)
- [ ] Kernel debug symbol packages
- [ ] Alternative CI platforms

## Code Guidelines

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote variables: `"$VAR"` not `$VAR`
- Use meaningful function names
- Add comments for complex logic

### Task Files

- Follow existing namespace structure
- Document tasks with descriptions
- Keep tasks focused and composable
- Use variables for configurability

### Documentation

- Use Markdown for all docs
- Follow existing structure
- Include code examples
- Link to related docs

### Commit Messages

Follow conventional commits:

```
type(scope): brief description

Longer explanation if needed.

- Bullet points for details
- Use present tense ("add" not "added")
- Reference issues: #123
```

**Types**: feat, fix, docs, refactor, test, chore

**Examples**:
```
feat(kernel): add support for longterm kernels
fix(signing): handle missing GPG key gracefully
docs(readme): clarify verification instructions
```

## Pull Request Process

### Before Submitting

1. **Test locally**:
   ```bash
   # Build and test
   task kernel:build KERNEL_VERSION=6.1
   task firecracker:test-kernel KERNEL_VERSION=6.1
   ```

2. **Check code style**:
   ```bash
   # Shell scripts
   shellcheck scripts/**/*.sh
   ```

3. **Update documentation**:
   - Update README if user-facing changes
   - Update docs/ for new features
   - Add comments to code

4. **Create atomic commits**:
   - One logical change per commit
   - Clear commit messages
   - Reference related issues

### PR Template

When creating a PR, include:

**Description**:
- What does this PR do?
- Why is this change needed?

**Changes**:
- List of modifications
- New files or deleted files

**Testing**:
- How was this tested?
- Test results or output

**Screenshots** (if applicable):
- Visual changes
- Terminal output

## Testing Changes

### Script Changes

```bash
# Test script directly
./scripts/kernel/build-kernel.sh --kernel 6.1 --verification-level disabled

# Test via Task
task kernel:build KERNEL_VERSION=6.1
```

### Task Changes

```bash
# Test specific task
task kernel:build KERNEL_VERSION=6.1

# Verify task list
task --list
```

### Configuration Changes

```bash
# Test new kernel config
cp my-new.config configs/microvm-kernel-x86_64.config
task kernel:build VERIFICATION_LEVEL=disabled
task firecracker:test-kernel
```

### Workflow Changes

```bash
# Validate workflow syntax
gh workflow view build-kernel.yml

# Trigger test run
gh workflow run build-kernel.yml -f kernel_version=6.1
```

## Review Process

### What to Expect

1. **Automated checks**: CI runs on all PRs
2. **Maintainer review**: Typically within 1-2 days
3. **Feedback**: Address review comments
4. **Approval**: PR merged after approval

### Review Criteria

- Code quality and readability
- Test coverage
- Documentation completeness
- No security issues
- Follows project conventions

## Community Guidelines

### Be Respectful

- Treat others with respect
- Provide constructive feedback
- Assume good intentions
- Be patient with new contributors

### Stay On Topic

- Keep discussions relevant
- Use appropriate channels (issues vs discussions)
- Search before asking

### Security

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. Email maintainers privately
3. Provide detailed information
4. Allow time for fix before disclosure

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

See [LICENSE.md](https://github.com/get-virgil/cracker-barrel/blob/master/LICENSE.md) for details.

## Questions?

- [Open a discussion](https://github.com/get-virgil/cracker-barrel/discussions)
- [Check existing issues](https://github.com/get-virgil/cracker-barrel/issues)
- Read the [documentation](index.md)

## Next Steps

- [Development Guide](development/index.md) - Set up your environment
- [Project Structure](reference/project-structure.md) - Understand the codebase
- [How It Works](reference/how-it-works.md) - Learn the internals
