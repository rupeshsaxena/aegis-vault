import XCTest
import SecureVaultKit
@testable import AegisVault

final class UseCaseTests: XCTestCase {
    func testUseCasesCallVaultEngineMock() async throws {
        let engine = MockVaultEngine()
        let vaultID = try await CreateVaultUseCase(vaultEngine: engine).execute(
            name: "Personal",
            deviceID: DeviceID("device"),
            unlockMethod: .passphrase
        )
        try await UnlockVaultUseCase(vaultEngine: engine).execute(vaultID: vaultID, method: .passkey)
        _ = try await ListVaultObjectsUseCase(vaultEngine: engine).execute()
        _ = try await SearchVaultUseCase(vaultEngine: engine).execute(query: "passport")
        await LockVaultUseCase(vaultEngine: engine).execute(vaultID: vaultID)

        let calls = await engine.calls()
        XCTAssertEqual(calls, [.create, .unlock, .list, .search, .lock])
    }

    func testViewModelsDoNotReferenceSecureVaultKitInternals() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let presentationDirectory = testsDirectory.deletingLastPathComponent()
            .appendingPathComponent("Presentation", isDirectory: true)
        let forbiddenSymbols = [
            "StorageEngine",
            "CryptoEngine",
            "BlobStore",
            "Repository",
            "SQLite"
        ]
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: presentationDirectory,
                includingPropertiesForKeys: nil
            )
        )

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix("ViewModel.swift") {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for symbol in forbiddenSymbols {
                XCTAssertFalse(source.contains(symbol), "\(fileURL.lastPathComponent) references \(symbol)")
            }
        }
    }
}

private actor MockVaultEngine: VaultEngine {
    enum Call: Equatable {
        case create
        case unlock
        case list
        case search
        case lock
    }

    private let vaultID = VaultID("mock-vault")
    private var recordedCalls: [Call] = []

    func calls() -> [Call] { recordedCalls }
    func runtimeStatus() async throws -> VaultRuntimeStatus { .locked(vaultID) }

    func createVault(config: VaultCreationConfig) async throws -> VaultID {
        recordedCalls.append(.create)
        return vaultID
    }

    func unlockVault(id: VaultID, using method: UnlockMethod) async throws {
        recordedCalls.append(.unlock)
    }

    func unlockVault(method: UnlockMethod) async throws {
        recordedCalls.append(.unlock)
    }

    func lockVault(id: VaultID) async {
        recordedCalls.append(.lock)
    }

    func lockVault() async {
        recordedCalls.append(.lock)
    }

    func createObject(_ draft: VaultObjectDraft) async throws -> VaultObjectID {
        throw TestEngineError.unimplemented
    }

    func createObject(_ draft: VaultObjectDraft, in vaultID: VaultID) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func listObjects(filter: VaultObjectFilter) async throws -> [VaultObjectSummary] {
        recordedCalls.append(.list)
        return []
    }

    func searchObjects(query: String) async throws -> [VaultObjectSummary] {
        recordedCalls.append(.search)
        return []
    }

    func getObjectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func updateObject(_ update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func updateObject(id: VaultObjectID, with update: VaultObjectUpdate) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func objectDetail(id: VaultObjectID) async throws -> VaultObjectDetail {
        throw TestEngineError.unimplemented
    }

    func objectSummaries(
        in vaultID: VaultID,
        matching filter: VaultObjectFilter
    ) async throws -> [VaultObjectSummary] {
        []
    }

    func moveToTrash(_ id: VaultObjectID) async throws {}
    func restoreFromTrash(_ id: VaultObjectID) async throws {}
    func purgeTrash() async throws {}

    func importDocument(
        _ input: DocumentImportInput,
        into vaultID: VaultID
    ) async throws -> DocumentImportResult {
        throw TestEngineError.unimplemented
    }

    func moveObjectToTrash(id: VaultObjectID) async throws {}
}

private enum TestEngineError: Error {
    case unimplemented
}
