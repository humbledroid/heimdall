import SwiftUI

// MARK: - Android Emulators Tab

struct AndroidEmulatorsTabView: View {
    let environmentService: EnvironmentService

    @State private var viewModel: AndroidEmulatorsViewModel?
    @State private var showCreateSheet = false
    @State private var searchText = ""

    private var filteredEmulators: [AndroidEmulator] {
        guard let vm = viewModel else { return [] }
        if searchText.isEmpty { return vm.emulators }
        return vm.emulators.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel {
                if !viewModel.isAvailable {
                    // Android SDK not configured
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Android SDK Not Found",
                        subtitle: "Configure the Android SDK path in Settings to manage emulators."
                    )
                } else {
                    // Toolbar
                    toolbar(viewModel: viewModel)

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
                        emulatorList(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = AndroidEmulatorsViewModel(environmentService: environmentService)
            viewModel = vm
            await vm.loadAll()
        }
        .onAppear { viewModel?.startPolling() }
        .onDisappear { viewModel?.stopPolling() }
        .sheet(isPresented: $showCreateSheet) {
            if let viewModel {
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
    }

    // MARK: - Toolbar

    private func toolbar(viewModel: AndroidEmulatorsViewModel) -> some View {
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

    // MARK: - List

    private func emulatorList(viewModel: AndroidEmulatorsViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEmulators) { emulator in
                    EmulatorRowView(emulator: emulator, viewModel: viewModel)
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}
