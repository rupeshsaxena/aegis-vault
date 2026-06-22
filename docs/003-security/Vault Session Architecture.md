# Vault Session Architecture

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines how AegisVault manages an unlocked vault session at runtime.

The vault session is responsible for controlling when decrypted vault access is available and when it must be destroyed.

This document defines:

* Vault session lifecycle
* Runtime key availability
* Lock and unlock behavior
* Auto-lock triggers
* Memory exposure rules
* Cache cleanup rules
* Concurrency boundaries

---

# Core Principle

AegisVault has two primary runtime states:

```text
Locked
```

and

```text
Unlocked
```

When the vault is locked:

* Object decryption is unavailable
* Blob decryption is unavailable
* Search index is unavailable
* Previews are unavailable
* Thumbnails are unavailable
* Session key material is unavailable

When the vault is unlocked:

* Vault objects can be decrypted
* Blob keys can be unwrapped
* Search index can be rebuilt
* Previews can be rendered
* Thumbnails can be displayed

---

# Session Responsibility

The vault session is responsible for:

* Maintaining unlock state
* Holding short-lived runtime key material
* Enforcing lock rules
* Coordinating cache cleanup
* Supporting auto-lock
* Preventing unsafe concurrent access to session material

---

# Session Non-Responsibilities

The vault session must not:

* Persist keys
* Persist decrypted payloads
* Persist decrypted previews
* Persist decrypted thumbnails
* Perform UI navigation
* Perform file import
* Perform database writes directly

---

# Runtime Session Model

The session is represented by:

```swift
actor VaultSessionActor
```

The actor owns the unlocked session state and serializes access to sensitive runtime material.

---

# Session State

```swift
public enum VaultSessionState: Sendable, Equatable {
    case locked
    case unlocking
    case unlocked
    case locking
}
```

---

# Session Data

A runtime session may contain:

```swift
public struct VaultSession: Sendable {
    public let vaultId: VaultID
    public let deviceId: DeviceID
    public let vaultEncryptionKeyReference: KeyReference
    public let unlockedAt: Date
    public let expiresAt: Date?
}
```

---

# Key Material Rules

The session may hold or reference:

* Vault Encryption Key
* Device ID
* Vault ID
* Session timestamps

The session must not hold long-lived:

* Item Keys
* Blob Keys
* Recovery Secret
* Recovery Key
* Plaintext payloads
* Plaintext previews
* Plaintext thumbnails

---

# Why Item Keys And Blob Keys Are Not Stored Long-Term

Item Keys and Blob Keys should be used only for a single operation.

Example object read:

```text
Load encrypted object
↓
Load wrapped item key
↓
Unwrap item key using VEK
↓
Decrypt object
↓
Discard item key
```

Example blob read:

```text
Load encrypted blob
↓
Load wrapped blob key
↓
Unwrap blob key using VEK
↓
Decrypt blob
↓
Discard blob key
```

This reduces memory exposure.

---

# Unlock Flow

```text
User authenticates
↓
Unlock material obtained
↓
Recover or unwrap Vault Encryption Key
↓
Create VaultSession
↓
Store session inside VaultSessionActor
↓
Rebuild in-memory search index
↓
Vault becomes unlocked
```

---

# Unlock Methods

Supported unlock methods:

* Biometric unlock
* Passkey unlock
* Recovery secret unlock

Future unlock methods:

* Hardware security key
* Trusted device unlock

---

# Lock Flow

```text
Manual lock or auto-lock trigger
↓
Set state to locking
↓
Clear search index
↓
Clear preview cache
↓
Clear thumbnail cache
↓
Clear decrypted object cache
↓
Destroy session key references
↓
Set state to locked
```

---

# Auto-Lock Triggers

The vault must lock when:

* User manually locks vault
* App enters background
* Device is locked
* Session timeout expires
* Authentication state changes
* Biometric enrollment changes
* Security settings change

---

# Auto-Lock Timeout Options

Supported timeout options:

* Immediately
* 1 minute
* 5 minutes
* 15 minutes
* Never

Default:

```text
5 minutes
```

The `Never` option may be disabled in future high-security modes.

---

# Backgrounding Behavior

When the app enters background:

* Sensitive UI should be hidden
* Search index should be cleared or invalidated
* Decrypted previews should be cleared
* Decrypted thumbnails should be cleared
* Lock policy should be evaluated

If auto-lock is immediate, the vault must lock before the app is suspended.

---

# Cache Cleanup Rules

When vault locks, the following must be cleared:

* Search index
* Decrypted object cache
* Preview cache
* Thumbnail cache
* Temporary plaintext files
* Pending decrypted blob references
* Temporary recovery package exports

---

# Search Index Rule

Search index is allowed only when vault is unlocked.

Search index must be:

* Local-only
* In-memory for MVP
* Cleared on lock

No persistent plaintext search index is allowed.

---

# Preview And Thumbnail Rule

Previews and thumbnails are sensitive.

They must be:

* Encrypted at rest
* Decrypted only while unlocked
* Cleared from memory on lock
* Hidden in app switcher

---

# Concurrency Rules

All sensitive session mutations must go through:

```swift
VaultSessionActor
```

Forbidden:

* Global mutable session state
* Static session keys
* Non-actor isolated session mutation
* UI-owned session keys

---

# MainActor Boundary

ViewModels may run on:

```swift
@MainActor
```

But session key material must never be stored inside:

* SwiftUI Views
* ViewModels
* Navigation state
* App state objects

ViewModels may only request actions through UseCases and VaultEngine.

---

# SecureVaultKit Boundary

The session belongs to SecureVaultKit.

The iOS app may observe lock state but must not access raw session material.

The public security-status projection may additionally expose the configured
auto-lock policy, recovery setup state, placeholder authentication state, and
sanitized trusted-device summaries. It must not expose session timestamps, key
references, raw device public keys, trust certificates, signatures, or device
permissions.

Allowed:

```swift
await vaultEngine.lockVault()
try await vaultEngine.unlockVault(method: method)
```

Forbidden:

```swift
viewModel.sessionKey
viewModel.vaultEncryptionKey
viewModel.itemKey
```

---

# Failure Behavior

If session validation fails:

* Operation must fail
* No partial plaintext should be returned
* No cache should be updated
* No decrypted content should persist

---

# Session Expiry

Each unlocked session may have:

* unlockedAt
* lastAccessedAt
* expiresAt

Session expiry should be enforced before decrypt operations.

---

# Security Invariants

The following must always be true:

* Locked vault cannot decrypt objects
* Locked vault cannot decrypt blobs
* Locked vault cannot search
* Locked vault cannot display previews
* Locked vault cannot display thumbnails
* Recovery Secret is not stored in session
* Item Keys are not stored long-term
* Blob Keys are not stored long-term
* Search index is cleared on lock
* Preview cache is cleared on lock
* Thumbnail cache is cleared on lock
* Session mutations happen through VaultSessionActor

Violation of these rules is a security defect.

---

# Related Documents

* Cryptography Architecture.md
* Key Hierarchy.md
* Envelope Encryption.md
* Recovery Key Model.md
* Threat Model.md
