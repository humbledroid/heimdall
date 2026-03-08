import Foundation
import SwiftUI

// MARK: - Log Level

enum LogLevel: String, CaseIterable, Identifiable {
    case verbose = "V"
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"
    case fatal = "F"
    case silent = "S"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verbose: return "Verbose"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .fatal: return "Fatal"
        case .silent: return "Silent"
        }
    }

    var color: Color {
        switch self {
        case .verbose: return .secondary
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .fatal: return .red
        case .silent: return .gray
        }
    }

    var badgeColor: Color {
        switch self {
        case .verbose: return .gray.opacity(0.3)
        case .debug: return .blue.opacity(0.2)
        case .info: return .green.opacity(0.2)
        case .warning: return .orange.opacity(0.2)
        case .error: return .red.opacity(0.2)
        case .fatal: return .red.opacity(0.4)
        case .silent: return .gray.opacity(0.2)
        }
    }

    /// Severity order for filtering (higher = more severe).
    var severity: Int {
        switch self {
        case .verbose: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .fatal: return 5
        case .silent: return 6
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let pid: String
    let tid: String
    let level: LogLevel
    let tag: String
    let message: String

    /// Parse a threadtime-format logcat line.
    /// Format: `MM-DD HH:MM:SS.mmm  PID  TID LEVEL TAG     : MESSAGE`
    static func parse(line: String) -> LogEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // threadtime format: "03-08 14:23:45.123  1234  5678 D MyTag   : some message"
        // Regex approach for reliability
        let pattern = #"^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s+(\d+)\s+(\d+)\s+([VDIWEFS])\s+(.+?)\s*:\s(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              match.numberOfRanges >= 7 else {
            // Fallback: treat as unstructured log line
            return LogEntry(
                timestamp: "",
                pid: "",
                tid: "",
                level: .info,
                tag: "",
                message: trimmed
            )
        }

        func extractGroup(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: trimmed) else { return "" }
            return String(trimmed[range])
        }

        let timestamp = extractGroup(1)
        let pid = extractGroup(2)
        let tid = extractGroup(3)
        let levelStr = extractGroup(4)
        let tag = extractGroup(5).trimmingCharacters(in: .whitespaces)
        let message = extractGroup(6)

        let level = LogLevel(rawValue: levelStr) ?? .info

        return LogEntry(
            timestamp: timestamp,
            pid: pid,
            tid: tid,
            level: level,
            tag: tag,
            message: message
        )
    }
}
