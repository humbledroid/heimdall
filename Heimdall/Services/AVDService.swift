import Foundation

// MARK: - AVD Service

/// Wrapper around `avdmanager` and `emulator` for managing Android Virtual Devices.
actor AVDService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - List AVDs

    func listAVDs() async throws -> [AndroidEmulator] {
        guard let emulatorPath = environmentService.emulatorPath else {
            throw AVDError.toolNotFound("emulator")
        }

        let namesOutput = try await runner.execute(
            command: emulatorPath,
            arguments: ["-list-avds"]
        )

        let avdNames = namesOutput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let runningEmulators = await getRunningEmulators()

        var emulators: [AndroidEmulator] = []

        for name in avdNames {
            let details = readAVDConfig(name: name)
            let isRunning = runningEmulators.contains(name)

            let emulator = AndroidEmulator(
                name: name,
                path: details["path"] ?? "",
                target: details["target"] ?? "Unknown",
                abi: details["abi"] ?? "Unknown",
                status: isRunning ? .booted : .shutdown,
                apiLevel: details["apiLevel"]
            )
            emulators.append(emulator)
        }

        return emulators.sorted { lhs, rhs in
            if lhs.status == .booted && rhs.status != .booted { return true }
            if lhs.status != .booted && rhs.status == .booted { return false }
            return lhs.name < rhs.name
        }
    }

    // MARK: - List System Images

    func listSystemImages() async throws -> [SystemImage] {
        // Always try filesystem scan first — it's the most reliable method
        let scanned = scanSystemImages()
        if !scanned.isEmpty {
            print("[Heimdall] Found \(scanned.count) system images via filesystem scan")
            return scanned
        }

        // Fallback to sdkmanager if filesystem scan found nothing
        if let sdkManagerPath = environmentService.sdkManagerPath {
            do {
                let output = try await runner.execute(
                    command: sdkManagerPath,
                    arguments: ["--list"],
                    timeout: 60
                )
                let parsed = parseSystemImages(from: output)
                print("[Heimdall] Found \(parsed.count) system images via sdkmanager")
                return parsed
            } catch {
                print("[Heimdall] sdkmanager --list failed: \(error)")
            }
        }

        return []
    }

    // MARK: - Start Emulator

    func startEmulator(name: String) async throws {
        guard let emulatorPath = environmentService.emulatorPath else {
            throw AVDError.toolNotFound("emulator")
        }

        try await runner.launchDetached(
            command: emulatorPath,
            arguments: ["@\(name)", "-no-snapshot-load"]
        )
    }

    // MARK: - Stop Emulator

    func stopEmulator(name: String) async throws {
        guard let adbPath = environmentService.adbPath else {
            throw AVDError.toolNotFound("adb")
        }

        let serial = try await findEmulatorSerial(for: name)

        _ = try await runner.execute(
            command: adbPath,
            arguments: ["-s", serial, "emu", "kill"]
        )
    }

    // MARK: - Create AVD

    func createAVD(
        name: String,
        systemImagePath: String,
        deviceProfile: String? = nil,
        config: EmulatorConfig = EmulatorConfig()
    ) async throws {
        guard let avdManagerPath = environmentService.avdManagerPath else {
            throw AVDError.toolNotFound("avdmanager")
        }

        var args = [
            "create", "avd",
            "--name", name,
            "--package", systemImagePath,
            "--force"
        ]

        if let profile = deviceProfile {
            args += ["--device", profile]
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: avdManagerPath)
        process.arguments = args
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.environment = ProcessInfo.processInfo.environment

        try process.run()

        // Send "no" to skip custom hardware profile prompt
        if let noData = "no\n".data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(noData)
            inputPipe.fileHandleForWriting.closeFile()
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AVDError.creationFailed(output)
        }

        // Apply advanced configuration to the AVD's config.ini
        applyConfig(name: name, config: config)
    }

    /// Write advanced config values to the AVD's config.ini.
    private func applyConfig(name: String, config: EmulatorConfig) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.android/avd/\(name).avd/config.ini"

        guard var contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("[Heimdall] Could not read config.ini for \(name) to apply advanced settings")
            return
        }

        // Helper to set or update a key in the config
        func setConfigValue(_ key: String, _ value: String) {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let pattern = "^\(escapedKey)\\s*=.*$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                let range = NSRange(contents.startIndex..., in: contents)
                if regex.firstMatch(in: contents, range: range) != nil {
                    contents = regex.stringByReplacingMatches(
                        in: contents, range: range,
                        withTemplate: "\(key)=\(value)"
                    )
                } else {
                    contents += "\n\(key)=\(value)"
                }
            }
        }

        setConfigValue("hw.ramSize", "\(config.ramMB)")
        setConfigValue("disk.dataPartition.size", "\(config.storageMB)M")
        setConfigValue("hw.gpu.enabled", "yes")
        setConfigValue("hw.gpu.mode", config.gpuMode.rawValue)

        do {
            try contents.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("[Heimdall] Applied advanced config to \(name): RAM=\(config.ramMB)MB, Storage=\(config.storageMB)MB, GPU=\(config.gpuMode.rawValue)")
        } catch {
            print("[Heimdall] Failed to write config.ini for \(name): \(error)")
        }
    }

    // MARK: - Delete AVD

    func deleteAVD(name: String) async throws {
        guard let avdManagerPath = environmentService.avdManagerPath else {
            throw AVDError.toolNotFound("avdmanager")
        }

        _ = try await runner.execute(
            command: avdManagerPath,
            arguments: ["delete", "avd", "--name", name]
        )
    }

    // MARK: - Private Helpers

    /// Read AVD config.ini for details (synchronous — just file I/O).
    private func readAVDConfig(name: String) -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.android/avd/\(name).avd/config.ini"
        var details: [String: String] = [:]

        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return details
        }

        for line in contents.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)

            switch key {
            case "abi.type": details["abi"] = value
            case "image.sysdir.1":
                if let range = value.range(of: #"android-(\d+)"#, options: .regularExpression) {
                    let apiStr = value[range].replacingOccurrences(of: "android-", with: "")
                    details["apiLevel"] = apiStr
                    details["target"] = "Android \(apiStr)"
                }
            case "tag.id": details["tag"] = value
            default: break
            }
        }

        details["path"] = "\(home)/.android/avd/\(name).avd"
        return details
    }

    /// Get list of currently running emulator AVD names.
    private func getRunningEmulators() async -> Set<String> {
        guard let adbPath = environmentService.adbPath else { return [] }

        do {
            let output = try await runner.execute(
                command: adbPath,
                arguments: ["devices"]
            )

            var running = Set<String>()

            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("emulator-") else { continue }
                let serial = trimmed.components(separatedBy: .whitespaces).first ?? ""

                if let name = try? await runner.execute(
                    command: adbPath,
                    arguments: ["-s", serial, "emu", "avd", "name"]
                ) {
                    let avdName = name.components(separatedBy: .newlines).first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !avdName.isEmpty {
                        running.insert(avdName)
                    }
                }
            }

            return running
        } catch {
            return []
        }
    }

    /// Find the emulator-XXXX serial for a given AVD name.
    private func findEmulatorSerial(for avdName: String) async throws -> String {
        guard let adbPath = environmentService.adbPath else {
            throw AVDError.toolNotFound("adb")
        }

        let output = try await runner.execute(
            command: adbPath,
            arguments: ["devices"]
        )

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("emulator-") else { continue }
            let serial = trimmed.components(separatedBy: .whitespaces).first ?? ""

            if let name = try? await runner.execute(
                command: adbPath,
                arguments: ["-s", serial, "emu", "avd", "name"]
            ) {
                let resolvedName = name.components(separatedBy: .newlines).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if resolvedName == avdName {
                    return serial
                }
            }
        }

        throw AVDError.emulatorNotRunning(avdName)
    }

    /// Parse system images from sdkmanager --list output.
    /// Handles both old format ("  system-images;android-34;...") and
    /// new tabular format ("  system-images;android-34;... | ... | ...").
    private func parseSystemImages(from output: String) -> [SystemImage] {
        var images: [SystemImage] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Extract the package path — it's always the first column
            let packagePath: String
            if trimmed.contains("|") {
                packagePath = trimmed.components(separatedBy: "|").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
            } else {
                packagePath = trimmed
            }

            guard packagePath.hasPrefix("system-images;") else { continue }

            let components = packagePath.components(separatedBy: ";")
            guard components.count >= 4 else { continue }

            let apiLevel = components[1].replacingOccurrences(of: "android-", with: "")
            let image = SystemImage(
                path: components.joined(separator: ";"),
                apiLevel: apiLevel,
                tag: components[2],
                abi: components[3]
            )
            images.append(image)
        }

        return images.sorted { $0.apiLevel > $1.apiLevel }
    }

    /// Primary method: scan filesystem for installed system images.
    /// This is the most reliable approach since sdkmanager output format varies.
    private func scanSystemImages() -> [SystemImage] {
        guard let sdkPath = environmentService.androidSDKPath else { return [] }

        let basePath = "\(sdkPath)/system-images"
        let fm = FileManager.default
        var images: [SystemImage] = []

        print("[Heimdall] Scanning for system images at: \(basePath)")

        guard fm.fileExists(atPath: basePath),
              let apiDirs = try? fm.contentsOfDirectory(atPath: basePath) else {
            print("[Heimdall] system-images directory not found or empty")
            return []
        }

        for apiDir in apiDirs {
            guard apiDir.hasPrefix("android-") else { continue }
            let apiPath = "\(basePath)/\(apiDir)"

            guard let tagDirs = try? fm.contentsOfDirectory(atPath: apiPath) else { continue }

            for tagDir in tagDirs {
                // Skip hidden directories
                guard !tagDir.hasPrefix(".") else { continue }
                let tagPath = "\(apiPath)/\(tagDir)"

                // Check if it's actually a directory
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: tagPath, isDirectory: &isDir), isDir.boolValue else { continue }

                guard let abiDirs = try? fm.contentsOfDirectory(atPath: tagPath) else { continue }

                for abiDir in abiDirs {
                    guard !abiDir.hasPrefix(".") else { continue }
                    let abiPath = "\(tagPath)/\(abiDir)"

                    // Verify this looks like a valid system image (has system.img or similar)
                    var abiIsDir: ObjCBool = false
                    guard fm.fileExists(atPath: abiPath, isDirectory: &abiIsDir), abiIsDir.boolValue else { continue }

                    // Check for typical system image files
                    let markerFiles = ["system.img", "source.properties", "build.prop"]
                    let hasMarker = markerFiles.contains { fm.fileExists(atPath: "\(abiPath)/\($0)") }
                    guard hasMarker else { continue }

                    let fullPath = "system-images;\(apiDir);\(tagDir);\(abiDir)"
                    let apiLevel = apiDir.replacingOccurrences(of: "android-", with: "")

                    images.append(SystemImage(
                        path: fullPath,
                        apiLevel: apiLevel,
                        tag: tagDir,
                        abi: abiDir
                    ))

                    print("[Heimdall] Found system image: \(fullPath)")
                }
            }
        }

        return images.sorted {
            if $0.apiLevel != $1.apiLevel {
                return (Int($0.apiLevel) ?? 0) > (Int($1.apiLevel) ?? 0)
            }
            return $0.tag < $1.tag
        }
    }
}

// MARK: - Errors

enum AVDError: LocalizedError {
    case toolNotFound(String)
    case emulatorNotRunning(String)
    case creationFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "\(tool) not found. Check Android SDK path in settings."
        case .emulatorNotRunning(let name):
            return "Emulator '\(name)' is not running."
        case .creationFailed(let message):
            return "Failed to create AVD: \(message)"
        }
    }
}
