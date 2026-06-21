# Thumbnail Storage Architecture

## Status

Accepted

---

# Purpose

This document defines how thumbnails are generated, stored, encrypted, and retrieved within AegisVault.

The goal is to provide a visual representation of stored content while preserving the platform's privacy-first and zero-knowledge principles.

---

# Scope

Supported content types:

* Images
* PDFs
* Documents

Future support:

* Video
* Audio
* Rich Documents

---

# Design Goals

* Fast vault browsing
* Reduced memory usage
* Offline operation
* Encrypted thumbnail storage
* No permanent plaintext thumbnails

---

# Thumbnail Definition

A thumbnail is a small visual representation of an imported object.

Examples:

```text
passport.pdf
    ↓
thumbnail.jpg

photo.heic
    ↓
thumbnail.jpg
```

---

# Security Requirements

## Never Store Plaintext Thumbnails

Forbidden:

```text
Application Support/thumbnails/
thumbnail.jpg
```

Persistent plaintext thumbnails are prohibited.

---

## Required Storage Model

```text
Generate Thumbnail
↓
Encrypt Thumbnail
↓
Store As Blob
↓
Delete Plaintext Thumbnail
```

Only encrypted blobs are persisted.

---

# Thumbnail Lifecycle

```text
Import File
↓
Generate Thumbnail
↓
Encrypt Thumbnail
↓
Blob Store
↓
Create Attachment
↓
Delete Temporary File
```

---

# Attachment Structure

Thumbnail attachments use:

```swift
AttachmentRole.thumbnail
```

Example:

```swift
VaultAttachment(
    id: UUID(),
    role: .thumbnail,
    blobId: thumbnailBlobId
)
```

---

# Supported Formats

## Images

Supported:

* jpg
* jpeg
* png
* heic

Generation:

```text
512 x 512
Aspect Fit
```

---

## PDF

Supported:

* pdf

Generation:

```text
First Page Render
512 x 512
```

---

## Generic Documents

Supported:

* txt
* docx

Generation:

```text
Placeholder Thumbnail
```

Future versions may support document rendering.

---

# Blob Storage Layout

Logical structure:

```text
Vault Object
│
├── Original Blob
├── Thumbnail Blob
└── Preview Blob
```

Each thumbnail receives a dedicated BlobID.

Thumbnail generation and encrypted persistence are best-effort during import. If generation or derivative persistence fails, the original encrypted blob and Document object may still be created without a thumbnail reference. Cancellation continues to abort the import.

---

# Performance Requirements

Target generation times:

| Content Type     | Target  |
| ---------------- | ------- |
| Image            | < 200ms |
| PDF              | < 500ms |
| Generic Document | < 100ms |

---

# Memory Rules

Thumbnail generation must:

* Avoid loading large files entirely into memory
* Release intermediate images promptly
* Support cancellation

---

# Future Enhancements

Future versions may support:

* Multi-resolution thumbnails
* Smart thumbnail selection
* Video frame extraction
* Background thumbnail regeneration

---

# Security Invariants

Must always be true:

* Plaintext thumbnail never persisted
* Thumbnail stored as encrypted blob
* Thumbnail removed from temporary workspace
* Thumbnail inaccessible while vault is locked

Violation of these rules is a security defect.
