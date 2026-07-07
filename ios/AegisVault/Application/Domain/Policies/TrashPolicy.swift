import SecureVaultKit

struct TrashPolicy {
    func validateCanRestore(_ summary: VaultObjectSummary) throws {
        guard summary.isDeleted else {
            throw ValidationError.invalidState("Object is not in trash.")
        }
    }

    func validateCanPermanentlyDelete(_ summary: VaultObjectSummary) throws {
        guard summary.isDeleted else {
            throw ValidationError.invalidState("Object must be in trash before permanent deletion.")
        }
    }
}
