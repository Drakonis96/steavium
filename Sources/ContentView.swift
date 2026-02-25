import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: StoreViewModel
    @StateObject private var updater = AppUpdater()
    @State private var showingStopSteamDialog: Bool = false
    @State private var showingDataWipeDialog: Bool = false
    @State private var showingManualDialog: Bool = false
    @State private var showingUninstallDialog: Bool = false
    @State private var showingUpdateDialog: Bool = false
    @State private var uninstallKeepData: Bool = false
    @State private var showingLeftSidebar: Bool = true
    @State private var showingRightSidebar: Bool = true
    @State private var wipeAccountData: Bool = true
    @State private var wipeLibraryData: Bool = false
    @State private var gameSearchText: String = ""
    @State private var showOnlyGamesWithSavedProfiles: Bool = false

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HSplitView {
                if showingLeftSidebar {
                    leftSidebar
                        .frame(minWidth: 260, idealWidth: 320, maxWidth: 460, maxHeight: .infinity, alignment: .top)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        ActionPanel(
                            viewModel: viewModel,
                            showingStopSteamDialog: $showingStopSteamDialog,
                            showingDataWipeDialog: $showingDataWipeDialog
                        )
                        GameProfilesPanel(
                            viewModel: viewModel,
                            gameSearchText: $gameSearchText,
                            showOnlyGamesWithSavedProfiles: $showOnlyGamesWithSavedProfiles
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                if showingRightSidebar {
                    rightSidebar
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 560, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            sidebarToggleOverlay
        }
        .sheet(isPresented: $showingDataWipeDialog) {
            WipeDataSheet(
                viewModel: viewModel,
                isPresented: $showingDataWipeDialog,
                wipeAccountData: $wipeAccountData,
                wipeLibraryData: $wipeLibraryData
            )
        }
        .sheet(isPresented: $showingManualDialog) {
            UserManualSheet(language: language, isPresented: $showingManualDialog)
        }
        .sheet(isPresented: $showingUpdateDialog) {
            UpdateSheet(updater: updater, isPresented: $showingUpdateDialog, language: language)
        }
        .alert(
            L.uninstallTitle.resolve(in: language),
            isPresented: $showingUninstallDialog
        ) {
            Button(L.uninstallConfirm.resolve(in: language), role: .destructive) {
                viewModel.uninstallSteavium(keepData: uninstallKeepData)
            }
            Button(L.cancel.resolve(in: language), role: .cancel) {}
        } message: {
            Text(L.uninstallMessage.resolve(in: language))
        }
        .confirmationDialog(
            L.closeStoreCompletely(viewModel.currentStoreName).resolve(in: language),
            isPresented: $showingStopSteamDialog,
            titleVisibility: .visible
        ) {
            Button(L.closeStore(viewModel.currentStoreName).resolve(in: language), role: .destructive) {
                viewModel.stopStoreCompletely()
            }
            Button(L.cancel.resolve(in: language), role: .cancel) {}
        } message: {
            Text(L.closeStoreMessage(viewModel.currentStoreName).resolve(in: language))
        }
        .confirmationDialog(
            L.storeAlreadyRunning(viewModel.currentStoreName).resolve(in: language),
            isPresented: $viewModel.showingStoreRunningDialog,
            titleVisibility: .visible
        ) {
            Button(L.reuse.resolve(in: language)) {
                viewModel.launchStoreReusingSession()
            }
            Button(L.restart.resolve(in: language)) {
                viewModel.launchStoreRestarting()
            }
            Button(L.cancel.resolve(in: language), role: .cancel) {
                viewModel.cancelStoreLaunchDecision()
            }
        } message: {
            Text(L.storeRunningMessage(viewModel.currentStoreName).resolve(in: language))
        }
    }

    // MARK: - Cached logo

    private static let cachedAppLogo: NSImage? = {
        guard let logoURL = Bundle.module.url(forResource: "logo", withExtension: "png", subdirectory: "Resources") else {
            return nil
        }
        return NSImage(contentsOf: logoURL)
    }()

    private var appLogo: NSImage? { Self.cachedAppLogo }

    // MARK: - Sidebars

    private var leftSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusPanel(viewModel: viewModel)
                PreflightPanel(viewModel: viewModel)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rightSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            LogPanel(viewModel: viewModel)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if let logo = appLogo {
                        Image(nsImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Steavium")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(L.appSubtitle.resolve(in: language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Picker(L.launcher.resolve(in: language), selection: $viewModel.selectedLauncher) {
                            ForEach(GameStoreLauncher.allCases) { launcher in
                                Text(launcher.label).tag(launcher)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .disabled(viewModel.isBusy)

                        Picker(L.language.resolve(in: language), selection: $viewModel.language) {
                            ForEach(AppLanguage.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .disabled(viewModel.isBusy)

                        Button {
                            showingManualDialog = true
                        } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(ResponsiveBorderedStyle())
                        .help(L.openManual.resolve(in: language))
                        .disabled(viewModel.isBusy)

                        Button {
                            showingUpdateDialog = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.circle")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(ResponsiveBorderedStyle())
                        .help(L.checkForUpdates.resolve(in: language))
                        .disabled(viewModel.isBusy)

                        Menu {
                            Button {
                                showingUpdateDialog = true
                            } label: {
                                Label(L.checkForUpdates.resolve(in: language), systemImage: "arrow.triangle.2.circlepath")
                            }

                            Divider()

                            Button(role: .destructive) {
                                uninstallKeepData = false
                                showingUninstallDialog = true
                            } label: {
                                Label(L.uninstallSteavium.resolve(in: language), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                        .disabled(viewModel.isBusy)
                    }
                }

                HStack(spacing: 8) {
                    StatusPill(
                        title: L.status.resolve(in: language),
                        value: viewModel.statusText,
                        highlighted: viewModel.isBusy
                    )
                    StatusPill(
                        title: L.backend.resolve(in: language),
                        value: viewModel.graphicsBackend.title(in: language),
                        highlighted: false
                    )
                    StatusPill(
                        title: L.gamepads.resolve(in: language),
                        value: viewModel.gamepadSummary,
                        highlighted: false
                    )
                }
            }
        }
    }

    // MARK: - Sidebar toggle

    private var sidebarToggleOverlay: some View {
        HStack {
            sidebarToggleButton(
                isVisible: showingLeftSidebar,
                accessibilityLabel: L.toggleLeftSidebar.resolve(in: language),
                helpText: L.leftSidebar.resolve(in: language)
            ) {
                showingLeftSidebar.toggle()
            }

            Spacer(minLength: 0)

            sidebarToggleButton(
                isVisible: showingRightSidebar,
                accessibilityLabel: L.toggleRightSidebar.resolve(in: language),
                helpText: L.rightSidebar.resolve(in: language)
            ) {
                showingRightSidebar.toggle()
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
        .zIndex(10)
    }

    private func sidebarToggleButton(
        isVisible: Bool,
        accessibilityLabel: String,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 1))
                .opacity(isVisible ? 1 : 0.82)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(accessibilityLabel)
        .help(helpText)
    }
}
