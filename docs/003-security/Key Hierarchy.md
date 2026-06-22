# Key Hierarchy

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines the cryptographic key hierarchy used by AegisVault.

The key hierarchy exists to:

* Minimize the impact of key compromise
* Support secure recovery
* Support future device trust
* Support future synchronization
* Enable key rotation
* Avoid direct encryption using user-controlled secrets

The architecture follows a layered approach where high-level keys protect lower-level keys rather than encrypting user data directly.

---

# Design Principles

## Separation of Responsibility

Each key has exactly one purpose.

Examples:

| Key                  | Responsibility    |
| -------------------- | ----------------- |
| Recovery Key         | Recovery          |
| Root Vault Key       | Vault Ownership   |
| Vault Encryption Key | Key Wrapping      |
| Item Key             | Object Encryption |
| Blob Key             | Blob Encryption   |
| Device Key Pair      | Device Trust      |

A single key must never be responsible for multiple domains.

---

## Envelope Encryption

User data is never encrypted directly with:

* Recovery Secret
* Recovery Key
* Biometric Credentials
* Passkeys

Instead:

```text
Recovery Secret
        ↓
Recovery Key
        ↓
Root Vault Key
        ↓
Vault Encryption Key
        ↓
Item Keys / Blob Keys
        ↓
Encrypted Data
```

---

## Blast Radius Reduction

Compromise of a single key should expose the smallest possible amount of information.

For example:

* Compromise of one Item Key should affect one object.
* Compromise of one Blob Key should affect one blob.
* Compromise of one device should not expose all devices.

---

## Future Rotation

All major keys must support future rotation.

The architecture must allow:

```text
VEK v1
↓
VEK v2
```

without requiring immediate vault-wide re-encryption.

---

# High-Level Hierarchy

```text
Recovery Secret
        ↓
     Argon2id
        ↓
Recovery Key
        ↓
Root Vault Key (RVK)
        ↓
Vault Encryption Key (VEK)
        ↓
 ┌─────────────┬─────────────┐
 ↓             ↓             ↓
Item Keys   Blob Keys   Future Keys
```

---

# Recovery Secret

## Purpose

Human-controlled recovery material.

Examples:

```text
ocean basket lemon bridge ...
```

or

```text
ABCD-EFGH-IJKL-MNOP
```

---

## Rules

The Recovery Secret:

* Never leaves the user's control
* Never appears in logs
* Never appears in analytics
* Never encrypts vault data directly
* Never encrypts blobs directly
* Never gets uploaded to backend systems

---

# Recovery Key

## Purpose

Derived from the Recovery Secret using Argon2id.

Flow:

```text
Recovery Secret
↓
Argon2id
↓
Recovery Key
```

---

## Responsibilities

The Recovery Key may:

* Restore vault ownership
* Validate recovery packages
* Bootstrap device recovery

The Recovery Key must not:

* Encrypt objects
* Encrypt blobs
* Encrypt previews
* Encrypt thumbnails

---

# Root Vault Key (RVK)

## Purpose

Represents ownership of the vault.

The Root Vault Key sits at the top of the vault hierarchy.

---

## Responsibilities

The RVK may:

* Wrap Vault Encryption Keys
* Participate in recovery operations

The RVK must not:

* Encrypt user content directly
* Encrypt blobs directly
* Encrypt previews directly

---

# Vault Encryption Key (VEK)

## Purpose

Primary operational encryption key.

The Vault Encryption Key protects lower-level data keys.

---

## Responsibilities

The VEK wraps:

* Item Keys
* Blob Keys

The VEK does not directly encrypt:

* Notes
* Identity Records
* Documents
* Images
* Blobs

---

## Why?

This allows:

* Key rotation
* Faster recovery
* Reduced re-encryption cost

---

# Item Key (IK)

## Purpose

Encrypt exactly one vault object.

Every vault object receives a dedicated Item Key.

---

## Examples

### Identity Record

```text
Identity Record
↓
Generate IK-001
↓
Encrypt Object
```

### Secure Note

```text
Secure Note
↓
Generate IK-002
↓
Encrypt Object
```

---

## Benefits

Compromise of:

```text
IK-001
```

does not compromise:

```text
IK-002
```

---

# Blob Key (BK)

## Purpose

Encrypt exactly one blob.

Every blob receives a dedicated Blob Key.

---

## Examples

### Original File

```text
passport.pdf
↓
BK-001
```

### Thumbnail

```text
thumbnail.jpg
↓
BK-002
```

### Preview

```text
preview.jpg
↓
BK-003
```

---

## Benefits

Compromise of:

```text
BK-002
```

does not compromise:

```text
BK-001
```

or

```text
BK-003
```

---

# Device Key Pair

## Purpose

Provides cryptographic identity for devices.

Used for:

* Device Trust
* Device Registration
* Device Revocation
* Future Sync
* Event Signing

---

## Structure

```text
Device Public Key
Device Private Key
```

---

## Rules

### Public Key

May be:

* Shared
* Registered
* Stored remotely

### Private Key

Must:

* Remain on device
* Never be exported
* Never be uploaded
* Never be synchronized

---

# Future Key Domains

Future versions may introduce:

| Key           | Purpose               |
| ------------- | --------------------- |
| Sync Key      | Event Synchronization |
| Sharing Key   | Vault Sharing         |
| Workspace Key | Team Vaults           |
| Backup Key    | Encrypted Backup      |

These must integrate into the hierarchy without breaking compatibility.

---

# Key Rotation

## Vault Encryption Key Rotation

Supported flow:

```text
VEK v1
↓
Generate VEK v2
↓
Re-wrap Item Keys
↓
Re-wrap Blob Keys
↓
Retire VEK v1
```

---

## Item Key Rotation

Supported flow:

```text
IK v1
↓
Decrypt Object
↓
Generate IK v2
↓
Re-encrypt Object
```

---

## Blob Key Rotation

Supported flow:

```text
BK v1
↓
Decrypt Blob
↓
Generate BK v2
↓
Re-encrypt Blob
```

---

# Storage Rules

Keys must never be stored in:

* UserDefaults
* Logs
* Analytics
* Crash Reports
* Plaintext Files

Apple implementations use or should use:

* Secure Enclave
* Keychain
* Hardware-backed storage where available

`KeychainSecureKeyStore` now provides namespaced symmetric-key persistence and
access-policy enforcement. Secure Enclave asymmetric-key generation and
production vault-key lifecycle integration remain future work.

---

# Security Invariants

The following must always be true:

* Recovery Secret is never stored directly
* Recovery Key never encrypts content
* Root Vault Key never encrypts content
* Every object has its own Item Key
* Every blob has its own Blob Key
* Device private keys never leave device
* Vault Encryption Key wraps operational keys
* Key hierarchy supports rotation
* Key hierarchy supports future synchronization
* Key hierarchy supports future device trust

Violation of any invariant is considered a security defect.

---

# Related Documents

* Cryptography Architecture.md
* Envelope Encryption.md
* Recovery Key Model.md
* Threat Model.md
