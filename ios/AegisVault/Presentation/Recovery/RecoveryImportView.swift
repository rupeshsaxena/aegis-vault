import Observation
import SecureVaultKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - State

enum RecoveryImportState: Equatable {
    case idle
    case packageSelected(URL)
    case validating
    case recovered(RecoveryImportResult)
    case failed(String)
}

// MARK: - View Model

@MainActor
@Observable
final class RecoveryImportViewModel {
    private(set) var state: RecoveryImportState = .idle
    var recoverySecretInput: String = ""
    private(set) var selectedPackageURL: URL?

    var canImport: Bool {
        guard selectedPackageURL != nil else { return false }
        guard !recoverySecretInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch state {
        case .validating, .recovered: return false
        default: return true
        }
    }

    var selectedPackageName: String? {
        selectedPackageURL?.lastPathComponent
    }

    @ObservationIgnored private let importUseCase: any ImportRecoveryPackageUsing

    init(importUseCase: any ImportRecoveryPackageUsing) {
        self.importUseCase = importUseCase
    }

    func selectPackage(url: URL) {
        selectedPackageURL = url
        state = .packageSelected(url)
    }

    func retry() {
        guard let url = selectedPackageURL else { return }
        state = .packageSelected(url)
    }

    func importPackage() async {
        guard let url = selectedPackageURL else { return }
        let trimmedSecret = recoverySecretInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else { return }

        state = .validating

        do {
            let result = try await importUseCase.execute(
                packageURL: url,
                recoverySecret: RecoverySecret(trimmedSecret)
            )
            state = .recovered(result)
        } catch {
            state = .failed(safeErrorMessage(from: error))
        }
    }

    private func safeErrorMessage(from error: Error) -> String {
        switch error {
        case VaultError.invalidInput(let message):
            return message
        case VaultError.unsupportedOperation:
            return "Recovery import is not supported in this version."
        default:
            return "Recovery failed. Please check your package and secret."
        }
    }
}

// MARK: - View

struct RecoveryImportView: View {
    @State private var viewModel: RecoveryImportViewModel
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(importUseCase: any ImportRecoveryPackageUsing) {
        _viewModel = State(initialValue: RecoveryImportViewModel(importUseCase: importUseCase))
    }

    var body: some View {
        NavigationStack {
            switch viewModel.state {
            case .recovered(let result):
                recoveredView(result: result)
            default:
                importFormView
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFilePickerResult(result)
        }
    }

    // MARK: - Import Form

    private var importFormView: some View {
        Form {
            warningSection
            packageSection
            secretSection
            if case .failed(let message) = viewModel.state {
                errorSection(message: message)
            }
            importSection
        }
        .navigationTitle("Recover Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("cancelRecoveryButton")
            }
        }
    }

    private var warningSection: some View {
        Section {
            Label {
                Text("Only continue if this is your recovery package and you know your recovery secret.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .accessibilityIdentifier("recoveryWarning1")

            Label {
                Text("Anyone with both your recovery package and recovery secret may recover your vault.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("recoveryWarning2")
        } header: {
            Text("Security Warning")
        }
    }

    private var packageSection: some View {
        Section {
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.badge.arrow.up")
                    if let name = viewModel.selectedPackageName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Package Selected")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Select Recovery Package")
                    }
                    Spacer()
                    if viewModel.selectedPackageURL != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .accessibilityIdentifier("selectPackageButton")
        } header: {
            Text("Recovery Package")
        }
    }

    private var secretSection: some View {
        Section {
            SecureField("Recovery Secret", text: $viewModel.recoverySecretInput)
                .textContentType(.password)
                .autocorrectionDisabled()
                .accessibilityIdentifier("recoverySecretField")
        } header: {
            Text("Recovery Secret")
        } footer: {
            Text("Enter the secret you created when you set up vault recovery.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func errorSection(message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            Button("Try Again") { viewModel.retry() }
                .accessibilityIdentifier("retryRecoveryButton")
        }
        .accessibilityIdentifier("recoveryErrorSection")
    }

    private var importSection: some View {
        Section {
            Button {
                Task { await viewModel.importPackage() }
            } label: {
                if case .validating = viewModel.state {
                    HStack {
                        ProgressView()
                        Text("Validating…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Recover Vault")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canImport)
            .accessibilityIdentifier("importRecoveryButton")
        }
    }

    // MARK: - Recovered

    private func recoveredView(result: RecoveryImportResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .accessibilityIdentifier("recoverySuccessIcon")

            Text("Recovery Package Validated")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("recoverySuccessTitle")

            Text("Your recovery package is valid. You can now use your recovery secret to regain access to your vault.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .accessibilityIdentifier("recoveryDoneButton")
        }
        .navigationTitle("Recovery Complete")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Request security-scoped resource access for files from the document picker
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("RecoveryImport-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                try data.write(to: tempURL, options: .atomic)
                viewModel.selectPackage(url: tempURL)
            } catch {
                viewModel.selectPackage(url: url)
            }
        case .failure:
            break
        }
    }
}
