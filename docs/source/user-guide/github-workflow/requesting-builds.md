# Requesting Kernel Builds

Don't see the kernel version you need? **Open an issue to request a build!**

## Quick Request

[🔨 Request Kernel Build](https://github.com/get-virgil/cracker-barrel/issues/new?template=build-request.yml)

1. Select "Kernel Build Request" template
2. Enter the kernel version (e.g., 6.1.75)
3. Submit the issue
4. Automated validation and build process kicks in
5. Download from releases once complete

**Important:**
- Only stable kernel versions from kernel.org are accepted
- Invalid requests are tracked (5 invalid requests = automatic ban)
- Check https://kernel.org first to verify the version exists

## How It Works

The system provides automated validation and builds:

1. **Submit Request**: Open an issue using the "Kernel Build Request" template
2. **Automatic Validation**: The system checks if the version exists on kernel.org
3. **Build Trigger**: Valid requests trigger the build workflow automatically
4. **Release**: Built kernels are published to GitHub releases

## Request Process

### Via GitHub UI

1. Go to Issues → New Issue
2. Select "Kernel Build Request"
3. Enter kernel version (e.g., 6.1.75)
4. Submit

### Via GitHub CLI

```bash
gh issue create --template build-request.yml \
  --title "[BUILD] Kernel version: 6.1.75"
```

## Validation Rules

### Valid Requests

- ✅ Version exists on kernel.org (verified via releases.json API)
- ✅ Version not already built and released
- ✅ User has fewer than 5 invalid requests

### Invalid Requests

- ❌ Version doesn't exist on kernel.org
- ❌ Typo in version number
- ❌ Non-numeric characters

## Rate Limiting & Bans

To prevent abuse, invalid requests are tracked:

- Each user can submit up to **5 invalid requests**
- After 5 invalid requests, the user is **automatically banned**
- Banned users' future build requests are immediately closed
- Invalid request count is tracked via GitHub issue labels

**Ban criteria:**
- 5+ issues labeled `invalid-kernel-version` from the same user

**Warning system:**
- Request 4/5: Warning message in issue comment
- Request 5/5: Automatic ban with notification

## Response Types

### Valid Request (Version Exists)

```
✅ Build Triggered
Kernel version 6.1.75 build has been triggered.
[Link to workflow runs]
```

### Already Exists

```
ℹ️ Release Already Exists
Kernel version 6.1.75 has already been built.
[Link to release]
```

### Invalid Version

```
❌ Invalid Kernel Version
The requested kernel version 6.1.999 does not exist on kernel.org.
Invalid requests: 1/5
```

### User Banned

```
🚫 User Banned
User has been automatically banned for exceeding the invalid build request limit.
Invalid requests: 5/5
```

## Checking Kernel Versions

Before requesting, verify the version exists:

```bash
# Check kernel.org releases
curl -s https://www.kernel.org/releases.json | jq '.releases[] | .version'

# Or visit kernel.org directly
open https://kernel.org
```

## Build Timeline

Once a valid request is submitted:

1. **Validation**: Immediate (< 1 minute)
2. **Build Trigger**: Immediate after validation
3. **Build Duration**: ~30-45 minutes (both architectures in parallel)
4. **Release**: Immediately after build completes

You'll receive GitHub notifications at each step.

## Next Steps

- [Automated Releases](automated-releases.md) - Understanding the daily build schedule
- [Verification](../../getting-started/verification.md) - Verify your downloaded kernel
