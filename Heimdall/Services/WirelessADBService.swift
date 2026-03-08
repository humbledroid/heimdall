import Foundation

// MARK: - Wireless ADB Service

/// Handles wireless ADB pairing and connection.
actor WirelessADBService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - Pair

    /// Pair with a device using wireless debugging.
    /// The device must have "Pair device with pairing code" active in Developer Options → Wireless Debugging.
    func pair(ip: String, port: String, code: String) async throws -> String {
        guard let adbPath = environmentService.adbPath else {
            throw WirelessADBError.toolNotFound("adb")
        }

        let address = "\(ip):\(port)"
        print("[Heimdall:WirelessADB] Pairing with \(address)")

        // adb pair requires the pairing code as the third argument
        let output = try await runner.execute(
            command: adbPath,
            arguments: ["pair", address, code],
            timeout: 30
        )

        print("[Heimdall:WirelessADB] Pair result: \(output)")

        if output.lowercased().contains("failed") || output.lowercased().contains("error") {
            throw WirelessADBError.pairingFailed(output)
        }

        return output
    }

    // MARK: - Connect

    /// Connect to a wirelessly paired device.
    /// Use the connection port (different from pairing port) shown under Wireless Debugging.
    func connect(ip: String, port: String) async throws -> String {
        guard let adbPath = environmentService.adbPath else {
            throw WirelessADBError.toolNotFound("adb")
        }

        let address = "\(ip):\(port)"
        print("[Heimdall:WirelessADB] Connecting to \(address)")

        let output = try await runner.execute(
            command: adbPath,
            arguments: ["connect", address],
            timeout: 15
        )

        print("[Heimdall:WirelessADB] Connect result: \(output)")

        if output.lowercased().contains("failed") || output.lowercased().contains("cannot") {
            throw WirelessADBError.connectionFailed(output)
        }

        return output
    }

    // MARK: - Disconnect

    /// Disconnect a wirelessly connected device.
    func disconnect(ip: String, port: String) async throws {
        guard let adbPath = environmentService.adbPath else {
            throw WirelessADBError.toolNotFound("adb")
        }

        let address = "\(ip):\(port)"
        _ = try await runner.execute(
            command: adbPath,
            arguments: ["disconnect", address],
            timeout: 10
        )
    }
}

// MARK: - Errors

enum WirelessADBError: LocalizedError {
    case toolNotFound(String)
    case pairingFailed(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "\(tool) not found. Check Android SDK path in settings."
        case .pairingFailed(let message):
            return "Pairing failed: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
