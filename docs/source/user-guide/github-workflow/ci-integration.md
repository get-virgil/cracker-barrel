# CI/CD Integration

Integrate Cracker Barrel kernels into your CI/CD pipelines.

## GitHub Actions

### Basic Download

```yaml
name: Test with Firecracker

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Firecracker kernel
        run: |
          KERNEL_VERSION="6.18.9"
          wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz
          wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
          xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz
          sha256sum -c SHA256SUMS --ignore-missing

      - name: Run tests
        run: |
          # Your Firecracker tests here
          firecracker --kernel-path vmlinux-6.18.9-x86_64 ...
```

### With Full Verification

```yaml
- name: Download and verify kernel
  run: |
    # Import signing key
    curl -s https://raw.githubusercontent.com/get-virgil/cracker-barrel/master/keys/signing-key.asc | gpg --import

    # Download kernel and signature
    KERNEL_VERSION="6.18.9"
    wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz
    wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
    wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS.asc

    # Verify signature
    gpg --verify SHA256SUMS.asc SHA256SUMS

    # Decompress and verify checksum
    xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz
    sha256sum -c SHA256SUMS --ignore-missing
```

### Cache for Speed

```yaml
- name: Cache kernel
  uses: actions/cache@v4
  with:
    path: vmlinux-*
    key: kernel-${{ env.KERNEL_VERSION }}

- name: Download kernel if not cached
  run: |
    if [ ! -f vmlinux-${KERNEL_VERSION}-x86_64 ]; then
      wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz
      xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz
    fi
```

## GitLab CI

```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y wget xz-utils
  script:
    - KERNEL_VERSION="6.18.9"
    - wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz
    - wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS
    - xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz
    - sha256sum -c SHA256SUMS --ignore-missing
    - firecracker --kernel-path vmlinux-${KERNEL_VERSION}-x86_64 ...
  cache:
    paths:
      - vmlinux-*
```

## CircleCI

```yaml
version: 2.1

jobs:
  test:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - restore_cache:
          keys:
            - kernel-v1-{{ .Environment.KERNEL_VERSION }}
      - run:
          name: Download kernel
          command: |
            if [ ! -f vmlinux-${KERNEL_VERSION}-x86_64 ]; then
              wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz
              xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz
            fi
      - save_cache:
          key: kernel-v1-{{ .Environment.KERNEL_VERSION }}
          paths:
            - vmlinux-*
      - run:
          name: Run tests
          command: firecracker --kernel-path vmlinux-${KERNEL_VERSION}-x86_64 ...
```

## Dockerfile

Build Docker images with pre-downloaded kernels:

```dockerfile
FROM ubuntu:latest

ARG KERNEL_VERSION=6.18.9

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget xz-utils gnupg && \
    rm -rf /var/lib/apt/lists/*

# Download and verify kernel
RUN wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz && \
    wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/SHA256SUMS && \
    xz -d vmlinux-${KERNEL_VERSION}-x86_64.xz && \
    sha256sum -c SHA256SUMS --ignore-missing && \
    mv vmlinux-${KERNEL_VERSION}-x86_64 /usr/local/bin/vmlinux

# Your application setup
COPY . /app
WORKDIR /app

CMD ["firecracker", "--kernel-path", "/usr/local/bin/vmlinux", ...]
```

## Terraform / Infrastructure as Code

### Terraform

```hcl
data "http" "kernel" {
  url = "https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-6.18.9-x86_64.xz"
}

resource "null_resource" "kernel_setup" {
  provisioner "local-exec" {
    command = <<-EOT
      wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-6.18.9-x86_64.xz
      xz -d vmlinux-6.18.9-x86_64.xz
      sha256sum -c SHA256SUMS --ignore-missing
    EOT
  }
}
```

## Best Practices

### Pin Versions

Always pin to specific kernel versions in production:

```bash
# Good - specific version
KERNEL_VERSION="6.18.9"
wget .../vmlinux-${KERNEL_VERSION}-x86_64.xz

# Bad - using "latest" unpredictably
wget .../releases/latest/download/vmlinux-*
```

### Cache Kernels

Kernels are ~50MB compressed. Cache them to speed up builds:

- GitHub Actions: `actions/cache`
- GitLab CI: `cache:` directive
- Docker: Multi-stage builds with kernel layer

### Verify in Production

Always verify checksums in production pipelines:

```bash
# Minimum: checksum verification
sha256sum -c SHA256SUMS --ignore-missing

# Better: full PGP verification
gpg --verify SHA256SUMS.asc SHA256SUMS
```

### Handle Download Failures

```bash
# Retry with exponential backoff
for i in {1..5}; do
  wget https://github.com/get-virgil/cracker-barrel/releases/latest/download/vmlinux-${KERNEL_VERSION}-x86_64.xz && break
  sleep $((2**i))
done
```

## Next Steps

- [Verification](../../getting-started/verification.md) - Verify kernels in your pipeline
- [Automated Releases](automated-releases.md) - Understanding what gets built
