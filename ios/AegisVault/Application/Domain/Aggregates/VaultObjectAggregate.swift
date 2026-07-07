import SecureVaultKit

protocol VaultObjectAggregate {
    var objectType: VaultObjectType { get }

    func validateInvariants() throws
    func toVaultObjectDraft() throws -> VaultObjectDraft
}
