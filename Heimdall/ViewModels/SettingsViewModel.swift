import Foundation
import AppKit

// MARK: - Settings ViewModel

@MainActor
@Observable
final class SettingsViewModel {
    let environmentService: EnvironmentService

    var isDetecting: Bool = false

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - Browse Actions

    func browseAndroidSDK() {
        let panel = NSOpenPanel()
        panel.title = "Select Android SDK Directory"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await environmentService.setAndroidSDKPath(url.path)
            }
        }
    }

    func browseScrcpy() {
        let panel = NSOpenPanel()
        panel.title = "Select scrcpy Binary"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            environmentService.setScrcpyPath(url.path)
        }
    }

    // MARK: - Re-detect

    func redetect() async {
        isDetecting = true
        await environmentService.detect()
        isDetecting = false
    }
}
