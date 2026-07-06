# Persistent Secure Note Validation

## Summary

Secure Note persistence is validated through the public `VaultEngine` API and the iOS app routing boundary. The current simulator/MVP wiring stores vault headers and vault objects in stable SQLite storage under Application Support, then reconstructs a new engine against the same storage directory to simulate app relaunch.

Result: Secure Note metadata and payload survive engine recreation, list/detail APIs read the persisted object, and root routing detects the existing vault as locked after recreation.

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

`AppContainer.makeDefault()` calls `AppContainer.persistentStorageURL()` and passes the result to `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`. No temporary directory is used for app persistence.

## Lifecycle Coverage

Validated by automated tests:

- Create vault through `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`.
- Create Secure Note through `VaultEngine.createObject(_:)`.
- Recreate the engine with the same storage URL.
- Confirm `runtimeStatus()` reports the persisted vault as locked.
- Unlock using the current fake/demo recovery-secret path.
- Confirm `listObjects(filter:)` returns exactly one Secure Note, avoiding duplicate reload creation.
- Confirm `getObjectDetail(id:)` returns the persisted Secure Note title, type, and note payload.
- Confirm iOS `ResolveAppRouteUseCase` routes the recreated persistent vault to `AppRoute.unlock`.

## Implementation Checks

- `createObject` persists through `SQLiteStorageEngine` in the persistent local engine composition.
- `listObjects` reads object summaries from persistent storage after engine recreation.
- `getObjectDetail` reads and decrypts the persisted object record after engine recreation.
- `RootViewModel` delegates startup routing to `ResolveAppRouteUseCase`; it does not use in-memory bootstrap state.
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
Executed 261 tests, with 3 tests skipped and 0 failures.
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

iOS test validation:

```bash
cd ios/AegisVault
env DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcodebuild -project AegisVault.xcodeproj \
  -scheme AegisVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test
```

Result:

```text
Executed 125 tests, with 0 failures.
```

## Manual Relaunch Status

Manual click-through relaunch validation was not performed in this pass. The relaunch-equivalent behavior is covered by engine recreation tests and the iOS route test that recreates the persistent engine and resolves the initial app route.

Manual checklist still recommended:

```text
[ ] Install/run app
[ ] Create vault
[ ] Create secure note
[ ] Confirm note appears in Vault Home
[ ] Stop app
[ ] Relaunch app
[ ] Confirm app routes to Unlock instead of Onboarding
[ ] Unlock vault
[ ] Confirm note appears again
[ ] Open Object Detail
[ ] Confirm persisted note detail loads
[ ] Confirm no duplicate note appears
```

## Remaining Gaps

- The simulator/MVP persistent engine still uses fake/demo unlock behavior.
- Plain `swift test` is blocked by the local swiftly toolchain configuration; Xcode Swift validation passes.
- Manual simulator click-through is still pending.
- Blob/document persistence limitations are tracked separately and do not affect Secure Note lifecycle validation.
