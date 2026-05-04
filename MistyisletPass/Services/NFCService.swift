import Foundation
import CoreNFC

/// Reads DESFire EV3 physical card UID for self-service card binding.
/// iOS only supports reading NFC tags (not writing), which is sufficient for binding.
@MainActor
final class NFCService: NSObject {
    static let shared = NFCService()

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?

    private override init() { super.init() }

    /// Whether this device supports NFC tag reading
    nonisolated var isAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    /// Start NFC scan and return the card UID as hex string
    func scanCard() async throws -> String {
        guard isAvailable else {
            throw NFCError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            session = NFCTagReaderSession(
                pollingOption: [.iso14443],
                delegate: self,
                queue: .main
            )
            session?.alertMessage = "Hold your access card near the top of your iPhone"
            session?.begin()
        }
    }

    /// Register scanned card UID with backend
    func bindCard(cardUID: String, label: String) async throws -> Credential {
        let body: [String: String] = [
            "card_uid": cardUID,
            "card_type": "desfire_ev3",
            "label": label,
        ]

        guard let url = URL(string: Constants.API.baseURL + "/app/credentials/nfc") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8)
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Credential.self, from: data)
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCService: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session is active, waiting for card
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            continuation?.resume(throwing: NFCError.cancelled)
        } else if nfcError?.code == .readerSessionInvalidationErrorSessionTimeout {
            continuation?.resume(throwing: NFCError.timeout)
        } else {
            continuation?.resume(throwing: NFCError.readFailed(error.localizedDescription))
        }
        continuation = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No card detected")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                self?.continuation?.resume(throwing: NFCError.readFailed(error.localizedDescription))
                self?.continuation = nil
                return
            }

            switch tag {
            case .iso7816(let iso7816Tag):
                let uid = iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined(separator: ":")
                session.alertMessage = "Card read successfully!"
                session.invalidate()
                self?.continuation?.resume(returning: uid)
                self?.continuation = nil

            case .miFare(let miFareTag):
                let uid = miFareTag.identifier.map { String(format: "%02X", $0) }.joined(separator: ":")
                session.alertMessage = "Card read successfully!"
                session.invalidate()
                self?.continuation?.resume(returning: uid)
                self?.continuation = nil

            default:
                session.invalidate(errorMessage: "Unsupported card type")
                self?.continuation?.resume(throwing: NFCError.unsupportedCard)
                self?.continuation = nil
            }
        }
    }
}

// MARK: - Errors

enum NFCError: Error, LocalizedError {
    case notAvailable
    case cancelled
    case timeout
    case readFailed(String)
    case unsupportedCard

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "NFC is not available on this device"
        case .cancelled: return "NFC scan was cancelled"
        case .timeout: return "NFC scan timed out"
        case .readFailed(let msg): return "Failed to read card: \(msg)"
        case .unsupportedCard: return "Unsupported card type"
        }
    }
}
