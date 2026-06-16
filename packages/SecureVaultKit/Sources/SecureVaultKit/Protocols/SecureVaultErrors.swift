import Foundation

public enum SecureVaultError: Error, Equatable, Sendable {
    case vaultNotFound(VaultID)
    case itemNotFound(VaultItemID)
    case blobNotFound(BlobID)
    case locked
    case unsupportedOperation(String)
}
