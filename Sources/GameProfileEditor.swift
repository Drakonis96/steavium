import SwiftUI

struct GameProfileEditor: View {
    @ObservedObject var viewModel: SteamViewModel

    private var language: AppLanguage { viewModel.language }

    private var editorActionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 10)]
    }

    var body: some View {
        if let selectedGame = viewModel.selectedGame {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedGame.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text("AppID \(selectedGame.appID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L.targetResolution(
                        viewModel.environment.hardwareProfile.displayResolutionIdentifier
                    ).resolve(in: language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker(
                        L.preset.resolve(in: language),
                        selection: Binding(
                            get: { viewModel.profileEditor.preset },
                            set: { viewModel.applySelectedPreset($0) }
                        )
                    ) {
                        ForEach(GameCompatibilityPreset.allCases, id: \.self) { preset in
                            Text(preset.title(in: language)).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isBusy)

                    Picker(
                        L.compatibilityMode.resolve(in: language),
                        selection: Binding(
                            get: { viewModel.profileEditor.compatibilityMode },
                            set: { viewModel.setCompatibilityMode($0) }
                        )
                    ) {
                        ForEach(GameCompatibilityMode.allCases, id: \.self) { mode in
                            Text(mode.title(in: language)).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isBusy)

                    if !viewModel.selectedGameExecutableCandidates.isEmpty {
                        Picker(
                            L.executable.resolve(in: language),
                            selection: Binding(
                                get: { viewModel.profileEditor.selectedExecutableRelativePath },
                                set: { viewModel.setSelectedExecutablePath($0) }
                            )
                        ) {
                            ForEach(viewModel.selectedGameExecutableCandidates, id: \.relativePath) { candidate in
                                Text(candidate.relativePath).tag(candidate.relativePath)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isBusy)
                    } else {
                        Text(L.noExecutableFound.resolve(in: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(
                        L.forceWindowed.resolve(in: language),
                        isOn: Binding(
                            get: { viewModel.profileEditor.forceWindowed },
                            set: { viewModel.setForceWindowed($0) }
                        )
                    )
                    .disabled(viewModel.isBusy)

                    Toggle(
                        L.force640x480.resolve(in: language),
                        isOn: Binding(
                            get: { viewModel.profileEditor.force640x480 },
                            set: { viewModel.setForce640x480($0) }
                        )
                    )
                    .disabled(viewModel.isBusy)

                    Picker(
                        L.reducedColor.resolve(in: language),
                        selection: Binding(
                            get: { viewModel.profileEditor.reducedColorMode },
                            set: { viewModel.setReducedColorMode($0) }
                        )
                    ) {
                        ForEach(GameReducedColorMode.allCases, id: \.self) { colorMode in
                            Text(colorMode.title(in: language)).tag(colorMode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isBusy)

                    Picker(
                        L.highDPIOverride.resolve(in: language),
                        selection: Binding(
                            get: { viewModel.profileEditor.highDPIOverrideMode },
                            set: { viewModel.setHighDPIOverrideMode($0) }
                        )
                    ) {
                        ForEach(GameHighDPIOverrideMode.allCases, id: \.self) { mode in
                            Text(mode.title(in: language)).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.isBusy)

                    Toggle(
                        L.disableFullscreenOpt.resolve(in: language),
                        isOn: Binding(
                            get: { viewModel.profileEditor.disableFullscreenOptimizations },
                            set: { viewModel.setDisableFullscreenOptimizations($0) }
                        )
                    )
                    .disabled(viewModel.isBusy)

                    Toggle(
                        L.runAsAdmin.resolve(in: language),
                        isOn: Binding(
                            get: { viewModel.profileEditor.runAsAdmin },
                            set: { viewModel.setRunAsAdmin($0) }
                        )
                    )
                    .disabled(viewModel.isBusy)

                    LazyVGrid(columns: editorActionColumns, alignment: .leading, spacing: 10) {
                        Button(L.saveProfile.resolve(in: language)) {
                            viewModel.saveSelectedGameProfile()
                        }
                        .buttonStyle(ResponsiveBorderedProminentStyle())
                        .disabled(viewModel.isBusy)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(L.reset.resolve(in: language)) {
                            viewModel.resetSelectedGameProfile()
                        }
                        .buttonStyle(ResponsiveBorderedStyle())
                        .disabled(viewModel.isBusy || !viewModel.selectedGameHasSavedProfile)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(L.openFolder.resolve(in: language)) {
                            viewModel.openSelectedGameFolder()
                        }
                        .buttonStyle(ResponsiveBorderedStyle())
                        .disabled(viewModel.isBusy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(L.selectGameToEdit.resolve(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
