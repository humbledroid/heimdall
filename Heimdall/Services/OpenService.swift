import Foundation

// MARK: - Open Service

/// Launches external applications and URLs using macOS `/usr/bin/open`.
actor OpenService {
    private let runner = ShellCommandRunner()
    private let openPath = "/usr/bin/open"

    // MARK: - Core

    private func runOpen(_ arguments: [String], timeout: TimeInterval = 10) async throws {
        print("[Heimdall:Open] Running: \(openPath) \(arguments.joined(separator: " "))")

        do {
            _ = try await runner.execute(
                command: openPath,
                arguments: arguments,
                environment: nil,
                timeout: timeout
            )
        } catch {
            throw OpenServiceError.launchFailed(
                app: arguments.first(where: { !$0.hasPrefix("-") }) ?? "unknown",
                underlying: error
            )
        }
    }

    // MARK: - iOS Simulator

    /// Opens Simulator.app and switches to the device with the given UDID.
    func openSimulator(udid: String) async throws {
        try await runOpen([
            "-a", "Simulator",
            "--args",
            "-CurrentDeviceUDID", udid
        ])
    }

    // MARK: - General Purpose

    /// Opens a file or directory in its default application.
    func openFile(at path: String) async throws {
        try await runOpen([path])
    }

    /// Opens a file or directory with a specific application.
    func openFile(at path: String, withApp appName: String) async throws {
        try await runOpen(["-a", appName, path])
    }

    /// Opens a URL in the default browser.
    func openURL(_ url: String) async throws {
        try await runOpen([url])
    }

    // MARK: - Errors

    enum OpenServiceError: LocalizedError {
        case launchFailed(app: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let app, let underlying):
                return "Failed to open \(app): \(underlying.localizedDescription)"
            }
        }
    }
}
