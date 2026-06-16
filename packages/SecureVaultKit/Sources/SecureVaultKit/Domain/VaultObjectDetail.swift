public struct VaultObjectDetail: Equatable, Codable, Sendable {
    public var id: VaultObjectID
    public var type: VaultObjectType
    public var metadata: VaultMetadata
    public var payload: VaultPayload
    public var version: Int

    public init(
        id: VaultObjectID,
        type: VaultObjectType,
        metadata: VaultMetadata,
        payload: VaultPayload,
        version: Int = 1
    ) {
        self.id = id
        self.type = type
        self.metadata = metadata
        self.payload = payload
        self.version = version
    }
}
