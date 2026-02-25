import SwiftUI

struct GameProfilesPanel: View {
    @ObservedObject var viewModel: SteamViewModel
    @Binding var gameSearchText: String
    @Binding var showOnlyGamesWithSavedProfiles: Bool

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        PanelCard(title: L.perGameProfiles.resolve(in: language)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(filteredGamesSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(L.detectGames.resolve(in: language)) {
                        viewModel.refreshInstalledGames(forceRefresh: true)
                    }
                    .buttonStyle(ResponsiveBorderedProminentStyle())
                    .disabled(viewModel.isBusy)
                }

                HStack(spacing: 10) {
                    TextField(
                        L.searchByNameOrAppID.resolve(in: language),
                        text: $gameSearchText
                    )
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.installedGames.isEmpty)

                    Toggle(
                        L.onlySavedProfiles.resolve(in: language),
                        isOn: $showOnlyGamesWithSavedProfiles
                    )
                    .toggleStyle(.switch)
                    .disabled(viewModel.installedGames.isEmpty)
                }

                if viewModel.installedGames.isEmpty {
                    Text(L.noInstalledGames.resolve(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else if filteredInstalledGames.isEmpty {
                    Text(L.noMatchingGames.resolve(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else {
                    HSplitView {
                        List(filteredInstalledGames, selection: $viewModel.selectedGameID) { game in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text("AppID \(game.appID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if viewModel.hasSavedProfile(appID: game.appID) {
                                    Text(L.savedProfile.resolve(in: language))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                            .tag(Optional(game.appID))
                        }
                        .frame(minWidth: 220, idealWidth: 280, maxWidth: 360, minHeight: 360)

                        GameProfileEditor(viewModel: viewModel)
                            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(minHeight: 430)
                }
            }
        }
    }

    private var filteredInstalledGames: [InstalledGame] {
        let query = gameSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return viewModel.installedGames.filter { game in
            if showOnlyGamesWithSavedProfiles && !viewModel.hasSavedProfile(appID: game.appID) {
                return false
            }
            guard !query.isEmpty else { return true }
            if game.name.lowercased().contains(query) { return true }
            return String(game.appID).contains(query)
        }
    }

    private var filteredGamesSummary: String {
        L.filteredGamesSummary(
            shown: filteredInstalledGames.count,
            total: viewModel.installedGames.count,
            profilesSummary: viewModel.gameProfilesSummary
        ).resolve(in: language)
    }
}
