# ADR-010 GRDB SQLite Storage

Status: Accepted

## Context

SecureVaultKit needs durable local persistence for encrypted vault records while preserving the existing `StorageEngine` boundary. The repository has no approved SQLite dependency. `ADR-009` is already assigned to the temporary CryptoKit AES-GCM decision, so this decision uses the next available identifier.

## Decision

Use GRDB as the SQLite access layer inside SecureVaultKit. GRDB remains an internal infrastructure dependency and must not be exposed through `VaultEngine` or application ViewModels.

The Milestone 21 foundation may use the platform SQLite 3 API as a temporary bootstrap when GRDB cannot be resolved in the build environment. That adapter must remain isolated behind `StorageEngine`, use bound parameters and explicit transactions, and be replaced by GRDB before production persistence ships.

GRDB is selected because it provides:

- Versioned, testable migrations.
- Transactional writes through `DatabaseWriter`.
- Typed row access and parameter binding.
- Explicit SQL without introducing an object graph or UI persistence framework.
- Mature Swift Package Manager support and direct access to SQLite capabilities.

## Alternatives

### Raw SQLite

Raw SQLite would reduce dependency count, but requires substantial custom statement lifecycle, binding, row decoding, migration, and transaction code. That increases the defect surface in security-sensitive persistence.

### Core Data

Core Data is rejected because it introduces an object-graph persistence model, migration behavior, and application-framework coupling that do not match SecureVaultKit's explicit encrypted-record architecture. Core Data must not be used for vault engine storage.

## Security Boundaries

- Encryption occurs before persistence.
- Plaintext titles, tags, payload fields, notes, filenames, and document identifiers are forbidden in SQLite.
- Encrypted metadata, encrypted payloads, and wrapped keys are stored as BLOB values.
- GRDB and SQLite do not replace object-level encryption.
- Database encryption may be considered later only as defense in depth under a separate decision.

## Consequences

GRDB is approved as a reviewed third-party dependency. Schema changes must remain migration-driven. Storage remains local-first and replaceable behind `StorageEngine`.
