# Threat Model

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines the threat model for AegisVault.

The purpose of this document is to establish:

* Security assumptions
* Trust boundaries
* Protected assets
* Supported threat scenarios
* Non-goals

Every security feature, architecture decision, and future audit should be evaluated against this threat model.

---

# Security Objective

AegisVault aims to ensure that unauthorized parties cannot access user vault content even if:

* Backend infrastructure is compromised
* Blob storage is compromised
* Network traffic is intercepted
* Device storage is copied
* Database files are stolen

while preserving a local-first, zero-knowledge architecture.

---

# Assets Protected

The following assets are considered sensitive.

## Vault Objects

Examples:

* Secure Notes
* Identity Records
* Cards
* Documents
* Photos

---

## Blob Content

Examples:

* PDF files
* Images
* Future video files

---

## Derived Content

Examples:

* Thumbnails
* Previews

---

## Cryptographic Material

Examples:

* Recovery metadata
* Wrapped keys
* Device trust metadata

---

## Future Sync Data

Examples:

* Event logs
* Device trust records
* Synchronization metadata

---

# Trust Boundaries

## Trusted

The following are trusted:

* Authenticated user
* Trusted device
* SecureVaultKit runtime
* Platform secure storage
* Future Secure Enclave integration

---

## Untrusted

The following are untrusted:

* Network
* Backend
* PostgreSQL
* Blob Storage
* Analytics
* Logs
* Monitoring systems
* Crash reporting systems

Compromise of these systems must not expose plaintext vault data.

---

# Threat Category 1

## Backend Breach

### Scenario

Attacker gains access to:

* Backend database
* Object metadata
* Event storage

### Goal

Read vault content.

### Protection

AegisVault should expose only encrypted data.

### Required Controls

* Client-side encryption
* Zero-knowledge backend
* Envelope encryption
* Wrapped keys

### Expected Result

Attacker cannot decrypt vault content.

---

# Threat Category 2

## Blob Storage Breach

### Scenario

Attacker gains access to:

* Encrypted files
* Encrypted thumbnails
* Encrypted previews

### Goal

Recover file contents.

### Required Controls

* Per-blob encryption
* Blob keys
* Wrapped blob keys

### Expected Result

Attacker cannot access file contents.

---

# Threat Category 3

## SQLite Database Theft

### Scenario

Attacker copies local vault database.

Examples:

* Device backup extraction
* Filesystem access
* Physical storage copy

### Required Controls

* Object-level encryption
* Encrypted metadata
* Wrapped item keys

### Expected Result

Attacker cannot recover plaintext objects.

---

# Threat Category 4

## Network Interception

### Scenario

Attacker intercepts traffic.

Examples:

* Public Wi-Fi
* Proxy attacks
* MITM attempts

### Required Controls

* TLS
* Client-side encryption
* Event signing (future)

### Expected Result

Traffic contents remain protected.

---

# Threat Category 5

## Device Theft

### Scenario

User loses:

* Phone
* Tablet
* Laptop

### Required Controls

* Vault lock
* Biometric unlock
* Passkey unlock
* Secure local key storage

### Expected Result

Attacker cannot access vault content without authentication.

Biometric authorization fails closed when unavailable, cancelled, failed,
locked out, not enrolled, or not configured. A successful platform result is
not persisted and is never treated as cryptographic key material. Protection
of long-lived keys still depends on the future production secure-key-store
integration.

---

# Threat Category 6

## Malicious Backend Operator

### Scenario

Administrator intentionally attempts to inspect user data.

### Required Controls

* Zero-knowledge architecture
* Client-side encryption
* No plaintext processing

### Expected Result

Operator cannot decrypt vault data.

---

# Threat Category 7

## Recovery Package Theft

### Scenario

Attacker obtains:

```text
Recovery Package
```

but not:

```text
Recovery Secret
```

### Expected Result

Recovery must fail.

Temporary recovery package exports are treated as sensitive user-controlled
artifacts even though they contain no secret or vault keys. SecureVaultKit
removes its active temporary export when the vault locks; once the user shares
or saves a copy outside the app, protection of that copy is the user's
responsibility.

---

# Threat Category 8

## Recovery Secret Theft

### Scenario

Attacker obtains:

```text
Recovery Secret
```

but not:

```text
Recovery Package
```

### Expected Result

Recovery must fail.

---

# Threat Category 9

## Combined Recovery Material Theft

### Scenario

Attacker obtains:

* Recovery Package
* Recovery Secret

### Expected Result

Vault compromise is possible.

This is considered expected behavior.

User protection relies on safeguarding recovery material.

---

# Partial Protection

## Rooted Device

### Scenario

Device operating system is compromised.

Examples:

* Rooted Android
* Jailbroken iPhone

### Protection Level

Partial.

AegisVault may:

* Detect compromise
* Warn user
* Restrict operation

However, complete protection is not guaranteed.

---

## Memory Inspection

### Scenario

Attacker gains runtime memory access while vault is unlocked.

### Protection Level

Partial.

AegisVault minimizes exposure but cannot fully protect against a compromised runtime.

---

# Explicit Non-Goals

AegisVault does not guarantee protection against:

## Fully Compromised Device

Examples:

* Malware with elevated privileges
* Runtime code injection
* Kernel compromise

---

## Screen Capture

Examples:

* User screenshots
* Malicious screen recording

---

## Malicious Keyboard

Examples:

* Third-party keyboard logging

---

## Nation-State Adversaries

Examples:

* Advanced persistent threats
* Hardware implants
* Supply-chain attacks

These are outside MVP scope.

---

# Security Assumptions

The threat model assumes:

* Cryptographic primitives remain secure
* User protects recovery material
* Device operating system functions correctly
* Trusted execution environment behaves correctly

---

# Security Invariants

The following must always be true:

* Backend cannot decrypt vault content
* Blob storage cannot reveal files
* SQLite cannot reveal plaintext objects
* Recovery secrets are never stored directly
* Item keys remain wrapped
* Blob keys remain wrapped
* Search index is unavailable when locked
* Temporary plaintext files are removed
* Plaintext thumbnails are never persisted
* Plaintext previews are never persisted

Violation of any invariant is a security defect.

---

# Future Threat Model Expansion

Future versions should add:

* Multi-device trust threats
* Sync threats
* Sharing threats
* Enterprise threats
* Quantum-resistance review

---

# Related Documents

* Cryptography Architecture.md
* Key Hierarchy.md
* Envelope Encryption.md
* Recovery Key Model.md
