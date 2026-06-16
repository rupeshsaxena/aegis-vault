public struct VaultObjectDraft: Equatable, Codable, Sendable {
    public var type: VaultObjectType
    public var metadata: VaultMetadata
    public var payload: VaultPayload

    public init(
        type: VaultObjectType,
        metadata: VaultMetadata,
        payload: VaultPayload = VaultPayload()
    ) {
        self.type = type
        self.metadata = metadata
        self.payload = payload
    }
}
