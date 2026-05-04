import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// Displays a dynamic QR code on screen for the door reader to scan (被扫模式).
/// The QR token auto-refreshes every 30 seconds for security.
struct QRPassView: View {
    @State private var qrToken: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expiresAt: Date?
    @State private var refreshTask: Task<Void, Never>?
    @State private var originalBrightness: CGFloat?

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Generating pass...")
                } else if let qrToken {
                    qrContent(token: qrToken)
                } else if let errorMessage {
                    errorContent(message: errorMessage)
                }
            }
            .padding()
            .navigationTitle("Pass")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .task {
                await fetchQRToken()
                guard !Task.isCancelled else { return }
                startAutoRefresh()
            }
            .onDisappear {
                refreshTask?.cancel()
                restoreBrightness()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    boostBrightness()
                } else {
                    restoreBrightness()
                }
            }
        }
    }

    // MARK: - QR Display

    private func qrContent(token: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Instruction
            Text("Hold your phone near the reader")
                .font(.headline)
                .foregroundStyle(.secondary)

            // QR Code
            if let qrImage = generateQRImage(from: token) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .padding(20)
                    .background(Color.white)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .accessibilityLabel("QR access code")
                    .accessibilityHint("Show this to the door reader to unlock")
            }

            // Countdown timer
            if let expiresAt {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("Refreshes in")
                            .font(.caption)
                        Text(expiresAt, style: .relative)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)

                    // Progress bar
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let remaining = expiresAt.timeIntervalSince(timeline.date)
                        let total: TimeInterval = 30
                        let progress = max(0, min(1, remaining / total))
                        ProgressView(value: progress)
                            .tint(.brandPrimary)
                            .animation(.linear(duration: 1), value: progress)
                    }
                    .frame(width: 200)
                }
            }

            Spacer()

            // Manual refresh button
            Button {
                Task { await fetchQRToken() }
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.glass)
            .tint(.brandPrimary)

            // Brightness hint
            Text("Screen brightness is increased for scanning")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Unable to Generate Pass")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await fetchQRToken() }
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        }
    }

    // MARK: - QR Generation

    private func generateQRImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Token Management

    private func fetchQRToken() async {
        isLoading = true
        errorMessage = nil

        do {
            // Request a short-lived QR token from the API
            let response: QRTokenResponse = try await requestQRToken()
            qrToken = response.token
            expiresAt = Date().addingTimeInterval(TimeInterval(response.ttlSeconds))
            boostBrightness()
        } catch {
            errorMessage = error.localizedDescription
            qrToken = nil
        }

        isLoading = false
    }

    private func requestQRToken() async throws -> QRTokenResponse {
        // Call API to get a short-lived QR token
        guard let url = URL(string: Constants.API.baseURL + "/app/qr-token") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8)
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(QRTokenResponse.self, from: data)
    }

    private func startAutoRefresh() {
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await fetchQRToken()
            }
        }
    }

    // MARK: - Brightness

    private func boostBrightness() {
        guard originalBrightness == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        originalBrightness = scene.screen.brightness
        scene.screen.brightness = 1.0
    }

    private func restoreBrightness() {
        guard let saved = originalBrightness,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.screen.brightness = saved
        originalBrightness = nil
    }
}

// MARK: - QR Token Model

struct QRTokenResponse: Codable {
    let token: String
    let ttlSeconds: Int

    enum CodingKeys: String, CodingKey {
        case token
        case ttlSeconds = "ttl_seconds"
    }
}

#Preview {
    QRPassView()
}
