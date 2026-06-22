# Known Issues

## No Runnable iOS Target

Severity: High

### Affected Flow

All manual app and simulator flows.

### Reproduction Steps

1. Open the `ios` directory.
2. Look for an Xcode project, workspace, app target, or shared scheme.

### Expected

A buildable iOS app and test target are available.

### Actual

Only source files and Fastlane placeholders exist.

### Suggested Fix

Create a minimal maintained Xcode project with the local SecureVaultKit package and existing sources.

### Status

Open

## No Public VaultEngine Composition Factory

Severity: High

### Affected Flow

App launch, onboarding, persistence, lock, and unlock.

### Reproduction Steps

1. Attempt to instantiate the iOS `AppContainer` from a future app entry point.
2. Attempt to create a concrete engine using only SecureVaultKit public APIs.

### Expected

The app can request a reviewed production or simulator `VaultEngine` composition.

### Actual

Concrete engine configuration and dependencies are internal to SecureVaultKit.

### Suggested Fix

Add a narrow public composition factory that returns `any VaultEngine` and keeps infrastructure types internal.

### Status

Open

## Fastlane iOS Lanes Are Placeholders

Severity: Medium

### Affected Flow

Automated iOS build and XCTest execution.

### Reproduction Steps

1. Install the repository bundle dependencies.
2. Run `bundle exec fastlane ios test_ios`.

### Expected

The iOS test suite runs.

### Actual

The current bundle does not provide the Fastlane executable. Once installed, the lane is explicitly configured to exit with `iOS app target is not created yet.`

### Suggested Fix

Point the lane at the shared scheme after the Xcode project is introduced.

### Status

Open

## Secure Note With Empty Content May Be Rejected

Severity: Medium

### Affected Flow

Create Secure Note.

### Reproduction Steps

1. Enter a non-empty title.
2. Leave note content empty.
3. Save.

### Expected

The title-only note policy is consistent between the app and engine.

### Actual

The app validates the title only, while current engine draft validation may reject an empty payload.

### Suggested Fix

Resolve the product rule and apply the same validation in SecureVaultKit and the editor.

### Status

Open

## Observation Strategy Is Mixed

Severity: Low

### Affected Flow

iOS presentation implementation and future maintenance.

### Reproduction Steps

1. Inspect the existing iOS ViewModels.
2. Compare their Combine observation with current governance preference for Swift Observation.

### Expected

One documented observation strategy is used consistently.

### Actual

The source foundation predates the current Observation preference and uses `ObservableObject`.

### Suggested Fix

Migrate presentation state consistently after the app target exists and macro-based builds are part of CI.

### Status

Open
