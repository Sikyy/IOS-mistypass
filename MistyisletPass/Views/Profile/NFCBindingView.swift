import SwiftUI

struct NFCBindingView: View {
    @Environment(ProfileViewModel.self) private var viewModel
    private let settings = SettingsService.shared

    @State private var isScanning = false
    @State private var scannedUID: String?
    @State private var cardLabel = ""
    @State private var errorMessage: String?
    @State private var isBinding = false
    @State private var bindSuccess = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.brandPrimary)

                    Text(settings.L("nfc.title"))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(settings.L("nfc.description"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Step 1: Scan
            Section(settings.L("nfc.scan_step")) {
                if let uid = scannedUID {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(settings.L("nfc.card_detected"))
                                .font(.headline)
                            Text("UID: \(uid)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                    }
                } else {
                    Button {
                        Task { await scanCard() }
                    } label: {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text(settings.L("nfc.hold_near"))
                            } else {
                                Image(systemName: "wave.3.right")
                                Text(settings.L("nfc.scan_card"))
                            }
                        }
                    }
                    .disabled(isScanning)
                }
            }

            if scannedUID != nil {
                Section(settings.L("nfc.label_step")) {
                    TextField(settings.L("nfc.label_placeholder"), text: $cardLabel)
                }

                Section {
                    Button {
                        Task { await bindCard() }
                    } label: {
                        HStack {
                            Spacer()
                            if isBinding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(settings.L("nfc.bind_card"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(cardLabel.isEmpty || isBinding)
                    .buttonStyle(.glassProminent)
                    .tint(.brandPrimary)
                }
            }

            // Error
            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(settings.L("nfc.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(settings.L("nfc.card_bound"), isPresented: $bindSuccess) {
            Button(settings.L("common.done")) { dismiss() }
        } message: {
            Text(settings.L("nfc.bind_success"))
        }
    }

    private func scanCard() async {
        isScanning = true
        errorMessage = nil

        do {
            scannedUID = try await NFCService.shared.scanCard()
        } catch NFCError.cancelled {
            // User cancelled, do nothing
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }

    private func bindCard() async {
        guard let uid = scannedUID else { return }
        isBinding = true
        errorMessage = nil

        do {
            let credential = try await NFCService.shared.bindCard(
                cardUID: uid,
                label: cardLabel.isEmpty ? "NFC Card" : cardLabel
            )
            // Add to credentials list
            viewModel.credentials.append(credential)
            bindSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isBinding = false
    }
}

#Preview {
    NavigationStack {
        NFCBindingView()
            .environment(ProfileViewModel())
    }
}
