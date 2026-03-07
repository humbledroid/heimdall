import SwiftUI

// MARK: - iOS Simulators Tab

struct iOSSimulatorsTabView: View {
    let viewModel: iOSSimulatorsViewModel

    @State private var showCreateSheet = false
    @State private var searchText = ""

    private var filteredGroups: [(runtime: String, simulators: [iOSSimulator])] {
        if searchText.isEmpty {
            return viewModel.groupedSimulators
        }
        return viewModel.groupedSimulators.compactMap { group in
            let filtered = group.simulators.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (runtime: group.runtime, simulators: filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            // Content
            if viewModel.isLoading && viewModel.simulators.isEmpty {
                ProgressView("Loading simulators...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.simulators.isEmpty {
                EmptyStateView(
                    icon: "iphone.slash",
                    title: "No Simulators",
                    subtitle: "Create a new simulator to get started, or install runtimes via Xcode.",
                    actionLabel: "Create New",
                    action: { showCreateSheet = true }
                )
            } else {
                simulatorList
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSimulatorSheet(
                runtimes: viewModel.runtimes,
                deviceTypes: viewModel.deviceTypes
            ) { name, deviceTypeId, runtimeId in
                Task {
                    await viewModel.create(
                        name: name,
                        deviceTypeId: deviceTypeId,
                        runtimeId: runtimeId
                    )
                    showCreateSheet = false
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Search field
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

            // Running count
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
            .help("Refresh simulators")

            // Create button
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Create new simulator")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Simulator List

    private var simulatorList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(filteredGroups, id: \.runtime) { group in
                    Section {
                        ForEach(group.simulators) { simulator in
                            SimulatorRowView(
                                simulator: simulator,
                                viewModel: viewModel
                            )
                            Divider()
                                .padding(.leading, 44)
                        }
                    } header: {
                        Text(group.runtime)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                    }
                }
            }
        }
    }
}
