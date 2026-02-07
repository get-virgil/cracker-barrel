# Public Key History

This directory contains historical public keys used to sign releases.

## Purpose

When rotating signing keys, the old public key is saved here with a timestamp. This ensures that:
- Old releases can still be verified with their original signing key
- There is an auditable trail of all keys used to sign releases
- Users can find the correct key for any release

## File Format

Keys are saved with the UTC timestamp of when they were rotated:
```
YYYY-MM-DD-HHMMSS.asc
```

Example: `2024-01-15-143022.asc` was rotated on January 15, 2024 at 14:30:22 UTC.

## Usage

To verify an old release:
1. Check the release date on GitHub
2. Find the corresponding key in this directory (the key valid at that time)
3. Import the historical key: `gpg --import keys/history/YYYY-MM-DD-HHMMSS.asc`
4. Verify the release signature

## Git History

This directory is committed to the repository so that key history is preserved and auditable.
