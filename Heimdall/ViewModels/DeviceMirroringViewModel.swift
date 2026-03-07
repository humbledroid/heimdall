import Foundation
import SwiftUI

// MARK: - Device Mirroring ViewModel

@MainActor
@Observable
final class DeviceMirroringViewModel {
    var devices: [AndroidDevice] = []
    var activeSessions: [MirroringSession] = []

    var isLoading: Bool = false
    var errorMessage: String?
    var isAvailable: Bool = false

    private let adbService: ADBService
    private let scrcpyService: ScrcpyService
    private let environmentService: EnvironmentService
    private let usbMonitor: USBDeviceMonitor
    private var monitorTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.adbService = ADBService(environmentService: environmentService)
        self.scrcpyService = ScrcpyService(environmentService: environmentService)
        self.usbMonitor = USBDeviceMonitor(environmentService: environmentService)
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

    func refresh() async {
        guard environmentService.adbPath != nil else { return }

        do {
            let deviceList = try await adbService.listConnectedDevices()

            // Enrich new devices with model names
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
                windowTitle: "Heimdall - \(device.displayName)"
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

    // MARK: - USB Monitoring

    /// Start real-time USB monitoring via `adb track-devices`.
    /// Falls back to polling if the monitor cannot be started.
    func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }

            let events = self.usbMonitor.startMonitoring()

            for await event in events {
                guard !Task.isCancelled else { break }
                switch event {
                case .changed:
                    print("[Heimdall:USB] Device change event — refreshing")
                    await self.refresh()
                }
            }

            // If the monitor stream ends (adb died, etc.), fall back to polling
            if !Task.isCancelled {
                print("[Heimdall:USB] Monitor stream ended, falling back to polling")
                self.startPolling()
            }
        }
    }

    /// Stop USB monitoring.
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        pollTask?.cancel()
        pollTask = nil
        usbMonitor.stopMonitoring()
    }

    // MARK: - Polling (Fallback)

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
