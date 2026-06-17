# Architecture Governance

## Status

Accepted

## Purpose

This document defines the mandatory architecture, dependency rules, module boundaries, and implementation constraints for the AegisVault iOS application and SecureVaultKit.

All contributors and AI-assisted development tools must follow this document.

---

# Architectural Style

The application architecture shall follow:

* SwiftUI
* MVVM
* Clean Architecture
* Use Case Driven Application Layer
* External Vault Engine Package
* Actor-Based Concurrency

---

# Dependency Direction

The following dependency flow is mandatory:

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

Reverse dependencies are forbidden.

---

# Module Ownership

## iOS Application

The application layer owns:

* SwiftUI Views
* Navigation
* ViewModels
* Dependency Injection
* Application Lifecycle
* User Interaction

## SecureVaultKit

SecureVaultKit owns:

* Vault Creation
* Vault Unlock
* Vault Lock
* Search
* Object Management
* Document Import
* Blob Management
* Recovery
* Device Trust
* Event Log
* Storage
* Cryptography

---

# Forbidden Dependencies

The following are not allowed:

```text
View → StorageEngine
View → CryptoEngine
View → BlobStore

ViewModel → StorageEngine
ViewModel → CryptoEngine

SecureVaultKit → SwiftUI
SecureVaultKit → UIKit
SecureVaultKit → ViewModels
SecureVaultKit → Navigation
```

---

# Public API Rule

The application must only communicate with SecureVaultKit through public APIs.

Allowed:

```swift
try await vaultEngine.createObject(draft)
try await vaultEngine.importDocument(input)
try await vaultEngine.searchObjects(query)
```

Forbidden:

```swift
try await cryptoEngine.encrypt(data)
try await storageEngine.insert(record)
try await blobStore.writeBlob(fileURL)
```

---

# Generic Vault Object Model

The platform uses a single generic vault object model.

Supported object types:

* Secure Note
* Identity
* Card
* Document
* Photo

No specialized storage models shall be created without an approved ADR.

---

# Architecture Drift Policy

Any change to:

* Architectural Style
* Dependency Direction
* Storage Strategy
* State Management Strategy
* Concurrency Model

requires a new ADR before implementation.

---

# Accepted Decisions

* SwiftUI
* MVVM
* Use Cases
* SecureVaultKit External Package
* MainActor ViewModels
* Actor-Based Sensitive Runtime
* Generic Vault Object Model
* Local First Architecture
* Zero Knowledge Security Model
* Event-Based Sync Strategy
