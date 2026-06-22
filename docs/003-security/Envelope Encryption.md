# Envelope Encryption

## Status

Accepted

## Version

1.0

---

# Purpose

This document defines how AegisVault encrypts and stores vault objects and blobs using envelope encryption.

Envelope encryption allows:

* Per-object encryption
* Per-blob encryption
* Key rotation
* Reduced blast radius
* Future synchronization support

without requiring every object to share the same encryption key.

---

# Overview

AegisVault uses envelope encryption for:

* Vault Objects
* Blob Storage
* Thumbnails
* Previews
* Future Sync Payloads

The model is:

```text
Plaintext Data
↓
Generate Data Key
↓
Encrypt Data
↓
Wrap Data Key
↓
Store Encrypted Envelope
```

The wrapped key is stored.

The plaintext key is never persisted.

---

# Why Envelope Encryption?

Without envelope encryption:

```text
Single Vault Key
↓
Encrypt Everything
```

Problems:

* Large blast radius
* Difficult rotation
* Poor future scalability

---

With envelope encryption:

```text
Vault Encryption Key
↓
Wrap
↓
Item Key
↓
Encrypt One Object
```

Benefits:

* Key isolation
* Rotation support
* Future sharing support
* Better security boundaries

---

# Terminology

## Data Key

A temporary encryption key.

Examples:

* Item Key
* Blob Key

---

## Wrapping Key

A higher-level key used to protect Data Keys.

Example:

```text
Vault Encryption Key
```

---

## Envelope

The encrypted structure persisted to storage.

Contains:

* Ciphertext
* Metadata
* Wrapped Key
* Version Information

---

# Object Encryption Flow

## Step 1

Create object:

```text
Identity
Card
Note
Document
```

---

## Step 2

Generate Item Key.

```text
IK-001
```

---

## Step 3

Encrypt payload.

```text
Payload
↓
Encrypt
↓
Ciphertext
```

---

## Step 4

Wrap Item Key.

```text
IK-001
↓
Wrap using VEK
↓
Wrapped IK
```

---

## Step 5

Create envelope.

```text
Object Envelope
```

---

## Step 6

Persist encrypted envelope.

---

# Object Envelope Structure

```swift
struct EncryptedObjectEnvelope {
    let version: Int
    let objectId: VaultObjectID

    let algorithm: String

    let keyId: String

    let nonce: Data

    let ciphertext: Data

    let wrappedItemKey: WrappedKey

    let createdAt: Date
}
```

---

# Blob Encryption Flow

## Step 1

Import file.

Example:

```text
passport.pdf
```

---

## Step 2

Generate Blob Key.

```text
BK-001
```

---

## Step 3

Encrypt blob.

```text
Blob
↓
Encrypt
↓
Encrypted Blob
```

---

## Step 4

Wrap Blob Key.

```text
BK-001
↓
Wrap using VEK
↓
Wrapped BK
```

---

## Step 5

Persist encrypted blob.

---

# Blob Envelope Structure

```swift
struct EncryptedBlobEnvelope {
    let version: Int

    let blobId: BlobID

    let algorithm: String

    let keyId: String

    let nonce: Data

    let checksum: String

    let encryptedSize: Int64

    let wrappedBlobKey: WrappedKey
}
```

---

# Thumbnail Encryption

Thumbnail files are treated exactly like normal blobs.

Flow:

```text
Generate Thumbnail
↓
Generate Blob Key
↓
Encrypt
↓
Store Blob
```

---

# Preview Encryption

Preview files are treated exactly like normal blobs.

Flow:

```text
Generate Preview
↓
Generate Blob Key
↓
Encrypt
↓
Store Blob
```

---

# Envelope Versioning

Every envelope must contain:

```text
version
```

Example:

```text
v1
v2
v3
```

Purpose:

* Crypto migrations
* Format upgrades
* Future compatibility

---

# Algorithm Metadata

Every envelope must contain:

```text
algorithm
```

Example:

```text
xchacha20-poly1305
aes-gcm
future-algorithm
```

Purpose:

Future cryptographic agility.

---

# Key Identification

Every wrapped key must contain:

```text
keyId
```

Purpose:

* Rotation
* Migration
* Recovery

Example:

```text
vek-v1
vek-v2
```

---

# Nonce Rules

Nonces must:

* Be generated securely
* Be unique per encryption operation
* Never be reused with the same key

---

# Integrity Protection

Authenticated encryption must protect:

* Payload
* Metadata
* Envelope contents

Corruption must result in:

```text
Decryption Failure
```

Never partial recovery.

---

# Storage Rules

The following must never be persisted:

* Plaintext Item Key
* Plaintext Blob Key
* Plaintext Payload
* Plaintext Metadata

Only:

* Wrapped Keys
* Ciphertext
* Envelope Metadata

may be stored.

---

# Decryption Flow

```text
Load Envelope
↓
Load Wrapped Key
↓
Unwrap Key using VEK
↓
Decrypt Ciphertext
↓
Return Plaintext
```

Plaintext exists only in memory.

---

# Error Handling

Decryption must fail when:

* Wrong key
* Wrong version
* Corrupted envelope
* Corrupted ciphertext
* Invalid nonce

No partial plaintext may be returned.

---

# Security Invariants

The following must always be true:

* Item Keys are never persisted unwrapped
* Blob Keys are never persisted unwrapped
* Plaintext payloads are never stored
* Plaintext metadata is never stored
* Every object uses its own Item Key
* Every blob uses its own Blob Key
* Envelopes are versioned
* Envelopes include algorithm metadata
* Plaintext exists only during active session

Long-lived local wrapping or unlock keys may be persisted only through
`SecureKeyStore`. This does not change the envelope rule: Item Keys and Blob
Keys remain wrapped in records and are never stored as standalone Keychain
items.

Violation of these rules is a security defect.

---

# Related Documents

* Cryptography Architecture.md
* Key Hierarchy.md
* Recovery Key Model.md
* Threat Model.md
