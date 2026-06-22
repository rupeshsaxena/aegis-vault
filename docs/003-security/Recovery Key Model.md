# Recovery Key Model

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines how AegisVault recovery works.

Recovery must satisfy two competing goals:

1. Allow legitimate users to recover access.
2. Prevent backend systems from recovering user data.

AegisVault follows a zero-knowledge recovery model.

The backend must never be capable of decrypting vault content.

---

# Recovery Philosophy

AegisVault does not support:

* Password reset
* Server-side recovery
* Administrator recovery
* Customer support recovery

If all recovery material is lost, vault recovery may become impossible.

This is an intentional security tradeoff.

---

# Recovery Components

Recovery consists of:

```text
Recovery Package
+
Recovery Secret
```

Both are required.

---

# Recovery Package

The Recovery Package is a portable metadata file.

Example:

```text
aegis-recovery.json
```

Purpose:

* Identify vault
* Carry recovery metadata
* Bootstrap device onboarding

The Recovery Package alone is insufficient to recover a vault.

---

# Recovery Secret

The Recovery Secret is user-controlled.

Examples:

```text
ocean basket lemon bridge ...
```

or

```text
ABCD-EFGH-IJKL-MNOP
```

The Recovery Secret is never stored directly.

---

# Recovery Architecture

```text
Recovery Secret
        ↓
     Argon2id
        ↓
Recovery Key
        ↓
Recover Root Vault Key
        ↓
Recover Vault Encryption Key
        ↓
Access Vault
```

---

# Why Two Recovery Components?

## Recovery Package Only

Insufficient.

Anyone with the file could recover the vault.

---

## Recovery Secret Only

Insufficient.

User would need vault-specific metadata.

---

## Combined Model

Required.

```text
Recovery Package
+
Recovery Secret
```

This significantly reduces accidental compromise.

---

# Recovery Package Contents

The package may contain:

```json
{
  "packageVersion": 1,
  "vaultId": "vault-id",
  "createdAt": "timestamp",
  "recoveryMetadata": {},
  "deviceBootstrapMetadata": {}
}
```

---

# Recovery Package Must Not Contain

The package must never contain:

* Recovery Secret
* Root Vault Key
* Vault Encryption Key
* Item Keys
* Blob Keys
* Decrypted Metadata
* Object Payloads
* Blob Data

---

# Recovery Secret Derivation

Recovery Secret is transformed into a Recovery Key.

Process:

```text
Recovery Secret
↓
Argon2id
↓
Recovery Key
```

Purpose:

* Slow brute force attacks
* Increase attack cost
* Protect against GPU attacks

---

# Recovery Key Responsibilities

The Recovery Key may:

* Validate recovery material
* Recover vault ownership
* Restore trusted device access

The Recovery Key must not:

* Encrypt vault objects
* Encrypt blobs
* Encrypt previews
* Encrypt thumbnails

---

# Vault Creation Flow

When a vault is created:

```text
Create Vault
↓
Generate Recovery Secret
↓
Generate Recovery Package
↓
Generate Root Vault Key
↓
Generate Vault Encryption Key
↓
Export Recovery Material
```

User must acknowledge backup instructions.

---

# Device Loss Scenario

Example:

```text
User loses iPhone
```

Recovery flow:

```text
Install App
↓
Import Recovery Package
↓
Enter Recovery Secret
↓
Derive Recovery Key
↓
Validate Package
↓
Recover Vault Ownership
↓
Create New Trusted Device
↓
Access Vault
```

---

# Multi-Device Future

Future versions may support:

```text
Trusted Device A
Trusted Device B
Trusted Device C
```

Recovery must remain compatible with:

* Device onboarding
* Device replacement
* Device revocation

---

# Recovery Validation

Recovery must fail if:

* Recovery Package missing
* Recovery Secret missing
* Recovery Secret invalid
* Package corrupted
* Package version unsupported
* Vault identifier mismatch

---

# Recovery Package Versioning

Every package must contain:

```text
packageVersion
```

Purpose:

* Format evolution
* Migration support
* Future compatibility

---

# Export Rules

Recovery Package exports must:

* Be user initiated
* Be auditable
* Be versioned

## Milestone 37 Export Foundation

The initial public export API produces a versioned JSON metadata package only
after an unlocked session and explicit user acknowledgment. Because vault
creation does not yet establish a user recovery secret, this export does not
claim that recovery is configured and does not fabricate a secret or validation
proof.

The package contains package version, package identifier, vault identifier,
device identifier, creation time, and the incomplete setup state. It contains
no recovery secret, key material, payload, blob data, or decrypted metadata.
The export is staged under a temporary URL, replaced by a later export, and
removed when the vault locks. A metadata-only audit event records the export
time without recording the URL or package contents.

Future versions may support:

* Encrypted package export
* QR recovery
* Recovery package rotation

---

# User Education Requirements

The user must be informed:

* Recovery Secret must be stored safely
* Recovery Package must be stored safely
* Losing both may permanently lose access
* Support cannot recover vault data

---

# Backend Rules

Backend systems:

Must not possess:

* Recovery Secret
* Recovery Key
* Root Vault Key
* Vault Encryption Key

Backend may store:

* Encrypted metadata
* Device registration metadata
* Future encrypted recovery backups

Backend must remain zero-knowledge.

---

# Security Invariants

The following must always be true:

* Recovery Secret is never stored directly
* Recovery Package does not contain vault keys
* Recovery Package does not contain payloads
* Recovery Package does not contain blob data
* Recovery requires both package and secret
* Backend cannot recover vault data
* Recovery creates a new trusted device after success
* Recovery remains compatible with future key rotation

Violation of these rules is a security defect.

---

# Related Documents

* Cryptography Architecture.md
* Key Hierarchy.md
* Envelope Encryption.md
* Threat Model.md
