import Foundation

// MARK: - ADB Service

/// Wrapper around `adb` for detecting connected Android devices.
actor ADBService {
    private let runner = ShellCommandRunner()
    private let environmentService: EnvironmentService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
    }

    // MARK: - List Devices

    /// List all connected Android devices (physical only, filtering out emulators).
    func listConnectedDevices() async throws -> [AndroidDevice] {
        guard let adbPath = environmentService.adbPath else {
            throw ADBError.toolNotFound
        }

        let output = try await runner.execute(
            command: adbPath,
            arguments: ["devices", "-l"]
        )

        return parseDeviceList(output)
    }

    // MARK: - Device Properties

    /// Get a specific property from a device.
    func getDeviceProperty(serial: String, property: String) async throws -> String {
        guard let adbPath = environmentService.adbPath else {
            throw ADBError.toolNotFound
        }

        let output = try await runner.execute(
            command: adbPath,
            arguments: ["-s", serial, "shell", "getprop", property]
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the device model name.
    func getDeviceModel(serial: String) async -> String? {
        try? await getDeviceProperty(serial: serial, property: "ro.product.model")
    }

    // MARK: - Parsing

    /// Parse `adb devices -l` output into AndroidDevice structs.
    private func parseDeviceList(_ output: String) -> [AndroidDevice] {
        var devices: [AndroidDevice] = []

        print("[Heimdall] Parsing adb output:\n\(output)")

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip header and empty lines
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("List of"),
                  !trimmed.hasPrefix("*") else { continue }

            // Skip emulators — they're handled by AVDService
            guard !trimmed.hasPrefix("emulator-") else { continue }

            // Parse: "SERIAL    STATE    key:value key:value ..."
            let components = trimmed.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }

            let serial = components[0]
            let state = components[1]

            // Parse key:value pairs
            var model: String?
            var product: String?
            var transportId: String?

            for component in components.dropFirst(2) {
                let kv = component.components(separatedBy: ":")
                guard kv.count == 2 else { continue }
                switch kv[0] {
                case "model": model = kv[1]
                case "product": product = kv[1]
                case "transport_id": transportId = kv[1]
                default: break
                }
            }

            let device = AndroidDevice(
                serial: serial,
                connectionState: state,
                model: model?.replacingOccurrences(of: "_", with: " "),
                product: product,
                transportId: transportId
            )
            print("[Heimdall] Parsed device: \(device.serial) state=\(device.connectionState) model=\(device.model ?? "nil")")
            devices.append(device)
        }

        print("[Heimdall] Total physical devices found: \(devices.count)")
        return devices
    }
}

// MARK: - Errors

enum ADBError: LocalizedError {
    case toolNotFound
    case deviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound:
            return "adb not found. Check Android SDK path in settings."
        case .deviceNotFound(let serial):
            return "Device '\(serial)' not found."
        }
    }
}
