import Foundation

// MARK: - Connected Android Device

/// Represents a physical Android device connected via USB or WiFi (detected via adb).
struct AndroidDevice: Identifiable, Sendable {
    let serial: String          // e.g. "ABC123DEF456" or "192.168.1.5:5555"
    let connectionState: String // e.g. "device", "offline", "unauthorized"
    let model: String?          // e.g. "Pixel 7", from device properties
    let product: String?        // e.g. "panther"
    let transportId: String?

    var id: String { serial }

    /// Whether the device is ready for mirroring.
    var isOnline: Bool {
        connectionState == "device"
    }

    /// Display name: model if available, otherwise serial.
    var displayName: String {
        model ?? serial
    }

    /// Status description for the device.
    var statusDescription: String {
        switch connectionState {
        case "device": return "Connected"
        case "offline": return "Offline"
        case "unauthorized": return "Unauthorized"
        case "no permissions": return "No Permissions"
        default: return connectionState.capitalized
        }
    }
}

// MARK: - Mirroring Session

/// Tracks an active scrcpy mirroring session for a device.
struct MirroringSession: Identifiable, Sendable {
    let id: UUID
    let deviceSerial: String
    let processIdentifier: Int32
    let startedAt: Date

    /// How long the session has been running.
    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    /// Formatted duration string.
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
