# Swift Coding Standards

## Purpose

Define coding conventions for all Swift code in AegisVault.

---

# Naming

## Types

```swift
VaultHomeView
VaultHomeViewModel
SearchVaultUseCase
VaultEngine
```

Use:

* PascalCase

---

## Variables

```swift
vaultId
objectId
searchResults
```

Use:

* camelCase

---

## Protocols

Avoid:

```swift
VaultEngineProtocol
```

Prefer:

```swift
VaultEngine
StorageEngine
SearchEngine
```

---

# Access Control

Default:

```swift
internal
```

Use:

```swift
public
```

only for APIs intentionally exposed outside SecureVaultKit.

---

# File Structure

Preferred order:

```swift
Imports
Type Declaration
Properties
Initializers
Public APIs
Internal APIs
Private Helpers
Extensions
```

---

# Extensions

Use extensions to organize behavior.

```swift
extension VaultObject {
}
```

Avoid 1000-line files.

---

# Forbidden

* Force unwraps (`!`)
* Force try (`try!`)
* Fatal errors in production code
* Massive God Objects
* Singleton abuse
