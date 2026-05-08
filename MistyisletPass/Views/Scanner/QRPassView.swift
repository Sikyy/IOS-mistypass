import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct QRPassView: View {
    @State private var qrToken: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expiresAt: Date?
    @State private var refreshTask: Task<Void, Never>?
    @State private var originalBrightness: CGFloat?
    @State private var doors: [AccessibleDoor] = []
    @State private var selectedDoor: AccessibleDoor?

    @Environment(\.scenePhase) private var scenePhase

    private let settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !doors.isEmpty {
                    doorSelector
                }

                Spacer()

                if isLoading {
                    ProgressView("Loading QR code...")
                } else if let qrToken, selectedDoor != nil {
                    qrContent(token: qrToken)
                } else if let errorMessage {
                    errorContent(message: errorMessage)
                } else if doors.isEmpty {
                    noDoorContent
                } else {
                    selectDoorPrompt
                }

                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .task { await loadDoors() }
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

    // MARK: - Door Selector

    private var doorSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(doors) { door in
                    Button {
                        selectedDoor = door
                        Task { await fetchQRToken() }
                    } label: {
                        Text(door.name)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(selectedDoor?.id == door.id ? .white : .primary)
                            .background(
                                selectedDoor?.id == door.id
                                    ? AnyShapeStyle(.brandPrimary)
                                    : AnyShapeStyle(.quaternary)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var noDoorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(settings.L("pass.no_doors"))
                .font(.headline)
            Text(settings.L("pass.no_doors_desc"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var selectDoorPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(settings.L("pass.select_door"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - QR Display

    private func qrContent(token: String) -> some View {
        VStack(spacing: 20) {
            if let qrImage = QRGenerator.generate(from: token) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .padding(20)
                    .background(Color.white)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .accessibilityLabel("QR access code")
            }

            if let expiresAt {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let remaining = expiresAt.timeIntervalSince(timeline.date)
                    let seconds = max(0, Int(remaining))
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(String(format: settings.L("pass.expires_in"), seconds))
                            .font(.callout)
                            .monospacedDigit()
                    }
                    .foregroundStyle(timerColor(seconds: seconds))
                }
            }

            Text(settings.L("pass.scan_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await fetchQRToken() }
            } label: {
                Label(settings.L("pass.refresh"), systemImage: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.glass)
            .tint(.brandPrimary)
        }
    }

    private func timerColor(seconds: Int) -> Color {
        if seconds > 20 { return .green }
        if seconds > 10 { return .yellow }
        return .red
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(settings.L("pass.error"))
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(settings.L("unlock.try_again")) {
                Task { await fetchQRToken() }
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        }
    }

    // MARK: - Data

    private func loadDoors() async {
        guard let placeId = settings.selectedPlaceId else {
            isLoading = false
            return
        }
        do {
            doors = try await APIService.shared.fetchPlaceDoors(placeId: placeId)
            if let first = doors.first {
                selectedDoor = first
                await fetchQRToken()
            } else {
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func fetchQRToken() async {
        guard selectedDoor != nil else { return }
        isLoading = true
        errorMessage = nil
        refreshTask?.cancel()

        do {
            let response: QRTokenResponse = try await requestQRToken()
            qrToken = response.token
            expiresAt = Date().addingTimeInterval(TimeInterval(response.ttlSeconds))
            boostBrightness()
            startAutoRefresh(ttl: response.ttlSeconds)
        } catch {
            errorMessage = error.localizedDescription
            qrToken = nil
        }

        isLoading = false
    }

    private func requestQRToken() async throws -> QRTokenResponse {
        try await APIService.shared.fetchQRToken(doorId: selectedDoor?.id)
    }

    private func startAutoRefresh(ttl: Int) {
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ttl))
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

struct QRTokenResponse: Codable {
    let token: String
    let ttlSeconds: Int

    enum CodingKeys: String, CodingKey {
        case token
        case ttlSeconds = "ttl_seconds"
    }
}
