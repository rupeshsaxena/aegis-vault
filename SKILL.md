# SKILL.md — Secure Vault Project Setup for Codex

## Project Identity

Codename: AegisVault  
Product Name: Secure Vault  
Repository: secure-vault  
Primary Package: SecureVaultKit  

## Role

You are acting as a senior software architect and implementation assistant for a production-grade secure vault platform.

## Product Vision

Build a privacy-first, local-first, zero-knowledge secure vault for end consumers.

The product is not merely a password manager. It is intended to become:

- Secure identity platform
- Secure document locker
- Offline-first personal cloud
- Privacy-first vault ecosystem

## Core Principles

- Local-first
- Zero-knowledge
- Device-centric trust
- Optional sync
- Engine-first
- Encrypted object and blob storage
- Java Spring Boot backend later

## MVP Scope

Include:

- Single-user vault
- One primary vault
- Secure notes
- Identity records
- Cards
- Documents
- Photos
- Local encrypted storage
- Encrypted blob storage
- Biometric/passkey unlock abstraction
- Device identity model
- Recovery package abstraction
- Local event log
- Trash with 30-day retention
- Encrypted thumbnails/previews

Exclude:

- Sharing
- Family vault
- Enterprise admin
- Cloud sync implementation
- OCR indexing
- AI assistant
- Browser extension
- Password autofill

## Repository Structure

```text
secure-vault/
├── SKILL.md
├── README.md
├── docs/
├── ios/
│   └── fastlane/
├── android/
├── desktop/
├── backend/
└── packages/
    └── SecureVaultKit/
```

## SecureVaultKit Requirement

`SecureVaultKit` must be an external Swift Package.

Dependency direction:

```text
SecureVaultApp → SecureVaultKit
```

Forbidden:

```text
SecureVaultKit → SecureVaultApp
SecureVaultKit → SwiftUI Views
SecureVaultKit → ViewModels
SecureVaultKit → Navigation/UI
```

## Fastlane Requirement

Add Fastlane from the beginning for repeatable iOS workflows.

Initial lanes:

```text
fastlane ios test_package
fastlane ios test_ios
fastlane ios build
fastlane ios quality
fastlane ios beta
```

Rules:

- `test_package` must run `swift test` inside `packages/SecureVaultKit`.
- `test_ios` should run Xcode unit tests after app target exists.
- `quality` should run package tests first.
- `beta` should remain inactive until signing and App Store Connect are configured.
- Never commit signing certificates, `.p12`, provisioning profiles, or `.env` secrets.

## Backend Direction

Backend will be Java Spring Boot later.

Backend stack:

- Java + Spring Boot
- PostgreSQL
- S3-compatible blob storage
- Redis later
- Kafka later if needed

## What Codex Should Do First

1. Create domain/public Swift model files.
2. Add placeholder protocols.
3. Add initial unit tests.
4. Ensure `swift test` succeeds inside `packages/SecureVaultKit`.
5. Do not implement production crypto or SQLite until the package skeleton and tests are stable.
