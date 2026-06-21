# User Flows

## Purpose

This document defines the primary user journeys for the Secure Vault product (Codename: AegisVault).

The objective is to align UX decisions with the SecureVaultKit architecture and future platform implementations.

---

# UX Principles

## Local First

All primary vault operations must work offline.

Required offline capabilities:

* Create
* Read
* Update
* Delete
* Search
* Import
* Recovery Package Access

---

## Privacy First

The application should never expose sensitive content unnecessarily.

Examples:

* Show previews only when needed
* Hide sensitive fields by default
* Require explicit reveal actions

---

## Fast Access

Common operations should require minimal interaction.

Examples:

* Face ID → Vault Home
* Search → Open Object
* Import → Save

---

## Secure by Default

Security-sensitive decisions should default to the safest option.

Examples:

* Recovery setup enabled
* Biometric unlock encouraged
* Auto-lock enabled

---

# Flow 1 — First Launch

## Goal

Create a new vault.

## Flow

```text
Launch App
↓
Welcome Screen
↓
Security Principles
↓
Create Vault
↓
Recovery Package Introduction
↓
Required Recovery Warning Acknowledgment
↓
Optional Biometric / Passkey Placeholder
↓
Completion
↓
Vault Home
```

The vault is created by SecureVaultKit from the Create Vault step. The app does not complete onboarding or navigate to Vault Home until the recovery warning is acknowledged. Biometric/passkey setup remains optional and may be skipped for now.

## Open Questions

### Q1

Can user skip recovery package?

Recommendation:

```text
No. Acknowledgment is mandatory before onboarding completion.
```

Require explicit acknowledgment.

### Q2

Can user skip biometric setup?

Recommendation:

```text
Yes. The placeholder step can be skipped.
```

Biometric should remain optional.

---

# Flow 2 — Unlock Vault

## Goal

Access vault content.

## Happy Path

```text
Launch App
↓
Vault Exists And Is Locked
↓
Unlock Screen
↓
Biometric Placeholder Or Passkey Placeholder
↓
Vault Home
```

## Failure Path

```text
Launch App
↓
Face ID Failed
↓
Retry
↓
Passkey
↓
Recovery Option Placeholder
```

Authentication failures use a generic retry message. Missing-vault and locked-state errors are phrased without exposing internal storage or cryptographic details. Real Face ID, passkey authentication, and recovery-secret entry are deferred.

## Security Rules

```text
Search unavailable while locked
Object content unavailable while locked
Previews unavailable while locked
```

---

# Flow 3 — Create Secure Note

## Goal

Store arbitrary information.

## Flow

```text
Vault Home
↓
Create
↓
Secure Note
↓
Enter Title
↓
Enter Content
↓
Save
↓
Encrypted Vault Object Created
```

## Result

```text
Vault Object
Type = Secure Note
```

---

# Flow 4 — Create Identity

## Goal

Store personal identity information.

## Flow

```text
Vault Home
↓
Create
↓
Identity
↓
Choose Identity Type
↓
Enter Fields

Name
Date of Birth
Passport
Aadhaar
PAN
Other

↓
Save
↓
Encrypted Vault Object Created
```

Supported identity types are Passport, Aadhaar, PAN, Driver License, and Other. Passport, Aadhaar, PAN, and Driver License require a document number. Document-number input is masked, stored as a secure payload field, and hidden by default on Object Detail. Issue and expiry dates are optional; attachments, scanning, and document validation remain deferred.

## Result

```text
Vault Object
Type = Identity
```

---

# Flow 5 — Create Card

## Goal

Store card information without adding payment behavior.

## Flow

```text
Vault Home
↓
Add Card
↓
Choose Card Type
↓
Enter Card Details
↓
Save
↓
Encrypted Vault Object Created
```

Supported card types are Credit Card, Debit Card, Insurance Card, Membership Card, and Other. Credit and debit cards require a card number. Card-number input is masked, stored as a secure payload field, and hidden by default on Object Detail. Expiry month and year are optional. Autofill, payment processing, scanning, and attachments are excluded.

## Result

```text
Vault Object
Type = Card
```

---

# Flow 6 — Import Document

## Goal

Store secure files.

## Flow

```text
Vault Home
↓
Import
↓
Select Document
↓
Preview
↓
Choose Category
↓
Import
↓
Generate Thumbnail
↓
Generate Preview
↓
Encrypt Original
↓
Create Vault Object
↓
Vault Home
```

## Supported Types

* PDF
* JPEG
* PNG
* HEIC
* TXT
* DOCX

Additional formats can be added later.

---

# Flow 7 — Search Vault

## Goal

Quickly locate stored content.

## Flow

```text
Vault Home
↓
Tap Search
↓
Enter Query
↓
Local Search
↓
Matching Results
↓
Open Object
```

## Search Sources

* Title
* Tags
* Object Type

An empty search query shows all visible, non-deleted vault items. Type filters narrow those local results.

Vault Home supports All, Notes, Identities, Cards, Documents, and Photos filters. Search and filters are combined, deleted items are excluded, and selecting a result routes to Object Detail. Empty states distinguish an empty vault, an empty content category, and no search matches. The Add menu routes to Identity creation, Card creation, or document import.

## Security Rules

```text
Search only after unlock
No server search
No persistent plaintext search index
Search index cleared on lock
Search index rebuilt from decrypted metadata after unlock
```

---

# Flow 8 — Move Object To Trash

## Goal

Soft-delete content.

## Flow

```text
Object Detail
↓
Review Metadata, Fields, And Attachment Placeholders
↓
Move To Trash
↓
Confirmation
↓
Move To Trash
↓
Object Removed From Active Vault
```

## Result

```text
Object still recoverable
Retention = 30 days
```

Secure text fields on Object Detail are masked by default and require an explicit reveal action. Attachment rows show descriptors only; preview and blob access are not part of this flow.

---

# Flow 9 — Restore From Trash

## Goal

Recover deleted content.

## Flow

```text
Trash
↓
Select Object
↓
Restore
↓
Object Returns To Vault
```

---

# Flow 10 — Permanent Purge

## Goal

Remove content permanently.

## Manual Purge

```text
Trash
↓
Select Object
↓
Delete Permanently
↓
Confirmation
↓
Purge
```

## Automatic Purge

```text
Object In Trash
↓
30 Days Expire
↓
Automatic Purge
```

---

# Flow 11 — Recovery Package Setup

## Goal

Protect against device loss.

## Flow

```text
Create Vault
↓
Generate Recovery Package
↓
Display Recovery Secret
↓
Export Recovery Package
↓
User Stores Safely
↓
Setup Complete
```

## Recovery Package Components

* Recovery Secret
* Vault Recovery Metadata
* Device Trust Bootstrap Information

---

# Flow 12 — Recover Vault On New Device

## Goal

Restore access.

## Flow

```text
Install App
↓
Recover Existing Vault
↓
Import Recovery Package
↓
Enter Recovery Secret
↓
Verify Package
↓
Create Trusted Device
↓
Restore Vault Access
```

---

# Flow 13 — Settings

## Sections

* Vault
* Security
* Recovery
* Devices
* Storage
* Trash
* About

## Security Settings

* Enable Face ID
* Auto Lock
* Lock Timeout
* Recovery Package
* Trusted Devices

---

# Information Architecture

```text
Vault
│
├── Notes
├── Identities
├── Cards
├── Documents
├── Photos
│
├── Search
├── Trash
├── Recovery
└── Settings
```

---

# MVP UX Decisions

## Accepted

* Single User
* Single Vault
* No Sharing
* Local Search
* Offline First
* Recovery Package Required
* Biometric Optional
* 30-Day Trash Retention

---

# Deferred

* Family Vault
* Multi-User Vault
* Cloud Sync
* OCR
* AI Assistant
* Browser Extension
* Password Autofill
* Folder Hierarchies
* Collections
* Workspaces

---

# Open Architectural Decision

## Vault Object Model

### Recommended

```text
Single Generic Vault Object
```

All content types become:

* Secure Note
* Identity
* Card
* Document
* Photo

built on the same object model.

### Benefits

* Simpler Search
* Simpler Sync
* Simpler Versioning
* Simpler Sharing
* Simpler Recovery

### Status

```text
Recommended
Pending Final Approval
```
