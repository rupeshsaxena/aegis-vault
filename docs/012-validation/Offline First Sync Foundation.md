# Offline-First Sync Foundation

## Scope

This validation covers the SecureVaultKit synchronization foundation. It introduces durable local sync operation recording, queueing, basic sync execution contracts, remote/local repository boundaries, version-vector conflict detection, and blob sync placeholders.

No backend, HTTP client, cloud transport, SwiftUI, UIKit, or platform lifecycle integration is included in this milestone.

## Architecture

Local mutations remain the source of truth and complete before any remote synchronization attempt. The mutation flow is:

1. Vault transaction persists encrypted local state.
2. Domain event persistence completes.
3. Sync operation is recorded in the sync journal.
4. Pending sync operation is available for asynchronous processing.

Persistent simulator/local engines use the SQLite-backed sync journal. In-memory/demo engines use an in-memory journal.

## Zero-Knowledge Boundary

The sync journal stores:

- operation identifier
- vault identifier
- entity type
- entity identifier
- mutation kind
- operation state
- version vector
- object version when available
- encrypted record digest metadata

The sync journal does not store plaintext titles, tags, note bodies, identity numbers, card numbers, document payloads, blob contents, or key material.

## Validation

Command:

```bash
cd packages/SecureVaultKit
env DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/aegis-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/aegis-swiftpm-module-cache xcrun swift test
```

Result:

- 282 tests passed
- 3 Keychain integration tests skipped because Keychain is unavailable in the test environment
- 0 failures

New sync tests verify:

- version vectors detect concurrent changes without relying on timestamps
- conflict detector flags concurrent updates
- in-memory journal deduplicates operation identifiers
- persistent sync journal survives SQLite engine recreation
- sync queue state transitions from pending to completed
- default sync engine uploads pending operations through an injected repository
- vault mutations record pending sync operations
- raw SQLite bytes do not contain sync plaintext markers
- pending sync state survives engine recreation

## Known Limitations

- Remote synchronization is represented by repository protocols and a no-op default implementation.
- Conflict resolution is foundational and does not merge encrypted payloads.
- Blob sync is metadata-only; encrypted blob upload/download transport is not implemented.
- Sync journal entries are recorded after local mutation success, but full cross-store transaction coordination with future remote queues remains a later milestone.
- Retry backoff policy exists as data, but no scheduler or background runner is implemented.
