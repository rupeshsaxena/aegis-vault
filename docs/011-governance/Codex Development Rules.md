# Codex Development Rules

## Before Coding

Codex must read:

* SKILL.md
* Architecture Governance.md
* Relevant ADRs

---

# When Generating Code

Codex must:

* Preserve dependency direction
* Add tests
* Prefer protocol-driven design
* Prefer composition over inheritance
* Use Sendable when appropriate

---

# Forbidden

Codex must not:

* Add business logic to Views
* Add storage logic to ViewModels
* Add crypto logic to ViewModels
* Add direct SQLite access to Views
* Add global mutable singletons

---

# Documentation

Every major feature should include:

* Tests
* Documentation updates
* ADR updates if needed

---

# Priority Order

When rules conflict:

```text
ADR
↓
Governance Documents
↓
SKILL.md
↓
Implementation
```
