import Foundation

// MARK: - USB Device Monitor

/// Monitors USB device connections using `adb track-devices`.
/// Provides real-time notifications when devices are connected or disconnected.
///
/// Uses a class (not actor) to avoid actor isolation issues with Process callbacks.
/// Thread safety is handled via a dedicated serial DispatchQueue.
final class USBDeviceMonitor: @unchecked Sendable {
    private let environmentService: EnvironmentService
    private let queue = DispatchQueue(label: "com.heimdall.usb-monitor")
    private var process: Process?
    private var isRunning = false

    enum DeviceEvent: Sendable {
        case changed
    }

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    deinit {
        stopMonitoring()
    }

    /// Start monitoring device events. Returns an AsyncStream that emits
    /// events whenever the device list changes.
    func startMonitoring() -> AsyncStream<DeviceEvent> {
        // Stop any existing monitor first
        stopMonitoring()

        guard let adbPath = environmentService.adbPath else {
            print("[Heimdall:USB] adb not found, cannot monitor devices")
            return AsyncStream { $0.finish() }
        }

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.queue.async {
                // 1. Ensure adb server is running first
                self.startADBServer(adbPath: adbPath)

                // 2. Launch adb track-devices
                let process = Process()
                let outputPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: adbPath)
                process.arguments = ["track-devices"]
                process.standardOutput = outputPipe
                process.standardError = FileHandle.nullDevice

                // Set up environment
                var env = ProcessInfo.processInfo.environment
                let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
                let existingPath = env["PATH"] ?? "/usr/bin:/bin"
                env["PATH"] = (extraPaths + existingPath.components(separatedBy: ":"))
                    .joined(separator: ":")
                process.environment = env

                self.process = process
                self.isRunning = true

                // Handle output — each chunk from track-devices means device list changed
                let fileHandle = outputPipe.fileHandleForReading
                fileHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        // EOF — process ended
                        print("[Heimdall:USB] track-devices EOF")
                        return
                    }

                    let output = String(data: data, encoding: .utf8) ?? ""
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        print("[Heimdall:USB] Device change detected: \(trimmed)")
                    }
                    continuation.yield(.changed)
                }

                process.terminationHandler = { [weak self] proc in
                    print("[Heimdall:USB] track-devices terminated (status: \(proc.terminationStatus))")
                    fileHandle.readabilityHandler = nil
                    self?.queue.async {
                        self?.isRunning = false
                        self?.process = nil
                    }
                    continuation.finish()
                }

                // Handle stream cancellation
                continuation.onTermination = { @Sendable _ in
                    if process.isRunning {
                        process.terminate()
                    }
                }

                do {
                    try process.run()
                    print("[Heimdall:USB] Started adb track-devices (PID: \(process.processIdentifier))")
                } catch {
                    print("[Heimdall:USB] Failed to start track-devices: \(error)")
                    self.isRunning = false
                    self.process = nil
                    continuation.finish()
                }
            }
        }
    }

    /// Stop monitoring device events.
    func stopMonitoring() {
        queue.sync {
            if let process, process.isRunning {
                process.terminate()
                print("[Heimdall:USB] Stopped device monitor")
            }
            process = nil
            isRunning = false
        }
    }

    // MARK: - Private

    /// Start the adb server if it's not already running.
    /// This is synchronous and quick — adb start-server returns immediately
    /// if the server is already up.
    private func startADBServer(adbPath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["start-server"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + existingPath.components(separatedBy: ":"))
            .joined(separator: ":")
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
            print("[Heimdall:USB] adb server started (status: \(process.terminationStatus))")
        } catch {
            print("[Heimdall:USB] Failed to start adb server: \(error)")
        }
    }
}
