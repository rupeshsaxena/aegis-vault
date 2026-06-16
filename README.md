# AegisVault / Secure Vault

A production-grade, privacy-first secure vault platform.

## Direction

Secure Vault is a local-first, zero-knowledge digital vault for:

- identities
- documents
- notes
- photos
- cards

## Initial Technical Focus

The first engineering milestone is `SecureVaultKit`, an external Swift Package.

```text
SecureVaultApp → SecureVaultKit
```

## Fastlane

Fastlane configuration is available under:

```text
ios/fastlane/
```

Start with:

```bash
cd ios
bundle install
bundle exec fastlane ios test_package
```
