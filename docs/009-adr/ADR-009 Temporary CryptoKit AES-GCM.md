# ADR-009 Temporary CryptoKit AES-GCM

Status: Accepted

## Context

AegisVault's target symmetric encryption algorithm is XChaCha20-Poly1305, as documented in the cryptography architecture.

SecureVaultKit currently has no approved XChaCha20-Poly1305 implementation dependency. Governance requires an ADR and security review before adding third-party dependencies or introducing a new cryptographic approach.

## Decision

Use Apple's CryptoKit AES-GCM as a temporary platform-provided authenticated encryption implementation for `RealCryptoEngine`.

This implementation is limited to:

- Data encryption and decryption behind the `CryptoEngine` abstraction.
- Key wrapping and unwrapping behind the `CryptoEngine` abstraction.
- Versioned encrypted envelopes that record the algorithm used.

## Rationale

CryptoKit is a platform cryptography framework and avoids adding an unreviewed third-party dependency. AES-GCM provides authenticated encryption and supports the envelope encryption model while preserving cryptographic agility through explicit algorithm metadata.

## Constraints

- Do not treat AES-GCM as the final target algorithm.
- Do not implement custom cryptography.
- Do not implement Argon2id as part of this ADR.
- Do not add Keychain, Secure Enclave, SQLite, sync, backend, or UI behavior as part of this ADR.
- Every encrypted envelope must include version, algorithm, key identifier, nonce, and ciphertext.
- Nonces must be generated securely and must not be reused with the same key.

## Consequences

SecureVaultKit can begin exercising real authenticated encryption flows without introducing a third-party dependency. A future ADR is required to approve and integrate XChaCha20-Poly1305.

## Migration

Encrypted envelopes include their algorithm. Future XChaCha20-Poly1305 support can coexist with AES-GCM during migration and key rotation.
