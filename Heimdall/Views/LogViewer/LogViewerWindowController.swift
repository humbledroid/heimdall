import AppKit
import SwiftUI

// MARK: - Log Viewer Window Controller

/// Manages a standalone window for viewing Android logs.
/// Each device/emulator gets its own window.
final class LogViewerWindowController: NSWindowController {
    private(set) var serial: String = ""

    init(
        deviceName: String,
        serial: String,
        environmentService: EnvironmentService
    ) {
        self.serial = serial

        let viewModel = LogViewerViewModel(
            deviceName: deviceName,
            serial: serial,
            environmentService: environmentService
        )

        let hostingView = NSHostingView(rootView: LogViewerView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Logs — \(deviceName)"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("LogViewer-\(serial)")
        window.minSize = NSSize(width: 500, height: 300)
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
