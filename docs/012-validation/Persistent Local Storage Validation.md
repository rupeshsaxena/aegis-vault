# Persistent Local Storage Validation

## Summary

The iOS app reset across launches because `AegisVaultApp` constructed `VaultEngineFactory.makeSimulatorEngine()`. That factory intentionally used in-memory simulator infrastructure (`SimulatorStorageEngine`, `SimulatorBlobStore`, `SimulatorEventEngine`, and `SimulatorDeviceTrustEngine`), so vault headers and objects disappeared whenever the process restarted.

The app now creates its engine through `AppContainer.makeDefault()`, which resolves a stable Application Support directory and calls `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`.

## Storage Location

Simulator/MVP storage is rooted at:

```text
Application Support/AegisVault/
```

Inside that directory:

```text
vault.sqlite
blobs/
```

The iOS app resolves the Application Support directory through `FileManager` inside `AppContainer`, then passes only the resulting URL into the public `VaultEngineFactory` API. ViewModels and UseCases do not access storage, crypto, blob, SQLite, or repository types.

## Storage Mode

- SQLite is real local SQLite through `SQLiteStorageEngine`.
- Blob files are file-backed through `FileSystemBlobStore`.
- Crypto remains the approved fake/MVP crypto composition for this simulator factory so object keys can be reconstructed by the current fake unlock flow.
- Search remains in-memory and is rebuilt after unlock.
- Root routing uses `VaultEngine.runtimeStatus()` through `ResolveAppRouteUseCase`, so vault existence is now backed by persistent storage.

## Validated Flows

- Persistent engine creates a stable directory, database, and blob directory.
- Vault header survives engine recreation.
- Secure note object survives engine recreation.
- Deleted object state survives engine recreation.
- AppContainer uses the persistent public factory instead of the in-memory simulator factory.
- Root routing still goes through the UseCase -> VaultEngine boundary.
- Root routing maps persisted runtime status to the correct first screen:
  - missing vault -> onboarding
  - existing locked vault -> unlock
  - unlocked session -> vault home

## Persistent Unlock Routing

`AppContainer.makeDefault()` resolves a stable Application Support directory and calls `VaultEngineFactory.makePersistentLocalEngine(storageURL:)`. `RootViewModel` does not own demo bootstrap state; it calls `ResolveAppRouteUseCase`, which calls the public `VaultEngine.runtimeStatus()` API.

Expected relaunch behavior:

```text
No vault header in Application Support/AegisVault/vault.sqlite
  -> Onboarding

Vault header exists, no active runtime session after process restart
  -> Unlock

Vault header exists, active runtime session in current process
  -> Vault Home
```

Unlock remains the current fake/demo unlock path for simulator/MVP validation. The route decision is persistent, but production recovery-derived unlock material is still future work.

## Validation Commands

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

```bash
cd ios/AegisVault
xcodegen generate
env DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcodebuild -project AegisVault.xcodeproj \
  -scheme AegisVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Result:

```text
BUILD SUCCEEDED
```

The requested `iPhone 16 Pro` simulator was not installed in this environment, so validation used the available `iPhone 17 Pro` simulator.

```bash
cd ios/AegisVault
env DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcodebuild -project AegisVault.xcodeproj \
  -scheme AegisVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Result:

```text
Executed 124 tests, with 0 failures.
```

Added/verified route-specific app tests:

- `ResolveAppRouteUseCase` routes missing vaults to onboarding.
- `ResolveAppRouteUseCase` routes persisted locked vaults to unlock.
- `ResolveAppRouteUseCase` routes unlocked sessions to vault home.
- `RootViewModel` applies onboarding, unlock, and vault home routes from its use case.

## Manual Simulator Checklist

Use the installed iPhone 17 Pro simulator in this environment:

```text
[x] Build app for simulator
[x] Launch app during automated app test execution
[x] Validate persistent vault/object survival through engine recreation tests
[x] Validate root route decisions through iOS unit tests
[ ] Manually install/run app
[ ] Manually create vault
[ ] Manually create secure note
[ ] Manually stop app
[ ] Manually relaunch app
[ ] Manually verify app does not reset to onboarding
[ ] Manually unlock/load vault
[ ] Manually verify secure note still appears
[ ] Manually verify object detail still loads
```

Manual click-through relaunch validation was not performed in this non-interactive pass. The equivalent persistence behavior is covered by SecureVaultKit engine-recreation tests, and the iOS route behavior is covered by unit tests.

## Known Limitations

- This milestone wires persistent local simulator storage only. It does not add cloud sync, backend storage, sharing, OCR, AI, or new UI.
- The persistent simulator factory still uses fake/MVP crypto. Real recovery-derived unlock material and production key storage remain future work.
- Blob files are stored in a stable local directory, but the current document import path keeps some blob record metadata inside the in-memory blob store. Document blob/thumbnail recovery after full engine recreation needs a follow-up repository/storage integration pass.
- Search and thumbnail caches remain in-memory by design and are cleared on lock.
