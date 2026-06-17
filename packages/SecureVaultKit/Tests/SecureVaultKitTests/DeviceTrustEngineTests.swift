import XCTest
@testable import SecureVaultKit

final class DeviceTrustEngineTests: XCTestCase {
    func testCreateFirstDeviceIdentityCreatesTrustedDevice() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")

        let identity = try await engine.createFirstDeviceIdentity(
            deviceId: DeviceID("device-1"),
            deviceName: "Rupesh's iPhone",
            platform: "iOS",
            vaultId: vaultId
        )

        let trustedDevices = try await engine.listTrustedDevices(for: vaultId)

        XCTAssertEqual(identity.deviceId, DeviceID("device-1"))
        XCTAssertEqual(identity.deviceName, "Rupesh's iPhone")
        XCTAssertEqual(identity.platform, "iOS")
        XCTAssertEqual(identity.trustState, .trusted)
        XCTAssertEqual(trustedDevices, [identity])
    }

    func testFirstDeviceHasManageDevicesPermission() async throws {
        let engine = InMemoryDeviceTrustEngine()

        let identity = try await engine.createFirstDeviceIdentity(
            deviceId: DeviceID("device-1"),
            deviceName: "Primary",
            platform: "iOS",
            vaultId: VaultID("vault-1")
        )

        XCTAssertTrue(identity.permissions.contains(.manageDevices))
    }

    func testRegisterPendingDeviceCreatesPendingDevice() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")

        let identity = try await engine.registerPendingDevice(
            deviceId: DeviceID("device-2"),
            deviceName: "MacBook",
            platform: "macOS",
            publicKey: "fake-public-key-device-2",
            for: vaultId
        )

        let storedIdentity = try await engine.getDevice(id: DeviceID("device-2"), for: vaultId)

        XCTAssertEqual(identity.trustState, .pending)
        XCTAssertEqual(storedIdentity, identity)
    }

    func testTrustDeviceChangesStateToTrusted() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")
        _ = try await engine.registerPendingDevice(
            deviceId: DeviceID("device-2"),
            deviceName: "MacBook",
            platform: "macOS",
            publicKey: "fake-public-key-device-2",
            for: vaultId
        )

        let certificate = try await engine.trustDevice(
            id: DeviceID("device-2"),
            for: vaultId,
            issuedBy: DeviceID("device-1"),
            permissions: [.read, .sync]
        )

        let identity = try await engine.getDevice(id: DeviceID("device-2"), for: vaultId)
        XCTAssertEqual(identity.trustState, .trusted)
        XCTAssertEqual(identity.permissions, [.read, .sync])
        XCTAssertEqual(certificate.deviceId, DeviceID("device-2"))
        XCTAssertEqual(certificate.issuedByDeviceId, DeviceID("device-1"))
        XCTAssertEqual(certificate.permissions, [.read, .sync])
        XCTAssertFalse(certificate.signature.isEmpty)
    }

    func testRevokeDeviceChangesStateToRevoked() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")
        try await createTrustedSecondaryDevice(using: engine, vaultId: vaultId)

        try await engine.revokeDevice(id: DeviceID("device-2"), for: vaultId)

        let identity = try await engine.getDevice(id: DeviceID("device-2"), for: vaultId)
        XCTAssertEqual(identity.trustState, .revoked)
    }

    func testMarkDeviceLostChangesStateToLost() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")
        try await createTrustedSecondaryDevice(using: engine, vaultId: vaultId)

        try await engine.markDeviceLost(id: DeviceID("device-2"), for: vaultId)

        let identity = try await engine.getDevice(id: DeviceID("device-2"), for: vaultId)
        XCTAssertEqual(identity.trustState, .lost)
    }

    func testRevokedDeviceDoesNotAppearInTrustedList() async throws {
        let engine = InMemoryDeviceTrustEngine()
        let vaultId = VaultID("vault-1")
        let primary = try await engine.createFirstDeviceIdentity(
            deviceId: DeviceID("device-1"),
            deviceName: "Primary",
            platform: "iOS",
            vaultId: vaultId
        )
        try await createTrustedSecondaryDevice(using: engine, vaultId: vaultId)

        try await engine.revokeDevice(id: DeviceID("device-2"), for: vaultId)

        let trustedDevices = try await engine.listTrustedDevices(for: vaultId)
        XCTAssertEqual(trustedDevices, [primary])
    }

    func testUnknownDeviceLookupFails() async {
        let engine = InMemoryDeviceTrustEngine()

        await XCTAssertThrowsVaultError(.invalidInput("Unknown device.")) {
            _ = try await engine.getDevice(id: DeviceID("missing"), for: VaultID("vault-1"))
        }
    }

    func testDeviceTrustEventsAreAppended() async throws {
        let eventEngine = InMemoryEventEngine()
        let engine = InMemoryDeviceTrustEngine(eventEngine: eventEngine)
        let vaultId = VaultID("vault-1")

        _ = try await engine.createFirstDeviceIdentity(
            deviceId: DeviceID("device-1"),
            deviceName: "Primary",
            platform: "iOS",
            vaultId: vaultId
        )
        _ = try await engine.registerPendingDevice(
            deviceId: DeviceID("device-2"),
            deviceName: "MacBook",
            platform: "macOS",
            publicKey: "fake-public-key-device-2",
            for: vaultId
        )
        _ = try await engine.trustDevice(
            id: DeviceID("device-2"),
            for: vaultId,
            issuedBy: DeviceID("device-1"),
            permissions: [.read]
        )
        try await engine.revokeDevice(id: DeviceID("device-2"), for: vaultId)
        try await engine.markDeviceLost(id: DeviceID("device-1"), for: vaultId)

        let events = try await eventEngine.listEvents(for: vaultId)
        XCTAssertEqual(events.map(\.type), [
            .deviceRegistered,
            .deviceTrusted,
            .deviceRegistered,
            .deviceTrusted,
            .deviceRevoked,
            .deviceLost
        ])
    }

    func testCreateVaultCreatesFirstTrustedDevice() async throws {
        let deviceTrustEngine = InMemoryDeviceTrustEngine()
        let configuration = makeInMemoryConfiguration(deviceTrustEngine: deviceTrustEngine)
        let engine = DefaultVaultEngine(configuration: configuration)

        let vaultId = try await engine.createVault(
            config: VaultCreationConfig(
                name: "Primary",
                deviceID: DeviceID("device-1"),
                unlockMethod: .passphrase
            )
        )

        let trustedDevices = try await deviceTrustEngine.listTrustedDevices(for: vaultId)
        XCTAssertEqual(trustedDevices.count, 1)
        XCTAssertEqual(trustedDevices.first?.deviceId, DeviceID("device-1"))
        XCTAssertEqual(trustedDevices.first?.trustState, .trusted)
        XCTAssertTrue(trustedDevices.first?.permissions.contains(.manageDevices) == true)
    }

    private func createTrustedSecondaryDevice(
        using engine: InMemoryDeviceTrustEngine,
        vaultId: VaultID
    ) async throws {
        _ = try await engine.registerPendingDevice(
            deviceId: DeviceID("device-2"),
            deviceName: "MacBook",
            platform: "macOS",
            publicKey: "fake-public-key-device-2",
            for: vaultId
        )
        _ = try await engine.trustDevice(
            id: DeviceID("device-2"),
            for: vaultId,
            issuedBy: DeviceID("device-1"),
            permissions: [.read, .write]
        )
    }
}
