public struct VaultPayload: Equatable, Codable, Sendable {
    public var fields: [String: VaultFieldValue]
    public var attachments: [VaultAttachment]

    public init(
        fields: [String: VaultFieldValue] = [:],
        attachments: [VaultAttachment] = []
    ) {
        self.fields = fields
        self.attachments = attachments
    }
}
