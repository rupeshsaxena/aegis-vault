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

A generated iOS 17 app target, shared scheme, and minimal SwiftUI entry point now exist and build for a generic iOS Simulator destination.

### Suggested Fix

Keep the checked-in project synchronized with `project.yml` and add a test target in a later milestone.

### Status

Resolved in Milestone 39.6

## No Production VaultEngine Composition Factory

Severity: High

### Affected Flow

App launch, onboarding, persistence, lock, and unlock.

### Reproduction Steps

1. Attempt to instantiate the iOS `AppContainer` from a future app entry point.
2. Attempt to create a concrete engine using only SecureVaultKit public APIs.

### Expected

The app can request a reviewed production or simulator `VaultEngine` composition.

### Actual

The public simulator factory is available and intentionally ephemeral. No reviewed persistent production factory exists yet.

### Suggested Fix

Add a persistent production composition that continues to return only `any VaultEngine`.

### Status

Open

## Simulator XCTest Host Stalls

Severity: Medium

### Affected Flow

Automated iOS XCTest execution and manual vertical-slice validation.

### Reproduction Steps

1. Build the AegisVault shared scheme for an installed simulator.
2. Run the iOS test action.

### Expected

The compiled Identity/Card tests launch and report results.

### Actual

The app and XCTest bundles compile, but two simulator test-host attempts stalled without producing test results.

### Suggested Fix

Inspect the generated `.xcresult`, simulator logs, and test-host launch environment; then rerun `fastlane ios test_ios`.

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
