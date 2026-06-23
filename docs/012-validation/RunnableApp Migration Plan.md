# RunnableApp Migration Plan

## Overview

This document defines the safe, ordered migration from the temporary `RunnableApp/` compilation shell to the production-grade layered structure under `ios/AegisVault/`. The goal is to maintain a buildable iOS app at every commit boundary throughout the migration.

Reference audit: `docs/012-validation/RunnableApp Architecture Audit.md`

---

## Target Directory Structure

All directories below exist on disk. Only `RunnableApp/` and `RunnableAppTests/` are currently wired into `project.yml`.

```
ios/AegisVault/
├── App/                          ← @main, AppContainer, AppRoute, RootView, RootViewModel
├── Application/
│   ├── UseCases/                 ← one file per UseCase protocol + implementation (18 files)
│   └── Models/                   ← view data models shared across features (5 files)
├── Presentation/                 ← one subdirectory per feature, each with State/ViewModel/View
│   ├── Onboarding/
│   ├── Unlock/
│   ├── VaultHome/
│   ├── SecureNoteEditor/
│   ├── ObjectDetail/
│   ├── Trash/
│   ├── IdentityEditor/
│   ├── CardEditor/
│   ├── ImportDocument/
│   ├── Settings/
│   └── RecoveryImport/           ← to be created (gap from Milestone 40)
├── DesignSystem/
│   └── Components/
├── Infrastructure/               ← platform adapters (placeholder, to be populated)
├── Tests/                        ← one test file per ViewModel or UseCase (10 files)
├── RunnableApp/                  ← TEMPORARY — remove after migration complete
└── RunnableAppTests/             ← TEMPORARY — remove after Tests/ is active
```

---

## Current Files and Target Locations

### RunnableApp/ → App/

| Current file | Target file | Risk | Notes |
|---|---|---|---|
| `RunnableApp/AegisVaultApp.swift` | `App/AegisVaultApp.swift` | Low | Already exists in `App/`; identical purpose |
| `RunnableApp/RootRoute.swift` | Deleted | Medium | Superseded by `App/AppRoute.swift` (15 cases vs 3) |
| `RunnableApp/RootView.swift` | `App/RootView.swift` | High | Proper version uses Combine `@StateObject`; needs `@Observable` migration |
| `RunnableApp/RootViewModel.swift` | `App/RootViewModel.swift` | High | Proper version uses Combine; needs `@Observable` migration |
| `RunnableApp/ResolveRootRouteUseCase.swift` | Deleted | Medium | Superseded by `Application/UseCases/ResolveAppRouteUseCase.swift` |
| `RunnableApp/AppContainer.swift` | `App/AppContainer.swift` | Critical | Monolith replaced by decomposed container; 7 API conflicts (see below) |

### RunnableApp/ → Application/UseCases/

| Current file | Target file | Risk | Notes |
|---|---|---|---|
| `RunnableApp/AppContainer.swift` (protocols section) | `Application/UseCases/*.swift` | Critical | 10+ protocols embedded in monolith; proper files already exist on disk |
| `RunnableApp/IdentityCardUseCases.swift` | `Application/UseCases/CreateIdentityUseCase.swift` | High | Type conflict: `IdentityEditorData` vs `IdentityEditorViewData` |
| `RunnableApp/IdentityCardUseCases.swift` | `Application/UseCases/UpdateIdentityUseCase.swift` | High | Same type conflict |
| `RunnableApp/IdentityCardUseCases.swift` | `Application/UseCases/CreateCardUseCase.swift` | High | Type conflict: `CardEditorData` vs `CardEditorViewData` |
| `RunnableApp/IdentityCardUseCases.swift` | `Application/UseCases/UpdateCardUseCase.swift` | High | Same type conflict |

### RunnableApp/ → Presentation/

| Current file | Target location | Risk | Notes |
|---|---|---|---|
| `RunnableApp/OnboardingView.swift` | `Presentation/Onboarding/` | Medium | Bundled ViewModel+View; must be split into separate files |
| `RunnableApp/UnlockView.swift` | `Presentation/Unlock/` | Low | View-only; clean |
| `RunnableApp/VaultHomeView.swift` | `Presentation/VaultHome/` | Critical | Defines `VaultHomeFlowUseCases`; ViewModel uses `@Observable`, proper version uses `ObservableObject` |
| `RunnableApp/SecureNoteEditorView.swift` | `Presentation/SecureNoteEditor/` | Medium | Bundled; mode enum must move to Application/Models |
| `RunnableApp/ObjectDetailView.swift` | `Presentation/ObjectDetail/` | Medium | Contains `UnavailableThumbnailUseCase` stub; parameter label conflict |
| `RunnableApp/TrashView.swift` | `Presentation/Trash/` | Medium | Bundled |
| `RunnableApp/IdentityEditorView.swift` | `Presentation/IdentityEditor/` | High | Uses `IdentityEditorData` (type conflict) |
| `RunnableApp/CardEditorView.swift` | `Presentation/CardEditor/` | High | Uses `CardEditorData` (type conflict) |
| `RunnableApp/DocumentImportView.swift` | `Presentation/ImportDocument/` | Medium | Bundled |
| `RunnableApp/RecoveryImportView.swift` | `Presentation/RecoveryImport/` | Medium | No counterpart exists; subdirectory must be created |

### RunnableAppTests/ → Tests/

| Current file | Target file | Notes |
|---|---|---|
| `RunnableAppTests/RootViewModelTests.swift` | `Tests/RootViewModelTests.swift` + `Tests/RecoveryImportViewModelTests.swift` | Tests three features; must be split |
| `RunnableAppTests/VaultHomeViewModelTests.swift` | `Tests/VaultHomeViewModelTests.swift` | Direct replacement |
| `RunnableAppTests/ObjectDetailViewModelTests.swift` | `Tests/ObjectDetailViewModelTests.swift` | Direct replacement |

---

## API Conflicts Requiring Resolution Before Migration

These conflicts will cause duplicate-symbol build errors if both `RunnableApp/` and the proper structure are compiled together. Each must be resolved atomically before the corresponding file is migrated.

### C-1: Identity/Card model type names (Critical)

| Location | Type name | Protocol affected |
|---|---|---|
| `RunnableApp/IdentityCardUseCases.swift` | `IdentityEditorData` | `CreateIdentityUsing`, `UpdateIdentityUsing` |
| `Application/Models/IdentityEditorViewData.swift` | `IdentityEditorViewData` | `CreateIdentityUsing`, `UpdateIdentityUsing` |
| `RunnableApp/IdentityCardUseCases.swift` | `CardEditorData` | `CreateCardUsing`, `UpdateCardUsing` |
| `Application/Models/CardEditorViewData.swift` | `CardEditorViewData` | `CreateCardUsing`, `UpdateCardUsing` |

**Resolution**: `IdentityEditorViewData` and `CardEditorViewData` are canonical (proper structure wins). Rename `IdentityEditorData` → `IdentityEditorViewData` and `CardEditorData` → `CardEditorViewData` in all RunnableApp files and their callers (`IdentityEditorView.swift`, `CardEditorView.swift`).

### C-2: Search use case protocol name (High)

| Location | Protocol name | Signature |
|---|---|---|
| `RunnableApp/IdentityCardUseCases.swift` | `SearchVaultObjectsUsing` | `execute(query:filter:) -> [VaultObjectSummary]` |
| `Application/UseCases/SearchVaultUseCase.swift` | `SearchVaultUsing` | `execute(query:filter:) -> [VaultObjectSummary]` |

**Resolution**: `SearchVaultUsing` is canonical. Rename `SearchVaultObjectsUsing` → `SearchVaultUsing` in RunnableApp and rename `SearchVaultObjectsUseCase` → `SearchVaultUseCase`.

### C-3: Route enum and protocol (High)

| Location | Enum/Protocol | Cases |
|---|---|---|
| `RunnableApp/RootRoute.swift` | `RootRoute` | 3 (`onboarding`, `unlock`, `vaultHome`) |
| `App/AppRoute.swift` | `AppRoute` | 15 (full navigation graph) |
| `RunnableApp/ResolveRootRouteUseCase.swift` | `ResolveRootRouteUsing` → `RootRoute` | — |
| `Application/UseCases/ResolveAppRouteUseCase.swift` | `ResolveAppRouteUsing` → `AppRoute` | — |

**Resolution**: `AppRoute` and `ResolveAppRouteUsing` are canonical. `RootRoute` and `ResolveRootRouteUsing` are removed once the RunnableApp router adopts `AppRoute`.

### C-4: Observation strategy (Critical)

| Location | Strategy | Governance |
|---|---|---|
| `RunnableApp/` ViewModels | `@Observable` (Swift Observation) | Correct — matches governance |
| `App/RootViewModel.swift` | `ObservableObject` + `@Published` (Combine) | Violation — Known Issue #6 |
| `Presentation/*/ViewModel.swift` | `ObservableObject` + `@Published` (Combine) | Violation — Known Issue #6 |
| `App/RootView.swift` | `@StateObject` + `@ObservedObject` | Violation |

**Resolution**: All `App/` and `Presentation/` ViewModels must be migrated from `ObservableObject` to `@Observable` before the Xcode target switches to these files. RunnableApp ViewModels are the reference implementation for the correct pattern.

### C-5: LoadThumbnail parameter label (Low)

| Location | Parameter label |
|---|---|
| `RunnableApp/ObjectDetailView.swift` (stub) | `execute(objectID:)` — capital `ID` |
| `Application/UseCases/LoadThumbnailUseCase.swift` | `execute(objectId:)` — lowercase `d` |

**Resolution**: `objectId` is canonical. Update the stub `UnavailableThumbnailUseCase` in `ObjectDetailView.swift`.

### C-6: AppContainer type conflict (Critical)

Both `RunnableApp/AppContainer.swift` and `App/AppContainer.swift` define `AppContainer`. They cannot coexist in the same compilation unit.

**Resolution**: Replace the RunnableApp monolith with `App/AppContainer.swift` in a single atomic commit after all upstream conflicts (C-1 through C-5) are resolved.

### C-7: VaultHomeFlowUseCases definition location (High)

`VaultHomeFlowUseCases` is defined in `RunnableApp/VaultHomeView.swift` (a View file) but is referenced by `RunnableApp/AppContainer.swift`. This Application-layer struct must not live in a View file.

**Resolution**: `VaultHomeFlowUseCases` is already referenced in `App/AppContainer.swift`. During migration, keep this struct in the Application layer (moved to `Application/Models/` or removed if the decomposed ViewModel factory pattern is adopted).

---

## Migration Order

Dependencies must be resolved bottom-up. Do not start a step until the previous step builds cleanly.

```
Step 0: Pre-conditions (this milestone)
  ✓ Create Infrastructure/ placeholder
  ✓ Add README.md governance note to RunnableApp/
  ✓ Document all conflicts (this file)

Step 1: Rename type conflicts in RunnableApp (no project.yml changes)
  - Rename IdentityEditorData → IdentityEditorViewData
  - Rename CardEditorData → CardEditorViewData
  - Rename SearchVaultObjectsUsing → SearchVaultUsing
  - Fix LoadThumbnailUsing parameter label: objectID → objectId
  - App still builds from RunnableApp/ only

Step 2: Migrate App/ and Presentation/ ViewModels to @Observable
  - App/RootViewModel.swift: ObservableObject → @Observable
  - App/RootView.swift: @StateObject/@ObservedObject → @State/@Bindable
  - All Presentation/*/ViewModel.swift files: same migration
  - These files are not yet compiled; migration can be done safely on disk

Step 3: Expand route enum
  - Delete RunnableApp/RootRoute.swift
  - Update RunnableApp/ResolveRootRouteUseCase.swift to use AppRoute
  - Update RunnableApp/RootViewModel.swift to use AppRoute
  - Update RunnableApp/RootView.swift to use AppRoute
  - App still builds (RootRoute replaced by AppRoute inline or via typealias)

Step 4: Add Application/UseCases/ and Application/Models/ to project.yml
  - Add sources path to project.yml:
      - path: Application
  - Verify build — no duplicate symbols expected at this point (C-1 and C-2 already resolved)
  - RunnableApp/AppContainer.swift protocols now shadow Application protocols
    → Remove protocol definitions from RunnableApp/AppContainer.swift (keep only container class)

Step 5: Replace RunnableApp/AppContainer.swift with App/AppContainer.swift
  - Add App/ to project.yml sources
  - Delete RunnableApp/AppContainer.swift
  - Delete RunnableApp/IdentityCardUseCases.swift (protocols now in Application/UseCases/)
  - Delete RunnableApp/ResolveRootRouteUseCase.swift (replaced by Application/UseCases/ResolveAppRouteUseCase.swift)
  - Verify build

Step 6-N: Feature-by-feature Presentation/ migration (one commit per feature)
  For each feature F (start with least dependent: Onboarding, Unlock, then others):
    a. Add Presentation/F/ to project.yml
    b. Delete RunnableApp/[F]View.swift
    c. Update AppContainer factory method if needed
    d. Verify build before proceeding to next feature

  Recommended order:
    6.  Onboarding (clean, no cascade effects)
    7.  Unlock (clean)
    8.  SecureNoteEditor
    9.  ObjectDetail
    10. Trash
    11. IdentityEditor (depends on IdentityEditorViewData — resolved in Step 1)
    12. CardEditor (depends on CardEditorViewData — resolved in Step 1)
    13. VaultHome (most complex — cascades to AppContainer)
    14. ImportDocument
    15. RecoveryImport (create Presentation/RecoveryImport/ subdirectory first)

Step 17: Add Settings/ features (not in RunnableApp — additive only)
  - Add Presentation/Settings/ to project.yml

Step 18: Add DesignSystem/ to project.yml
  - Add sources path: DesignSystem

Step 19: Switch test target
  - Add Tests/ to project.yml AegisVaultTests sources
  - Remove RunnableAppTests/ from project.yml
  - Verify all tests pass

Step 20: Remove RunnableApp shell (final)
  - Delete RunnableApp/ directory from disk and project.yml
  - Delete RunnableAppTests/ directory from disk and project.yml
  - Regenerate .xcodeproj from project.yml via xcodegen
  - Run full build + tests
```

---

## Risk Assessment Summary

| Category | Risk | Details |
|---|---|---|
| Observation strategy migration | Critical | `App/` and `Presentation/` ViewModels use Combine. Must migrate to `@Observable` before switching target membership. Affects 12+ ViewModel files. |
| AppContainer replacement | Critical | Two definitions of `AppContainer` cannot coexist. Must remove monolith atomically after all upstream protocols are resolved. |
| Type name conflicts | High | `IdentityEditorData`/`CardEditorData` → proper names affect 4 UseCase files and 2 View files. |
| Route expansion | High | `RootRoute` (3 cases) → `AppRoute` (15 cases) affects `RootView`, `RootViewModel`, `ResolveRootRouteUseCase`. |
| VaultHome complexity | High | `VaultHomeFlowUseCases` struct defined in View file; ViewModel has different interface shape than proper structure. |
| RecoveryImport gap | Medium | `Presentation/RecoveryImport/` does not exist. Must be created before this feature can be migrated. |
| Test migration | Medium | `RootViewModelTests.swift` tests 3 feature ViewModels; must be split before removal. |
| Settings addition | Low | Settings features not in RunnableApp — purely additive, no replacement needed. |

---

## Files That Should NOT Move Yet

| File | Reason |
|---|---|
| `RunnableApp/AegisVaultApp.swift` | Safe to replace only after `App/AppContainer.swift` is the active container |
| Any Presentation/ ViewModel | Observation strategy must be migrated first (Step 2) |
| `App/AppContainer.swift` | Cannot become active until all upstream protocol conflicts resolved (Steps 1-4) |
| `App/RootView.swift` | Depends on `@Observable` ViewModels from Presentation/ (after Step 2) |
| `Tests/` test files | Cannot replace `RunnableAppTests/` until Presentation/ ViewModels are active |

---

## Files That Require Manual Review Before Migration

| File | Review Required |
|---|---|
| `App/AppContainer.swift` | Verify `makeRecoveryImportUseCase()` is present (added in Milestone 40 only to RunnableApp monolith) |
| `App/RootView.swift` | Verify all 15 `AppRoute` cases are handled and `@Observable` migration is complete |
| `Presentation/VaultHome/VaultHomeViewModel.swift` | Verify it accepts decomposed use cases matching `App/AppContainer` factory signature |
| `Presentation/ObjectDetail/ObjectDetailViewModel.swift` | Verify `LoadThumbnailUsing.execute(objectId:)` label matches (not `objectID:`) |
| All `Presentation/*/ViewModel.swift` | Must be migrated from `ObservableObject` to `@Observable` before compilation |
| `RunnableAppTests/RootViewModelTests.swift` | Contains `RecoveryImportViewModel` tests — must move to `Tests/RecoveryImportViewModelTests.swift` |

---

## Suggested Commit Sequence

Each commit must leave the iOS app in a buildable state. Run `xcodegen generate` after any `project.yml` change.

```
feat: create Infrastructure/ directory and RunnableApp governance note   ← this milestone (40.2)

refactor: reconcile IdentityEditorData and SearchVaultUsing type names    ← Step 1
refactor: migrate App/ and Presentation/ ViewModels to @Observable        ← Step 2
refactor: replace RootRoute with AppRoute in RunnableApp router           ← Step 3
feat: add Application/ layer to project.yml                               ← Step 4
refactor: replace RunnableApp AppContainer monolith with App/AppContainer ← Step 5
refactor: migrate Onboarding to Presentation/                             ← Step 6
refactor: migrate Unlock to Presentation/                                 ← Step 7
refactor: migrate SecureNoteEditor to Presentation/                       ← Step 8
refactor: migrate ObjectDetail to Presentation/                           ← Step 9
refactor: migrate Trash to Presentation/                                  ← Step 10
refactor: migrate IdentityEditor to Presentation/                         ← Step 11
refactor: migrate CardEditor to Presentation/                             ← Step 12
refactor: migrate VaultHome to Presentation/                              ← Step 13
refactor: migrate DocumentImport to Presentation/                         ← Step 14
feat: create Presentation/RecoveryImport/ and migrate RecoveryImportView  ← Step 15
feat: add Settings/ features to project.yml                               ← Step 16
feat: add DesignSystem/ to project.yml                                    ← Step 17
refactor: switch test target from RunnableAppTests/ to Tests/             ← Step 18
chore: remove RunnableApp/ shell after migration validated                ← Step 19 (final)
```

---

## project.yml Target State (after all phases complete)

```yaml
targets:
  AegisVault:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: App
      - path: Application
      - path: Presentation
      - path: DesignSystem
      - path: Infrastructure
    dependencies:
      - package: SecureVaultKit
        product: SecureVaultKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aegisvault.app
        PRODUCT_NAME: AegisVault
        SWIFT_VERSION: "5.0"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: AegisVault
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        TARGETED_DEVICE_FAMILY: "1,2"

  AegisVaultTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Tests
    dependencies:
      - target: AegisVault
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aegisvault.app.tests
        GENERATE_INFOPLIST_FILE: YES
```

---

## Validation Checkpoints

After each step in the migration:

1. `cd ios/AegisVault && xcodegen generate` — regenerate .xcodeproj
2. Build the `AegisVault` scheme for `generic iOS Simulator`
3. Run `AegisVaultTests` scheme
4. After full migration: `cd packages/SecureVaultKit && swift test`

The iOS app must build and tests must pass at every commit boundary. Never merge a migration commit that breaks the build.

---

_Plan date: 2026-06-23. Branch: develop. Audit reference: RunnableApp Architecture Audit.md_
