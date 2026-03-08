import SwiftUI

// MARK: - Device Row

struct DeviceRowView: View {
    let device: AndroidDevice
    let viewModel: DeviceMirroringViewModel
    let hasScrcpy: Bool
    var onOpenLink: ((AndroidDevice) -> Void)?
    var onInstallApp: ((AndroidDevice) -> Void)?
    var onOpenLogs: ((AndroidDevice) -> Void)?

    @State private var isMirroring = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Device icon
            Image(systemName: "smartphone")
                .font(.title3)
                .foregroundStyle(device.isOnline ? .primary : .tertiary)
                .frame(width: 24)

            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(device.serial)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Text(device.statusDescription)
                        .font(.caption2)
                        .foregroundStyle(device.isOnline ? .green : .orange)
                }
            }

            Spacer()

            // Actions for online devices
            if device.isOnline {
                // Install app button
                if let onInstallApp {
                    Button {
                        onInstallApp(device)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Install App")
                }

                // Deep link button
                if let onOpenLink {
                    Button {
                        onOpenLink(device)
                    } label: {
                        Image(systemName: "link")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open Deep Link")
                }

                // Logs button
                if let onOpenLogs {
                    Button {
                        onOpenLogs(device)
                    } label: {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("View Logs")
                }

                // Mirror button
                if hasScrcpy {
                    if isMirroring {
                        Button {
                            Task {
                                await viewModel.stopMirroring(device)
                                isMirroring = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text("Stop")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    } else {
                        Button {
                            Task {
                                await viewModel.startMirroring(device)
                                isMirroring = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.on.rectangle")
                                    .font(.caption2)
                                Text("Mirror")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.blue)
                    }
                }
            } else if device.connectionState == "unauthorized" {
                Text("Authorize on device")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            isMirroring = await viewModel.isMirroring(device)
        }
    }
}
