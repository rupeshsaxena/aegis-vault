public enum VaultSessionLockState: String, Codable, Sendable {
    case locked
    case unlocked
}

public struct VaultSessionKeyReferences: Equatable, Codable, Sendable {
    public var vaultKeyReference: String?
    public var objectKeyReference: String?
    public var blobKeyReference: String?

    public init(
        vaultKeyReference: String? = nil,
        objectKeyReference: String? = nil,
        blobKeyReference: String? = nil
    ) {
        self.vaultKeyReference = vaultKeyReference
        self.objectKeyReference = objectKeyReference
        self.blobKeyReference = blobKeyReference
    }
}

public struct VaultSession: Equatable, Codable, Sendable {
    public var vaultId: VaultID
    public var deviceId: DeviceID
    public var lockState: VaultSessionLockState
    public var keyReferences: VaultSessionKeyReferences

    public init(
        vaultId: VaultID,
        deviceId: DeviceID,
        lockState: VaultSessionLockState = .locked,
        keyReferences: VaultSessionKeyReferences = VaultSessionKeyReferences()
    ) {
        self.vaultId = vaultId
        self.deviceId = deviceId
        self.lockState = lockState
        self.keyReferences = keyReferences
    }
}
