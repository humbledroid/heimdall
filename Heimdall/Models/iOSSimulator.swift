import Foundation

// MARK: - iOS Simulator

struct iOSSimulator: Identifiable, Sendable {
    let udid: String
    let name: String
    let runtime: String          // e.g. "iOS 17.2"
    let runtimeIdentifier: String // e.g. "com.apple.CoreSimulator.SimRuntime.iOS-17-2"
    var status: DeviceStatus
    let deviceTypeIdentifier: String
    let isAvailable: Bool

    var id: String { udid }
}

// MARK: - iOS Runtime

struct iOSRuntime: Identifiable, Hashable, Sendable {
    let identifier: String       // e.g. "com.apple.CoreSimulator.SimRuntime.iOS-17-2"
    let name: String             // e.g. "iOS 17.2"
    let version: String          // e.g. "17.2"
    let isAvailable: Bool

    var id: String { identifier }
}

// MARK: - Device Type

struct iOSDeviceType: Identifiable, Hashable, Sendable {
    let identifier: String       // e.g. "com.apple.CoreSimulator.SimDeviceType.iPhone-15"
    let name: String             // e.g. "iPhone 15"
    let productFamily: String    // e.g. "iPhone", "iPad"

    var id: String { identifier }
}

// MARK: - Simctl JSON Response Models (for Codable parsing)

/// Root response from `xcrun simctl list --json`
struct SimctlListResponse: Codable {
    let devices: [String: [SimctlDevice]]
    let runtimes: [SimctlRuntime]?
    let devicetypes: [SimctlDeviceType]?
}

struct SimctlDevice: Codable {
    let state: String
    let isAvailable: Bool
    let name: String
    let udid: String
    let deviceTypeIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case state, isAvailable, name, udid
        case deviceTypeIdentifier = "deviceTypeIdentifier"
    }
}

struct SimctlRuntime: Codable {
    let identifier: String
    let name: String
    let version: String
    let isAvailable: Bool
}

struct SimctlDeviceType: Codable {
    let identifier: String
    let name: String
    let productFamily: String?
}

// MARK: - Runtime-only response

struct SimctlRuntimesResponse: Codable {
    let runtimes: [SimctlRuntime]
}

// MARK: - Device-types-only response

struct SimctlDeviceTypesResponse: Codable {
    let devicetypes: [SimctlDeviceType]
}
