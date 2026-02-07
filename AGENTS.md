# Agent Guidelines: Taskfile Conventions

This document describes the Taskfile conventions and patterns used in this project for AI agents and developers working on the codebase.

## Project Structure

### Namespace Organization

Tasks are organized into logical namespaces, each in its own directory under `tasks/`:

```
scripts/
├── kernel/
│   ├── build-kernel.sh             # Build kernels from source
│   └── download-kernel.sh          # Download pre-built kernels
├── firecracker/
│   ├── create-test-rootfs.sh       # Create test rootfs
│   └── test-kernel.sh              # Test kernels with Firecracker
└── signing/
    ├── sign-artifacts.sh           # Sign artifacts with PGP
    ├── verify-artifacts.sh         # Verify PGP signatures
    ├── generate-signing-key.sh     # Generate new signing key
    ├── rotate-signing-key.sh       # Rotate signing key
    ├── check-key-expiry.sh         # Check key expiration
    └── remove-signing-key.sh       # Remove signing key

tasks/
├── kernel/Taskfile.dist.yaml       # Kernel operations (get, download, build)
├── firecracker/Taskfile.dist.yaml  # Firecracker testing
├── clean/Taskfile.dist.yaml        # Cleanup operations
├── signing/Taskfile.dist.yaml      # PGP key management
├── release/Taskfile.dist.yaml      # CI release operations
└── dev/Taskfile.dist.yaml          # Development utilities

Taskfile.dist.yaml                  # Root taskfile (includes all namespaces)
```

### Root Taskfile Pattern

The root `Taskfile.dist.yaml` includes all namespaces and provides convenience aliases:

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: '3'

includes:
  kernel:
    taskfile: tasks/kernel
    dir: .
  firecracker:
    taskfile: tasks/firecracker
    dir: .
  # ... more namespaces

tasks:
  default:
    desc: Show available tasks
    silent: true
    cmds:
      - task --list

  # Convenience alias: task clean → task clean:all
  clean:
    desc: Remove all build artifacts, caches, and downloads
    cmds:
      - task: clean:all
```

**Key points:**
- Always set `dir: .` so tasks run from project root
- Use `includes` to load namespace taskfiles
- Provide convenience aliases for common operations
- Default task should show available tasks

## Naming Conventions

### Avoid Redundancy

❌ **Bad:** `task clean:clean` (redundant)
✅ **Good:** `task clean:all` or just `task clean`

❌ **Bad:** `task build:build-kernel`
✅ **Good:** `task kernel:build`

### Task Name Patterns

When a namespace provides multiple operations on the same resource, use clear action verbs:

```yaml
# kernel namespace
kernel:get        # Smart: try download, fallback to build
kernel:download   # Explicit: download only
kernel:build      # Explicit: build from source

# signing namespace
signing:list              # Show keys
signing:generate-signing-key  # Generate new key
signing:rotate            # Rotate key
signing:remove-signing-key    # Remove key

# clean namespace
clean:all         # Clean everything
clean:kernel      # Clean specific artifacts
clean:firecracker # Clean specific artifacts
```

**Patterns:**
- **Smart operations** use simple names: `get`, `test`
- **Explicit operations** use descriptive names: `download`, `build`, `generate-signing-key`
- **Scoped operations** use resource names: `kernel`, `firecracker`, `rootfs`

### File Naming

- Taskfiles: Always `Taskfile.dist.yaml` (Task convention)
- Scripts: Use kebab-case in `scripts/namespace/` directories: `scripts/kernel/download-kernel.sh`, `scripts/signing/sign-artifacts.sh`
- Script directories: Mirror task namespaces (kernel → scripts/kernel/, signing → scripts/signing/)
- Namespaces: Use singular: `kernel`, not `kernels`

## Task Structure

### Required Fields

Every task must have:

```yaml
task-name:
  desc: "Short description for task list"
  silent: true  # Suppress task command echo
  cmds:
    - # commands here
```

### Full Task Template

```yaml
task-name:
  desc: "Short one-line description"
  silent: true
  summary: |
    Longer description with details

    Options:
      VAR1=value    Description of variable
      VAR2=value    Description of variable

    Examples:
      task namespace:task-name                    # Example 1
      task namespace:task-name VAR1=foo           # Example 2
      task namespace:task-name VAR1=foo VAR2=bar  # Example 3
  cmds:
    - |
      # Bash commands here
      # Can be multiline
```

**Guidelines:**
- `desc`: One line, shows in `task --list`
- `summary`: Detailed help, shows with `task --summary namespace:task-name`
- Include options and examples in summary
- Use `silent: true` for cleaner output
- Quote descriptions containing colons: `desc: "Get kernel (smart: download or build)"`

### YAML Schema Declaration

**Always include at the top of every Taskfile:**

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: '3'
```

This enables IDE autocomplete and validation.

## Common Patterns

### Smart vs Explicit Tasks

Provide both smart (convenient) and explicit (predictable) operations:

```yaml
# Smart: tries download, falls back to build
get:
  desc: "Get kernel (smart: download or build)"
  cmds:
    - |
      if ! ./scripts/kernel/download-kernel.sh $OPTS 2>/dev/null; then
        echo "[INFO] Download not available, building from source..."
        ./scripts/kernel/build-kernel.sh $OPTS
      fi

# Explicit: download only
download:
  desc: Download pre-built kernel from GitHub releases
  cmds:
    - ./scripts/kernel/download-kernel.sh $OPTS

# Explicit: build only
build:
  desc: Build kernel from source
  cmds:
    - ./scripts/kernel/build-kernel.sh $OPTS
```

**Why this pattern?**
- New users want smart behavior: `task kernel:get` just works
- Power users want control: `task kernel:download` or `task kernel:build`
- Scripts want predictability: explicit operations don't surprise

### Variable Passing

Use Task variables to pass options to scripts:

```yaml
vars:
  DETECTED_ARCH:
    sh: uname -m | sed 's/arm64/aarch64/'
  ARCH: '{{.ARCH | default .DETECTED_ARCH}}'  # CLI-overridable with fallback
  KERNEL_VERSION: ""  # Empty default (optional)

tasks:
  build:
    cmds:
      - |
        OPTS="--arch {{.ARCH}}"
        {{if .KERNEL_VERSION}}OPTS="$OPTS --kernel {{.KERNEL_VERSION}}"{{end}}
        {{if .VERIFICATION_LEVEL}}OPTS="$OPTS --verification-level {{.VERIFICATION_LEVEL}}"{{end}}
        ./scripts/kernel/build-kernel.sh $OPTS
```

**Patterns:**
- Use `vars:` for defaults (can use shell commands with `sh:`)
- Use `{{.VARIABLE}}` to access variables
- Use `{{if .VAR}}...{{end}}` for optional flags
- Build option strings, then pass to scripts

**CRITICAL - CLI Variable Overrides:**

Variables with `sh:` commands **always execute** and ignore CLI overrides. To make variables CLI-overridable:

```yaml
# ❌ Bad - CLI override doesn't work
vars:
  ARCH:
    sh: uname -m  # Always executes, ignores `task build ARCH=aarch64`

# ✅ Good - CLI override works
vars:
  DETECTED_ARCH:
    sh: uname -m
  ARCH: '{{.ARCH | default .DETECTED_ARCH}}'  # Uses CLI value or falls back
```

**Pattern:**
1. Create a separate variable for the shell command (e.g., `DETECTED_ARCH`)
2. Use `'{{.VAR | default .FALLBACK}}'` for the actual variable
3. This allows: `task build ARCH=aarch64` to override the default

**References:**
- [Demystification of taskfile variables](https://medium.com/@TianchenW/demystification-of-taskfile-variables-29b751950393)
- [Task variable precedence rules](https://taskfile.dev/docs/reference/schema)

### Task Dependencies

Call other tasks with `task:` instead of duplicating logic:

```yaml
# Bad: duplicates logic
build:
  cmds:
    - task: get
      vars:
        FORCE_BUILD: true

# Good: passes through to same script with different flag
build:
  cmds:
    - ./scripts/kernel/build-kernel.sh --force-build
```

Use task dependencies when you genuinely need orchestration:

```yaml
release:
  deps:
    - build:kernel
    - sign:artifacts
  cmds:
    - ./publish-release.sh
```

### Prompts for Destructive Operations

Use Task's `prompt` field for destructive operations:

```yaml
remove-signing-key:
  desc: Remove local signing key and keyring (destructive operation)
  prompt:
    - This will delete your local signing key and .gnupg directory. Continue?
    - Are you absolutely sure? This cannot be undone.
  cmds:
    - rm -rf .gnupg keys/
```

**Multiple prompts create a confirmation chain** - all must be approved.

## Security Conventions

### Fail-Secure by Default

Operations that affect security must fail-secure:

```yaml
# Bad: defaults to skip verification
build:
  cmds:
    - ./scripts/kernel/build-kernel.sh --verification-level ${VERIFICATION_LEVEL:-disabled}

# Good: defaults to highest security
build:
  cmds:
    - |
      OPTS=""
      {{if .VERIFICATION_LEVEL}}OPTS="$OPTS --verification-level {{.VERIFICATION_LEVEL}}"{{end}}
      ./scripts/kernel/build-kernel.sh $OPTS  # Script defaults to 'high'
```

### Cache Management for Security

When verification is enabled, delete cached sources to prevent using tampered files:

```bash
# In build-kernel.sh
if [ "$VERIFICATION_LEVEL" != "disabled" ]; then
    if [ -f "$KERNEL_TARBALL" ] || [ -d "$KERNEL_SRC_DIR" ]; then
        info "Deleting cached source (verification enabled - using fresh sources)"
        rm -f "$KERNEL_TARBALL"
        rm -rf "$KERNEL_SRC_DIR"
    fi
fi
```

**When verification is disabled:**
- Keep cache for faster iteration
- Allows source code modifications for development

### PGP Key Management

```yaml
# Generation: check for existing keys first
generate-signing-key:
  cmds:
    - |
      if [ -d ".gnupg" ] || [ -f "keys/signing-key.asc" ]; then
        echo "Error: Local signing key already exists"
        exit 1
      fi
      # ... generate key

# Rotation: check GitHub secret exists
rotate:
  cmds:
    - |
      if ! gh secret list --json name | jq -r '.[].name' | grep -q "^SIGNING_KEY$"; then
        echo "Error: SIGNING_KEY not found in GitHub Actions"
        exit 1
      fi
      # ... rotate key
```

## Script Integration

### Shell Script Wrappers

Tasks should wrap shell scripts, not replace them:

```yaml
# Good: wrapper around script
build:
  cmds:
    - ./scripts/kernel/build-kernel.sh $OPTS

# Bad: complex bash in taskfile
build:
  cmds:
    - |
      wget kernel.tar.xz
      tar -xf kernel.tar.xz
      cd kernel
      make -j$(nproc)
      # ... 50 more lines
```

**Why?**
- Scripts are testable independently
- Scripts work in environments without Task
- Taskfiles stay simple and readable
- Shell scripts can have proper error handling

### Script Output

Scripts should use consistent output formatting:

```bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}
```

Tasks should use `silent: true` to avoid echoing commands, letting script output be clean.

## Testing Patterns

### Task Testing Workflow

```bash
# 1. View task help
task --summary namespace:task-name

# 2. List namespace tasks
task --list | grep "namespace:"

# 3. Test basic invocation
task namespace:task-name

# 4. Test with variables
task namespace:task-name VAR1=value

# 5. Test idempotency (run twice)
task namespace:task-name
task namespace:task-name  # Should skip work or be safe
```

### Idempotency

Tasks should be safe to run multiple times:

```yaml
build:
  cmds:
    - |
      # Check if already built
      if [ -f "artifacts/vmlinux-${VERSION}.xz" ]; then
        echo "Kernel already exists, skipping build"
        exit 0
      fi
      ./scripts/kernel/build-kernel.sh
```

## Documentation Standards

### README Integration

Document the task workflow in README.md:

```markdown
### Using Task (Recommended)

**Tasks are organized into namespaces:**
- `kernel:*` - Kernel operations (get, download, build)
- `firecracker:*` - Testing kernels with Firecracker
- `clean:*` - Cleaning artifacts

**Kernel task workflow:**
- `kernel:get` - Smart: tries download, builds if unavailable (recommended)
- `kernel:download` - Download only: fails if pre-built not available
- `kernel:build` - Build from source: always uses fresh sources when verifying

\`\`\`bash
task kernel:get
task kernel:download
task kernel:build KERNEL_VERSION=6.1
\`\`\`
```

### Task List Output

Ensure `desc` fields are clear and concise for `task --list`:

```
$ task --list
task: Available tasks for this project:
* clean:                     Remove all build artifacts, caches, and downloads
* default:                   Show available tasks
* clean:all:                 Remove all build artifacts, caches, and downloads
* clean:firecracker:         Remove cached Firecracker binaries
* clean:kernel:              Remove only kernel artifacts (keep Firecracker and rootfs)
* clean:rootfs:              Remove test rootfs (will be recreated on next test)
* dev:check-kvm:             Check if KVM is available for Firecracker testing
* dev:install-deps:          Install required build dependencies (Ubuntu/Debian)
* dev:list-artifacts:        List all cached artifacts
* firecracker:create-rootfs: Create test rootfs for Firecracker boot testing
* firecracker:test-kernel:   Test kernel by booting in Firecracker VM
* kernel:build:              Build kernel from source
* kernel:download:           Download pre-built kernel from GitHub releases
* kernel:get:                Get kernel (smart: download or build)
```

## CI/CD Integration

### Local-First Philosophy

CI should run the same commands as local development:

```yaml
# GitHub Actions
- name: Install Task
  run: sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

- name: Install dependencies
  run: task dev:install-deps

- name: Build kernel
  run: task kernel:build KERNEL_VERSION=${{ matrix.version }} ARCH=${{ matrix.arch }}

- name: Sign artifacts
  run: task signing:sign-artifacts
  env:
    SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
```

**Why?**
- CI behavior is reproducible locally
- Debugging CI failures is easier
- No CI-specific scripts to maintain
- Testing locally = testing CI

### Multi-Architecture Support

Support both x86_64 and ARM64 runners using a dedicated task:

```yaml
# GitHub Actions - Use task for cross-compilation setup
- name: Install cross-compilation tools
  run: task dev:ensure-cross-tools ARCH=${{ matrix.arch }}
```

The `dev:ensure-cross-tools` task handles runtime detection internally:

```yaml
# tasks/dev/Taskfile.dist.yaml
ensure-cross-tools:
  desc: Install cross-compilation tools if needed for target architecture
  silent: true
  cmds:
    - |
      RUNNER_ARCH="$(uname -m | sed 's/arm64/aarch64/')"
      TARGET_ARCH="{{.ARCH}}"

      echo "Runner architecture: $RUNNER_ARCH"
      echo "Target architecture: $TARGET_ARCH"

      # Install cross-compilation tools only when runner and target differ
      if [ "$RUNNER_ARCH" = "x86_64" ] && [ "$TARGET_ARCH" = "aarch64" ]; then
        task dev:install-arm-tools
      elif [ "$RUNNER_ARCH" = "aarch64" ] && [ "$TARGET_ARCH" = "x86_64" ]; then
        task dev:install-x86-tools
      else
        echo "Native build - no cross-compilation tools needed"
      fi
```

**Why this pattern?**
- Supports x86_64 runners (GitHub hosted `ubuntu-latest`)
- Supports ARM64 runners (GitHub hosted `ubuntu-24.04-arm` or self-hosted)
- Only installs cross-compilation tools when needed
- Native builds are faster (no cross-compilation overhead)
- Logic lives in taskfile, not CI config (local-first)
- CI stays thin: just `task dev:ensure-cross-tools ARCH=...`
- Same command works locally and in CI

### Environment Detection

Tasks can detect CI vs local environments:

```yaml
sign-artifacts:
  cmds:
    - |
      # CI: use environment variable
      if [ -n "${SIGNING_KEY:-}" ]; then
        echo "$SIGNING_KEY" | gpg --import
        KEY_ID=$(gpg --list-keys --with-colons | grep '^pub' | cut -d: -f5 | head -1)
      # Local: use .gnupg directory
      elif [ -d ".gnupg" ]; then
        KEY_ID=$(gpg --homedir .gnupg --list-keys --with-colons | grep '^pub' | cut -d: -f5)
        GPG_OPTS="--homedir .gnupg"
      fi
```

## Anti-Patterns

### ❌ Don't: Redundant Naming

```yaml
# Bad
clean:
  clean:
    cmds: ...

# Good
clean:
  all:
    cmds: ...
```

### ❌ Don't: Complex Logic in Taskfiles

```yaml
# Bad: 100 lines of bash in taskfile
build:
  cmds:
    - |
      # Complex download logic
      # Complex verification logic
      # Complex build logic
      # Complex packaging logic

# Good: delegate to script
build:
  cmds:
    - ./scripts/kernel/build-kernel.sh
```

### ❌ Don't: Hardcode Paths

```yaml
# Bad
build:
  cmds:
    - cd /home/user/project && make

# Good
build:
  dir: .  # Use Task's dir option
  cmds:
    - make
```

### ❌ Don't: Silent Failures

```yaml
# Bad: errors hidden
build:
  cmds:
    - ./build.sh || true

# Good: let failures propagate
build:
  cmds:
    - ./build.sh
```

### ❌ Don't: Skip Documentation

```yaml
# Bad: no help
build:
  cmds:
    - ./build.sh

# Good: clear documentation
build:
  desc: Build kernel from source
  summary: |
    Build Firecracker-compatible kernel from source

    Options:
      KERNEL_VERSION=6.1  Specific version
      ARCH=aarch64        Target architecture

    Examples:
      task kernel:build
      task kernel:build KERNEL_VERSION=6.1
  cmds:
    - ./build.sh
```

## Quick Reference

### Task Command Cheatsheet

```bash
# List all tasks
task --list

# Show task details
task --summary namespace:task-name

# Run task
task namespace:task-name

# Run with variables
task namespace:task-name VAR=value

# Multiple variables
task namespace:task-name VAR1=value VAR2=value

# Bypass prompts
task namespace:task-name --yes
```

### Taskfile Template

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: '3'

vars:
  VAR_NAME:
    sh: command  # or hardcoded value

tasks:
  task-name:
    desc: "Short description"
    silent: true
    summary: |
      Detailed description

      Options:
        VAR=value   Description

      Examples:
        task namespace:task-name
    cmds:
      - |
        # Commands here
```

## Maintenance

When adding new tasks:

1. ✅ Add YAML schema declaration
2. ✅ Use clear, non-redundant names
3. ✅ Provide both `desc` and `summary`
4. ✅ Include examples in summary
5. ✅ Use `silent: true` for clean output
6. ✅ Delegate complex logic to scripts
7. ✅ Document in README.md
8. ✅ Test with `task --summary` and `task --list`
9. ✅ Verify idempotency (safe to run twice)
10. ✅ Update AGENTS.md if introducing new patterns
