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
    private var _isRunning = false

    enum DeviceEvent: Sendable {
        case changed
    }

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    deinit {
        // Don't use queue.sync in deinit — just terminate directly
        process?.terminate()
    }

    /// Start monitoring device events. Returns an AsyncStream that emits
    /// events whenever the device list changes.
    func startMonitoring() -> AsyncStream<DeviceEvent> {
        // Stop any existing monitor first (non-blocking)
        stopMonitoring()

        guard let adbPath = environmentService.adbPath else {
            print("[Heimdall:USB] adb not found, cannot monitor devices")
            return AsyncStream { $0.finish() }
        }

        print("[Heimdall:USB] Starting monitor with adb at: \(adbPath)")

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.queue.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                // 1. Ensure adb server is running first
                self.startADBServer(adbPath: adbPath)

                // 2. Launch adb track-devices
                let proc = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                proc.executableURL = URL(fileURLWithPath: adbPath)
                proc.arguments = ["track-devices"]
                proc.standardOutput = outputPipe
                proc.standardError = errorPipe

                // Build environment with proper PATH
                var env = ProcessInfo.processInfo.environment
                let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
                let existingPath = env["PATH"] ?? "/usr/bin:/bin"
                let allPaths = (extraPaths + existingPath.components(separatedBy: ":"))
                env["PATH"] = allPaths.joined(separator: ":")

                // Also set ANDROID_HOME / ANDROID_SDK_ROOT if we know them
                if let sdkRoot = self.environmentService.androidSDKPath {
                    env["ANDROID_HOME"] = sdkRoot
                    env["ANDROID_SDK_ROOT"] = sdkRoot
                }
                proc.environment = env

                self.process = proc
                self._isRunning = true

                // Handle output — each chunk from track-devices means device list changed
                let fileHandle = outputPipe.fileHandleForReading
                fileHandle.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        // EOF — process ended
                        print("[Heimdall:USB] track-devices EOF")
                        fileHandle.readabilityHandler = nil
                        return
                    }

                    if let output = String(data: data, encoding: .utf8) {
                        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            print("[Heimdall:USB] Device change detected: \(trimmed.prefix(200))")
                        }
                    }
                    continuation.yield(.changed)
                }

                // Read stderr for diagnostics
                let stderrHandle = errorPipe.fileHandleForReading
                stderrHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            print("[Heimdall:USB] stderr: \(trimmed)")
                        }
                    }
                }

                proc.terminationHandler = { [weak self] terminatedProc in
                    print("[Heimdall:USB] track-devices terminated (status: \(terminatedProc.terminationStatus))")
                    fileHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    self?.queue.async {
                        self?._isRunning = false
                        self?.process = nil
                    }
                    continuation.finish()
                }

                // Handle stream cancellation
                continuation.onTermination = { @Sendable _ in
                    if proc.isRunning {
                        proc.terminate()
                    }
                }

                do {
                    try proc.run()
                    print("[Heimdall:USB] Started adb track-devices (PID: \(proc.processIdentifier))")
                } catch {
                    print("[Heimdall:USB] Failed to start track-devices: \(error)")
                    self._isRunning = false
                    self.process = nil
                    continuation.finish()
                }
            }
        }
    }

    /// Stop monitoring device events.
    func stopMonitoring() {
        // Use async dispatch to avoid deadlock if called from within the queue
        queue.async { [weak self] in
            guard let self else { return }
            if let proc = self.process, proc.isRunning {
                proc.terminate()
                print("[Heimdall:USB] Stopped device monitor")
            }
            self.process = nil
            self._isRunning = false
        }
    }

    // MARK: - Private

    /// Start the adb server if it's not already running.
    private func startADBServer(adbPath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: adbPath)
        proc.arguments = ["start-server"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + existingPath.components(separatedBy: ":"))
            .joined(separator: ":")
        if let sdkRoot = environmentService.androidSDKPath {
            env["ANDROID_HOME"] = sdkRoot
            env["ANDROID_SDK_ROOT"] = sdkRoot
        }
        proc.environment = env

        do {
            try proc.run()
            proc.waitUntilExit()
            print("[Heimdall:USB] adb server started (status: \(proc.terminationStatus))")
        } catch {
            print("[Heimdall:USB] Failed to start adb server: \(error)")
        }
    }
}
