import SwiftUI
import UniformTypeIdentifiers

// MARK: - Device Mirroring Tab

struct DeviceMirroringTabView: View {
    let viewModel: DeviceMirroringViewModel
    let environmentService: EnvironmentService

    @State private var deepLinkTarget: AndroidDevice?
    @State private var showWirelessPairingSheet = false

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
        .sheet(isPresented: $showWirelessPairingSheet) {
            WirelessPairingSheet { ip, pairPort, code, connectPort in
                await viewModel.pairAndConnect(
                    ip: ip,
                    pairingPort: pairPort,
                    code: code,
                    connectPort: connectPort
                )
            }
        }
        .sheet(item: $deepLinkTarget) { target in
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

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.devices.count) device(s)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Always-on-top toggle for scrcpy mirroring
            if environmentService.hasScrcpy {
                Button {
                    viewModel.alwaysOnTop.toggle()
                } label: {
                    Image(systemName: viewModel.alwaysOnTop ? "pin.fill" : "pin.slash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(viewModel.alwaysOnTop ? "Mirror window: always on top (click to disable)" : "Mirror window: normal (click to pin on top)")
            }

            // Wireless pairing button
            Button {
                showWirelessPairingSheet = true
            } label: {
                Image(systemName: "wifi")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Pair wireless device")

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

    // MARK: - Install App

    private func pickAndInstallApp(for device: AndroidDevice) {
        let panel = NSOpenPanel()
        panel.title = "Select APK to Install"
        panel.allowedContentTypes = [.init(filenameExtension: "apk")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an .apk file to install on \(device.displayName)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.installApp(on: device, apkPath: url.path)
        }
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
                        },
                        onInstallApp: { dev in
                            pickAndInstallApp(for: dev)
                        },
                        onOpenLogs: { dev in
                            print("[Heimdall:DEBUG] Logs button tapped for device: \(dev.displayName), serial: \(dev.serial)")
                            AppDelegate.shared.openLogViewer(deviceName: dev.displayName, serial: dev.serial)
                        }
                    )
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}
