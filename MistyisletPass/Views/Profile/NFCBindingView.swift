import SwiftUI

struct NFCBindingView: View {
    let viewModel: ProfileViewModel

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

                    Text("Bind NFC Card")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Register your DESFire EV3 physical access card with your account. Hold the card near the top of your iPhone when prompted.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Step 1: Scan
            Section("Step 1: Scan Card") {
                if let uid = scannedUID {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Card Detected")
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
                                Text("Hold card near iPhone...")
                            } else {
                                Image(systemName: "wave.3.right")
                                Text("Scan NFC Card")
                            }
                        }
                    }
                    .disabled(isScanning)
                }
            }

            // Step 2: Label
            if scannedUID != nil {
                Section("Step 2: Label") {
                    TextField("Card label (e.g., \"Office Card\")", text: $cardLabel)
                }

                // Step 3: Bind
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
                                Text("Bind Card")
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
        .navigationTitle("Bind NFC Card")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Card Bound", isPresented: $bindSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your NFC card has been registered successfully. You can now use it to unlock doors.")
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
        NFCBindingView(viewModel: ProfileViewModel())
    }
}
