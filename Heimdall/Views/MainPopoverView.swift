import SwiftUI

// MARK: - Main Popover View

/// Root container for the menu bar popover. Shows tabbed navigation between
/// iOS Simulators, Android Emulators, and connected Devices.
///
/// ViewModels are created here and persist across tab switches to avoid
/// reloading data every time the user changes tabs.
struct MainPopoverView: View {
    let environmentService: EnvironmentService

    @State private var selectedTab: Tab = .iOS
    @State private var showSettings = false

    // ViewModels owned here so they survive tab switches
    @State private var iOSViewModel: iOSSimulatorsViewModel?
    @State private var androidViewModel: AndroidEmulatorsViewModel?
    @State private var devicesViewModel: DeviceMirroringViewModel?

    enum Tab: String, CaseIterable {
        case iOS = "iOS"
        case android = "Android"
        case devices = "Devices"

        var icon: String {
            switch self {
            case .iOS: return "iphone"
            case .android: return "desktopcomputer"
            case .devices: return "cable.connector"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .iOS:
                    if let iOSViewModel {
                        iOSSimulatorsTabView(viewModel: iOSViewModel)
                    } else {
                        ProgressView("Loading simulators...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .android:
                    if let androidViewModel {
                        AndroidEmulatorsTabView(viewModel: androidViewModel)
                    } else {
                        ProgressView("Loading emulators...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .devices:
                    if let devicesViewModel {
                        DeviceMirroringTabView(
                            viewModel: devicesViewModel,
                            environmentService: environmentService
                        )
                    } else {
                        ProgressView("Loading devices...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            footer
        }
        .frame(width: 420, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Create all ViewModels once and load their data
            let iosVM = iOSSimulatorsViewModel(environmentService: environmentService)
            let androidVM = AndroidEmulatorsViewModel(environmentService: environmentService)
            let devicesVM = DeviceMirroringViewModel(environmentService: environmentService)

            iOSViewModel = iosVM
            androidViewModel = androidVM
            devicesViewModel = devicesVM

            // Load data concurrently
            async let iosLoad: () = iosVM.loadAll()
            async let androidLoad: () = androidVM.loadAll()
            async let devicesLoad: () = devicesVM.loadDevices()

            _ = await (iosLoad, androidLoad, devicesLoad)

            // Start background updates
            iosVM.startPolling()
            androidVM.startPolling()
            devicesVM.startMonitoring()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                viewModel: SettingsViewModel(environmentService: environmentService)
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(.primary)
                Text("Heimdall")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Environment status indicators
            HStack(spacing: 8) {
                StatusDot(isActive: environmentService.hasXcode, label: "Xcode")
                StatusDot(isActive: environmentService.hasAndroidSDK, label: "Android")
                StatusDot(isActive: environmentService.hasScrcpy, label: "scrcpy")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Status Dot

private struct StatusDot: View {
    let isActive: Bool
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(label)
        }
    }
}
