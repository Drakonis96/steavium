import AppKit
import SwiftUI

@main
struct SteaviumApp: App {
    @StateObject private var viewModel = SteamViewModel()
    @NSApplicationDelegateAdaptor(SteaviumAppDelegate.self) private var appDelegate

    init() {
        configureAppIcon()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 820)
        }

        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.isSteamRunning ? "gamecontroller.fill" : "gamecontroller")
        }
    }

    private func configureAppIcon() {
        guard
            let logoURL = Bundle.module.url(forResource: "logo", withExtension: "png", subdirectory: "Resources"),
            let logoImage = NSImage(contentsOf: logoURL)
        else {
            return
        }
        NSApplication.shared.applicationIconImage = logoImage
    }
}

// MARK: - App Delegate (keep app alive when all windows close)

final class SteaviumAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var viewModel: SteamViewModel

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isSteamRunning ? "circle.fill" : "circle")
                    .foregroundStyle(viewModel.isSteamRunning ? .green : .secondary)
                    .font(.caption2)
                Text(viewModel.isSteamRunning
                     ? L.menuBarSteamRunning.resolve(in: language)
                     : L.menuBarSteamNotRunning.resolve(in: language))
            }

            Divider()

            Button(L.menuBarShowSteavium.resolve(in: language)) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button(L.menuBarQuit.resolve(in: language)) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
