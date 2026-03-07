import SwiftUI

// MARK: - Create Android Emulator Sheet

struct CreateEmulatorSheet: View {
    let systemImages: [SystemImage]
    let onCreate: (String, String, String?, EmulatorConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedImage: SystemImage?
    @State private var selectedProfile: DeviceProfile?

    // Advanced config
    @State private var showAdvanced = false
    @State private var ramMB: Double = 2048
    @State private var storageMB: Double = 8192
    @State private var gpuMode: EmulatorConfig.GPUMode = .auto

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedImage != nil
    }

    /// Group system images by API level.
    private var groupedImages: [(apiLevel: String, images: [SystemImage])] {
        let grouped = Dictionary(grouping: systemImages) { $0.apiLevel }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (apiLevel: $0.key, images: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Create Android Emulator")
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

            // Form
            ScrollView {
                Form {
                    Section("Emulator Name") {
                        TextField("e.g. Pixel_7_API_34", text: $name)
                            .textFieldStyle(.roundedBorder)

                        Text("Use letters, numbers, underscores, hyphens, and periods only.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Section("System Image") {
                        if systemImages.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No system images installed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Install images via Android Studio's SDK Manager.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Picker("System Image", selection: $selectedImage) {
                                Text("Select a system image").tag(nil as SystemImage?)
                                ForEach(groupedImages, id: \.apiLevel) { group in
                                    Section("API \(group.apiLevel)") {
                                        ForEach(group.images) { image in
                                            Text(image.displayName).tag(image as SystemImage?)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section("Device Profile (Optional)") {
                        Picker("Device Profile", selection: $selectedProfile) {
                            Text("Default").tag(nil as DeviceProfile?)
                            ForEach(DeviceProfile.commonProfiles) { profile in
                                Text(profile.name).tag(profile as DeviceProfile?)
                            }
                        }
                    }

                    // Advanced Configuration
                    Section {
                        DisclosureGroup("Advanced Configuration", isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 12) {
                                // RAM
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("RAM")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(ramMB)) MB")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $ramMB, in: 512...8192, step: 256)
                                    HStack {
                                        Text("512 MB")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text("8 GB")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Divider()

                                // Internal Storage
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Internal Storage")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(storageDisplayString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Slider(value: $storageMB, in: 2048...32768, step: 1024)
                                    HStack {
                                        Text("2 GB")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text("32 GB")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Divider()

                                // GPU Acceleration
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("GPU Acceleration")
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    Picker("GPU Mode", selection: $gpuMode) {
                                        ForEach(EmulatorConfig.GPUMode.allCases, id: \.self) { mode in
                                            Text(mode.displayName).tag(mode)
                                        }
                                    }
                                    .labelsHidden()

                                    Text(gpuHelpText)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    guard let image = selectedImage else { return }
                    let sanitizedName = name
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: " ", with: "_")
                    let config = EmulatorConfig(
                        ramMB: Int(ramMB),
                        storageMB: Int(storageMB),
                        gpuMode: gpuMode
                    )
                    onCreate(sanitizedName, image.path, selectedProfile?.id, config)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 580)
        .onAppear {
            selectedImage = systemImages.first
            selectedProfile = DeviceProfile.commonProfiles.first
            if let profile = selectedProfile, let image = selectedImage {
                name = "\(profile.name.replacingOccurrences(of: " ", with: "_"))_API_\(image.apiLevel)"
            }
        }
    }

    // MARK: - Helpers

    private var storageDisplayString: String {
        let gb = storageMB / 1024
        if gb == Double(Int(gb)) {
            return "\(Int(gb)) GB"
        }
        return String(format: "%.1f GB", gb)
    }

    private var gpuHelpText: String {
        switch gpuMode {
        case .auto:
            return "Automatically selects the best GPU mode for your system."
        case .host:
            return "Uses your Mac's GPU directly. Best performance, but may not work on all systems."
        case .swiftshaderIndirect:
            return "Software rendering via SwiftShader. Slower but most compatible."
        case .angleIndirect:
            return "Uses ANGLE for GPU translation. Good balance of speed and compatibility."
        }
    }
}
