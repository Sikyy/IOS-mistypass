import Foundation
import Network
import CryptoKit

/// TCP-based authentication client for testing against the Gateway TCP simulator.
///
/// Protocol (identical to BLE GATT v2 but over TCP socket):
///   1. Reader → Phone: 52-byte v2 challenge (nonce[32] + issued_at[8] + expires_at[8] + gateway_id[4])
///   2. Phone → Reader: auth response ([1B userId_len][userId][ECDSA signature])
///   3. Reader → Phone: auth result ([1B code][reason string])
///
/// Usage:
///   ```swift
///   let result = try await TCPAuthClient.shared.authenticate(host: "192.168.1.100", port: 9900)
///   if result == Constants.BLE.resultGranted { /* door unlocked */ }
///   ```
///
/// This enables real-device testing against the Mac-hosted gateway-agent TCP simulator
/// without requiring BLE hardware (ESP32/BlueZ).
final class TCPAuthClient: Sendable {
    static let shared = TCPAuthClient()

    /// Challenge size: nonce(32) + issued_at(8) + expires_at(8) + gateway_id(4)
    private static let challengeSize = 52

    /// Connection timeout
    private static let timeout: TimeInterval = 8.0

    private init() {}

    // MARK: - Public API

    /// Authenticate against a Gateway TCP simulator.
    ///
    /// - Parameters:
    ///   - host: IP address or hostname of the Mac running gateway-agent (e.g. "192.168.1.100")
    ///   - port: TCP port of the BLE simulator (default: 9900)
    ///   - expectedGatewayId: Optional gateway ID string for challenge validation.
    ///     If provided, verifies SHA256(gatewayId)[0:4] matches challenge bytes[48:52].
    /// - Returns: Auth result code (0x01 = granted, 0x02 = denied)
    /// - Throws: `TCPAuthError` on connection failure, timeout, or protocol error
    func authenticate(host: String, port: UInt16 = 9900, expectedGatewayId: String? = nil) async throws -> UInt8 {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )

        let handler = TCPAuthHandler(
            connection: connection,
            expectedGatewayId: expectedGatewayId,
            timeout: Self.timeout,
            challengeSize: Self.challengeSize
        )

        return try await handler.run()
    }
}

// MARK: - Handler (isolates mutable + Sendable state for Swift 6)

/// Encapsulates a single TCP auth handshake. Each call to `authenticate()` creates
/// a fresh handler so there's no shared mutable state across calls.
private final class TCPAuthHandler: @unchecked Sendable {
    private let connection: NWConnection
    private let expectedGatewayId: String?
    private let timeout: TimeInterval
    private let challengeSize: Int
    private let queue = DispatchQueue(label: "com.mistyislet.tcp-auth", qos: .userInitiated)

    /// Guards one-shot continuation resume.
    private var resumed = false

    init(connection: NWConnection, expectedGatewayId: String?, timeout: TimeInterval, challengeSize: Int) {
        self.connection = connection
        self.expectedGatewayId = expectedGatewayId
        self.timeout = timeout
        self.challengeSize = challengeSize
    }

    func run() async throws -> UInt8 {
        try await withCheckedThrowingContinuation { continuation in
            let finish: @Sendable (Result<UInt8, Error>) -> Void = { [self] result in
                queue.async {
                    guard !self.resumed else { return }
                    self.resumed = true
                    self.connection.cancel()
                    continuation.resume(with: result)
                }
            }

            // Timeout
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(TCPAuthError.timeout))
            }

            connection.stateUpdateHandler = { [self] state in
                switch state {
                case .ready:
                    self.performHandshake(finish: finish)
                case .failed(let error):
                    finish(.failure(TCPAuthError.connectionFailed(error.localizedDescription)))
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    // MARK: - Protocol Implementation

    private func performHandshake(finish: @Sendable @escaping (Result<UInt8, Error>) -> Void) {
        // Step 1: Read 52-byte v2 challenge
        connection.receive(minimumIncompleteLength: challengeSize, maximumLength: challengeSize) { [self] data, _, _, error in
            if let error {
                finish(.failure(TCPAuthError.readFailed(error.localizedDescription)))
                return
            }
            guard let challengeData = data, challengeData.count == self.challengeSize else {
                finish(.failure(TCPAuthError.invalidChallenge("expected \(self.challengeSize) bytes, got \(data?.count ?? 0)")))
                return
            }

            // Step 2: Validate + sign + send response
            do {
                let response = try self.buildAuthResponse(challengeData: challengeData)

                self.connection.send(content: response, completion: .contentProcessed { sendError in
                    if let sendError {
                        finish(.failure(TCPAuthError.writeFailed(sendError.localizedDescription)))
                        return
                    }

                    // Step 3: Read auth result
                    self.connection.receive(minimumIncompleteLength: 1, maximumLength: 256) { resultData, _, _, recvError in
                        if let recvError {
                            finish(.failure(TCPAuthError.readFailed(recvError.localizedDescription)))
                            return
                        }
                        guard let resultData, !resultData.isEmpty else {
                            finish(.failure(TCPAuthError.invalidResponse))
                            return
                        }

                        let code = resultData[resultData.startIndex]
                        finish(.success(code))
                    }
                })
            } catch {
                finish(.failure(error))
            }
        }
    }

    /// Validate the challenge and build the auth response payload.
    ///
    /// Format: [1B userId_len][userId bytes][ECDSA signature]
    private func buildAuthResponse(challengeData: Data) throws -> Data {
        // Validate expiry: bytes [40:48] = expires_at as BigEndian uint64 unix timestamp
        let expiresAtRaw = challengeData[challengeData.startIndex + 40 ..< challengeData.startIndex + 48]
        let expiresAtUnix = expiresAtRaw.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtUnix))
        guard expiresAt > Date() else {
            throw TCPAuthError.challengeExpired
        }

        // Validate gateway_id if expected (bytes [48:52])
        if let gatewayId = expectedGatewayId, let gatewayIdData = gatewayId.data(using: .utf8) {
            let challengeGwBytes = challengeData[challengeData.startIndex + 48 ..< challengeData.startIndex + 52]
            let challengeGwId = challengeGwBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let digest = SHA256.hash(data: gatewayIdData)
            let expectedGwId = digest.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            if challengeGwId != expectedGwId {
                throw TCPAuthError.gatewayIdMismatch
            }
        }

        // Get userId from Keychain
        guard let userId = KeychainService.shared.readString(forKey: "com.mistyislet.userId"),
              let userIdData = userId.data(using: .utf8), !userIdData.isEmpty else {
            throw TCPAuthError.noUserId
        }

        // Build sign payload: nonce[32] || userId || "BLE" (transport binding)
        let nonce = challengeData.prefix(32)
        var signPayload = Data()
        signPayload.append(nonce)
        signPayload.append(userIdData)
        signPayload.append("BLE".data(using: .utf8)!)

        // Sign with Secure Enclave (ECDSA P-256 + SHA-256)
        let signature = try SecureEnclaveService.shared.sign(data: signPayload)

        // Build response: [1B len][userId][signature]
        var response = Data()
        response.append(UInt8(userIdData.count))
        response.append(userIdData)
        response.append(signature)

        return response
    }
}

// MARK: - Errors

enum TCPAuthError: Error, LocalizedError {
    case timeout
    case connectionFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case invalidChallenge(String)
    case challengeExpired
    case gatewayIdMismatch
    case noUserId
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .timeout: return "TCP connection timed out"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .readFailed(let msg): return "Read failed: \(msg)"
        case .writeFailed(let msg): return "Write failed: \(msg)"
        case .invalidChallenge(let msg): return "Invalid challenge: \(msg)"
        case .challengeExpired: return "Challenge expired"
        case .gatewayIdMismatch: return "Gateway ID mismatch"
        case .noUserId: return "No userId in Keychain"
        case .invalidResponse: return "Invalid auth response from gateway"
        }
    }
}
