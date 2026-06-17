# Concurrency Rules

## MainActor Usage

Use `@MainActor` only for:

* ViewModels
* UI State
* Navigation State

---

# Actor Usage

Use actors for:

* VaultSessionActor
* EventLogActor
* BlobMutationActor
* Future Sync Actors

---

# Forbidden

Never perform:

* Crypto
* File I/O
* Blob operations
* SQLite operations

on MainActor.

---

# Sendable

All cross-concurrency models must conform to:

```swift
Sendable
```

where possible.

---

# Isolation

Avoid:

```swift
Task.detached
```

unless justified in ADR.

Prefer structured concurrency.

---

# Cancellation

Long-running operations must support cancellation:

* Document import
* Blob processing
* Thumbnail generation
* Sync
