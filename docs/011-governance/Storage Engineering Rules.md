# Storage Engineering Rules

## Storage Philosophy

Object encryption first.

Database encryption is defense-in-depth.

---

# Storage Layers

```text
SQLite
↓
Encrypted Objects
↓
Encrypted Blobs
```

---

# Forbidden

Never store plaintext:

* Titles
* Tags
* Filenames
* Identity Numbers
* Notes
* Card Information

---

# Blob Storage

Every blob must have:

* Blob ID
* Blob Metadata
* Encryption Metadata

---

# Deletion

Deletion must support:

* Soft Delete
* Restore
* Purge
