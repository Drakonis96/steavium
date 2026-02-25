import SwiftUI

struct StatusPanel: View {
    @ObservedObject var viewModel: SteamViewModel

    private var language: AppLanguage { viewModel.language }

    private var statusColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 10)]
    }

    var body: some View {
        PanelCard(title: L.environmentStatus.resolve(in: language)) {
            LazyVGrid(columns: statusColumns, alignment: .leading, spacing: 10) {
                StatusTile(
                    title: L.wineRuntime.resolve(in: language),
                    value: viewModel.environment.wine64Path ?? L.notDetected.resolve(in: language)
                )
                StatusTile(
                    title: L.steamInstalled.resolve(in: language),
                    value: viewModel.environment.steamInstalled
                        ? L.yes.resolve(in: language)
                        : L.no.resolve(in: language)
                )
                StatusTile(
                    title: L.detectedChip.resolve(in: language),
                    value: viewModel.environment.hardwareProfile.chipModel
                )
                StatusTile(
                    title: "RAM",
                    value: "\(viewModel.environment.hardwareProfile.memoryGB) GB"
                )
                StatusTile(
                    title: L.cpuCores.resolve(in: language),
                    value: cpuCoreSummary
                )
                StatusTile(
                    title: L.resolution.resolve(in: language),
                    value: viewModel.environment.hardwareProfile.displayResolutionIdentifier
                )
                StatusTile(
                    title: L.hwProfile.resolve(in: language),
                    value: viewModel.environment.hardwareProfile.performanceTier.title(in: language)
                )
                StatusTile(
                    title: L.autoTuning.resolve(in: language),
                    value: autoTuningSummary
                )
                StatusTile(
                    title: L.library.resolve(in: language),
                    value: viewModel.gameLibrarySummary
                )
                StatusTile(
                    title: L.gameProfiles.resolve(in: language),
                    value: viewModel.gameProfilesSummary
                )
                StatusTile(
                    title: L.preflight.resolve(in: language),
                    value: viewModel.preflightSummary
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                StatusRow(
                    title: "Prefix",
                    value: viewModel.environment.prefixPath.isEmpty ? "-" : viewModel.environment.prefixPath
                )
                StatusRow(
                    title: "Logs",
                    value: viewModel.environment.logsPath.isEmpty ? "-" : viewModel.environment.logsPath
                )
            }
        }
    }

    private var cpuCoreSummary: String {
        let summary = viewModel.environment.hardwareProfile.cpuCoreLayout.summary
        if summary == "Not detected" {
            return L.notDetected.resolve(in: language)
        }
        return summary
    }

    private var autoTuningSummary: String {
        let profile = viewModel.environment.hardwareProfile
        let backendText = profile.recommendedBackend.title(in: language)
        let dxvkThreads = profile.recommendedDXVKCompilerThreads
        if let fpsCap = profile.recommendedFPSCap {
            return L.autoTuningWithCap(backendText, dxvkThreads, fpsCap).resolve(in: language)
        }
        return L.autoTuningNoCap(backendText, dxvkThreads).resolve(in: language)
    }
}
