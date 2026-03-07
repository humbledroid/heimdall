import SwiftUI

/// Unified device status used across iOS simulators, Android emulators, and connected devices.
enum DeviceStatus: String, Codable, Sendable {
    case shutdown = "Shutdown"
    case booting = "Booting"
    case booted = "Booted"
    case shuttingDown = "Shutting Down"
    case unknown = "Unknown"

    /// Human-readable label for display.
    var label: String {
        switch self {
        case .shutdown: return "Offline"
        case .booting: return "Starting"
        case .booted: return "Running"
        case .shuttingDown: return "Stopping"
        case .unknown: return "Unknown"
        }
    }

    /// Status indicator color.
    var color: Color {
        switch self {
        case .booted: return .green
        case .booting: return .orange
        case .shuttingDown: return .orange
        case .shutdown: return .gray
        case .unknown: return .gray
        }
    }

    /// Whether the device is in a transitional state.
    var isTransitioning: Bool {
        self == .booting || self == .shuttingDown
    }

    /// Initializer that normalizes various status strings from CLI tools.
    init(fromString string: String) {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "shutdown": self = .shutdown
        case "booted", "running", "online", "device": self = .booted
        case "booting", "starting": self = .booting
        case "shutting down", "stopping": self = .shuttingDown
        default: self = .unknown
        }
    }
}
