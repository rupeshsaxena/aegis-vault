# Preview Architecture

## Status

Accepted

---

# Purpose

This document defines how previews are generated and presented within AegisVault.

Previews allow users to inspect content without opening the original file.

---

# Difference Between Thumbnail And Preview

## Thumbnail

Used for:

* Grid Views
* Lists
* Search Results

Characteristics:

```text
Small
Fast
Low Resolution
```

---

## Preview

Used for:

* Detail Screens
* Object Inspection
* Quick Review

Characteristics:

```text
Large
Readable
Higher Resolution
```

---

# Preview Goals

* Improve user experience
* Reduce full file loading
* Maintain privacy guarantees
* Support offline operation

---

# Security Requirements

Previews are sensitive content.

Therefore:

```text
Preview = Sensitive Data
```

Previews must be protected exactly like originals.

---

# Storage Rules

Forbidden:

```text
Application Support/previews/
preview.jpg
```

Persistent plaintext previews are prohibited.

---

# Required Flow

```text
Generate Preview
↓
Encrypt Preview
↓
Blob Store
↓
Delete Temporary Preview
```

---

# Preview Generation Pipeline

```text
Import File
↓
Generate Preview
↓
Encrypt Preview
↓
Store Preview Blob
↓
Create Attachment
↓
Delete Temporary Files
```

---

# Preview Attachment

```swift
AttachmentRole.preview
```

Example:

```swift
VaultAttachment(
    id: UUID(),
    role: .preview,
    blobId: previewBlobId
)
```

---

# Image Previews

Supported:

* jpg
* jpeg
* png
* heic

Target size:

```text
1200px longest side
```

Maintain aspect ratio.

---

# PDF Previews

Generate:

```text
Rendered First Page
Higher Resolution
```

Purpose:

* Readable document preview
* Fast object inspection

---

# Generic Documents

Current MVP:

```text
Placeholder Preview
```

Future:

```text
Rendered Preview
Text Extraction
Rich Preview
```

---

# Runtime Access

When a user opens an object:

```text
Vault Unlocked
↓
Load Encrypted Preview Blob
↓
Decrypt In Memory
↓
Display Preview
```

---

# Locked Vault Behaviour

When vault is locked:

```text
Search Hidden
Thumbnails Hidden
Previews Hidden
Objects Hidden
```

No sensitive preview data should remain accessible.

---

# Memory Management

Previews should:

* Be loaded lazily
* Be released when screen disappears
* Support cancellation
* Avoid unnecessary caching

---

# Future Enhancements

Future versions may support:

* Multi-page PDF previews
* Rich document rendering
* Video previews
* Streaming previews

---

# Security Invariants

Must always be true:

* Preview stored as encrypted blob
* Plaintext preview never persisted
* Preview removed from temporary workspace
* Preview unavailable when vault is locked
* Preview decryption occurs only after successful unlock

Violation of these rules is a security defect.
