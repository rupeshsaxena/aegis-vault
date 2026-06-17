# API Design Standards

## Intent-Based APIs

Preferred:

```swift
createVault()
createObject()
importDocument()
```

Avoid:

```swift
encrypt()
insertRecord()
writeBlob()
```

at application level.

---

# Async First

Prefer:

```swift
async throws
```

for public APIs.

---

# Error Handling

Use domain errors:

```swift
VaultError
```

Avoid exposing infrastructure errors.

---

# Result Types

Return domain models.

Do not expose storage records.
