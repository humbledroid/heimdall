import Foundation

// MARK: - Deep Link Service

/// Opens deep links / URLs on iOS simulators and Android devices/emulators.
actor DeepLinkService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService
    private let simctlService: SimctlService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.simctlService = SimctlService(environmentService: environmentService)
    }

    // MARK: - iOS

    /// Open a URL on an iOS simulator via `simctl openurl`.
    func openOnSimulator(udid: String, url: String) async throws {
        let simctlPath = try await resolveSimctlPath()
        let env = simctlEnvironment()

        print("[Heimdall:DeepLink] Opening on simulator \(udid): \(url)")

        _ = try await runner.execute(
            command: simctlPath,
            arguments: ["openurl", udid, url],
            environment: env.isEmpty ? nil : env,
            timeout: 15
        )
    }

    // MARK: - Android

    /// Open a URL on an Android device or emulator via `adb shell am start`.
    func openOnAndroid(serial: String, url: String) async throws {
        guard let adbPath = environmentService.adbPath else {
            throw DeepLinkError.toolNotFound("adb")
        }

        print("[Heimdall:DeepLink] Opening on Android \(serial): \(url)")

        _ = try await runner.execute(
            command: adbPath,
            arguments: [
                "-s", serial,
                "shell", "am", "start",
                "-a", "android.intent.action.VIEW",
                "-d", url
            ],
            timeout: 15
        )
    }

    // MARK: - Simctl Helpers

    /// Resolve the simctl binary path (same strategy as SimctlService).
    private var resolvedSimctlPath: String?

    private func resolveSimctlPath() async throws -> String {
        if let cached = resolvedSimctlPath { return cached }

        if let devDir = environmentService.developerDir {
            let directPath = "\(devDir)/usr/bin/simctl"
            if FileManager.default.isExecutableFile(atPath: directPath) {
                resolvedSimctlPath = directPath
                return directPath
            }
        }

        let commonPaths = [
            "/Applications/Xcode.app/Contents/Developer/usr/bin/simctl",
            "/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl",
        ]
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                resolvedSimctlPath = path
                return path
            }
        }

        throw DeepLinkError.toolNotFound("simctl")
    }

    private func simctlEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let devDir = environmentService.developerDir {
            env["DEVELOPER_DIR"] = devDir
            env["DYLD_FRAMEWORK_PATH"] = "\(devDir)/../Frameworks"
        }
        return env
    }

    // MARK: - History

    private static let historyKey = "heimdall.deepLinkHistory"
    private static let maxHistory = 20

    /// Load recent deep link history from UserDefaults.
    nonisolated func loadHistory() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    /// Save a URL to deep link history.
    nonisolated func saveToHistory(_ url: String) {
        var history = loadHistory()
        // Remove if already exists (move to top)
        history.removeAll { $0 == url }
        history.insert(url, at: 0)
        // Cap at max
        if history.count > Self.maxHistory {
            history = Array(history.prefix(Self.maxHistory))
        }
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    /// Clear deep link history.
    nonisolated func clearHistory() {
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }
}

// MARK: - Errors

enum DeepLinkError: LocalizedError {
    case toolNotFound(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "\(tool) not found. Check settings."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        }
    }
}
