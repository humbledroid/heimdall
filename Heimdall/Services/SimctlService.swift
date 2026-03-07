import Foundation

// MARK: - Simctl Service

/// Wrapper around `simctl` for managing iOS simulators.
/// Runs simctl directly (no shell) with the correct DEVELOPER_DIR environment,
/// which is required for GUI apps that don't inherit Terminal's shell profile.
actor SimctlService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService?

    /// Resolved path to the simctl binary.
    /// We find this once and cache it to avoid repeated lookups.
    private var resolvedSimctlPath: String?

    init(environmentService: EnvironmentService? = nil) {
        self.environmentService = environmentService
    }

    // MARK: - Simctl Path Resolution

    /// Find the actual simctl binary. We look in the Xcode developer dir directly
    /// to avoid relying on xcrun (which has environment issues in GUI apps).
    private func simctlPath() async throws -> String {
        if let cached = resolvedSimctlPath {
            return cached
        }

        // Strategy 1: Look directly inside the Xcode developer directory
        if let devDir = environmentService?.developerDir {
            let directPath = "\(devDir)/usr/bin/simctl"
            if FileManager.default.isExecutableFile(atPath: directPath) {
                print("[Heimdall:Simctl] Found simctl at: \(directPath)")
                resolvedSimctlPath = directPath
                return directPath
            }
        }

        // Strategy 2: Common Xcode locations
        let commonPaths = [
            "/Applications/Xcode.app/Contents/Developer/usr/bin/simctl",
            "/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl",
        ]
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                print("[Heimdall:Simctl] Found simctl at: \(path)")
                resolvedSimctlPath = path
                return path
            }
        }

        // Strategy 3: Use xcrun to find it (direct process, no shell)
        do {
            var env: [String: String] = [:]
            if let devDir = environmentService?.developerDir {
                env["DEVELOPER_DIR"] = devDir
            }
            let output = try await runner.execute(
                command: "/usr/bin/xcrun",
                arguments: ["--find", "simctl"],
                environment: env.isEmpty ? nil : env,
                timeout: 15
            )
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                print("[Heimdall:Simctl] Found simctl via xcrun: \(path)")
                resolvedSimctlPath = path
                return path
            }
        } catch {
            print("[Heimdall:Simctl] xcrun --find simctl failed: \(error)")
        }

        throw SimctlError.simctlNotFound
    }

    /// Build environment dict needed for simctl to work properly.
    private func simctlEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let devDir = environmentService?.developerDir {
            env["DEVELOPER_DIR"] = devDir
        }
        // simctl needs access to the CoreSimulator framework
        if let devDir = environmentService?.developerDir {
            let frameworkPath = "\(devDir)/../Frameworks"
            env["DYLD_FRAMEWORK_PATH"] = frameworkPath
        }
        return env
    }

    /// Run a simctl command directly (no shell involved).
    private func runSimctl(_ arguments: [String], timeout: TimeInterval = 120) async throws -> String {
        let path = try await simctlPath()
        let env = simctlEnvironment()

        print("[Heimdall:Simctl] Running: \(path) \(arguments.joined(separator: " "))")

        return try await runner.execute(
            command: path,
            arguments: arguments,
            environment: env.isEmpty ? nil : env,
            timeout: timeout
        )
    }

    // MARK: - List Simulators

    func listSimulators() async throws -> [iOSSimulator] {
        let output = try await runSimctl(["list", "devices", "--json"])

        guard let data = output.data(using: .utf8) else {
            throw ShellCommandRunner.CommandError.outputDecodingFailed
        }

        print("[Heimdall:Simctl] Received \(data.count) bytes of device JSON")

        let response = try JSONDecoder().decode(SimctlListResponse.self, from: data)
        var simulators: [iOSSimulator] = []

        for (runtimeId, devices) in response.devices {
            let runtimeName = runtimeDisplayName(from: runtimeId)

            for device in devices {
                let simulator = iOSSimulator(
                    udid: device.udid,
                    name: device.name,
                    runtime: runtimeName,
                    runtimeIdentifier: runtimeId,
                    status: DeviceStatus(fromString: device.state),
                    deviceTypeIdentifier: device.deviceTypeIdentifier ?? "",
                    isAvailable: device.isAvailable
                )
                simulators.append(simulator)
            }
        }

        let available = simulators.filter { $0.isAvailable }
        print("[Heimdall:Simctl] Parsed \(simulators.count) total, \(available.count) available simulators")

        return available.sorted { lhs, rhs in
            if lhs.status == .booted && rhs.status != .booted { return true }
            if lhs.status != .booted && rhs.status == .booted { return false }
            return lhs.name < rhs.name
        }
    }

    // MARK: - List Runtimes

    func listRuntimes() async throws -> [iOSRuntime] {
        let output = try await runSimctl(["list", "runtimes", "--json"])

        guard let data = output.data(using: .utf8) else {
            throw ShellCommandRunner.CommandError.outputDecodingFailed
        }

        let response = try JSONDecoder().decode(SimctlRuntimesResponse.self, from: data)

        return response.runtimes
            .filter { $0.isAvailable }
            .map { runtime in
                iOSRuntime(
                    identifier: runtime.identifier,
                    name: runtime.name,
                    version: runtime.version,
                    isAvailable: runtime.isAvailable
                )
            }
            .sorted { $0.version > $1.version }
    }

    // MARK: - List Device Types

    func listDeviceTypes() async throws -> [iOSDeviceType] {
        let output = try await runSimctl(["list", "devicetypes", "--json"])

        guard let data = output.data(using: .utf8) else {
            throw ShellCommandRunner.CommandError.outputDecodingFailed
        }

        let response = try JSONDecoder().decode(SimctlDeviceTypesResponse.self, from: data)

        return response.devicetypes.map { dt in
            iOSDeviceType(
                identifier: dt.identifier,
                name: dt.name,
                productFamily: dt.productFamily ?? "Unknown"
            )
        }
    }

    // MARK: - Actions

    func bootSimulator(udid: String) async throws {
        _ = try await runSimctl(["boot", udid])
    }

    func shutdownSimulator(udid: String) async throws {
        _ = try await runSimctl(["shutdown", udid])
    }

    func eraseSimulator(udid: String) async throws {
        _ = try await runSimctl(["erase", udid])
    }

    func deleteSimulator(udid: String) async throws {
        _ = try await runSimctl(["delete", udid])
    }

    // MARK: - Create

    func createSimulator(
        name: String,
        deviceTypeIdentifier: String,
        runtimeIdentifier: String
    ) async throws -> String {
        let output = try await runSimctl([
            "create", name, deviceTypeIdentifier, runtimeIdentifier
        ])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func runtimeDisplayName(from identifier: String) -> String {
        let parts = identifier.components(separatedBy: ".")
        guard let last = parts.last else { return identifier }

        let components = last.components(separatedBy: "-")
        guard components.count >= 2 else { return last }

        let platform = components[0]
        let version = components.dropFirst().joined(separator: ".")
        return "\(platform) \(version)"
    }
}

// MARK: - Simctl Errors

enum SimctlError: LocalizedError {
    case simctlNotFound

    var errorDescription: String? {
        switch self {
        case .simctlNotFound:
            return "simctl not found. Ensure Xcode is installed and xcode-select is configured."
        }
    }
}
