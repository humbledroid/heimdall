import SwiftUI

// MARK: - Device Mirroring Tab

struct DeviceMirroringTabView: View {
    let viewModel: DeviceMirroringViewModel
    let environmentService: EnvironmentService

    @State private var showDeepLinkSheet = false
    @State private var deepLinkTarget: AndroidDevice?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isAvailable {
                EmptyStateView(
                    icon: "cable.connector.slash",
                    title: "adb Not Found",
                    subtitle: "Configure the Android SDK path in Settings to detect connected devices."
                )
            } else {
                // Toolbar with refresh
                toolbar

                // Error banner
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                // scrcpy warning
                if !environmentService.hasScrcpy {
                    scrcpyWarning
                }

                // Content
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView("Scanning for devices...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.devices.isEmpty {
                    EmptyStateView(
                        icon: "cable.connector",
                        title: "No Devices Connected",
                        subtitle: "Connect an Android device via USB and enable USB debugging to get started."
                    )
                } else {
                    deviceList
                }
            }
        }
        .sheet(isPresented: $showDeepLinkSheet) {
            if let target = deepLinkTarget {
                DeepLinkSheet(
                    targetName: target.displayName,
                    recentLinks: viewModel.deepLinkService.loadHistory(),
                    onOpen: { url in
                        Task { await viewModel.openDeepLink(on: target, url: url) }
                    },
                    onClearHistory: {
                        viewModel.deepLinkService.clearHistory()
                    }
                )
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.devices.count) device(s)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Refresh button
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                    .animation(
                        viewModel.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.isRefreshing
                    )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isRefreshing)
            .help("Refresh devices")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - scrcpy Warning

    private var scrcpyWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text("scrcpy not installed")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Install via: brew install scrcpy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Device List

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.devices) { device in
                    DeviceRowView(
                        device: device,
                        viewModel: viewModel,
                        hasScrcpy: environmentService.hasScrcpy,
                        onOpenLink: { dev in
                            deepLinkTarget = dev
                            showDeepLinkSheet = true
                        }
                    )
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}
