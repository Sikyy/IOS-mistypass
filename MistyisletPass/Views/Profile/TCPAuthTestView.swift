import SwiftUI

#if DEBUG
/// Developer-only view for testing BLE auth via TCP simulator.
/// Access: Profile → About → tap version 7x → "TCP Auth Test"
struct TCPAuthTestView: View {
    @State private var host = ""
    @State private var port = "9900"
    @State private var result: String = ""
    @State private var isRunning = false
    @State private var publicKeyPEM = ""
    @State private var userId = ""

    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Text("Host")
                        .frame(width: 50, alignment: .leading)
                    TextField("Gateway IP", text: $host)
                        .keyboardType(.decimalPad)
                        .textContentType(.URL)
                }
                HStack {
                    Text("Port")
                        .frame(width: 50, alignment: .leading)
                    TextField("9900", text: $port)
                        .keyboardType(.numberPad)
                }
            }

            Section("Device Identity") {
                LabeledContent("User ID", value: userId.isEmpty ? "(none)" : userId)
                    .contextMenu {
                        Button("Copy") { UIPasteboard.general.string = userId }
                    }

                if !publicKeyPEM.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public Key (PEM)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(publicKeyPEM)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(8)
                    }
                    .contextMenu {
                        Button("Copy PEM") { UIPasteboard.general.string = publicKeyPEM }
                    }
                } else {
                    Button("Generate Key Pair") {
                        generateKeyPair()
                    }
                }
            }

            Section("Test") {
                Button {
                    runTest()
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text(isRunning ? "Authenticating..." : "Run TCP Auth")
                    }
                }
                .disabled(isRunning || userId.isEmpty)

                if !result.isEmpty {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(result.contains("GRANTED") ? .green : .red)
                }
            }

            Section("Protocol Info") {
                LabeledContent("Challenge", value: "52 bytes (v2)")
                LabeledContent("Signing", value: "SHA256(nonce||userId||'BLE')")
                LabeledContent("Curve", value: "P-256 (Secure Enclave)")
                LabeledContent("Transport Tag", value: "BLE")
            }
        }
        .navigationTitle("TCP Auth Test")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadIdentity()
        }
    }

    private func loadIdentity() {
        userId = KeychainService.shared.readString(forKey: "com.mistyislet.userId") ?? ""
        if let pem = try? SecureEnclaveService.shared.exportPublicKeyPEM() {
            publicKeyPEM = pem
        }
    }

    private func generateKeyPair() {
        do {
            _ = try SecureEnclaveService.shared.generateKeyPair()
            publicKeyPEM = try SecureEnclaveService.shared.exportPublicKeyPEM()
            result = "Key pair generated"
        } catch {
            result = "Key gen error: \(error.localizedDescription)"
        }
    }

    private func runTest() {
        guard let portNum = UInt16(port) else {
            result = "Invalid port"
            return
        }
        isRunning = true
        result = ""

        Task {
            do {
                let code = try await TCPAuthClient.shared.authenticate(
                    host: host,
                    port: portNum
                )
                switch code {
                case 0x01:
                    result = "0x01 — ACCESS GRANTED"
                case 0x02:
                    result = "0x02 — ACCESS DENIED"
                default:
                    result = "0x\(String(format: "%02X", code)) — Unknown code"
                }
            } catch {
                result = "Error: \(error.localizedDescription)"
            }
            isRunning = false
        }
    }
}

#Preview {
    NavigationStack {
        TCPAuthTestView()
    }
}
#endif
