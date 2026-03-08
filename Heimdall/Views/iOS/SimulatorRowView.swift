import SwiftUI

// MARK: - Simulator Row

struct SimulatorRowView: View {
    let simulator: iOSSimulator
    let viewModel: iOSSimulatorsViewModel
    var onOpenLink: ((iOSSimulator) -> Void)?
    var onInstallApp: ((iOSSimulator) -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var showEraseConfirmation = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Device icon
            deviceIcon

            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                Text(simulator.name)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)

                Text(simulator.runtime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            StatusBadgeView(status: simulator.status)

            // Action buttons
            ActionButtonGroup(
                status: simulator.status,
                onBoot: {
                    Task { await viewModel.boot(simulator) }
                },
                onShutdown: {
                    Task { await viewModel.shutdown(simulator) }
                },
                onErase: {
                    showEraseConfirmation = true
                },
                onDelete: {
                    showDeleteConfirmation = true
                },
                onOpenLink: onOpenLink != nil ? {
                    onOpenLink?(simulator)
                } : nil,
                onInstallApp: onInstallApp != nil ? {
                    onInstallApp?(simulator)
                } : nil
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Erase Simulator?", isPresented: $showEraseConfirmation) {
            Button("Erase", role: .destructive) {
                Task { await viewModel.erase(simulator) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all content and settings from \"\(simulator.name)\". This cannot be undone.")
        }
        .alert("Delete Simulator?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(simulator) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(simulator.name)\". This cannot be undone.")
        }
    }

    // MARK: - Device Icon

    private var deviceIcon: some View {
        let iconName: String = {
            let lower = simulator.name.lowercased()
            if lower.contains("ipad") { return "ipad" }
            if lower.contains("watch") { return "applewatch" }
            if lower.contains("tv") { return "appletv" }
            return "iphone"
        }()

        return Image(systemName: iconName)
            .font(.title3)
            .foregroundStyle(simulator.status == .booted ? .primary : .tertiary)
            .frame(width: 24)
    }
}
