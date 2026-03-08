import SwiftUI
import UniformTypeIdentifiers

// MARK: - Android Emulators Tab

struct AndroidEmulatorsTabView: View {
    let viewModel: AndroidEmulatorsViewModel

    @State private var showCreateSheet = false
    @State private var deepLinkTarget: AndroidEmulator?
    @State private var searchText = ""

    private var filteredEmulators: [AndroidEmulator] {
        if searchText.isEmpty { return viewModel.emulators }
        return viewModel.emulators.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isAvailable {
                // Android SDK not configured
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Android SDK Not Found",
                    subtitle: "Configure the Android SDK path in Settings to manage emulators."
                )
            } else {
                // Toolbar
                toolbar

                // Error banner
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                // Content
                if viewModel.isLoading && viewModel.emulators.isEmpty {
                    ProgressView("Loading emulators...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.emulators.isEmpty {
                    EmptyStateView(
                        icon: "desktopcomputer.trianglebadge.exclamationmark",
                        title: "No Emulators",
                        subtitle: "Create a new Android emulator to get started.",
                        actionLabel: "Create New",
                        action: { showCreateSheet = true }
                    )
                } else {
                    emulatorList
                }
            }
        }
        .sheet(item: $deepLinkTarget) { target in
            DeepLinkSheet(
                targetName: target.name,
                recentLinks: viewModel.deepLinkService.loadHistory(),
                onOpen: { url in
                    Task { await viewModel.openDeepLink(on: target, url: url) }
                },
                onClearHistory: {
                    viewModel.deepLinkService.clearHistory()
                }
            )
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateEmulatorSheet(
                systemImages: viewModel.systemImages
            ) { name, imagePath, deviceProfile, config in
                Task {
                    await viewModel.create(
                        name: name,
                        systemImagePath: imagePath,
                        deviceProfile: deviceProfile,
                        config: config
                    )
                    showCreateSheet = false
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if viewModel.runningCount > 0 {
                Text("\(viewModel.runningCount) running")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }

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
            .help("Refresh emulators")

            // Create button
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Create new emulator")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Log Viewer

    private func openLogViewer(for emulator: AndroidEmulator) {
        print("[Heimdall:DEBUG] Emulator logs button tapped for: \(emulator.name), status: \(emulator.status)")
        guard emulator.status == .booted else {
            print("[Heimdall:DEBUG] Emulator not booted, skipping log viewer")
            return
        }
        // Resolve the emulator serial and open log viewer via AppDelegate
        Task {
            do {
                let serial = try await viewModel.resolveSerial(for: emulator)
                print("[Heimdall:DEBUG] Resolved emulator serial: \(serial)")
                AppDelegate.shared.openLogViewer(deviceName: emulator.name, serial: serial)
            } catch {
                print("[Heimdall:DEBUG] ERROR resolving emulator serial: \(error)")
                viewModel.errorMessage = "Could not resolve emulator serial: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Install App

    private func pickAndInstallApp(for emulator: AndroidEmulator) {
        let panel = NSOpenPanel()
        panel.title = "Select APK to Install"
        panel.allowedContentTypes = [.init(filenameExtension: "apk")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an .apk file to install on \(emulator.name)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.installApp(on: emulator, apkPath: url.path)
        }
    }

    // MARK: - List

    private var emulatorList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEmulators) { emulator in
                    EmulatorRowView(
                        emulator: emulator,
                        viewModel: viewModel,
                        onOpenLink: { emu in
                            deepLinkTarget = emu
                        },
                        onInstallApp: { emu in
                            pickAndInstallApp(for: emu)
                        },
                        onOpenLogs: { emu in
                            openLogViewer(for: emu)
                        }
                    )
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}
