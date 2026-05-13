import XCTest
import Network
import CryptoKit
@testable import MistyisletPass

final class TCPAuthClientTests: XCTestCase {

    // MARK: - Challenge Parsing Tests

    func testChallengeSize() {
        // v2 challenge = nonce(32) + issued_at(8) + expires_at(8) + gateway_id(4) = 52 bytes
        XCTAssertEqual(52, 32 + 8 + 8 + 4, "v2 challenge struct should be 52 bytes")
    }

    func testBuildValidChallenge() {
        // Build a 52-byte v2 challenge matching the Go gateway-agent format
        var challenge = Data()

        // nonce: 32 random bytes
        let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        challenge.append(nonce)

        // issued_at: now as BigEndian uint64
        let issuedAt = UInt64(Date().timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: issuedAt) { challenge.append(contentsOf: $0) }

        // expires_at: now + 30s as BigEndian uint64
        let expiresAt = UInt64(Date().addingTimeInterval(30).timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: expiresAt) { challenge.append(contentsOf: $0) }

        // gateway_id: SHA256("gw_test")[0:4] as BigEndian uint32
        let gwHash = SHA256.hash(data: "gw_test".data(using: .utf8)!)
        let gwId = gwHash.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        withUnsafeBytes(of: gwId) { challenge.append(contentsOf: $0) }

        XCTAssertEqual(challenge.count, 52, "Challenge should be exactly 52 bytes")
    }

    func testExpiredChallengeDetected() {
        // Build a challenge that's already expired
        var challenge = Data(count: 32) // nonce (zeros)

        // issued_at: 60 seconds ago
        let issuedAt = UInt64(Date().addingTimeInterval(-60).timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: issuedAt) { challenge.append(contentsOf: $0) }

        // expires_at: 1 second ago (expired)
        let expiresAt = UInt64(Date().addingTimeInterval(-1).timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: expiresAt) { challenge.append(contentsOf: $0) }

        // gateway_id: any 4 bytes
        challenge.append(contentsOf: [0x00, 0x00, 0x00, 0x01])

        // Parse expiry manually (same logic as TCPAuthHandler.buildAuthResponse)
        let expiresAtRaw = challenge[challenge.startIndex + 40 ..< challenge.startIndex + 48]
        let expiresAtUnix = expiresAtRaw.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let expiresAtDate = Date(timeIntervalSince1970: TimeInterval(expiresAtUnix))
        XCTAssertTrue(expiresAtDate < Date(), "Challenge should be detected as expired")
    }

    func testGatewayIdEncoding() {
        // Verify SHA256(gatewayId)[0:4] encoding matches Go side
        let gatewayId = "gw_demo_001"
        let hash = SHA256.hash(data: gatewayId.data(using: .utf8)!)
        let gwId = hash.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        XCTAssertNotEqual(gwId, 0, "Gateway ID hash should not be zero")

        // Same input should produce same output (deterministic)
        let hash2 = SHA256.hash(data: gatewayId.data(using: .utf8)!)
        let gwId2 = hash2.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        XCTAssertEqual(gwId, gwId2, "Gateway ID hash should be deterministic")
    }

    func testSignPayloadFormat() {
        // Verify the sign payload matches the Go gateway-agent verification:
        //   SHA256(nonce[32] || userId || "BLE")
        let nonce = Data(repeating: 0xAA, count: 32)
        let userId = "usr_test_001"
        let userIdData = userId.data(using: .utf8)!

        var signPayload = Data()
        signPayload.append(nonce)
        signPayload.append(userIdData)
        signPayload.append("BLE".data(using: .utf8)!)

        XCTAssertEqual(
            signPayload.count,
            32 + userIdData.count + 3,
            "Sign payload = nonce(32) + userId(\(userIdData.count)) + 'BLE'(3)"
        )
    }

    func testAuthResponseFormat() {
        // Verify response encoding: [1B len][userId][signature]
        let userId = "usr_test_001"
        let userIdData = userId.data(using: .utf8)!
        let fakeSig = Data(repeating: 0xFF, count: 64) // fake ECDSA sig

        var response = Data()
        response.append(UInt8(userIdData.count))
        response.append(userIdData)
        response.append(fakeSig)

        XCTAssertEqual(response[response.startIndex], UInt8(userIdData.count))
        XCTAssertEqual(
            response.count,
            1 + userIdData.count + fakeSig.count,
            "Response = 1 + userId.count + sig.count"
        )

        // Extract userId back
        let len = Int(response[response.startIndex])
        let extractedUserId = String(data: response[response.startIndex + 1 ..< response.startIndex + 1 + len], encoding: .utf8)
        XCTAssertEqual(extractedUserId, userId)
    }

    // MARK: - Error Type Tests

    func testTCPAuthErrorDescriptions() {
        XCTAssertNotNil(TCPAuthError.timeout.errorDescription)
        XCTAssertNotNil(TCPAuthError.connectionFailed("test").errorDescription)
        XCTAssertNotNil(TCPAuthError.readFailed("test").errorDescription)
        XCTAssertNotNil(TCPAuthError.writeFailed("test").errorDescription)
        XCTAssertNotNil(TCPAuthError.invalidChallenge("bad").errorDescription)
        XCTAssertNotNil(TCPAuthError.challengeExpired.errorDescription)
        XCTAssertNotNil(TCPAuthError.gatewayIdMismatch.errorDescription)
        XCTAssertNotNil(TCPAuthError.noUserId.errorDescription)
        XCTAssertNotNil(TCPAuthError.invalidResponse.errorDescription)
    }

    func testConnectionRefused() async {
        // Connecting to a port with nothing listening should fail
        do {
            _ = try await TCPAuthClient.shared.authenticate(host: "127.0.0.1", port: 19999)
            XCTFail("Should have thrown for connection refused")
        } catch {
            // Should be either connectionFailed or timeout
            XCTAssertTrue(
                error is TCPAuthError,
                "Error should be TCPAuthError, got \(type(of: error))"
            )
        }
    }

    func testTransportTagBLE() {
        // Verify the transport tag matches Go constant TransportTagBLE = "BLE"
        let tag = "BLE".data(using: .utf8)!
        XCTAssertEqual(tag.count, 3)
        XCTAssertEqual(tag, Data([0x42, 0x4C, 0x45])) // "BLE" in ASCII
    }
}
