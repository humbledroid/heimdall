import Foundation
import SwiftUI

// MARK: - Android Emulators ViewModel

@MainActor
@Observable
final class AndroidEmulatorsViewModel {
    var emulators: [AndroidEmulator] = []
    var systemImages: [SystemImage] = []

    var isLoading: Bool = false
    var errorMessage: String?
    var isAvailable: Bool = false

    /// Count of running emulators.
    var runningCount: Int {
        emulators.filter { $0.status == .booted }.count
    }

    private let avdService: AVDService
    private let environmentService: EnvironmentService
    private var pollTask: Task<Void, Never>?

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.avdService = AVDService(environmentService: environmentService)
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

    func refresh() async {
        guard environmentService.hasAndroidSDK else { return }

        do {
            emulators = try await avdService.listAVDs()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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

    // MARK: - Polling

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
