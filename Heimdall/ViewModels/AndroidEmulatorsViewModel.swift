import Foundation
import SwiftUI

// MARK: - Android Emulators ViewModel

@MainActor
@Observable
final class AndroidEmulatorsViewModel {
    var emulators: [AndroidEmulator] = []
    var systemImages: [SystemImage] = []

    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
    var isAvailable: Bool = false

    /// Count of running emulators.
    var runningCount: Int {
        emulators.filter { $0.status == .booted }.count
    }

    private let avdService: AVDService
    private let environmentService: EnvironmentService
    let deepLinkService: DeepLinkService

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.avdService = AVDService(environmentService: environmentService)
        self.deepLinkService = DeepLinkService(environmentService: environmentService)
    }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        guard environmentService.hasAndroidSDK else {
            isAvailable = false
            isLoading = false
            errorMessage = "Android SDK not found. Configure it in Settings."
            print("[Heimdall] Android SDK not found")
            return
        }

        isAvailable = true

        do {
            let emus = try await avdService.listAVDs()
            emulators = emus
            print("[Heimdall] Loaded \(emus.count) emulators")
        } catch {
            print("[Heimdall] Error loading emulators: \(error)")
            errorMessage = error.localizedDescription
        }

        do {
            let imgs = try await avdService.listSystemImages()
            systemImages = imgs
            print("[Heimdall] Loaded \(imgs.count) system images")
        } catch {
            print("[Heimdall] Error loading system images: \(error)")
            if errorMessage == nil {
                errorMessage = "Failed to load system images: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    /// Manual refresh triggered by user.
    func refresh() async {
        guard environmentService.hasAndroidSDK else { return }

        isRefreshing = true
        do {
            emulators = try await avdService.listAVDs()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    // MARK: - Actions

    func start(_ emulator: AndroidEmulator) async {
        do {
            try await avdService.startEmulator(name: emulator.name)
            try? await Task.sleep(for: .seconds(2))
            await refresh()
        } catch {
            errorMessage = "Failed to start \(emulator.name): \(error.localizedDescription)"
        }
    }

    func stop(_ emulator: AndroidEmulator) async {
        do {
            try await avdService.stopEmulator(name: emulator.name)
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        } catch {
            errorMessage = "Failed to stop \(emulator.name): \(error.localizedDescription)"
        }
    }

    func delete(_ emulator: AndroidEmulator) async {
        do {
            if emulator.status == .booted {
                try await avdService.stopEmulator(name: emulator.name)
                try? await Task.sleep(for: .seconds(2))
            }
            try await avdService.deleteAVD(name: emulator.name)
            await refresh()
        } catch {
            errorMessage = "Failed to delete \(emulator.name): \(error.localizedDescription)"
        }
    }

    /// Open a deep link on a running emulator.
    /// Resolves the emulator's adb serial (emulator-XXXX) first.
    func openDeepLink(on emulator: AndroidEmulator, url: String) async {
        guard emulator.status == .booted else {
            errorMessage = "Emulator must be running to open links."
            return
        }

        do {
            // Find the emulator's adb serial
            let serial = try await avdService.serialForEmulator(name: emulator.name)
            try await deepLinkService.openOnAndroid(serial: serial, url: url)
            deepLinkService.saveToHistory(url)
        } catch {
            errorMessage = "Failed to open link: \(error.localizedDescription)"
        }
    }

    func create(
        name: String,
        systemImagePath: String,
        deviceProfile: String?,
        config: EmulatorConfig = EmulatorConfig()
    ) async {
        do {
            try await avdService.createAVD(
                name: name,
                systemImagePath: systemImagePath,
                deviceProfile: deviceProfile,
                config: config
            )
            await loadAll()
        } catch {
            errorMessage = "Failed to create emulator: \(error.localizedDescription)"
        }
    }
}
