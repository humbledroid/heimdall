import SwiftUI

// MARK: - Log Viewer View

struct LogViewerView: View {
    @State var viewModel: LogViewerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Log content
            logContent

            Divider()

            // Status bar
            statusBar
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.startStreaming()
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Log Viewer")
                    .font(.headline)
                Text(viewModel.deviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Stream controls
            HStack(spacing: 4) {
                if viewModel.isStreaming {
                    Button {
                        viewModel.togglePause()
                    } label: {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(viewModel.isPaused ? "Resume" : "Pause")

                    Button {
                        viewModel.stopStreaming()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .help("Stop streaming")
                } else {
                    Button {
                        viewModel.startStreaming()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.green)
                    .help("Start streaming")
                }

                Button {
                    viewModel.clearLog()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear log")

                Button {
                    Task { await viewModel.clearDeviceLog() }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear device log buffer")

                Toggle(isOn: $viewModel.autoScroll) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Auto-scroll")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            // Tag filter
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextField("Filter tag...", text: $viewModel.filterTag)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: 150)

            // Message filter
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextField("Filter message...", text: $viewModel.filterMessage)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            // Level picker
            Picker("Level", selection: $viewModel.minimumLevel) {
                ForEach(LogLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.filteredEntries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
            }
            .onChange(of: viewModel.filteredEntries.count) {
                if viewModel.autoScroll, let last = viewModel.filteredEntries.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .font(.system(.caption2, design: .monospaced))
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Level badge
            Text(entry.level.rawValue)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(entry.level.color)
                .frame(width: 14)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(entry.level.badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Timestamp
            if !entry.timestamp.isEmpty {
                Text(entry.timestamp)
                    .foregroundStyle(.tertiary)
                    .frame(width: 110, alignment: .leading)
            }

            // Tag
            if !entry.tag.isEmpty {
                Text(entry.tag)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)
            }

            // Message
            Text(entry.message)
                .foregroundStyle(entry.level.color)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(entry.level == .error || entry.level == .fatal
            ? entry.level.badgeColor.opacity(0.3)
            : .clear)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            // Stream status
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isStreaming
                        ? (viewModel.isPaused ? .orange : .green)
                        : .red)
                    .frame(width: 6, height: 6)
                Text(viewModel.isStreaming
                    ? (viewModel.isPaused ? "Paused" : "Streaming")
                    : "Stopped")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(viewModel.filteredEntries.count) / \(viewModel.logEntries.count) entries")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Text(viewModel.serial)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
