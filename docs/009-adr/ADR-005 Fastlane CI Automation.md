# ADR-005 Fastlane CI Automation

Status: Accepted

## Decision

Use Fastlane from the beginning for iOS test, build, quality, and future TestFlight workflows.

## Reason

The project needs repeatable automation for a security-focused production app.

## Initial Lanes

- `test_package`
- `test_ios`
- `build`
- `quality`
- `beta`
