# Security Engineering Rules

## Core Principles

* Local First
* Zero Knowledge
* Encrypt Before Persistence
* Principle of Least Privilege

---

# Secrets

Never store:

* Recovery Secret
* Encryption Keys
* Device Secrets

in:

```text
UserDefaults
Plist
Logs
Analytics
```

---

# Logging

Never log:

* Payloads
* Identity Information
* Card Data
* Recovery Data
* Cryptographic Material

---

# Temporary Files

Temporary files must be cleaned using:

```swift
defer
```

after processing.

---

# Sensitive UI

App must:

* Hide content in app switcher
* Auto lock
* Require explicit reveal actions

---

# Crypto

Never implement custom cryptography.

Only approved libraries and platform APIs.
