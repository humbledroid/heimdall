import Foundation
import SwiftUI

// MARK: - Log Viewer ViewModel

@MainActor
@Observable
final class LogViewerViewModel {
    var logEntries: [LogEntry] = []
    var isStreaming: Bool = false
    var isPaused: Bool = false
    var autoScroll: Bool = true

    // Filters
    var filterTag: String = ""
    var filterMessage: String = ""
    var minimumLevel: LogLevel = .verbose

    /// Filtered log entries based on current filter settings.
    var filteredEntries: [LogEntry] {
        logEntries.filter { entry in
            // Level filter
            guard entry.level.severity >= minimumLevel.severity else { return false }

            // Tag filter
            if !filterTag.isEmpty {
                guard entry.tag.localizedCaseInsensitiveContains(filterTag) else { return false }
            }

            // Message filter
            if !filterMessage.isEmpty {
                guard entry.message.localizedCaseInsensitiveContains(filterMessage) ||
                      entry.tag.localizedCaseInsensitiveContains(filterMessage) else { return false }
            }

            return true
        }
    }

    let deviceName: String
    let serial: String

    private let logcatService: LogcatService
    private var streamTask: Task<Void, Never>?
    private let maxEntries = 5000

    init(deviceName: String, serial: String, environmentService: EnvironmentService) {
        self.deviceName = deviceName
        self.serial = serial
        self.logcatService = LogcatService(environmentService: environmentService)
    }

    // MARK: - Start Streaming

    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true
        isPaused = false

        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = await logcatService.stream(serial: serial)

            for await entry in stream {
                guard !Task.isCancelled else { break }

                if !self.isPaused {
                    self.logEntries.append(entry)

                    // Cap buffer size
                    if self.logEntries.count > self.maxEntries {
                        self.logEntries.removeFirst(self.logEntries.count - self.maxEntries)
                    }
                }
            }

            self.isStreaming = false
        }
    }

    // MARK: - Stop

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        Task { await logcatService.stop() }
        isStreaming = false
    }

    // MARK: - Pause / Resume

    func togglePause() {
        isPaused.toggle()
    }

    // MARK: - Clear

    func clearLog() {
        logEntries.removeAll()
    }

    func clearDeviceLog() async {
        do {
            try await logcatService.clearLog(serial: serial)
            logEntries.removeAll()
        } catch {
            print("[Heimdall:LogViewer] Failed to clear device log: \(error)")
        }
    }

    // MARK: - Cleanup

    deinit {
        streamTask?.cancel()
    }
}
