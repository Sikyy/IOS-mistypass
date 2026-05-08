import SwiftUI
import UIKit
import PassKit
import CoreImage.CIFilterBuiltins

// MARK: - Wallet View

struct WalletView: View {
    @State private var passes: [PassItem] = []
    @State private var expandedPassId: String?
    @State private var isLoading = true
    @State private var qrToken: String?
    @State private var qrExpiresAt: Date?
    @State private var pinCode: String?
    @State private var pinExpiresAt: Date?
    @State private var pinPeriod: Int = 30
    @State private var refreshTask: Task<Void, Never>?
    @State private var pinRefreshTask: Task<Void, Never>?
    @State private var originalBrightness: CGFloat?

    @Environment(\.scenePhase) private var scenePhase
    private let settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 80)
                } else if passes.isEmpty {
                    emptyState
                } else {
                    passStack
                }
            }
            .navigationTitle(settings.L("pass.title"))
            .task { await loadPasses() }
            .onDisappear {
                refreshTask?.cancel()
                pinRefreshTask?.cancel()
                restoreBrightness()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { restoreBrightness() }
            }
        }
    }

    // MARK: - Pass Stack

    private var passStack: some View {
        LazyVStack(spacing: 16) {
            ForEach(passes) { pass in
                PassCardView(
                    pass: pass,
                    qrToken: pass.type == .accessPass ? qrToken : nil,
                    qrExpiresAt: pass.type == .accessPass ? qrExpiresAt : nil,
                    pinCode: pass.type == .pinPass ? pinCode : nil,
                    pinExpiresAt: pass.type == .pinPass ? pinExpiresAt : nil,
                    isExpanded: expandedPassId == pass.id,
                    onTap: { toggleExpand(pass) },
                    onRefreshQR: { Task { await fetchQRToken() } },
                    onRefreshPIN: { Task { await fetchPinCode() } }
                )
            }

            addToWalletSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 100)
    }

    // MARK: - Add to Wallet

    private var addToWalletSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            PKAddPassButtonWrapper()
                .frame(width: 250, height: 50)
                .opacity(0.4)
                .allowsHitTesting(false)

            Text(settings.L("wallet.region_notice"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func toggleExpand(_ pass: PassItem) {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            if expandedPassId == pass.id {
                expandedPassId = nil
                restoreBrightness()
            } else {
                expandedPassId = pass.id
                if pass.type == .accessPass { boostBrightness() }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            settings.L("pass.no_passes"),
            systemImage: "wallet.pass",
            description: Text(settings.L("pass.no_passes_description"))
        )
        .padding(.top, 40)
    }

    // MARK: - Data Loading

    private func loadPasses() async {
        defer { isLoading = false }

        var result: [PassItem] = []
        let orgName = settings.selectedOrgName ?? "Mistyislet"

        do {
            let token = try await fetchDynamicQRToken()
            qrToken = token.token
            qrExpiresAt = Date().addingTimeInterval(TimeInterval(token.ttlSeconds))
        } catch {}
        #if DEBUG
        if qrToken == nil {
            qrToken = "MISTYPASS-\(UUID().uuidString.prefix(8))-\(Int(Date().timeIntervalSince1970))"
            qrExpiresAt = Date().addingTimeInterval(25)
        }
        #endif
        startAutoRefresh()

        result.append(PassItem(
            id: "access_pass",
            type: .accessPass,
            organizationName: orgName,
            holderName: nil,
            placeName: settings.selectedPlaceName,
            backgroundColor: Color(hex: 0x1A1F36),
            foregroundColor: .white,
            labelColor: .white.opacity(0.6)
        ))

        do {
            let pin = try await APIService.shared.fetchPinCode()
            pinCode = pin.pin
            pinPeriod = pin.periodSecs
            let formatter = ISO8601DateFormatter()
            if let expiry = formatter.date(from: pin.validUntil) {
                pinExpiresAt = expiry
            } else {
                pinExpiresAt = Date().addingTimeInterval(TimeInterval(pin.periodSecs))
            }
        } catch {}
        #if DEBUG
        if pinCode == nil {
            pinCode = String(format: "%06d", Int.random(in: 0...999999))
            pinPeriod = 30
            pinExpiresAt = Date().addingTimeInterval(30)
        }
        #endif
        startPinAutoRefresh()

        result.append(PassItem(
            id: "pin_pass",
            type: .pinPass,
            organizationName: orgName,
            holderName: nil,
            placeName: settings.selectedPlaceName,
            backgroundColor: Color(hex: 0x0F2027),
            foregroundColor: .white,
            labelColor: .white.opacity(0.6)
        ))

        do {
            let credentials = try await APIService.shared.fetchCredentials()
            for cred in credentials where cred.isActive {
                result.append(PassItem(
                    id: cred.id,
                    type: .deviceCredential,
                    organizationName: orgName,
                    holderName: cred.deviceName,
                    placeName: nil,
                    backgroundColor: Color(hex: 0x2C3E50),
                    foregroundColor: .white,
                    labelColor: .white.opacity(0.6),
                    credentialFingerprint: nil,
                    credentialExpiry: cred.expiresAt
                ))
            }
        } catch {}


        passes = result
    }

    private func fetchQRToken() async {
        do {
            let response = try await fetchDynamicQRToken()
            withAnimation(.easeInOut(duration: 0.4)) {
                qrToken = response.token
            }
            qrExpiresAt = Date().addingTimeInterval(TimeInterval(response.ttlSeconds))
            return
        } catch {}
        #if DEBUG
        withAnimation(.easeInOut(duration: 0.4)) {
            qrToken = "MISTYPASS-\(UUID().uuidString.prefix(8))-\(Int(Date().timeIntervalSince1970))"
        }
        qrExpiresAt = Date().addingTimeInterval(25)
        #endif
    }

    private func fetchDynamicQRToken() async throws -> QRTokenResponse {
        guard let url = URL(string: Constants.API.baseURL + "/app/qr-token") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8)
            )
        }
        return try JSONDecoder().decode(QRTokenResponse.self, from: data)
    }

    private func startAutoRefresh() {
        refreshTask = Task {
            while !Task.isCancelled {
                if let expiresAt = qrExpiresAt {
                    let remaining = max(1, expiresAt.timeIntervalSinceNow - 2)
                    try? await Task.sleep(for: .seconds(remaining))
                } else {
                    try? await Task.sleep(for: .seconds(25))
                }
                guard !Task.isCancelled else { break }
                await fetchQRToken()
            }
        }
    }

    private func fetchPinCode() async {
        do {
            let response = try await APIService.shared.fetchPinCode()
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                pinCode = response.pin
            }
            pinPeriod = response.periodSecs
            let formatter = ISO8601DateFormatter()
            if let expiry = formatter.date(from: response.validUntil) {
                pinExpiresAt = expiry
            } else {
                pinExpiresAt = Date().addingTimeInterval(TimeInterval(response.periodSecs))
            }
            return
        } catch {}
        #if DEBUG
        withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
            pinCode = String(format: "%06d", Int.random(in: 0...999999))
        }
        pinPeriod = 30
        pinExpiresAt = Date().addingTimeInterval(30)
        #endif
    }

    private func startPinAutoRefresh() {
        pinRefreshTask = Task {
            while !Task.isCancelled {
                if let expiresAt = pinExpiresAt {
                    let remaining = max(0.5, expiresAt.timeIntervalSinceNow)
                    try? await Task.sleep(for: .seconds(remaining))
                } else {
                    try? await Task.sleep(for: .seconds(pinPeriod))
                }
                guard !Task.isCancelled else { break }
                await fetchPinCode()
            }
        }
    }

    // MARK: - Brightness

    private func boostBrightness() {
        guard settings.autoScreenBrightness,
              originalBrightness == nil,
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

// MARK: - Pass Item Model

struct PassItem: Identifiable {
    let id: String
    let type: PassType
    let organizationName: String
    let holderName: String?
    let placeName: String?
    let backgroundColor: Color
    let foregroundColor: Color
    let labelColor: Color
    var credentialFingerprint: String?
    var credentialExpiry: Date?
}

enum PassType {
    case accessPass
    case pinPass
    case deviceCredential
}

// MARK: - Pass Card View (Apple Wallet Style)

private struct PassCardView: View {
    let pass: PassItem
    let qrToken: String?
    let qrExpiresAt: Date?
    let pinCode: String?
    let pinExpiresAt: Date?
    let isExpanded: Bool
    let onTap: () -> Void
    let onRefreshQR: () -> Void
    let onRefreshPIN: () -> Void
    private let settings = SettingsService.shared

    @State private var showBack = false

    var body: some View {
        VStack(spacing: 0) {
            passBody
            if isExpanded {
                barcodeStrip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .onTapGesture { onTap() }
        .contextMenu {
            if pass.type == .accessPass {
                Button {
                    onRefreshQR()
                } label: {
                    Label(settings.L("pass.refresh_qr"), systemImage: "arrow.clockwise")
                }
            }
            if pass.type == .pinPass {
                Button {
                    onRefreshPIN()
                } label: {
                    Label(settings.L("pass.refresh_pin"), systemImage: "arrow.clockwise")
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.4)) { showBack.toggle() }
            } label: {
                Label(showBack ? settings.L("pass.show_front") : settings.L("pass.show_details"), systemImage: "info.circle")
            }
        }
    }

    // MARK: - Front Face

    private var passBody: some View {
        ZStack {
            pass.backgroundColor

            if showBack {
                backFields
            } else {
                frontFields
            }
        }
        .frame(minHeight: isExpanded ? 260 : 200)
        .rotation3DEffect(
            .degrees(showBack ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
    }

    private var frontFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Spacer(minLength: 12)
            primaryRow
            Spacer(minLength: 8)
            secondaryRow
            Spacer(minLength: 4)
        }
        .padding(20)
    }

    // MARK: - Header (Logo + Header Field)

    private var headerRow: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: passIcon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(pass.foregroundColor)

                Text(pass.organizationName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(pass.foregroundColor)
                    .lineLimit(1)
            }

            Spacer()

            passTypeBadge
        }
    }

    private var passTypeBadge: some View {
        Text(passTypeLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pass.foregroundColor.opacity(0.15))
            .foregroundStyle(pass.foregroundColor.opacity(0.8))
            .clipShape(Capsule())
    }

    // MARK: - Primary Field

    private var primaryRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primaryLabel)
                .font(.caption)
                .foregroundStyle(pass.labelColor)

            Text(primaryValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(pass.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Secondary + Auxiliary Fields

    private var secondaryRow: some View {
        HStack(alignment: .top) {
            if let placeName = pass.placeName, !placeName.isEmpty {
                fieldColumn(label: "LOCATION", value: placeName)
            }

            Spacer()

            switch pass.type {
            case .accessPass:
                fieldColumn(label: "TYPE", value: "QR Access")
            case .pinPass:
                fieldColumn(label: "TYPE", value: "PIN Code")
            case .deviceCredential:
                if let expiry = pass.credentialExpiry {
                    fieldColumn(label: "EXPIRES", value: expiry.formatted(.dateTime.month(.abbreviated).day().year()))
                }
            }

            Spacer()

            fieldColumn(label: "STATUS", value: "Active")
        }
    }

    private func fieldColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(pass.labelColor)
                .tracking(0.5)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(pass.foregroundColor)
                .lineLimit(1)
        }
    }

    // MARK: - Back Fields

    private var backFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.L("pass.pass_details"))
                .font(.headline)
                .foregroundStyle(pass.foregroundColor)

            Divider().background(pass.foregroundColor.opacity(0.2))

            backRow(label: "Organization", value: pass.organizationName)

            if let place = pass.placeName {
                backRow(label: "Location", value: place)
            }

            switch pass.type {
            case .accessPass:
                backRow(label: "Authentication", value: "Dynamic QR (25s refresh)")
                backRow(label: "Protocol", value: "TOTP-based token")
            case .pinPass:
                backRow(label: "Authentication", value: "Dynamic PIN (30s refresh)")
                backRow(label: "Protocol", value: "TOTP-based PIN")
                backRow(label: "Usage", value: "Enter at keypad-equipped readers")
            case .deviceCredential:
                if let fp = pass.credentialFingerprint {
                    backRow(label: "Fingerprint", value: String(fp.prefix(24)) + "...")
                }
                if let exp = pass.credentialExpiry {
                    backRow(label: "Expires", value: exp.formatted(.dateTime.month().day().year()))
                }
                backRow(label: "Security", value: "Secure Enclave")
            }

            Spacer()

            Text(settings.L("pass.tap_hold_options"))
                .font(.caption2)
                .foregroundStyle(pass.labelColor)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    private func backRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(pass.labelColor)
            Text(value)
                .font(.callout)
                .foregroundStyle(pass.foregroundColor)
        }
    }

    // MARK: - Barcode Strip (Bottom)

    @ViewBuilder
    private var barcodeStrip: some View {
        VStack(spacing: 12) {
            Divider()
                .background(pass.foregroundColor.opacity(0.1))

            switch pass.type {
            case .accessPass:
                if let qrToken, let qrImage = QRGenerator.generate(from: qrToken) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .id(qrToken)
                        .transition(.blurReplace)

                    if let expiresAt = qrExpiresAt {
                        expiryTimer(expiresAt: expiresAt)
                    }
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 48))
                        .foregroundStyle(pass.foregroundColor.opacity(0.3))
                        .padding(.vertical, 24)

                    Text(settings.L("pass.qr_unavailable"))
                        .font(.caption)
                        .foregroundStyle(pass.labelColor)
                }

                Text(settings.L("pass.present_to_scanner"))
                    .font(.caption2)
                    .foregroundStyle(pass.labelColor)

            case .pinPass:
                if let pinCode {
                    pinDisplay(pin: pinCode)

                    if let expiresAt = pinExpiresAt {
                        expiryTimer(expiresAt: expiresAt)
                    }
                } else {
                    Image(systemName: "number.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(pass.foregroundColor.opacity(0.3))
                        .padding(.vertical, 24)

                    Text(settings.L("pass.pin_unavailable"))
                        .font(.caption)
                        .foregroundStyle(pass.labelColor)
                }

                Text(settings.L("pass.enter_at_keypad"))
                    .font(.caption2)
                    .foregroundStyle(pass.labelColor)

            case .deviceCredential:
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.L("pass.ble_active"))
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(pass.foregroundColor)
                        Text(settings.L("pass.secure_enclave_protected"))
                            .font(.caption)
                            .foregroundStyle(pass.labelColor)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(pass.backgroundColor)
    }

    private func expiryTimer(expiresAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, Int(expiresAt.timeIntervalSince(timeline.date)))
            HStack(spacing: 6) {
                Circle()
                    .fill(timerColor(remaining))
                    .frame(width: 6, height: 6)
                Text("\(settings.L("pass.refreshes_in")) \(remaining)s")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(pass.foregroundColor.opacity(0.7))
            }
        }
    }

    private func timerColor(_ seconds: Int) -> Color {
        if seconds > 15 { return .green }
        if seconds > 5 { return .yellow }
        return .red
    }

    // MARK: - PIN Display

    private func pinDisplay(pin: String) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(pin.enumerated()), id: \.offset) { index, digit in
                Text(String(digit))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(
                        .spring(duration: 0.6, bounce: 0.15).delay(Double(index) * 0.05),
                        value: pin
                    )
                    .frame(width: 42, height: 54)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var passIcon: String {
        switch pass.type {
        case .accessPass: return "door.left.hand.open"
        case .pinPass: return "number"
        case .deviceCredential: return "iphone"
        }
    }

    private var passTypeLabel: String {
        switch pass.type {
        case .accessPass: return "ACCESS"
        case .pinPass: return "PIN"
        case .deviceCredential: return "DEVICE"
        }
    }

    private var primaryLabel: String {
        switch pass.type {
        case .accessPass: return "ACCESS PASS"
        case .pinPass: return "PIN CODE"
        case .deviceCredential: return "CREDENTIAL"
        }
    }

    private var primaryValue: String {
        switch pass.type {
        case .accessPass: return "Mistyislet Pass"
        case .pinPass: return "Door PIN"
        case .deviceCredential: return pass.holderName ?? "Device Credential"
        }
    }
}

// MARK: - QR Generator

// MARK: - Color hex helper

// MARK: - PKAddPassButton Wrapper

private struct PKAddPassButtonWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .blackOutline)
        button.isUserInteractionEnabled = false
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
