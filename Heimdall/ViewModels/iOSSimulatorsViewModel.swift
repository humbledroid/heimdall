import Foundation
import SwiftUI

// MARK: - iOS Simulators ViewModel

@MainActor
@Observable
final class iOSSimulatorsViewModel {
    var simulators: [iOSSimulator] = []
    var runtimes: [iOSRuntime] = []
    var deviceTypes: [iOSDeviceType] = []

    var isLoading: Bool = false
    var errorMessage: String?

    /// Simulators grouped by runtime for the list display.
    var groupedSimulators: [(runtime: String, simulators: [iOSSimulator])] {
        let grouped = Dictionary(grouping: simulators) { $0.runtime }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (runtime: $0.key, simulators: $0.value) }
    }

    /// Count of running simulators.
    var runningCount: Int {
        simulators.filter { $0.status == .booted }.count
    }

    private let service: SimctlService
    private let openService: OpenService
    private var pollTask: Task<Void, Never>?

    init(environmentService: EnvironmentService? = nil) {
        self.service = SimctlService(environmentService: environmentService)
        self.openService = OpenService()
    }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            // Run sequentially to avoid actor reentrancy issues
            let sims = try await service.listSimulators()
            let rts = try await service.listRuntimes()
            let dts = try await service.listDeviceTypes()

            simulators = sims
            runtimes = rts
            deviceTypes = dts

            print("[Heimdall] Loaded \(sims.count) simulators, \(rts.count) runtimes, \(dts.count) device types")
        } catch {
            errorMessage = error.localizedDescription
            print("[Heimdall] Error loading simulators: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        do {
            simulators = try await service.listSimulators()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("[Heimdall] Error refreshing simulators: \(error)")
        }
    }

    // MARK: - Actions

    func boot(_ simulator: iOSSimulator) async {
        do {
            try await service.bootSimulator(udid: simulator.udid)
            try await openService.openSimulator(udid: simulator.udid)
            await refresh()
        } catch {
            errorMessage = "Failed to boot \(simulator.name): \(error.localizedDescription)"
        }
    }

    func shutdown(_ simulator: iOSSimulator) async {
        do {
            try await service.shutdownSimulator(udid: simulator.udid)
            await refresh()
        } catch {
            errorMessage = "Failed to shutdown \(simulator.name): \(error.localizedDescription)"
        }
    }

    func erase(_ simulator: iOSSimulator) async {
        do {
            if simulator.status == .booted {
                try await service.shutdownSimulator(udid: simulator.udid)
                try await Task.sleep(for: .seconds(1))
            }
            try await service.eraseSimulator(udid: simulator.udid)
            await refresh()
        } catch {
            errorMessage = "Failed to erase \(simulator.name): \(error.localizedDescription)"
        }
    }

    func delete(_ simulator: iOSSimulator) async {
        do {
            if simulator.status == .booted {
                try await service.shutdownSimulator(udid: simulator.udid)
                try await Task.sleep(for: .seconds(1))
            }
            try await service.deleteSimulator(udid: simulator.udid)
            await refresh()
        } catch {
            errorMessage = "Failed to delete \(simulator.name): \(error.localizedDescription)"
        }
    }

    func create(name: String, deviceTypeId: String, runtimeId: String) async {
        do {
            _ = try await service.createSimulator(
                name: name,
                deviceTypeIdentifier: deviceTypeId,
                runtimeIdentifier: runtimeId
            )
            await loadAll()
        } catch {
            errorMessage = "Failed to create simulator: \(error.localizedDescription)"
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
