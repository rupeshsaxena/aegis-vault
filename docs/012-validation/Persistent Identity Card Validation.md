# Persistent Identity Card Validation

## Summary

Identity and Card persistence is validated through the public `VaultEngine` API using the same persistent local engine composition used by the iOS app. The tests create a vault, create Identity and Card objects, recreate the engine with the same storage URL, unlock, list objects, and load details.

Result: Identity and Card metadata, object types, categories, and sensitive payload fields survive engine recreation. Reloaded lists contain exactly the persisted records, so no duplicate Identity or Card is created during reload.

## Storage Path

The iOS app resolves persistent storage in:

```text
Application Support/AegisVault/
```

Expected contents:

```text
vault.sqlite
blobs/
```

`AppContainer.makeDefault()` resolves that stable Application Support directory and calls `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`. ViewModels do not access storage, crypto, blob stores, repositories, or SQLite directly.

## Identity Lifecycle Coverage

Validated by automated tests:

- Create vault.
- Create Identity with `VaultObjectType.identity`.
- Persist Identity through `SQLiteStorageEngine`.
- Recreate the engine with the same storage URL.
- Unlock using the current fake/demo recovery-secret path.
- Confirm `listObjects(filter:)` includes the persisted Identity.
- Confirm `getObjectDetail(id:)` loads the persisted Identity.
- Confirm `metadata.category` remains `passport`.
- Confirm `documentNumber` remains `VaultFieldValue.secureText("P1234567")`.
- Confirm list count prevents duplicate Identity creation after reload.
- Confirm deleted Identity state survives engine recreation.

## Card Lifecycle Coverage

Validated by automated tests:

- Create Card with `VaultObjectType.card`.
- Persist Card through `SQLiteStorageEngine`.
- Recreate the engine with the same storage URL.
- Unlock using the current fake/demo recovery-secret path.
- Confirm `listObjects(filter:)` includes the persisted Card.
- Confirm `getObjectDetail(id:)` loads the persisted Card.
- Confirm `metadata.category` remains `creditCard`.
- Confirm `cardNumber` remains `VaultFieldValue.secureText("4111111111111111")`.
- Confirm list count prevents duplicate Card creation after reload.
- Confirm deleted Card state survives engine recreation.

## Security Field Status

- `CreateIdentityUseCase` mapping to `VaultObjectType.identity` and `documentNumber` as `secureText` is covered by existing iOS UseCase tests.
- `CreateCardUseCase` mapping to `VaultObjectType.card` and `cardNumber` as `secureText` is covered by existing iOS UseCase tests.
- Persistent reload now verifies `documentNumber` and `cardNumber` still decode as `VaultFieldValue.secureText`.
- Object Detail hidden-by-default behavior for secure fields is covered by existing `ObjectDetailViewModel` tests.
- No plaintext storage inspection was added in this validation pass; existing SQLite/security tests cover plaintext boundaries separately.

## Implementation Checks

- `listObjects` reads persisted Identity and Card summaries after engine recreation.
- `getObjectDetail` reads persisted Identity and Card payload fields after engine recreation.
- `RootViewModel` startup routing remains delegated to `ResolveAppRouteUseCase`; it does not use in-memory bootstrap state.
- `ResolveAppRouteUseCase` calls the public `VaultEngine.runtimeStatus()` API.
- `AppContainer` uses `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`.

## Validation Commands

Requested package command:

```bash
cd packages/SecureVaultKit
swift test
```

Result:

```text
Failed before tests because the local swiftly-selected Swift 6.2.3 toolchain is missing.
```

Validated with the installed Xcode toolchain:

```bash
cd packages/SecureVaultKit
env DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/Users/rupeshsaxena/Workspace/aegis-vault/packages/SecureVaultKit/.build/module-cache \
  SWIFT_MODULE_CACHE_PATH=/Users/rupeshsaxena/Workspace/aegis-vault/packages/SecureVaultKit/.build/swift-module-cache \
  /Applications/Xcode-26.5.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --disable-sandbox
```

Result:

```text
Executed 263 tests, with 3 tests skipped and 0 failures.
```

iOS project generation:

```bash
cd ios/AegisVault
xcodegen generate
```

Result:

```text
Created project at ios/AegisVault/AegisVault.xcodeproj
```

Requested iOS build command:

```bash
cd ios/AegisVault
xcodebuild -project AegisVault.xcodeproj -scheme AegisVault -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Result:

```text
Failed because no iPhone 16 Pro simulator is installed in this environment.
```

Fallback build using installed simulator:

```bash
cd ios/AegisVault
env DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcodebuild -project AegisVault.xcodeproj \
  -scheme AegisVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  build
```

Result:

```text
BUILD SUCCEEDED
```

## Manual Relaunch Status

Manual click-through relaunch validation was not performed in this pass. The relaunch-equivalent behavior is covered by engine recreation tests.

Manual checklist still recommended:

```text
[ ] Install/run app
[ ] Create vault
[ ] Create Identity
[ ] Confirm Identity appears in Vault Home
[ ] Open Identity detail
[ ] Confirm document number is hidden by default
[ ] Create Card
[ ] Confirm Card appears in Vault Home
[ ] Open Card detail
[ ] Confirm card number is hidden by default
[ ] Stop app
[ ] Relaunch app
[ ] Confirm app routes to Unlock instead of Onboarding
[ ] Unlock vault
[ ] Confirm Identity appears again
[ ] Confirm Card appears again
[ ] Confirm Identity detail loads
[ ] Confirm Card detail loads
[ ] Confirm no duplicate Identity/Card appears
```

## Remaining Gaps

- The simulator/MVP persistent engine still uses fake/demo unlock behavior.
- Plain `swift test` remains blocked by local swiftly toolchain configuration; Xcode Swift validation passes.
- Manual simulator click-through validation is still pending.
- This validation covers Identity/Card object records and secure fields; document/blob persistence limitations are tracked separately.
