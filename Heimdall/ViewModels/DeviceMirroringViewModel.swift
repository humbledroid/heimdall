import Foundation
import SwiftUI

// MARK: - Device Mirroring ViewModel

@MainActor
@Observable
final class DeviceMirroringViewModel {
    var devices: [AndroidDevice] = []
    var activeSessions: [MirroringSession] = []

    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
    var isAvailable: Bool = false
    var alwaysOnTop: Bool {
        get { UserDefaults.standard.object(forKey: "scrcpyAlwaysOnTop") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "scrcpyAlwaysOnTop") }
    }

    private let adbService: ADBService
    private let scrcpyService: ScrcpyService
    private let environmentService: EnvironmentService
    private let usbMonitor: USBDeviceMonitor
    let deepLinkService: DeepLinkService
    let appInstallerService: AppInstallerService
    let wirelessADBService: WirelessADBService
    private var monitorTask: Task<Void, Never>?

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.adbService = ADBService(environmentService: environmentService)
        self.scrcpyService = ScrcpyService(environmentService: environmentService)
        self.usbMonitor = USBDeviceMonitor(environmentService: environmentService)
        self.deepLinkService = DeepLinkService(environmentService: environmentService)
        self.appInstallerService = AppInstallerService(environmentService: environmentService)
        self.wirelessADBService = WirelessADBService(environmentService: environmentService)
    }

    // MARK: - Load

    func loadDevices() async {
        isLoading = true
        errorMessage = nil

        guard environmentService.adbPath != nil else {
            isAvailable = false
            isLoading = false
            errorMessage = "adb not found. Configure Android SDK in Settings."
            print("[Heimdall] adb not found for device detection")
            return
        }

        isAvailable = true

        do {
            let deviceList = try await adbService.listConnectedDevices()
            print("[Heimdall] Found \(deviceList.count) connected device(s)")

            // Enrich with model names for devices that don't have them
            var enriched: [AndroidDevice] = []
            for device in deviceList {
                if device.model == nil, device.isOnline {
                    let model = await adbService.getDeviceModel(serial: device.serial)
                    enriched.append(AndroidDevice(
                        serial: device.serial,
                        connectionState: device.connectionState,
                        model: model,
                        product: device.product,
                        transportId: device.transportId
                    ))
                } else {
                    enriched.append(device)
                }
            }
            devices = enriched

            activeSessions = await scrcpyService.activeSessions()
        } catch {
            errorMessage = error.localizedDescription
            print("[Heimdall] Error loading devices: \(error)")
        }

        isLoading = false
    }

    /// Manual refresh triggered by user or by USB event.
    func refresh() async {
        guard environmentService.adbPath != nil else { return }

        isRefreshing = true
        do {
            let deviceList = try await adbService.listConnectedDevices()

            var enriched: [AndroidDevice] = []
            for device in deviceList {
                // Re-use existing model name if we already have it
                if let existing = devices.first(where: { $0.serial == device.serial }),
                   existing.model != nil {
                    enriched.append(AndroidDevice(
                        serial: device.serial,
                        connectionState: device.connectionState,
                        model: existing.model,
                        product: device.product ?? existing.product,
                        transportId: device.transportId ?? existing.transportId
                    ))
                } else if device.model == nil, device.isOnline {
                    let model = await adbService.getDeviceModel(serial: device.serial)
                    enriched.append(AndroidDevice(
                        serial: device.serial,
                        connectionState: device.connectionState,
                        model: model,
                        product: device.product,
                        transportId: device.transportId
                    ))
                } else {
                    enriched.append(device)
                }
            }

            devices = enriched
            activeSessions = await scrcpyService.activeSessions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    // MARK: - Mirroring Actions

    func startMirroring(_ device: AndroidDevice) async {
        guard environmentService.hasScrcpy else {
            errorMessage = "scrcpy not found. Install via: brew install scrcpy"
            return
        }

        do {
            let session = try await scrcpyService.startMirroring(
                deviceSerial: device.serial,
                windowTitle: "Heimdall - \(device.displayName)",
                alwaysOnTop: alwaysOnTop
            )
            activeSessions.append(session)
        } catch {
            errorMessage = "Failed to mirror \(device.displayName): \(error.localizedDescription)"
        }
    }

    func stopMirroring(_ device: AndroidDevice) async {
        await scrcpyService.stopMirroring(deviceSerial: device.serial)
        activeSessions = await scrcpyService.activeSessions()
    }

    /// Check if a specific device is being mirrored.
    func isMirroring(_ device: AndroidDevice) async -> Bool {
        await scrcpyService.isMirroring(deviceSerial: device.serial)
    }

    // MARK: - Wireless ADB Pairing

    /// Pair and connect to a device wirelessly.
    func pairAndConnect(ip: String, pairingPort: String, code: String, connectPort: String) async {
        do {
            _ = try await wirelessADBService.pair(ip: ip, port: pairingPort, code: code)

            // If a connection port was provided, connect after pairing
            if !connectPort.isEmpty {
                _ = try await wirelessADBService.connect(ip: ip, port: connectPort)
            }

            // Refresh to pick up the newly connected device
            await refresh()
        } catch {
            errorMessage = "Wireless pairing failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Install App

    func installApp(on device: AndroidDevice, apkPath: String) async {
        do {
            try await appInstallerService.installOnAndroid(serial: device.serial, apkPath: apkPath)
        } catch {
            errorMessage = "Failed to install app: \(error.localizedDescription)"
        }
    }

    // MARK: - Deep Links

    func openDeepLink(on device: AndroidDevice, url: String) async {
        do {
            try await deepLinkService.openOnAndroid(serial: device.serial, url: url)
            deepLinkService.saveToHistory(url)
        } catch {
            errorMessage = "Failed to open link: \(error.localizedDescription)"
        }
    }

    // MARK: - USB Monitoring (Event-Driven)

    /// Start real-time USB monitoring via `adb track-devices`.
    /// This is event-driven — refreshes only happen when a device is
    /// actually connected or disconnected.
    func startMonitoring() {
        monitorTask?.cancel()

        guard environmentService.adbPath != nil else {
            print("[Heimdall:USB] adb not found, cannot monitor devices")
            return
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }

            print("[Heimdall:USB] Starting event-driven device monitoring")
            let events = self.usbMonitor.startMonitoring()

            for await event in events {
                guard !Task.isCancelled else { break }
                switch event {
                case .changed:
                    print("[Heimdall:USB] Device change event — refreshing")
                    await self.refresh()
                }
            }

            if !Task.isCancelled {
                print("[Heimdall:USB] Monitor stream ended unexpectedly")
            }
        }
    }

    /// Stop USB monitoring.
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        usbMonitor.stopMonitoring()
    }
}
