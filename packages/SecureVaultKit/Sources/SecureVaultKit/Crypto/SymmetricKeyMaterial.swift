import Foundation

public struct SymmetricKeyMaterial: Equatable, Sendable {
    public var keyId: KeyIdentifier
    public var data: Data

    public init(keyId: KeyIdentifier, data: Data) {
        self.keyId = keyId
        self.data = data
    }

    internal init(reference: String) {
        self.init(keyId: KeyIdentifier(reference), data: Data(reference.utf8))
    }

    internal var reference: String {
        keyId.rawValue
    }
}
