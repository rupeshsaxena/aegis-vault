# Fastlane Setup

Fastlane is included for repeatable local and CI workflows.

## Initial lanes

```text
fastlane ios test_package
fastlane ios test_ios
fastlane ios build
fastlane ios quality
fastlane ios beta
```

## Recommended first command

```bash
cd ios
bundle install
bundle exec fastlane ios test_package
```

## Notes

- `test_package` validates `SecureVaultKit` independently from the iOS app.
- `test_ios` should be enabled after the Xcode app target and scheme are created.
- `beta` should be enabled only after App Store Connect, signing, and bundle ID are ready.
- Do not commit signing certificates, provisioning profiles, `.env`, or private keys.
