import SwiftUI

// MARK: - Action Button Group

/// Contextual action buttons for a simulator/emulator row.
/// Shows play/stop based on state, plus an overflow menu for destructive actions.
struct ActionButtonGroup: View {
    let status: DeviceStatus
    let onBoot: () -> Void
    let onShutdown: () -> Void
    var onErase: (() -> Void)?
    var onDelete: (() -> Void)?
    var onOpenLink: (() -> Void)?
    var onInstallApp: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            // Primary action: Boot or Shutdown
            if status == .shutdown {
                Button {
                    onBoot()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.green)
                .help("Start")
            } else if status == .booted {
                Button {
                    onShutdown()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .help("Stop")
            } else {
                // Transitioning — show spinner
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            }

            // Overflow menu for additional actions
            Menu {
                // Actions available when running
                if status == .booted {
                    if let onOpenLink {
                        Button {
                            onOpenLink()
                        } label: {
                            Label("Open Link…", systemImage: "link")
                        }
                    }

                    if let onInstallApp {
                        Button {
                            onInstallApp()
                        } label: {
                            Label("Install App…", systemImage: "square.and.arrow.down")
                        }
                    }

                    if onOpenLink != nil || onInstallApp != nil {
                        Divider()
                    }
                }

                if let onErase {
                    Button {
                        onErase()
                    } label: {
                        Label("Erase Contents", systemImage: "arrow.counterclockwise")
                    }
                }

                if onErase != nil && onDelete != nil {
                    Divider()
                }

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
    }
}
