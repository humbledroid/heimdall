import SwiftUI

// MARK: - Main Popover View

/// Root container for the menu bar popover. Shows tabbed navigation between
/// iOS Simulators, Android Emulators, and connected Devices.
struct MainPopoverView: View {
    let environmentService: EnvironmentService

    @State private var selectedTab: Tab = .iOS
    @State private var showSettings = false

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
                    iOSSimulatorsTabView(environmentService: environmentService)
                case .android:
                    AndroidEmulatorsTabView(environmentService: environmentService)
                case .devices:
                    DeviceMirroringTabView(environmentService: environmentService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            footer
        }
        .frame(width: 420, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
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
