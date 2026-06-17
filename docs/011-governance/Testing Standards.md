# Testing Standards

## Coverage Targets

SecureVaultKit:

```text
80%+
```

critical domain coverage.

---

# Required Tests

Every feature requires:

* Success path
* Failure path
* Edge cases

---

# Vault Engine

Test:

* Create Vault
* Unlock
* Lock
* CRUD
* Search
* Import
* Recovery

---

# Security Tests

Verify:

* No plaintext leakage
* Search cleared on lock
* Deleted objects hidden
* Event consistency

---

# UI Tests

Focus on:

* Onboarding
* Unlock
* Import
* Search
* Recovery

Avoid testing implementation details.
