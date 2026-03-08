import Foundation

// MARK: - App Installer Service

/// Installs apps on iOS simulators and Android devices/emulators.
actor AppInstallerService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - iOS

    /// Install a `.app` bundle on an iOS simulator via `simctl install`.
    func installOnSimulator(udid: String, appPath: String) async throws {
        let simctlPath = try await resolveSimctlPath()
        let env = simctlEnvironment()

        print("[Heimdall:Install] Installing on simulator \(udid): \(appPath)")

        _ = try await runner.execute(
            command: simctlPath,
            arguments: ["install", udid, appPath],
            environment: env.isEmpty ? nil : env,
            timeout: 120
        )

        print("[Heimdall:Install] Successfully installed on simulator \(udid)")
    }

    // MARK: - Android

    /// Install an `.apk` on an Android device or emulator via `adb install`.
    func installOnAndroid(serial: String, apkPath: String) async throws {
        guard let adbPath = environmentService.adbPath else {
            throw AppInstallerError.toolNotFound("adb")
        }

        print("[Heimdall:Install] Installing on Android \(serial): \(apkPath)")

        _ = try await runner.execute(
            command: adbPath,
            arguments: ["-s", serial, "install", "-r", apkPath],
            timeout: 120
        )

        print("[Heimdall:Install] Successfully installed on Android \(serial)")
    }

    // MARK: - Simctl Helpers

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

        throw AppInstallerError.toolNotFound("simctl")
    }

    private func simctlEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let devDir = environmentService.developerDir {
            env["DEVELOPER_DIR"] = devDir
            env["DYLD_FRAMEWORK_PATH"] = "\(devDir)/../Frameworks"
        }
        return env
    }
}

// MARK: - Errors

enum AppInstallerError: LocalizedError {
    case toolNotFound(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "\(tool) not found. Check settings."
        case .installFailed(let message):
            return "Installation failed: \(message)"
        }
    }
}
