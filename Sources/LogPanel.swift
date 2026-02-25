import AppKit
import SwiftUI

struct LogPanel: View {
    @ObservedObject var viewModel: SteamViewModel

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        PanelCard(title: L.console.resolve(in: language)) {
            // Launch progress bar (visible during Steam launch)
            if let phase = viewModel.launchPhase {
                LaunchProgressView(phase: phase, language: language)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Log content with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewModel.logEntries.isEmpty {
                            Text(L.noRunsYet.resolve(in: language))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(10)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.logEntries) { entry in
                                    if entry.text.isEmpty {
                                        Spacer().frame(height: 6)
                                    } else {
                                        Text(entry.text)
                                            .font(.system(size: 12, weight: fontWeight(for: entry.category), design: .monospaced))
                                            .foregroundStyle(color(for: entry.category))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(10)
                        }

                        // Invisible anchor for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("log-bottom")
                    }
                }
                .frame(minHeight: 280, maxHeight: .infinity)
                .background(.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: viewModel.logEntries.count) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.launchPhase) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }

            // Toolbar: clear + copy
            HStack(spacing: 8) {
                Spacer()

                Button {
                    copyLogsToClipboard()
                } label: {
                    Label(L.copyLogs.resolve(in: language), systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .controlSize(.small)
                .disabled(viewModel.logs.isEmpty)

                Button {
                    viewModel.clearLogs()
                } label: {
                    Label(L.clearLogs.resolve(in: language), systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(ResponsiveBorderedStyle())
                .controlSize(.small)
                .disabled(viewModel.logs.isEmpty)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.launchPhase != nil)
    }

    private func color(for category: LogEntry.Category) -> Color {
        switch category {
        case .normal:
            return .primary
        case .header(let base):
            switch base {
            case .error: return .red
            case .success: return Color.green
            case .progress: return Color.orange
            case .normal: return .primary
            }
        case .error:
            return .red
        case .success:
            return Color.green
        case .progress:
            return Color.orange
        }
    }

    private func fontWeight(for category: LogEntry.Category) -> Font.Weight {
        switch category {
        case .header: return .bold
        default: return .regular
        }
    }

    private func copyLogsToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.logs, forType: .string)
        viewModel.statusText = L.logsCopied.resolve(in: language)
    }
}

// MARK: - Launch Progress View

struct LaunchProgressView: View {
    let phase: LaunchPhase
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if phase == .steamDetected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(phase.title(in: language))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(phase == .steamDetected ? .green : .primary)

                Spacer()
            }

            ProgressView(value: phase.estimatedProgress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(phase == .steamDetected ? .green : .accentColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(phase == .steamDetected
                      ? Color.green.opacity(0.08)
                      : Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    phase == .steamDetected
                        ? Color.green.opacity(0.2)
                        : Color.accentColor.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}
