# RunnableApp Architecture Audit

## Summary

`RunnableApp/` is an active Xcode compilation shell with 17 Swift files. It is the only directory currently wired into the Xcode project target. A parallel, properly layered structure (`App/`, `Application/`, `Presentation/`, `Tests/`) already exists on disk with 74 files but is **not referenced by any Xcode project target**.

The RunnableApp files contain significant architecture violations: ViewModels and Views are co-located in single files, the `AppContainer` is a monolith, and several Application-layer types are defined inside View files. The correct destination for every RunnableApp file already exists in the proper structure.

No files are migrated as part of this audit. This document is diagnostic only.

---

## Current Directory Structure

```
ios/AegisVault/
├── RunnableApp/           ← 17 files — IN Xcode project (active target)
├── RunnableAppTests/      ← 3 files  — IN Xcode project (active tests)
├── App/                   ← 5 files  — NOT in Xcode project
├── Application/
│   ├── UseCases/          ← 18 files — NOT in Xcode project
│   └── Models/            ← 5 files  — NOT in Xcode project
├── Presentation/          ← 36 files — NOT in Xcode project
└── Tests/                 ← 10 files — NOT in Xcode project
```

Total files outside Xcode project: **74** across proper layered structure.

---

## File Classification

### RunnableApp/ (17 files — active Xcode target)

| File | Contains | Category | Violations |
|------|----------|----------|-----------|
| `AegisVaultApp.swift` | `@main` App struct | App Shell | None |
| `AppContainer.swift` | 10+ protocols, 10+ use case impls, container class | DI + UseCase | Monolith: Application layer mixed into one 400-line file |
| `RootRoute.swift` | `RootRoute` enum | Navigation | Duplicates `App/AppRoute.swift` |
| `RootView.swift` | `RootView` | Navigation View | None |
| `RootViewModel.swift` | `RootViewModel`, `ResolveRootRouteUsing` protocol | Navigation ViewModel | Protocol belongs in Application layer |
| `ResolveRootRouteUseCase.swift` | `ResolveRootRouteUseCase` impl | UseCase | None — correct separation |
| `OnboardingView.swift` | `OnboardingViewModel` + `OnboardingView` | View + ViewModel | ViewModel and View co-located |
| `UnlockView.swift` | `UnlockView` | View | None observed |
| `VaultHomeView.swift` | `VaultHomeFlowUseCases` struct + `VaultHomeViewModel` + `VaultHomeView` | View + ViewModel + Model | Application-layer struct (`VaultHomeFlowUseCases`) defined inside View file; ViewModel co-located |
| `SecureNoteEditorView.swift` | `SecureNoteEditorMode` + `SecureNoteEditorViewModel` + `SecureNoteEditorView` | View + ViewModel + Enum | ViewModel and mode enum co-located with View |
| `ObjectDetailView.swift` | `ObjectDetailViewModel` + `ObjectDetailView` + `UnavailableThumbnailUseCase` | View + ViewModel + UseCase | ViewModel and stub use case co-located with View |
| `TrashView.swift` | `TrashViewModel` + `TrashView` | View + ViewModel | ViewModel co-located with View |
| `IdentityEditorView.swift` | Identity ViewModel + `IdentityEditorView` | View + ViewModel | ViewModel co-located with View |
| `CardEditorView.swift` | Card ViewModel + `CardEditorView` | View + ViewModel | ViewModel co-located with View |
| `DocumentImportView.swift` | Document import ViewModel + `DocumentImportView` | View + ViewModel | ViewModel co-located with View |
| `RecoveryImportView.swift` | `RecoveryImportState` + `RecoveryImportViewModel` + `RecoveryImportView` | View + ViewModel + State | ViewModel and state enum co-located with View; no counterpart in `Presentation/` |
| `IdentityCardUseCases.swift` | Multiple Identity/Card use case protocols + implementations | UseCase | Multiple unrelated use cases bundled into one file |

### RunnableAppTests/ (3 files — active Xcode test target)

| File | Contains | Notes |
|------|----------|-------|
| `RootViewModelTests.swift` | `RootViewModel`, `OnboardingViewModel`, `RecoveryImportViewModel` tests | Tests multiple ViewModels across feature boundaries |
| `VaultHomeViewModelTests.swift` | `VaultHomeViewModel` tests | |
| `ObjectDetailViewModelTests.swift` | `ObjectDetailViewModel` tests | |

### App/ (5 files — NOT in Xcode project)

| File | Contains | Correct destination for |
|------|----------|------------------------|
| `AegisVaultApp.swift` | `@main` App struct | `RunnableApp/AegisVaultApp.swift` |
| `AppContainer.swift` | Decomposed container | `RunnableApp/AppContainer.swift` (monolith) |
| `AppRoute.swift` | `AppRoute` enum | `RunnableApp/RootRoute.swift` |
| `RootView.swift` | `RootView` | `RunnableApp/RootView.swift` |
| `RootViewModel.swift` | `RootViewModel` | `RunnableApp/RootViewModel.swift` |

### Application/UseCases/ (18 files — NOT in Xcode project)

Each file contains a single use case protocol and its concrete implementation, matching governance requirements. These are the decomposed equivalents of `AppContainer.swift` and `IdentityCardUseCases.swift`.

| File | RunnableApp equivalent |
|------|----------------------|
| `CreateVaultUseCase.swift` | Embedded in `AppContainer.swift` |
| `UnlockVaultUseCase.swift` | Embedded in `AppContainer.swift` |
| `LockVaultUseCase.swift` | Embedded in `AppContainer.swift` |
| `ResolveAppRouteUseCase.swift` | `ResolveRootRouteUseCase.swift` |
| `ListVaultObjectsUseCase.swift` | Embedded in `AppContainer.swift` |
| `SearchVaultUseCase.swift` | Embedded in `AppContainer.swift` |
| `GetObjectDetailUseCase.swift` | Embedded in `AppContainer.swift` |
| `MoveObjectToTrashUseCase.swift` | Embedded in `AppContainer.swift` |
| `CreateSecureNoteUseCase.swift` | Embedded in `AppContainer.swift` |
| `UpdateSecureNoteUseCase.swift` | Embedded in `AppContainer.swift` |
| `CreateIdentityUseCase.swift` | Embedded in `IdentityCardUseCases.swift` |
| `UpdateIdentityUseCase.swift` | Embedded in `IdentityCardUseCases.swift` |
| `CreateCardUseCase.swift` | Embedded in `IdentityCardUseCases.swift` |
| `UpdateCardUseCase.swift` | Embedded in `IdentityCardUseCases.swift` |
| `ImportDocumentUseCase.swift` | Embedded in `AppContainer.swift` |
| `LoadThumbnailUseCase.swift` | Embedded in `AppContainer.swift` |
| `TrashUseCases.swift` | Embedded in `AppContainer.swift` |
| `SecurityUseCases.swift` | Embedded in `AppContainer.swift` |

### Application/Models/ (5 files — NOT in Xcode project)

| File | Notes |
|------|-------|
| `SecureNoteEditorViewData.swift` | Editor view model data |
| `IdentityEditorViewData.swift` | Editor view model data |
| `CardEditorViewData.swift` | Editor view model data |
| `DocumentImportFileInfo.swift` | Import model |
| `ThumbnailViewState.swift` | Thumbnail presentation state |

### Presentation/ (36 files — NOT in Xcode project)

Twelve feature subdirectories, each with correctly separated `State`, `ViewModel`, and `View` files:

| Feature | Files | RunnableApp equivalent |
|---------|-------|----------------------|
| `Onboarding/` | State, View, ViewModel | `OnboardingView.swift` |
| `Unlock/` | State, View, ViewModel | `UnlockView.swift` |
| `VaultHome/` | State, View, ViewModel | `VaultHomeView.swift` |
| `SecureNoteEditor/` | State, View, ViewModel | `SecureNoteEditorView.swift` |
| `ObjectDetail/` | State, View, ViewModel | `ObjectDetailView.swift` |
| `Trash/` | State, View, ViewModel | `TrashView.swift` |
| `IdentityEditor/` | State, View, ViewModel | `IdentityEditorView.swift` |
| `CardEditor/` | State, View, ViewModel | `CardEditorView.swift` |
| `ImportDocument/` | State, View, ViewModel | `DocumentImportView.swift` |
| `Settings/` | State, View, ViewModel | Not present in RunnableApp |
| `Settings/SecurityCenter` | State, View, ViewModel | Not present in RunnableApp |
| `Settings/RecoverySettings` | State, View, ViewModel | Not present in RunnableApp |

**Gap:** `RecoveryImportView.swift` (added in Milestone 40) exists in `RunnableApp/` but has no counterpart in `Presentation/`.

### Tests/ (10 files — NOT in Xcode project)

One test file per feature ViewModel, plus `UseCaseTests.swift`. These are the decomposed equivalents of the three `RunnableAppTests/` files.

---

## Architecture Violations

### Critical

**V-1: Monolithic AppContainer**
`RunnableApp/AppContainer.swift` bundles 10+ use case protocols, 10+ concrete use case structs, `ImportRecoveryPackageUsing` protocol, and the `AppContainer` class into a single file (~400 lines). Each use case should live in its own file under `Application/UseCases/`. The correct decomposition already exists on disk.

**V-2: Parallel orphaned structure**
74 files in a properly layered `App/Application/Presentation/Tests/` directory tree exist on disk but are not referenced by any Xcode target. The active Xcode target compiles only the 17-file `RunnableApp/` shell. Any work done on the proper structure is not compiled and cannot be tested.

### High

**V-3: ViewModel and View co-located in single file**
10 of 17 `RunnableApp/` files bundle a ViewModel and its View together. Governance requires each ViewModel and View to be in separate files (matching the `Presentation/` pattern). Affected files: `OnboardingView`, `VaultHomeView`, `SecureNoteEditorView`, `ObjectDetailView`, `TrashView`, `IdentityEditorView`, `CardEditorView`, `DocumentImportView`, `RecoveryImportView`, and `RootViewModel`.

**V-4: Application-layer type defined inside a View file**
`VaultHomeView.swift` defines `VaultHomeFlowUseCases` — a dependency bag struct that belongs in the Application layer. View files must not define types consumed by other views or injected by `AppContainer`.

**V-5: Bundled use cases**
`IdentityCardUseCases.swift` bundles four use case protocols and four concrete implementations. Each use case must be in its own file.

### Medium

**V-6: Duplicate route enum**
`RunnableApp/RootRoute.swift` defines `RootRoute` with cases `onboarding`, `unlock(VaultID)`, `vaultHome(VaultID)`. `App/AppRoute.swift` defines `AppRoute` with equivalent cases. Both serve the same purpose. One must be canonical when the directories are merged.

**V-7: UseCase stub in View file**
`ObjectDetailView.swift` defines `private struct UnavailableThumbnailUseCase: LoadThumbnailUsing` inside the View file. Stub implementations belong in the test target or a dedicated Application file.

**V-8: RecoveryImportView has no Presentation/ counterpart**
`RecoveryImportView.swift` was added to `RunnableApp/` in Milestone 40 but `Presentation/` has no `RecoveryImport/` subdirectory. The next migration milestone must create `Presentation/RecoveryImport/` with separated State, ViewModel, and View files.

### Low

**V-9: RunnableAppTests covers multiple feature boundaries per file**
`RootViewModelTests.swift` tests `RootViewModel`, `OnboardingViewModel`, and `RecoveryImportViewModel`. The `Tests/` directory has one file per feature; RunnableAppTests should follow the same pattern.

---

## Safe To Move Now

Nothing. This is an audit-only milestone. No files are moved or modified. All findings are recorded for migration planning.

---

## Should Remain Temporarily

All 17 `RunnableApp/` files and 3 `RunnableAppTests/` files must remain in place until the Xcode project is migrated to the proper structure. Moving them before the Xcode project is updated will break the build.

---

## Requires Manual Review

| Item | Reason |
|------|--------|
| `App/AppContainer.swift` vs `RunnableApp/AppContainer.swift` | Both define `AppContainer`. The `App/` version must be verified to cover all use cases present in the `RunnableApp/` version before the monolith can be retired. |
| `App/AppRoute.swift` vs `RunnableApp/RootRoute.swift` | Both define the root navigation enum. One canonical version must be chosen. |
| `Presentation/` ViewModels | Must be verified to match the use case protocol signatures currently defined in `RunnableApp/AppContainer.swift` before the Xcode project references are switched. |
| `RecoveryImportView.swift` | No counterpart in `Presentation/`. Must be migrated as part of the next milestone that touches `RecoveryImport`. |
| `Tests/` vs `RunnableAppTests/` | Overlap must be reconciled. `RunnableAppTests/` tests should be subsumed into `Tests/` before `RunnableAppTests/` is removed from the Xcode target. |

---

## Recommended Migration Plan

This plan is advisory. Execution should be scheduled as a dedicated migration milestone.

### Phase 1 — Wire existing structure into Xcode project

1. Add `App/`, `Application/`, `Presentation/`, and `Tests/` directories to the Xcode project file.
2. Compile the proper structure alongside `RunnableApp/` to surface any API gaps or naming conflicts.
3. Resolve duplicate type conflicts (`AppRoute` vs `RootRoute`, duplicate `AppContainer`).

### Phase 2 — Migrate active target

1. Switch the `@main` entry point from `RunnableApp/AegisVaultApp.swift` to `App/AegisVaultApp.swift`.
2. Replace `RunnableApp/AppContainer.swift` with `App/AppContainer.swift` + `Application/UseCases/` files.
3. Replace bundled ViewModel+View files with their `Presentation/` counterparts one feature at a time.
4. Add `Presentation/RecoveryImport/` subdirectory with separated State, ViewModel, and View for `RecoveryImportView`.

### Phase 3 — Remove RunnableApp shell

1. Delete `RunnableApp/` and `RunnableAppTests/` from the Xcode project and disk after all features are covered by `Tests/`.
2. Confirm test count parity between `RunnableAppTests/` and `Tests/` before deletion.

---

## Governance Note

`RunnableApp/` is a compilation shell only. It exists to give the Xcode project a buildable target while the proper directory structure is authored in parallel. Production application code must live under `ios/AegisVault/` in the appropriate layer (`App/`, `Application/`, `Presentation/`). Business logic must live in `Application/UseCases/` or `packages/SecureVaultKit/` — never in View or ViewModel files.

---

_Audit date: 2026-06-23. Toolchain: Xcode 26.5. Branch: develop._
