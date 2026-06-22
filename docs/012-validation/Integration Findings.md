# Integration Findings

## Public API Gaps

- `VaultEngine` exposes the required product operations, but SecureVaultKit has no public composition factory that returns a configured engine. The iOS app cannot construct the internal `DefaultVaultEngine`, configuration, or fake dependencies without crossing the module boundary.
- A public factory should define explicit simulator/demo and production composition policies without exposing storage, crypto, repositories, sessions, or blob services.

## Dependency Injection

- `AppContainer` uses initializer injection and owns UseCases and ViewModels without a global mutable singleton.
- ViewModels depend on UseCase protocols only. No iOS ViewModel directly references `StorageEngine`, `CryptoEngine`, `BlobStore`, or repositories.
- `AegisVaultApp` currently accepts an engine factory, but no legal runtime caller can provide one from the public package API.

## Routing

- Added the missing Secure Note editor route and wired Vault Home add, note save, and detail edit actions.
- Moving an object to Trash now routes to Trash.
- Restoring a trashed object now routes to Vault Home.
- Root flow preserves the active vault identifier across product routes.

## Async And ViewModel State

- UseCase and ViewModel operations use async/await across the VaultEngine boundary.
- Secure Note create/edit includes saving, saved, validation failure, and safe locked-vault states.
- Existing app ViewModels use Combine observation. A future migration to Swift Observation should be done consistently after a real Xcode target can execute macro plugins.

## Missing Integration Infrastructure

- A minimal generated app target, shared scheme, bundle configuration, and `@main` entry point now exist.
- The existing feature shell is intentionally excluded until a public runtime engine factory is available.
- Fastlane defines package and simulator build lanes. The iOS test lane remains blocked until an iOS test target is added, and the bundle must install Fastlane before lanes can run.
- The host's default `swift` selector points to an unavailable Swift 6.2.3 toolchain; direct validation used Xcode's installed Swift executable.
- No persistent runtime engine composition is available to resolve no-vault, locked, and unlocked state across process launches.

## Tests Added Or Refined

- Explicit UseCase boundary tests for create, unlock, lock, restore, secure note mapping, and the required vertical slice sequence.
- Secure Note editor ViewModel tests for initial state, save success, validation, routing, and safe error mapping.
- Trash restore and Object Detail move-to-trash routing tests.
