import SwiftUI

// MARK: - Device Mirroring Tab

struct DeviceMirroringTabView: View {
    let environmentService: EnvironmentService

    @State private var viewModel: DeviceMirroringViewModel?

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel {
                if !viewModel.isAvailable {
                    EmptyStateView(
                        icon: "cable.connector.slash",
                        title: "adb Not Found",
                        subtitle: "Configure the Android SDK path in Settings to detect connected devices."
                    )
                } else {
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
                        deviceList(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = DeviceMirroringViewModel(environmentService: environmentService)
            viewModel = vm
            await vm.loadDevices()
        }
        .onAppear { viewModel?.startMonitoring() }
        .onDisappear { viewModel?.stopMonitoring() }
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

    private func deviceList(viewModel: DeviceMirroringViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(viewModel.devices.count) device(s) connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                ForEach(viewModel.devices) { device in
                    DeviceRowView(
                        device: device,
                        viewModel: viewModel,
                        hasScrcpy: environmentService.hasScrcpy
                    )
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}
