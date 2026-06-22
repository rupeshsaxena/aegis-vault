# Cryptography Architecture

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines the cryptographic architecture for AegisVault.

The goal is to provide a secure, local-first, zero-knowledge vault capable of protecting user data even when:

* Backend systems are compromised
* Storage systems are compromised
* Blob storage is compromised
* Databases are compromised
* Network traffic is intercepted

This document defines:

* Cryptographic principles
* Trust boundaries
* Encryption architecture
* Key hierarchy overview
* Approved algorithms
* Security invariants

Detailed key management is defined in:

```text
Key Hierarchy.md
Recovery Key Model.md
Envelope Encryption.md
```

---

# Design Goals

## Primary Goals

* Confidentiality
* Integrity
* Forward compatibility
* Key rotation support
* Multi-device readiness
* Zero-knowledge backend support

---

## Secondary Goals

* Performance
* Offline operation
* Minimal attack surface
* Cryptographic agility

---

# Security Philosophy

AegisVault follows:

```text
Encrypt Before Persistence
```

All sensitive information must be encrypted before being written to:

* SQLite
* Blob storage
* Sync events
* Backup systems
* Remote services

---

# Trust Model

## Trusted Components

The following are considered trusted:

* User
* Authenticated session
* SecureVaultKit runtime
* Platform secure storage
* Secure Enclave (future)
* Trusted device identities

---

## Untrusted Components

The following are considered untrusted:

* Network
* Backend
* PostgreSQL
* Blob storage
* Sync service
* Logs
* Analytics
* Crash reporting systems

A compromise of these systems must not expose plaintext vault content.

---

# Cryptographic Principles

## Principle 1 — Least Key Exposure

Keys should only exist in memory for the shortest possible duration.

---

## Principle 2 — Key Separation

Separate keys must be used for:

* Recovery
* Vault ownership
* Object encryption
* Blob encryption
* Device trust

---

## Principle 3 — Envelope Encryption

Vault content is never encrypted directly with:

* Recovery secret
* Passkey
* Biometric credential

Instead:

```text
Recovery Secret
↓
Recovery Key
↓
Vault Encryption Key
↓
Item Keys / Blob Keys
```

Platform biometric authentication is isolated behind SecureVaultKit's
infrastructure boundary. `LAContext` and biometric outcomes never enter Views,
ViewModels, cryptographic envelopes, or key models. Authentication may only
authorize retrieval or use of locally protected key material. The Apple
Keychain adapter now implements protected storage behind `SecureKeyStore`, but
wiring production vault keys into it and Secure Enclave wrapping remain
deferred.

---

## Principle 4 — Zero Knowledge

Backend services must never possess:

* Vault keys
* Recovery secrets
* Object keys
* Blob keys

---

## Principle 5 — Cryptographic Agility

Algorithms must be replaceable in future versions.

Every encrypted structure must contain:

* Version
* Algorithm identifier

---

# Approved Cryptographic Algorithms

## Symmetric Encryption

Primary algorithm:

```text
XChaCha20-Poly1305
```

Purpose:

* Object encryption
* Blob encryption
* Preview encryption
* Thumbnail encryption

Reasons:

* Large nonce space
* Modern design
* Excellent performance
* Suitable for large blobs

---

## Key Derivation

Primary algorithm:

```text
Argon2id
```

Purpose:

* Recovery secret derivation
* Future password derivation

Reasons:

* Memory hard
* Resistant to GPU attacks
* Current industry recommendation

---

## Digital Signatures

Primary algorithm:

```text
Ed25519
```

Purpose:

* Device trust
* Event signing
* Future synchronization

---

## Hashing

Primary algorithm:

```text
SHA-256
```

Purpose:

* Integrity validation
* Checksums
* Content verification

---

# Data Protection Layers

## Layer 1 — Vault Objects

Every vault object receives:

```text
Dedicated Item Key
```

Examples:

* Notes
* Cards
* Identity records
* Metadata structures

---

## Layer 2 — Blob Storage

Every blob receives:

```text
Dedicated Blob Key
```

Examples:

* Original file
* Thumbnail
* Preview

---

## Layer 3 — Event Log

Future sync events may be encrypted independently.

---

# Encryption Domains

## Object Domain

Protects:

* Metadata
* Payload

Examples:

```text
Identity
Note
Card
```

---

## Blob Domain

Protects:

* Documents
* Images
* Videos (future)
* Thumbnails
* Previews

---

## Device Domain

Protects:

* Device trust metadata
* Device certificates
* Future synchronization metadata

---

# Runtime Encryption Flow

## Object Creation

```text
Create Object
↓
Generate Item Key
↓
Encrypt Payload
↓
Wrap Item Key
↓
Store Encrypted Envelope
```

---

## Blob Import

```text
Import File
↓
Generate Blob Key
↓
Encrypt Blob
↓
Wrap Blob Key
↓
Store Encrypted Blob
```

---

# Session Security

Decryption is permitted only when:

```text
Vault Unlocked
```

When vault becomes locked:

* Search index cleared
* Preview cache cleared
* Thumbnail cache cleared
* Session keys removed

---

# Temporary File Rules

Temporary plaintext files may exist only during processing.

Required cleanup:

```swift
defer {
    cleanup()
}
```

must be used wherever practical.

---

# Logging Rules

Never log:

* Vault payloads
* Identity information
* Card information
* Recovery secrets
* Cryptographic keys
* Decrypted metadata

---

# Security Invariants

The following must always be true:

* Backend cannot decrypt vault content
* SQLite cannot reveal plaintext
* Blob storage cannot reveal files
* Recovery secrets are never stored directly
* Item keys are unique per object
* Blob keys are unique per blob
* Temporary plaintext files are deleted
* Search index is unavailable when locked
* Thumbnails are encrypted before persistence
* Previews are encrypted before persistence

Violation of these rules is considered a security defect.

---

# Future Enhancements

Future versions may introduce:

* Secure Enclave integration
* Hardware-backed keys
* Key rotation
* Cryptographic migration support
* Multi-device trust chains
* Post-quantum migration strategy

These enhancements must preserve compatibility with the principles defined in this document.
