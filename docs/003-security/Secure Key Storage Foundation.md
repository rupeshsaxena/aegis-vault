# Secure Key Storage Foundation

## Status

Apple Keychain foundation implemented

## Problem

Long-lived vault keys will eventually require platform-protected storage without coupling SecureVaultKit to one operating system or exposing key storage to application ViewModels.

## Solution

`SecureKeyStore` defines an asynchronous platform-neutral boundary for storing,
loading, deleting, checking, and listing key metadata. The in-memory
implementation exists only for tests. `KeychainSecureKeyStore` implements the
boundary with namespaced data-protection Keychain generic-password items.

```mermaid
flowchart TD
    Engine["SecureVaultKit internal engine"] --> Store["SecureKeyStore"]
    Store --> Memory["InMemorySecureKeyStore (tests)"]
    Store --> Keychain["KeychainSecureKeyStore (Apple)"]
    Store --> Keystore["Android Keystore (future)"]
    Store --> TPM["Windows TPM (future)"]
```

## Security Boundaries

- Raw key material is returned only as runtime-only `SymmetricKeyMaterial`.
- Key listings expose metadata and key identifiers, never key bytes.
- No key material is stored in UserDefaults, logs, analytics, or plaintext files.
- Application Views and ViewModels must not access `SecureKeyStore` directly.
- Item and blob keys remain short-lived and wrapped according to the envelope encryption architecture.

## Apple Namespace And Metadata

All items use the service identifier:

```text
com.aegisvault.securevaultkit.keys
```

The item account is the `SecureKeyStoreKey`. Raw symmetric key bytes are stored
only as Keychain item data. Key identifier, creation time, update time, and
access policy are encoded in the item's generic metadata attribute so listings
do not return key bytes.

## Access Policy Mapping

| SecureVaultKit policy | Apple Keychain behavior |
| --- | --- |
| `afterFirstUnlock` | After first unlock, this device only |
| `whenUnlocked` | While unlocked, this device only |
| `biometricCurrentSet` | Passcode-set accessibility plus current biometric set access control |
| `passcodeProtected` | Passcode-set accessibility plus device passcode access control |

`LAContext` is created inside `KeychainSecureKeyStore` for protected loads and
never crosses the SecureVaultKit infrastructure boundary. Biometrics authorize
Keychain access; they do not become encryption keys.

## Tradeoffs And Risks

- The in-memory store provides no at-rest protection and must remain test/support infrastructure.
- Changing an existing item's access policy requires delete-and-reinsert because Keychain access-control attributes are immutable; callers should treat policy migration as a deliberate operation.
- Full Secure Enclave asymmetric-key generation remains deferred.
- Create-vault and unlock flows are not wired to this store yet because the current flows use fake/reference key material. Persisting that material would establish the wrong production key lifetime.

## Validation

In-memory tests cover CRUD, failure injection, and all access-policy metadata.
Apple integration tests cover Keychain store/load, contains, list metadata, and
delete using unique identifiers. They are conditionally skipped when the test
host reports an unavailable data-protection Keychain, as occurs in unsigned or
non-entitled command-line CI processes.

Manual validation must run from a signed Apple application context:

1. Verify `whenUnlocked` and `afterFirstUnlock` roundtrips.
2. Verify `biometricCurrentSet` with enrolled biometrics and invalidate it by changing enrollment.
3. Verify `passcodeProtected` prompts for device authentication.
4. Verify deleting each item removes both key data and metadata.
