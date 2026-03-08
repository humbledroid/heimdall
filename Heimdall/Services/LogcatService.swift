import Foundation

// MARK: - Logcat Service

/// Streams logcat output from an Android device/emulator as an AsyncStream of LogEntry.
actor LogcatService {
    private let environmentService: EnvironmentService
    private var process: Process?

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - Stream

    /// Start streaming logcat output from the given device serial.
    /// Returns an AsyncStream that yields parsed LogEntry values.
    func stream(serial: String) -> AsyncStream<LogEntry> {
        AsyncStream { continuation in
            Task {
                guard let adbPath = environmentService.adbPath else {
                    print("[Heimdall:Logcat] adb not found")
                    continuation.finish()
                    return
                }

                let proc = Process()
                let pipe = Pipe()

                proc.executableURL = URL(fileURLWithPath: adbPath)
                proc.arguments = ["-s", serial, "logcat", "-v", "threadtime"]
                proc.standardOutput = pipe
                proc.standardError = pipe
                proc.environment = buildEnvironment()

                // Handle termination
                proc.terminationHandler = { _ in
                    continuation.finish()
                }

                // Set up line-by-line reading
                let fileHandle = pipe.fileHandleForReading
                fileHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        // EOF
                        continuation.finish()
                        return
                    }

                    if let text = String(data: data, encoding: .utf8) {
                        let lines = text.components(separatedBy: .newlines)
                        for line in lines {
                            if let entry = LogEntry.parse(line: line) {
                                continuation.yield(entry)
                            }
                        }
                    }
                }

                // Handle cancellation
                continuation.onTermination = { @Sendable _ in
                    fileHandle.readabilityHandler = nil
                    if proc.isRunning {
                        proc.terminate()
                    }
                }

                do {
                    try proc.run()
                    self.process = proc
                    print("[Heimdall:Logcat] Started streaming for \(serial)")
                } catch {
                    print("[Heimdall:Logcat] Failed to start: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Clear

    /// Clear the logcat buffer on the device.
    func clearLog(serial: String) async throws {
        guard let adbPath = environmentService.adbPath else {
            throw LogcatError.toolNotFound("adb")
        }

        let runner = ShellCommandRunner()
        _ = try await runner.execute(
            command: adbPath,
            arguments: ["-s", serial, "logcat", "-c"],
            timeout: 10
        )
    }

    // MARK: - Stop

    /// Stop any running logcat process.
    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            print("[Heimdall:Logcat] Stopped streaming")
        }
        process = nil
    }

    // MARK: - Helpers

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let sdkPath = environmentService.androidSDKPath {
            env["ANDROID_HOME"] = sdkPath
            env["ANDROID_SDK_ROOT"] = sdkPath
        }
        return env
    }
}

// MARK: - Errors

enum LogcatError: LocalizedError {
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "\(tool) not found. Check Android SDK path in settings."
        }
    }
}
