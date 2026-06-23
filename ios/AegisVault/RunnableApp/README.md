# RunnableApp — Temporary Compilation Shell

## Purpose

`RunnableApp/` is a **temporary** Xcode compilation shell. Its only purpose is to give the project a buildable iOS target while the production application structure is authored and verified in parallel.

## This is NOT the production app

Production application code lives under `ios/AegisVault/` in the following layers:

```
ios/AegisVault/
├── App/              ← @main entry point, AppContainer, root routing
├── Application/
│   ├── UseCases/     ← one file per UseCase protocol + implementation
│   └── Models/       ← view data models shared across features
├── Presentation/     ← one subdirectory per feature (State/ViewModel/View)
├── DesignSystem/     ← shared UI components, styles, tokens
├── Infrastructure/   ← platform adapters (future)
└── Tests/            ← one test file per ViewModel or UseCase
```

## Governance Rules

- Business logic must live in `SecureVaultKit` or `Application/UseCases/`.
- ViewModels must live in `Presentation/<Feature>/`.
- Views must live in `Presentation/<Feature>/`.
- No ViewModel may be co-located in the same file as its View.
- No `StorageEngine`, `CryptoEngine`, or `BlobStore` may be referenced from Views or ViewModels.
- `AppContainer` must not define UseCase protocols or implementations inline.

## Migration Status

`RunnableApp/` will be removed after the migration described in:

```
docs/012-validation/RunnableApp Migration Plan.md
```

Do not add new production features to files in this directory. New features belong in `Presentation/`, `Application/UseCases/`, or `SecureVaultKit`.
