import SwiftUI

// MARK: - Deep Link Sheet

/// Modal sheet for entering and opening deep links on a device/simulator.
struct DeepLinkSheet: View {
    let targetName: String
    let recentLinks: [String]
    let onOpen: (String) -> Void
    let onClearHistory: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var urlInput: String = ""
    @State private var isOpening = false
    @FocusState private var isURLFieldFocused: Bool

    private var isValid: Bool {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Deep Link")
                        .font(.headline)
                    Text("on \(targetName)")
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

            // URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("https:// or myapp://path", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($isURLFieldFocused)
                        .onSubmit {
                            if isValid { openLink() }
                        }

                    Button {
                        openLink()
                    } label: {
                        if isOpening {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!isValid || isOpening)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Recent links
            if !recentLinks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Recent")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Clear") {
                            onClearHistory()
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(recentLinks, id: \.self) { link in
                                Button {
                                    urlInput = link
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(link)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: recentLinks.isEmpty ? 220 : 380)
        .onAppear {
            isURLFieldFocused = true
        }
    }

    private func openLink() {
        guard isValid else { return }
        let url = urlInput.trimmingCharacters(in: .whitespaces)
        isOpening = true
        onOpen(url)
        // Dismiss after a brief moment so user sees the action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}
