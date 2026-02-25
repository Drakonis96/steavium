import SwiftUI

struct PreflightPanel: View {
    @ObservedObject var viewModel: SteamViewModel

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        PanelCard(title: L.runtimePreflight.resolve(in: language)) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: preflightStatusIcon(viewModel.preflightReport.overallStatus))
                        .foregroundStyle(preflightStatusColor(viewModel.preflightReport.overallStatus))
                    Text(viewModel.preflightSummary)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 0)

                Button(L.runPreflight.resolve(in: language)) {
                    viewModel.refreshPreflight()
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .disabled(viewModel.isBusy)
            }

            if viewModel.preflightReport.checks.isEmpty {
                Text(L.noPreflightData.resolve(in: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.preflightReport.checks) { check in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: preflightStatusIcon(check.status))
                                    .foregroundStyle(preflightStatusColor(check.status))
                                Text(check.kind.title(in: language))
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(check.status.title(in: language))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(check.detail(in: language))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            preflightFixActions(for: check)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func preflightFixActions(for check: RuntimePreflightCheck) -> some View {
        switch check.kind {
        case .homebrew:
            if check.status == .failed {
                Button(L.openHomebrewGuide.resolve(in: language)) {
                    viewModel.openHomebrewInstallGuide()
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .font(.caption)
            }
        case .ffmpeg:
            if check.status != .ok && viewModel.preflightHomebrewAvailable {
                Button(L.installFfmpeg.resolve(in: language)) {
                    viewModel.installFFmpegDependency()
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .font(.caption)
                .disabled(viewModel.isBusy)
            }
        case .diskSpace:
            if check.status != .ok {
                Button(L.openAppFolder.resolve(in: language)) {
                    viewModel.openAppHomeFolder()
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .font(.caption)
            }
        case .network:
            if check.status == .failed {
                Button(L.retryCheck.resolve(in: language)) {
                    viewModel.refreshPreflight()
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .font(.caption)
                .disabled(viewModel.isBusy)
            }
        case .runtime:
            EmptyView()
        }
    }

    private func preflightStatusIcon(_ status: RuntimePreflightStatus) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    private func preflightStatusColor(_ status: RuntimePreflightStatus) -> Color {
        switch status {
        case .ok: .green
        case .warning: .orange
        case .failed: .red
        }
    }
}
