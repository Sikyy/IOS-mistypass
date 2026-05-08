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

        AppLogger.nfc.info("NFC scan started")
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
        do {
            let credential = try await APIService.shared.bindNFCCard(cardUID: cardUID, label: label)
            AppLogger.nfc.info("NFC card bind success for \(cardUID)")
            return credential
        } catch {
            AppLogger.nfc.error("NFC card bind failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCService: @preconcurrency NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        Task { @MainActor [weak self] in
            if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
                self?.continuation?.resume(throwing: NFCError.cancelled)
            } else if nfcError?.code == .readerSessionInvalidationErrorSessionTimeout {
                self?.continuation?.resume(throwing: NFCError.timeout)
            } else {
                self?.continuation?.resume(throwing: NFCError.readFailed(error.localizedDescription))
            }
            self?.continuation = nil
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No card detected")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.continuation?.resume(throwing: NFCError.readFailed(error.localizedDescription))
                    self?.continuation = nil
                }
                return
            }

            var uid: String?
            switch tag {
            case .iso7816(let iso7816Tag):
                uid = iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined(separator: ":")
            case .miFare(let miFareTag):
                uid = miFareTag.identifier.map { String(format: "%02X", $0) }.joined(separator: ":")
            default:
                break
            }

            if let uid {
                AppLogger.nfc.info("NFC card detected: \(uid)")
                session.alertMessage = "Card read successfully!"
                session.invalidate()
                Task { @MainActor in
                    self?.continuation?.resume(returning: uid)
                    self?.continuation = nil
                }
            } else {
                AppLogger.nfc.error("Unsupported NFC card type")
                session.invalidate(errorMessage: "Unsupported card type")
                Task { @MainActor in
                    self?.continuation?.resume(throwing: NFCError.unsupportedCard)
                    self?.continuation = nil
                }
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
