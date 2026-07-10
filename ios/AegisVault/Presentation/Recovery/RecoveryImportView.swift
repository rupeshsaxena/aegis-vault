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
    @ObservationIgnored private let errorMapper: any ErrorMapper
    @ObservationIgnored private let packageStager: RecoveryPackageStager
    @ObservationIgnored private var importTask: Task<Void, Never>?
    @ObservationIgnored private var stagingTask: Task<Void, Never>?

    init(
        importUseCase: any ImportRecoveryPackageUsing,
        errorMapper: any ErrorMapper = DefaultErrorMapper(),
        packageStager: RecoveryPackageStager = RecoveryPackageStager()
    ) {
        self.importUseCase = importUseCase
        self.errorMapper = errorMapper
        self.packageStager = packageStager
    }

    deinit {
        importTask?.cancel()
        stagingTask?.cancel()
    }

    func selectPackage(url: URL) {
        selectedPackageURL = url
        state = .packageSelected(url)
    }

    func retry() {
        guard let url = selectedPackageURL else { return }
        state = .packageSelected(url)
    }

    func handlePackageSelection(_ result: Result<[URL], Error>) async {
        stagingTask?.cancel()
        let sourceURL: URL
        do {
            guard let url = try result.get().first else { return }
            sourceURL = url
        } catch {
            state = .failed(safeErrorMessage(from: error))
            return
        }

        let task = Task { [packageStager] in
            do {
                let stagedURL = try await packageStager.stagePackage(from: sourceURL)
                try Task.checkCancellation()
                await MainActor.run {
                    self.selectPackage(url: stagedURL)
                    self.stagingTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.stagingTask = nil
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(self.safeErrorMessage(from: error))
                    self.stagingTask = nil
                }
            }
        }
        stagingTask = task
        await task.value
    }

    func importPackage() async {
        importTask?.cancel()
        guard let url = selectedPackageURL else { return }
        let trimmedSecret = recoverySecretInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else { return }

        state = .validating

        let task = Task { [importUseCase] in
            do {
                let result = try await importUseCase.execute(
                    packageURL: url,
                    recoverySecret: RecoverySecret(trimmedSecret)
                )
                try Task.checkCancellation()
                await MainActor.run {
                    self.state = .recovered(result)
                    self.importTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.importTask = nil
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(self.safeErrorMessage(from: error))
                    self.importTask = nil
                }
            }
        }
        importTask = task
        await task.value
    }

    private func safeErrorMessage(from error: Error) -> String {
        errorMapper.userMessage(
            for: error,
            fallback: UserMessage(
                title: "Recovery Failed",
                message: "Recovery failed. Please check your package and secret."
            )
        ).message
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
            Task { await viewModel.handlePackageSelection(result) }
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

}
