import Foundation

// MARK: - Environment Service

/// Detects and manages paths to required CLI tools (Android SDK, scrcpy, Xcode tools).
@Observable
final class EnvironmentService: @unchecked Sendable {

    // MARK: - Detected Paths

    var androidSDKPath: String?
    var avdManagerPath: String?
    var emulatorPath: String?
    var adbPath: String?
    var scrcpyPath: String?
    var xcrunPath: String?
    var sdkManagerPath: String?
    var developerDir: String?

    // MARK: - Status

    var isDetecting: Bool = false
    var hasDetected: Bool = false

    var hasAndroidSDK: Bool { androidSDKPath != nil }
    var hasScrcpy: Bool { scrcpyPath != nil }
    var hasXcode: Bool { xcrunPath != nil }

    private let runner = ShellCommandRunner()
    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let androidSDK = "heimdall.androidSDKPath"
        static let scrcpy = "heimdall.scrcpyPath"
    }

    // MARK: - Detection

    /// Run full environment detection. Checks saved paths first, then auto-detects.
    func detect() async {
        isDetecting = true
        defer {
            isDetecting = false
            hasDetected = true
        }

        // 1. Xcode tools (always try)
        xcrunPath = await runner.which("xcrun")
        print("[Heimdall:Env] xcrun: \(xcrunPath ?? "NOT FOUND")")

        // Detect Xcode developer directory for simctl
        developerDir = await detectDeveloperDir()
        print("[Heimdall:Env] DEVELOPER_DIR: \(developerDir ?? "NOT FOUND")")

        // 2. Android SDK
        androidSDKPath = await detectAndroidSDK()
        print("[Heimdall:Env] Android SDK: \(androidSDKPath ?? "NOT FOUND")")

        if let sdk = androidSDKPath {
            avdManagerPath = resolveToolInSDK(sdk, tool: "avdmanager", subdir: "cmdline-tools/latest/bin")
                ?? resolveToolInSDK(sdk, tool: "avdmanager", subdir: "tools/bin")
            emulatorPath = resolveToolInSDK(sdk, tool: "emulator", subdir: "emulator")
            adbPath = resolveToolInSDK(sdk, tool: "adb", subdir: "platform-tools")
            sdkManagerPath = resolveToolInSDK(sdk, tool: "sdkmanager", subdir: "cmdline-tools/latest/bin")
                ?? resolveToolInSDK(sdk, tool: "sdkmanager", subdir: "tools/bin")

            print("[Heimdall:Env] avdmanager: \(avdManagerPath ?? "NOT FOUND")")
            print("[Heimdall:Env] emulator: \(emulatorPath ?? "NOT FOUND")")
            print("[Heimdall:Env] adb: \(adbPath ?? "NOT FOUND")")
            print("[Heimdall:Env] sdkmanager: \(sdkManagerPath ?? "NOT FOUND")")
        }

        // 3. scrcpy
        scrcpyPath = await detectScrcpy()
        print("[Heimdall:Env] scrcpy: \(scrcpyPath ?? "NOT FOUND")")
    }

    // MARK: - Android SDK Detection

    private func detectAndroidSDK() async -> String? {
        // Check saved preference
        if let saved = defaults.string(forKey: Keys.androidSDK),
           FileManager.default.fileExists(atPath: saved) {
            return saved
        }

        // Check environment variables
        let envVars = ["ANDROID_HOME", "ANDROID_SDK_ROOT"]
        for envVar in envVars {
            if let path = ProcessInfo.processInfo.environment[envVar],
               FileManager.default.fileExists(atPath: path) {
                defaults.set(path, forKey: Keys.androidSDK)
                return path
            }
        }

        // Check common locations
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPaths = [
            "\(home)/Library/Android/sdk",
            "\(home)/Android/Sdk",
            "/usr/local/share/android-sdk",
            "/opt/homebrew/share/android-sdk",
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                defaults.set(path, forKey: Keys.androidSDK)
                return path
            }
        }

        return nil
    }

    // MARK: - scrcpy Detection

    private func detectScrcpy() async -> String? {
        // Check saved preference
        if let saved = defaults.string(forKey: Keys.scrcpy),
           FileManager.default.fileExists(atPath: saved) {
            return saved
        }

        // Check common locations
        let commonPaths = [
            "/opt/homebrew/bin/scrcpy",
            "/usr/local/bin/scrcpy",
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                defaults.set(path, forKey: Keys.scrcpy)
                return path
            }
        }

        // Try which
        if let path = await runner.which("scrcpy") {
            defaults.set(path, forKey: Keys.scrcpy)
            return path
        }

        return nil
    }

    // MARK: - Developer Directory Detection

    private func detectDeveloperDir() async -> String? {
        do {
            let output = try await runner.executeShell("xcode-select -p")
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                return path
            }
        } catch {
            print("[Heimdall:Env] xcode-select -p failed: \(error)")
        }

        // Fallback to common location
        let defaultPath = "/Applications/Xcode.app/Contents/Developer"
        if FileManager.default.fileExists(atPath: defaultPath) {
            return defaultPath
        }

        return nil
    }

    // MARK: - Manual Path Setting

    func setAndroidSDKPath(_ path: String) async {
        defaults.set(path, forKey: Keys.androidSDK)
        await detect()
    }

    func setScrcpyPath(_ path: String) {
        defaults.set(path, forKey: Keys.scrcpy)
        scrcpyPath = path
    }

    // MARK: - Helpers

    private func resolveToolInSDK(_ sdkPath: String, tool: String, subdir: String) -> String? {
        let fullPath = (sdkPath as NSString).appendingPathComponent(subdir)
            .appending("/\(tool)")
        return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
    }
}
