import SwiftUI

struct UpdateSheet: View {
    @ObservedObject var updater: AppUpdater
    @Binding var isPresented: Bool
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Text(L.checkForUpdates.resolve(in: language))
                .font(.title2.bold())

            Text(L.currentVersionLabel(AppUpdater.currentVersion).resolve(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Group {
                switch updater.status {
                case .idle:
                    idleView

                case .checking:
                    ProgressView(L.updateChecking.resolve(in: language))

                case .noUpdate:
                    noUpdateView

                case .available(let version, let notes):
                    availableView(version: version, notes: notes)

                case .downloading(let progress):
                    downloadingView(progress: progress)

                case .installing:
                    ProgressView(L.updateInstalling.resolve(in: language))

                case .installed(let version):
                    installedView(version: version)

                case .failed(let message):
                    failedView(message: message)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(L.close.resolve(in: language)) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 380)
        .onAppear {
            if updater.status == .idle || updater.status == .noUpdate {
                Task {
                    await updater.checkForUpdate()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Button(L.checkForUpdates.resolve(in: language)) {
                Task { await updater.checkForUpdate() }
            }
            .buttonStyle(ResponsiveBorderedProminentStyle())
        }
    }

    private var noUpdateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text(L.updateNoUpdate.resolve(in: language))
                .font(.headline)
        }
    }

    private func availableView(version: String, notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                Text(L.updateNewVersion(version).resolve(in: language))
                    .font(.headline)
            }

            if !notes.isEmpty {
                GroupBox(L.releaseNotes.resolve(in: language)) {
                    ScrollView {
                        Text(notes)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                }
            }

            Button(L.updateNow.resolve(in: language)) {
                Task { await updater.downloadAndInstall() }
            }
            .buttonStyle(ResponsiveBorderedProminentStyle())
        }
    }

    private func downloadingView(progress: Double) -> some View {
        VStack(spacing: 12) {
            Text(L.updateDownloading.resolve(in: language))
                .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func installedView(version: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text(L.updateInstalled(version).resolve(in: language))
                .font(.headline)
                .multilineTextAlignment(.center)
            Button(L.updateRelaunch.resolve(in: language)) {
                updater.relaunchApp()
            }
            .buttonStyle(ResponsiveBorderedProminentStyle())
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text(L.updateFailed.resolve(in: language))
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L.updateRetry.resolve(in: language)) {
                Task { await updater.checkForUpdate() }
            }
            .buttonStyle(ResponsiveBorderedStyle())
        }
    }
}
