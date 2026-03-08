import SwiftUI

// MARK: - Wireless Pairing Sheet

/// Sheet for pairing and connecting to an Android device wirelessly via ADB.
struct WirelessPairingSheet: View {
    let onPairAndConnect: (String, String, String, String) async -> Void  // ip, pairPort, code, connectPort

    @Environment(\.dismiss) private var dismiss

    @State private var ip: String = ""
    @State private var pairingPort: String = ""
    @State private var pairingCode: String = ""
    @State private var connectPort: String = ""
    @State private var isPairing = false
    @State private var statusMessage: String?
    @State private var isError = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case ip, pairingPort, pairingCode, connectPort
    }

    private var isValid: Bool {
        !ip.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pairingPort.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pairingCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wireless ADB Pairing")
                        .font(.headline)
                    Text("Pair and connect to a device over Wi-Fi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Instructions
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)

                Text("On your device: Settings → Developer Options → Wireless Debugging → Pair device with pairing code")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Form
            VStack(alignment: .leading, spacing: 12) {
                // IP Address
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device IP Address")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("192.168.1.100", text: $ip)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: .ip)
                }

                HStack(spacing: 12) {
                    // Pairing Port
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pairing Port")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("37845", text: $pairingPort)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .pairingPort)
                    }

                    // Pairing Code
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pairing Code")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("482956", text: $pairingCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .pairingCode)
                    }
                }

                // Connect Port (optional, shown after pairing info)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Port (shown under Wireless Debugging, optional)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("5555", text: $connectPort)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: .connectPort)
                }

                // Status message
                if let statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isError ? .red : .green)
                            .font(.caption)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    pairAndConnect()
                } label: {
                    if isPairing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Pair & Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isPairing)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 420)
        .onAppear {
            focusedField = .ip
        }
    }

    private func pairAndConnect() {
        guard isValid else { return }
        isPairing = true
        statusMessage = nil

        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let trimmedPairPort = pairingPort.trimmingCharacters(in: .whitespaces)
        let trimmedCode = pairingCode.trimmingCharacters(in: .whitespaces)
        let trimmedConnectPort = connectPort.trimmingCharacters(in: .whitespaces)

        Task {
            await onPairAndConnect(trimmedIP, trimmedPairPort, trimmedCode, trimmedConnectPort)
            dismiss()
        }
    }
}
