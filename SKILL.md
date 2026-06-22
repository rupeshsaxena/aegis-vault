# SKILL.md — AegisVault Project Constitution

## Project Identity

Codename: AegisVault
Product Name: Secure Vault
Repository: secure-vault
Primary Package: SecureVaultKit

---

## Role

You are acting as a senior software architect and implementation assistant for a production-grade secure vault platform.

You must prioritize:

* Architecture correctness
* Security
* Maintainability
* Testability
* Long-term product evolution

over implementation speed.

---

# Project Constitution

This repository follows a layered governance model.

Before implementing any feature, modifying architecture, introducing dependencies, or changing storage/security behavior, contributors must read:

1. SKILL.md
2. Accepted ADRs
3. Relevant Governance Documents

---

# Governance Priority

When instructions conflict:

```text
Accepted ADRs
↓
Governance Documents
↓
SKILL.md
↓
Existing Code
↓
New Implementation
```

Architecture decisions must never violate accepted ADRs.

---

# Governance Documents

Governance documents are located under:

```text
docs/011-governance/
```

Required governance files:

```text
Architecture Governance.md
Swift Coding Standards.md
Concurrency Rules.md
Security Engineering Rules.md
Testing Standards.md
Dependency Rules.md
Storage Engineering Rules.md
API Design Standards.md
Documentation Standards.md
ADR Governance.md
Codex Development Rules.md
```

---

# Product Vision

Build a privacy-first, local-first, zero-knowledge secure vault for end consumers.

The platform is not merely a password manager.

Long-term vision:

* Secure Identity Platform
* Secure Document Locker
* Offline-First Personal Cloud
* Privacy-First Data Platform

---

# Core Principles

## Local First

The device is the primary source of truth.

Core operations must function offline.

---

## Zero Knowledge

Backend systems must never decrypt vault content.

Plaintext must never leave trusted devices.

---

## Device Trust

Authentication alone is insufficient.

Devices must become cryptographically trusted.

---

## Engine First

SecureVaultKit is the product foundation.

UI layers consume SecureVaultKit.

Vault logic must not be implemented in the application layer.

---

## Generic Vault Object Model

The platform uses a single generic vault object model.

Supported types:

* Secure Note
* Identity
* Card
* Document
* Photo

All content types share:

* Metadata
* Payload
* Attachments
* Versioning
* Search
* Recovery
* Event Tracking

Specialized storage models require ADR approval.

---

# MVP Scope

Include:

* Single User
* Single Vault
* Secure Notes
* Identity Records
* Cards
* Documents
* Photos
* Local Encrypted Storage
* Blob Storage
* Search
* Trash
* Recovery Package
* Device Identity
* Event Log
* Thumbnail Generation
* Preview Generation

Exclude:

* Sharing
* Family Vault
* Enterprise Admin
* OCR
* AI Assistant
* Browser Extension
* Password Autofill
* Cloud Sync
* Multi-User Vault

---

# Repository Structure

```text
secure-vault/
├── SKILL.md
├── README.md
│
├── docs/
│   ├── 001-vision/
│   ├── 002-architecture/
│   ├── 003-security/
│   ├── 004-storage/
│   ├── 005-sync/
│   ├── 006-backend/
│   ├── 007-client/
│   ├── 008-operational/
│   ├── 009-adr/
│   ├── 010-ux/
│   └── 011-governance/
│
├── ios/
├── android/
├── desktop/
├── backend/
│
└── packages/
    └── SecureVaultKit/
```

---

# Accepted ADRs

Accepted architecture decisions:

```text
ADR-001 Local First
ADR-002 Zero Knowledge
ADR-003 Event-Based Sync
ADR-004 External Vault Engine Package
ADR-005 Single User MVP
ADR-006 No Sharing In MVP
ADR-007 Java Spring Boot Backend
ADR-008 Generic Vault Object Model
```

All implementation must comply with accepted ADRs.

---

# ADR Requirement

ADR approval is required before introducing:

* New architecture patterns
* New persistence technologies
* New sync approaches
* New crypto approaches
* New module boundaries
* New dependency directions
* New third-party dependencies
* Persistent plaintext caching

Store ADRs under:

```text
docs/009-adr/
```

---

# SecureVaultKit Requirement

SecureVaultKit must be an external Swift Package.

Dependency direction:

```text
SwiftUI View
    ↓
ViewModel (@MainActor)
    ↓
UseCase
    ↓
VaultEngine
    ↓
SecureVaultKit Internal Services
    ↓
Infrastructure
```

Forbidden:

```text
View → StorageEngine
View → CryptoEngine
View → BlobStore

ViewModel → StorageEngine
ViewModel → CryptoEngine
ViewModel → BlobStore

SecureVaultKit → SwiftUI
SecureVaultKit → UIKit
SecureVaultKit → Navigation
SecureVaultKit → ViewModels
SecureVaultKit → App Layer
```

---

# Security Requirements

Never store:

* Recovery Secrets
* Encryption Keys
* Vault Payloads

inside:

```text
UserDefaults
Plists
Logs
Analytics
```

Never log:

* Notes
* Identity Information
* Card Information
* Recovery Data
* File Contents
* Cryptographic Material

Custom cryptography is prohibited.

Temporary files must be removed after processing.

---

# Fastlane Requirement

Fastlane must be available from the beginning.

Required lanes:

```text
fastlane ios test_package
fastlane ios test_ios
fastlane ios build
fastlane ios quality
fastlane ios beta
```

Rules:

* test_package must run SecureVaultKit tests
* quality must run package validation
* beta remains disabled until signing exists
* certificates must never be committed

---

# Backend Direction

Backend will be introduced later.

Technology stack:

* Java
* Spring Boot
* PostgreSQL
* S3-Compatible Blob Storage
* Redis (Future)
* Kafka (Future)

Backend responsibilities:

* Accounts
* Device Registry
* Subscription Management
* Sync Events
* Encrypted Blob Storage

Backend must never decrypt vault content.

---

# Testing Requirements

Every milestone must include:

* Success Path Tests
* Failure Path Tests
* Edge Case Tests
* Security Invariant Tests (when applicable)

SecureVaultKit milestones are incomplete unless:

```bash
cd packages/SecureVaultKit
swift test
```

passes successfully.

---

# Documentation Requirements

Major features must update documentation.

Examples:

```text
Blob Storage → docs/004-storage/
Security → docs/003-security/
UX Changes → docs/010-ux/
Architecture Changes → docs/002-architecture/
Governance Changes → docs/011-governance/
```

---

# Current Milestone Order

```text
Foundation
↓
Session Runtime
↓
CRUD
↓
Search
↓
Document Import
↓
Blob Store
↓
Thumbnail Generation
↓
Recovery Package
↓
Device Trust
↓
Real Crypto
↓
SQLite Persistence
↓
iOS Application
↓
Sync
↓
Backend
```

---

# Mandatory Pre-Coding Checklist

Before implementing a milestone:

* Read SKILL.md
* Read relevant ADRs
* Read relevant governance documents
* Preserve dependency direction
* Preserve generic vault object model
* Add tests
* Update documentation
* Avoid architecture drift

---

# Codex Rules

Codex must:

* Follow accepted ADRs
* Follow governance documents
* Preserve dependency direction
* Add tests
* Update documentation
* Prefer protocol-driven design
* Prefer composition over inheritance
* Use actors for sensitive shared state
* Use Sendable where appropriate

Codex must not:

* Add business logic to Views
* Add storage logic to ViewModels
* Add crypto logic to ViewModels
* Expose SecureVaultKit internals
* Introduce architecture drift
* Introduce dependencies without ADR
* Store plaintext sensitive data

---

## Observation Rules

- Prefer Swift Concurrency over Combine.
- Prefer async/await over Publisher chains.
- Prefer AsyncStream and AsyncThrowingStream for event streams.
- Prefer @Observable for SwiftUI observation.
- ViewModels must not expose AnyPublisher.
- ViewModels must not own PassthroughSubject.
- Combine is allowed only for third-party SDK integration.

---

# What Codex Should Do First

When starting work:

1. Read SKILL.md
2. Read accepted ADRs
3. Read relevant governance documents
4. Implement milestone
5. Add tests
6. Update documentation
7. Run validation

Validation:

```bash
cd packages/SecureVaultKit
swift test
```

must pass before milestone completion.
