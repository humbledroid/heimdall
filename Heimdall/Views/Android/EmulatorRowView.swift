import SwiftUI

// MARK: - Emulator Row

struct EmulatorRowView: View {
    let emulator: AndroidEmulator
    let viewModel: AndroidEmulatorsViewModel
    var onOpenLink: ((AndroidEmulator) -> Void)?
    var onInstallApp: ((AndroidEmulator) -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Android icon
            Image(systemName: "desktopcomputer")
                .font(.title3)
                .foregroundStyle(emulator.status == .booted ? .primary : .tertiary)
                .frame(width: 24)

            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                Text(emulator.name)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(emulator.displayTarget)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(emulator.abi)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer()

            // Status
            StatusBadgeView(status: emulator.status)

            // Actions
            ActionButtonGroup(
                status: emulator.status,
                onBoot: {
                    Task { await viewModel.start(emulator) }
                },
                onShutdown: {
                    Task { await viewModel.stop(emulator) }
                },
                onDelete: {
                    showDeleteConfirmation = true
                },
                onOpenLink: onOpenLink != nil ? {
                    onOpenLink?(emulator)
                } : nil,
                onInstallApp: onInstallApp != nil ? {
                    onInstallApp?(emulator)
                } : nil
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Delete Emulator?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(emulator) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the emulator \"\(emulator.name)\". This cannot be undone.")
        }
    }
}
