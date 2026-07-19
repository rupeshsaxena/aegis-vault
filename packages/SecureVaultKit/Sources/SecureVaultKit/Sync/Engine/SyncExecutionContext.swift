public struct SyncExecutionContext: Sendable {
    public var vaultId: VaultID
    public var deviceId: DeviceID
    public var cursor: SyncCursor?

    public init(vaultId: VaultID, deviceId: DeviceID, cursor: SyncCursor? = nil) {
        self.vaultId = vaultId
        self.deviceId = deviceId
        self.cursor = cursor
    }
}

