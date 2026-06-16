# ADR-008 — Generic Vault Object Model

## Status

Accepted

---

# Context

The Secure Vault platform needs to support multiple content types:

* Secure Notes
* Identity Records
* Cards
* Documents
* Photos

During the architecture phase, two approaches were considered.

### Option A — Generic Vault Object

All content types share a common storage model.

```text
VaultObject
```

The object type determines behavior.

### Option B — Specialized Objects

Separate models for each content type.

```text
DocumentObject
PhotoObject
IdentityObject
CardObject
SecureNoteObject
```

---

# Decision

The platform will adopt a **Single Generic Vault Object Model**.

All content types will be represented by a common core object structure.

Supported object types:

* Secure Note
* Identity
* Card
* Document
* Photo

---

# Generic Object Structure

```swift
public struct VaultObject {
    let id: VaultObjectID
    let type: VaultObjectType
    let metadata: VaultMetadata
    let payload: VaultPayload
    let attachments: [VaultAttachment]
    let version: Int
    let createdAt: Date
    let updatedAt: Date
}
```

---

# Shared Characteristics

Every vault object will support:

* Object ID
* Object Type
* Metadata
* Payload
* Attachments
* Versioning
* Search
* Encryption
* Event Tracking
* Trash Lifecycle
* Recovery

---

# Example: Identity

```swift
type = .identity
```

Payload Example:

```json
{
  "name": "Rupesh Saxena",
  "passportNumber": "XXXXXX",
  "dateOfBirth": "1990-01-01"
}
```

---

# Example: Document

```swift
type = .document
```

Payload Example:

```json
{
  "category": "Passport",
  "issuer": "Government of India"
}
```

Attachments:

```text
passport.pdf
thumbnail.jpg
preview.jpg
```

---

# Example: Photo

```swift
type = .photo
```

Payload Example:

```json
{
  "capturedAt": "2026-06-17",
  "location": "Delhi"
}
```

Attachments:

```text
original.heic
thumbnail.jpg
preview.jpg
```

---

# Rejected Alternative

The following design was rejected:

```text
DocumentObject
PhotoObject
IdentityObject
CardObject
SecureNoteObject
```

Reasons:

* Increased storage complexity
* Separate search implementations
* Separate sync implementations
* More migration complexity
* More maintenance cost
* More versioning logic
* More recovery logic

---

# Benefits

## Storage

Single storage schema.

```text
VaultObjectRecord
```

can represent every object type.

---

## Search

Single search engine implementation.

```text
Search once
Index once
Filter by type
```

---

## Sync

Single event model.

```text
object_created
object_updated
object_deleted
```

works for all object types.

---

## Recovery

Recovery logic becomes content-type agnostic.

All objects follow the same restoration process.

---

## Versioning

Single versioning strategy.

```text
Version 1
Version 2
Version 3
...
```

regardless of content type.

---

# UX Impact

The primary navigation will be:

```text
All Items
```

with filtering.

```text
All
Notes
Identities
Cards
Documents
Photos
```

Instead of separate application sections.

This aligns with modern products such as:

* 1Password
* Notion
* Obsidian

---

# Impact on Document Import

Document Import will follow:

```text
Import File
↓
Generate Thumbnail
↓
Generate Preview
↓
Encrypt Blobs
↓
Create VaultObject(type: .document)
↓
Attach Blob References
↓
Save
```

No dedicated document storage model is required.

---

# Consequences

The following subsystems will operate on a single object model:

* Storage Engine
* Search Engine
* Event Engine
* Recovery Engine
* Sync Engine
* Sharing Engine (future)
* Versioning Engine

This significantly reduces architectural complexity.

---

# Final Decision

The Secure Vault platform will use a **Single Generic Vault Object Model** as the foundational storage and domain abstraction for all vault content types.

Status: **Accepted**
