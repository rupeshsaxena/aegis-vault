# Preview Architecture

## Status

Milestone 34 foundation. Thumbnail rendering is implemented; full preview
rendering remains deferred.

## Boundary

The iOS application may request display material only through public
`VaultEngine` APIs and application use cases. It must never load blobs, unwrap
keys, decrypt files, or access storage records directly.

```text
SwiftUI View
-> MainActor ViewModel
-> LoadThumbnailUseCase
-> VaultEngine.loadThumbnail(for:)
-> SecureVaultKit blob and crypto services
```

`VaultThumbnail` contains only object identity, display bytes, content type,
and optional creation time. It exposes no blob identifier, key material,
infrastructure service, or filesystem path.

## Lifecycle

Thumbnail requests require an unlocked session. SecureVaultKit locates the
thumbnail attachment, decrypts its encrypted blob inside a temporary workspace,
returns display-safe bytes, and removes temporary plaintext. Returned bytes may
be cached only in memory and the cache is cleared on vault lock.

Views request thumbnails independently from object loading. Loading failures,
missing derivatives, and unsupported formats render a generic placeholder and
must not fail Vault Home or Object Detail.

## Preview API

A future `VaultPreview` API should follow the same boundary, session checks,
temporary-workspace cleanup, and lock invalidation. Milestone 34 does not expose
or persist decrypted preview files and does not implement multi-page previews.

## Security Invariants

- No persistent plaintext thumbnail or preview cache.
- No thumbnail or preview bytes in `UserDefaults` or logs.
- No blob, crypto, or storage dependency in iOS view models.
- No display material is available after lock.
- Encrypted derivative blobs are the only persistent representation.
