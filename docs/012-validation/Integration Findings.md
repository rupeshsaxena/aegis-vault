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

## Recovery Import

- `VaultEngine` protocol extended with `importRecoveryPackage(from:recoverySecret:)` and `validateRecoveryPackage(from:recoverySecret:)`.
- `DefaultVaultEngine` implements both: reads the package file, parses JSON via `DefaultRecoveryPackageService`, validates the KDF-backed `validationProof`, and returns `RecoveryImportResult` with status `.validated`.
- `RecoveryImportResult` and `RecoveryImportStatus` are public SecureVaultKit types; raw key material is never included in the result.
- `RecoveryImportView` presents the flow: file picker, security warnings, secret entry, validation progress, and success/failure states.
- `RecoveryImportViewModel` is `@MainActor @Observable`; maps engine errors to user-safe messages; never logs or persists the recovery secret.
- `ImportRecoveryPackageUseCase` and `ImportRecoveryPackageUsing` follow the established UseCase pattern in `AppContainer`.
- Current limitation: the recovery package format contains identity metadata and a KDF validation proof only — no vault encryption keys. Recovery validates the package is authentic but does not unlock the vault. Full key-material recovery is a future milestone.

## Tests Added Or Refined

- Explicit UseCase boundary tests for create, unlock, lock, restore, secure note mapping, and the required vertical slice sequence.
- Secure Note editor ViewModel tests for initial state, save success, validation, routing, and safe error mapping.
- Trash restore and Object Detail move-to-trash routing tests.
- Engine-backed Identity/Card create, read, edit, trash, restore, filter, and search tests.
- Editor validation, Vault Home listing, secure-field masking, and architecture-boundary tests.
- `RecoveryImportViewModel` tests: 8 tests covering idle state, package selection, empty-secret guard, import success, safe error mapping, retry transition, and secret non-exposure.
- `SecureVaultKit` `RecoveryImportTests`: 9 tests covering validate success/failure, import success/failure, corrupted package, invalid file URL, secret non-persistence, raw key non-exposure, and no-device-creation on failure.
