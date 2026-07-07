import Foundation
import SecureVaultKit

struct DuplicateDetectionPolicy {
    func containsDuplicateTitle(
        _ title: String,
        in summaries: [VaultObjectSummary]
    ) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return summaries.contains {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }
    }
}
