import AppKit
import SwiftUI

@main
struct SteaviumApp: App {
    @StateObject private var viewModel = SteamViewModel()

    init() {
        configureAppIcon()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 820)
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
