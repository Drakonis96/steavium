import SwiftUI

struct ActionPanel: View {
    @ObservedObject var viewModel: StoreViewModel
    @Binding var showingStopSteamDialog: Bool
    @Binding var showingDataWipeDialog: Bool

    private var language: AppLanguage { viewModel.language }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 10)]
    }

    var body: some View {
        PanelCard(title: L.actions.resolve(in: language)) {
            HStack(spacing: 10) {
                Picker(L.wineMode.resolve(in: language), selection: $viewModel.wineMode) {
                    ForEach(WineMode.allCases, id: \.self) { mode in
                        Text(mode.title(in: language)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .disabled(viewModel.isBusy)

                Picker(L.backend.resolve(in: language), selection: $viewModel.graphicsBackend) {
                    ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                        Text(backend.title(in: language)).tag(backend)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
                .disabled(viewModel.isBusy)

                Spacer(minLength: 0)

                if let phase = viewModel.launchPhase {
                    HStack(spacing: 6) {
                        if phase == .storeDetected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(phase.title(in: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isBusy {
                    Label(L.working.resolve(in: language), systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Setup
            VStack(alignment: .leading, spacing: 8) {
                Text(L.setup.resolve(in: language))
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    ActionTileButton(
                        title: L.installPrerequisites.resolve(in: language),
                        icon: viewModel.prerequisitesInstalled ? "checkmark.circle.fill" : "shippingbox",
                        tone: viewModel.prerequisitesInstalled ? .success : .primary,
                        isDisabled: viewModel.isBusy
                    ) {
                        viewModel.installPrerequisites()
                    }
                    ActionTileButton(
                        title: L.installRuntime.resolve(in: language),
                        icon: viewModel.environment.wine64Path != nil ? "checkmark.circle.fill" : "square.and.arrow.down",
                        tone: viewModel.environment.wine64Path != nil ? .success : .primary,
                        isDisabled: viewModel.isBusy || !viewModel.prerequisitesInstalled
                    ) {
                        viewModel.installRuntime()
                    }
                    ActionTileButton(
                        title: L.setUpStore(viewModel.currentStoreName).resolve(in: language),
                        icon: viewModel.setupCompleted ? "checkmark.circle.fill" : "wrench.and.screwdriver",
                        tone: viewModel.setupCompleted ? .success : .primary,
                        isDisabled: viewModel.isBusy || viewModel.environment.wine64Path == nil
                    ) {
                        viewModel.setupStore()
                    }
                    ActionTileButton(
                        title: L.launchStore(viewModel.currentStoreName).resolve(in: language),
                        icon: "play.circle",
                        tone: .primary,
                        isDisabled: viewModel.isBusy || viewModel.environment.wine64Path == nil || !viewModel.environment.storeAppInstalled || !viewModel.setupCompleted
                    ) {
                        viewModel.launchStore()
                    }
                    ActionTileButton(
                        title: L.closeStore(viewModel.currentStoreName).resolve(in: language),
                        icon: "xmark.circle",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy || viewModel.environment.wine64Path == nil || !viewModel.environment.storeAppInstalled
                    ) {
                        showingStopSteamDialog = true
                    }
                }
            }

            Divider()

            // Utilities
            VStack(alignment: .leading, spacing: 8) {
                Text(L.utilities.resolve(in: language))
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    ActionTileButton(
                        title: L.refresh.resolve(in: language),
                        icon: "arrow.clockwise",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy
                    ) {
                        Task {
                            await viewModel.refreshEnvironment()
                            viewModel.refreshInstalledGames(forceRefresh: true)
                        }
                    }
                    ActionTileButton(
                        title: L.runPreflight.resolve(in: language),
                        icon: "checklist",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy
                    ) {
                        viewModel.refreshPreflight()
                    }
                    ActionTileButton(
                        title: L.exportDiagnostics.resolve(in: language),
                        icon: "square.and.arrow.up",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy
                    ) {
                        viewModel.exportDiagnosticsBundle()
                    }
                    ActionTileButton(
                        title: L.refreshGamepads.resolve(in: language),
                        icon: "gamecontroller",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy
                    ) {
                        viewModel.refreshGamepads()
                    }
                    ActionTileButton(
                        title: L.clearConsole.resolve(in: language),
                        icon: "trash",
                        tone: .neutral,
                        isDisabled: false
                    ) {
                        viewModel.clearLogs()
                    }
                }
            }

            Divider()

            // Folders and Data
            VStack(alignment: .leading, spacing: 8) {
                Text(L.foldersAndData.resolve(in: language))
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    ActionTileButton(
                        title: L.chooseLibrary.resolve(in: language),
                        icon: "folder.badge.plus",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy
                    ) {
                        viewModel.chooseGameLibraryPath()
                    }
                    ActionTileButton(
                        title: L.clearLibrary.resolve(in: language),
                        icon: "folder.badge.minus",
                        tone: .neutral,
                        isDisabled: viewModel.isBusy || viewModel.gameLibraryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        viewModel.clearGameLibraryPath()
                    }
                    ActionTileButton(
                        title: L.openLibrary.resolve(in: language),
                        icon: "folder",
                        tone: .neutral,
                        isDisabled: viewModel.gameLibraryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        viewModel.openGameLibraryFolder()
                    }
                    ActionTileButton(
                        title: L.openPrefix.resolve(in: language),
                        icon: "folder",
                        tone: .neutral,
                        isDisabled: viewModel.environment.prefixPath.isEmpty
                    ) {
                        viewModel.openPrefixFolder()
                    }
                    ActionTileButton(
                        title: L.openLogs.resolve(in: language),
                        icon: "doc.text",
                        tone: .neutral,
                        isDisabled: viewModel.environment.logsPath.isEmpty
                    ) {
                        viewModel.openLogsFolder()
                    }
                    ActionTileButton(
                        title: L.wipeData.resolve(in: language),
                        icon: "exclamationmark.triangle",
                        tone: .destructive,
                        isDisabled: viewModel.isBusy || !viewModel.environment.storeAppInstalled
                    ) {
                        showingDataWipeDialog = true
                    }
                }
            }
        }
    }
}
