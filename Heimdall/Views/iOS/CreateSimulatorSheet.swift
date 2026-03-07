import SwiftUI

// MARK: - Create iOS Simulator Sheet

struct CreateSimulatorSheet: View {
    let runtimes: [iOSRuntime]
    let deviceTypes: [iOSDeviceType]
    let onCreate: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedRuntime: iOSRuntime?
    @State private var selectedDeviceType: iOSDeviceType?

    /// Filter device types by category.
    private var iPhoneTypes: [iOSDeviceType] {
        deviceTypes.filter { $0.productFamily == "iPhone" }
    }

    private var iPadTypes: [iOSDeviceType] {
        deviceTypes.filter { $0.productFamily == "iPad" }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedRuntime != nil
            && selectedDeviceType != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Create iOS Simulator")
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
            Form {
                Section("Simulator Name") {
                    TextField("e.g. My iPhone 15", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Runtime") {
                    if runtimes.isEmpty {
                        Text("No runtimes available. Install via Xcode > Settings > Platforms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Runtime", selection: $selectedRuntime) {
                            Text("Select a runtime").tag(nil as iOSRuntime?)
                            ForEach(runtimes) { runtime in
                                Text(runtime.name).tag(runtime as iOSRuntime?)
                            }
                        }
                    }
                }

                Section("Device Type") {
                    Picker("Device Type", selection: $selectedDeviceType) {
                        Text("Select a device type").tag(nil as iOSDeviceType?)

                        if !iPhoneTypes.isEmpty {
                            Section("iPhone") {
                                ForEach(iPhoneTypes) { dt in
                                    Text(dt.name).tag(dt as iOSDeviceType?)
                                }
                            }
                        }

                        if !iPadTypes.isEmpty {
                            Section("iPad") {
                                ForEach(iPadTypes) { dt in
                                    Text(dt.name).tag(dt as iOSDeviceType?)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    guard let runtime = selectedRuntime,
                          let deviceType = selectedDeviceType else { return }

                    let trimmedName = name.trimmingCharacters(in: .whitespaces)
                    onCreate(trimmedName, deviceType.identifier, runtime.identifier)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .onAppear {
            // Default selections
            selectedRuntime = runtimes.first
            selectedDeviceType = iPhoneTypes.last  // Latest iPhone
            if let dt = selectedDeviceType {
                name = dt.name
            }
        }
        .onChange(of: selectedDeviceType) { _, newValue in
            if let dt = newValue, name.isEmpty || deviceTypes.contains(where: { $0.name == name }) {
                name = dt.name
            }
        }
    }
}
