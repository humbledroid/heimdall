import Foundation

// MARK: - Scrcpy Service

/// Manages scrcpy processes for mirroring physical Android devices.
actor ScrcpyService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService

    /// Active mirroring sessions keyed by device serial.
    private var sessions: [String: ActiveSession] = [:]

    private struct ActiveSession {
        let session: MirroringSession
        let process: Process
    }

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - Start Mirroring

    /// Start mirroring a device. Returns the session info.
    func startMirroring(deviceSerial: String, windowTitle: String? = nil) async throws -> MirroringSession {
        guard let scrcpyPath = environmentService.scrcpyPath else {
            throw ScrcpyError.scrcpyNotFound
        }

        // Don't start duplicate sessions
        if let existing = sessions[deviceSerial], existing.process.isRunning {
            return existing.session
        }

        var args = ["-s", deviceSerial]

        if let title = windowTitle {
            args += ["--window-title", title]
        }

        // Keep window on top for convenience
        args += ["--always-on-top"]

        let process = try await runner.launchDetached(
            command: scrcpyPath,
            arguments: args
        )

        let session = MirroringSession(
            id: UUID(),
            deviceSerial: deviceSerial,
            processIdentifier: process.processIdentifier,
            startedAt: Date()
        )

        sessions[deviceSerial] = ActiveSession(session: session, process: process)

        // Monitor process termination to clean up
        process.terminationHandler = { [weak self] _ in
            Task {
                await self?.removeSession(for: deviceSerial)
            }
        }

        return session
    }

    // MARK: - Stop Mirroring

    /// Stop an active mirroring session.
    func stopMirroring(deviceSerial: String) {
        guard let active = sessions[deviceSerial] else { return }

        if active.process.isRunning {
            active.process.terminate()
        }

        sessions.removeValue(forKey: deviceSerial)
    }

    // MARK: - Stop All

    /// Stop all active mirroring sessions.
    func stopAll() {
        for (_, active) in sessions {
            if active.process.isRunning {
                active.process.terminate()
            }
        }
        sessions.removeAll()
    }

    // MARK: - Query

    /// Get all active mirroring sessions.
    func activeSessions() -> [MirroringSession] {
        // Clean up dead sessions first
        let dead = sessions.filter { !$0.value.process.isRunning }
        for key in dead.keys {
            sessions.removeValue(forKey: key)
        }

        return sessions.values.map(\.session)
    }

    /// Check if a device is currently being mirrored.
    func isMirroring(deviceSerial: String) -> Bool {
        guard let active = sessions[deviceSerial] else { return false }
        return active.process.isRunning
    }

    // MARK: - Private

    private func removeSession(for serial: String) {
        sessions.removeValue(forKey: serial)
    }
}

// MARK: - Errors

enum ScrcpyError: LocalizedError {
    case scrcpyNotFound
    case mirroringFailed(String)

    var errorDescription: String? {
        switch self {
        case .scrcpyNotFound:
            return "scrcpy not found. Install via Homebrew: brew install scrcpy"
        case .mirroringFailed(let message):
            return "Mirroring failed: \(message)"
        }
    }
}
