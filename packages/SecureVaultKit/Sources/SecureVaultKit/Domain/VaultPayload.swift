public struct VaultPayload: Equatable, Codable, Sendable {
    public var notes: String?
    public var fields: [String: VaultFieldValue]
    public var attachments: [VaultAttachment]

    public init(
        notes: String? = nil,
        fields: [String: VaultFieldValue] = [:],
        attachments: [VaultAttachment] = []
    ) {
        self.notes = notes
        self.fields = fields
        self.attachments = attachments
    }
}
