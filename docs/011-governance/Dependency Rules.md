# Dependency Rules

## Allowed

```text
View
 ↓
ViewModel
 ↓
UseCase
 ↓
VaultEngine
 ↓
Internal Services
```

---

# Forbidden

```text
View → StorageEngine
View → CryptoEngine

ViewModel → StorageEngine
ViewModel → BlobStore

UseCase → SQLite

SecureVaultKit → SwiftUI
```

---

# Third Party Libraries

Every new dependency requires:

* Technical justification
* ADR
* Security review

---

# Preferred Dependencies

* Swift Testing
* GRDB (future)
* Apple Frameworks

Minimize external dependencies.
