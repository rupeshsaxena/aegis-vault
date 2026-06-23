# Integration Findings

## Public API Gaps

- `VaultEngineFactory.makeSimulatorEngine()` now returns a fully functional in-memory engine without exposing internal storage, crypto, repository, session, or blob services.
- A security-reviewed persistent production composition is still required.

## Dependency Injection

- `AppContainer` uses initializer injection and owns UseCases and ViewModels without a global mutable singleton.
- ViewModels depend on UseCase protocols only. No iOS ViewModel directly references `StorageEngine`, `CryptoEngine`, `BlobStore`, or repositories.
- The runnable `AppContainer` creates one simulator engine and injects only UseCases into ViewModels.

## Routing

- Added the missing Secure Note editor route and wired Vault Home add, note save, and detail edit actions.
- Moving an object to Trash now routes to Trash.
- Restoring a trashed object now routes to Vault Home.
- Root flow preserves the active vault identifier across product routes.
- Vault Home creates Identity/Card editors, opens type-aware detail, and refreshes after create, edit, trash, and restore.

## Async And ViewModel State

- UseCase and ViewModel operations use async/await across the VaultEngine boundary.
- Secure Note create/edit includes saving, saved, validation failure, and safe locked-vault states.
- Identity/Card editors cover create/edit state and required-field validation using Swift Observation.
- Object Detail masks `secureText` values by default and reveals them only after explicit action.
- Existing app ViewModels use Combine observation. A future migration to Swift Observation should be done consistently after a real Xcode target can execute macro plugins.

## Missing Integration Infrastructure

- A minimal generated app target, shared scheme, bundle configuration, and `@main` entry point now exist.
- The runnable target contains the validated note, Identity, Card, detail, and Trash slices. The older source-only shell remains excluded.
- Fastlane defines package, simulator build, and iOS test lanes. The bundle must install Fastlane before lanes can run.
- The host's default `swift` selector points to an unavailable Swift 6.2.3 toolchain; direct validation used Xcode's installed Swift executable.
- No persistent runtime engine composition is available to resolve no-vault, locked, and unlocked state across process launches.

## Tests Added Or Refined

- Explicit UseCase boundary tests for create, unlock, lock, restore, secure note mapping, and the required vertical slice sequence.
- Secure Note editor ViewModel tests for initial state, save success, validation, routing, and safe error mapping.
- Trash restore and Object Detail move-to-trash routing tests.
- Engine-backed Identity/Card create, read, edit, trash, restore, filter, and search tests.
- Editor validation, Vault Home listing, secure-field masking, and architecture-boundary tests.
