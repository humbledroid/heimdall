import SwiftUI

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let viewModel: SettingsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                // Tool Paths
                Section("Tool Paths") {
                    pathRow(
                        label: "Android SDK",
                        path: viewModel.environmentService.androidSDKPath,
                        action: viewModel.browseAndroidSDK
                    )

                    pathRow(
                        label: "scrcpy",
                        path: viewModel.environmentService.scrcpyPath,
                        action: viewModel.browseScrcpy
                    )
                }

                // Auto-detected tools
                Section("Detected Tools") {
                    toolStatusRow(
                        name: "xcrun (Xcode)",
                        path: viewModel.environmentService.xcrunPath
                    )

                    toolStatusRow(
                        name: "adb",
                        path: viewModel.environmentService.adbPath
                    )

                    toolStatusRow(
                        name: "emulator",
                        path: viewModel.environmentService.emulatorPath
                    )

                    toolStatusRow(
                        name: "avdmanager",
                        path: viewModel.environmentService.avdManagerPath
                    )

                    toolStatusRow(
                        name: "sdkmanager",
                        path: viewModel.environmentService.sdkManagerPath
                    )

                    toolStatusRow(
                        name: "scrcpy",
                        path: viewModel.environmentService.scrcpyPath
                    )
                }

                // Re-detect
                Section {
                    Button {
                        Task { await viewModel.redetect() }
                    } label: {
                        HStack {
                            if viewModel.isDetecting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.isDetecting ? "Detecting..." : "Re-detect Environment")
                        }
                    }
                    .disabled(viewModel.isDetecting)
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440, height: 520)
    }

    // MARK: - Path Row

    private func pathRow(label: String, path: String?, action: @escaping () -> Void) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                if let path {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 180, alignment: .leading)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Not found")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button("Browse", action: action)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Tool Status Row

    private func toolStatusRow(name: String, path: String?) -> some View {
        HStack {
            Circle()
                .fill(path != nil ? Color.green : Color.red.opacity(0.6))
                .frame(width: 8, height: 8)

            Text(name)
                .font(.body)

            Spacer()

            if let path {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
            } else {
                Text("Not found")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }
}
