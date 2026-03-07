import Foundation

// MARK: - Android Emulator (AVD)

struct AndroidEmulator: Identifiable, Sendable {
    let name: String
    let path: String
    let target: String          // e.g. "Google APIs (Google Inc.) - API 34"
    let abi: String             // e.g. "x86_64", "arm64-v8a"
    var status: DeviceStatus
    let apiLevel: String?       // e.g. "34"

    var id: String { name }

    /// Display-friendly target name.
    var displayTarget: String {
        if let api = apiLevel {
            return "API \(api)"
        }
        return target
    }
}

// MARK: - System Image

/// Represents an installed Android system image that can be used to create new AVDs.
struct SystemImage: Identifiable, Hashable, Sendable {
    let path: String            // e.g. "system-images;android-34;google_apis;x86_64"
    let apiLevel: String        // e.g. "34"
    let tag: String             // e.g. "google_apis", "google_apis_playstore", "default"
    let abi: String             // e.g. "x86_64", "arm64-v8a"

    var id: String { path }

    /// Human-readable display name.
    var displayName: String {
        let tagLabel: String
        switch tag {
        case "google_apis": tagLabel = "Google APIs"
        case "google_apis_playstore": tagLabel = "Google Play"
        case "default": tagLabel = "Default"
        default: tagLabel = tag
        }
        return "Android \(apiLevel) (\(tagLabel)) - \(abi)"
    }
}

// MARK: - Emulator Configuration

/// Advanced configuration options for creating an Android emulator.
struct EmulatorConfig: Sendable {
    var ramMB: Int = 2048             // RAM in megabytes
    var storageMB: Int = 8192         // Internal storage in megabytes
    var gpuMode: GPUMode = .auto

    enum GPUMode: String, CaseIterable, Sendable {
        case auto = "auto"
        case host = "host"              // Hardware (host GPU)
        case swiftshaderIndirect = "swiftshader_indirect"  // Software (SwiftShader)
        case angleIndirect = "angle_indirect"              // ANGLE

        var displayName: String {
            switch self {
            case .auto: return "Default (Auto)"
            case .host: return "Hardware (Host GPU)"
            case .swiftshaderIndirect: return "Software (SwiftShader)"
            case .angleIndirect: return "ANGLE (Indirect)"
            }
        }
    }
}

// MARK: - Device Profile

/// Predefined device hardware profiles for creating emulators.
struct DeviceProfile: Identifiable, Hashable, Sendable {
    let id: String              // e.g. "pixel_7"
    let name: String            // e.g. "Pixel 7"
    let manufacturer: String    // e.g. "Google"

    /// Common profiles bundled with Android SDK.
    static let commonProfiles: [DeviceProfile] = [
        DeviceProfile(id: "pixel_7", name: "Pixel 7", manufacturer: "Google"),
        DeviceProfile(id: "pixel_7_pro", name: "Pixel 7 Pro", manufacturer: "Google"),
        DeviceProfile(id: "pixel_6", name: "Pixel 6", manufacturer: "Google"),
        DeviceProfile(id: "pixel_6_pro", name: "Pixel 6 Pro", manufacturer: "Google"),
        DeviceProfile(id: "pixel_5", name: "Pixel 5", manufacturer: "Google"),
        DeviceProfile(id: "pixel_4", name: "Pixel 4", manufacturer: "Google"),
        DeviceProfile(id: "Nexus 5X", name: "Nexus 5X", manufacturer: "LG"),
        DeviceProfile(id: "Nexus 6P", name: "Nexus 6P", manufacturer: "Huawei"),
    ]
}
