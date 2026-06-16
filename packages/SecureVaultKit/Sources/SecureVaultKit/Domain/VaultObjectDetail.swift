public struct VaultObjectDetail: Equatable, Codable, Sendable {
    public var id: VaultObjectID
    public var type: VaultObjectType
    public var metadata: VaultMetadata
    public var payload: VaultPayload

    public init(
        id: VaultObjectID,
        type: VaultObjectType,
        metadata: VaultMetadata,
        payload: VaultPayload
    ) {
        self.id = id
        self.type = type
        self.metadata = metadata
        self.payload = payload
    }
}
