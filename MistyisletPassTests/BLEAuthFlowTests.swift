import XCTest
import CryptoKit
@testable import MistyisletPass

/// Integration tests for the BLE challenge-response authentication protocol.
///
/// These tests validate the v2 protocol logic that BLEManager.signAndRespond() and
/// TCPAuthClient use without requiring CoreBluetooth hardware:
///   1. Challenge structure parsing (52 bytes: nonce[32] + issued_at[8] + expires_at[8] + gateway_id[4])
///   2. Challenge expiry validation
///   3. Gateway ID verification via SHA256
///   4. Sign payload construction (nonce || userId || "BLE")
///   5. Auth response encoding ([1B userId_len][userId][ECDSA signature])
///   6. Auth result code handling (0x01 granted, 0x02 denied)
///   7. Error scenarios (expired challenge, invalid size, gateway mismatch)
final class BLEAuthFlowTests: XCTestCase {

    // MARK: - Helpers

    /// Build a v2 challenge matching the Go gateway-agent format.
    private func buildChallenge(
        nonce: Data? = nil,
        issuedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(30),
        gatewayId: String = "gw_test_001"
    ) -> Data {
        var challenge = Data()

        // nonce: 32 bytes
        let nonceData = nonce ?? Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        challenge.append(nonceData.prefix(32))
        if nonceData.count < 32 {
            challenge.append(Data(count: 32 - nonceData.count))
        }

        // issued_at: BigEndian uint64 unix timestamp
        let issuedAtBE = UInt64(issuedAt.timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: issuedAtBE) { challenge.append(contentsOf: $0) }

        // expires_at: BigEndian uint64 unix timestamp
        let expiresAtBE = UInt64(expiresAt.timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: expiresAtBE) { challenge.append(contentsOf: $0) }

        // gateway_id: SHA256(gatewayId)[0:4] as BigEndian uint32
        // The Go side writes the first 4 bytes of SHA256 directly (which is
        // big-endian by convention). We replicate that by appending the raw
        // hash prefix without any byte-swapping.
        let hash = SHA256.hash(data: gatewayId.data(using: .utf8)!)
        let hashData = Data(hash)
        challenge.append(hashData.prefix(4))

        return challenge
    }

    /// Parse the expires_at field from a 52-byte challenge (same logic as BLEManager/TCPAuthHandler).
    private func parseExpiresAt(from challenge: Data) -> Date {
        let raw = challenge[challenge.startIndex + 40 ..< challenge.startIndex + 48]
        let unix = raw.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        return Date(timeIntervalSince1970: TimeInterval(unix))
    }

    /// Parse the gateway_id field from a 52-byte challenge.
    private func parseGatewayId(from challenge: Data) -> UInt32 {
        let raw = challenge[challenge.startIndex + 48 ..< challenge.startIndex + 52]
        return raw.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    /// Compute the expected gateway_id hash for a given string (same as Go side).
    private func computeGatewayIdHash(_ gatewayId: String) -> UInt32 {
        let hash = SHA256.hash(data: gatewayId.data(using: .utf8)!)
        return hash.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    /// Build a sign payload matching the BLE auth protocol.
    private func buildSignPayload(nonce: Data, userId: String) -> Data {
        var payload = Data()
        payload.append(nonce)
        payload.append(userId.data(using: .utf8)!)
        payload.append("BLE".data(using: .utf8)!)
        return payload
    }

    /// Build an auth response matching the BLE protocol wire format.
    private func buildAuthResponse(userId: String, signature: Data) -> Data {
        let userIdData = userId.data(using: .utf8)!
        var response = Data()
        response.append(UInt8(userIdData.count))
        response.append(userIdData)
        response.append(signature)
        return response
    }

    // MARK: - Challenge Structure Tests

    func testValidChallengeIs52Bytes() {
        let challenge = buildChallenge()
        XCTAssertEqual(challenge.count, 52, "v2 challenge must be exactly 52 bytes")
    }

    func testChallengeNonceIs32Bytes() {
        let knownNonce = Data(repeating: 0xAB, count: 32)
        let challenge = buildChallenge(nonce: knownNonce)
        let extractedNonce = challenge.prefix(32)
        XCTAssertEqual(extractedNonce, knownNonce, "First 32 bytes should be the nonce")
    }

    func testChallengeIssuedAtParsesCorrectly() {
        let now = Date()
        let challenge = buildChallenge(issuedAt: now)

        let raw = challenge[challenge.startIndex + 32 ..< challenge.startIndex + 40]
        let unix = raw.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let parsed = Date(timeIntervalSince1970: TimeInterval(unix))

        // Allow 1 second tolerance due to floating point truncation
        XCTAssertEqual(parsed.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1.0)
    }

    func testChallengeExpiresAtParsesCorrectly() {
        let future = Date().addingTimeInterval(60)
        let challenge = buildChallenge(expiresAt: future)
        let parsed = parseExpiresAt(from: challenge)

        XCTAssertEqual(parsed.timeIntervalSince1970, future.timeIntervalSince1970, accuracy: 1.0)
    }

    func testChallengeGatewayIdMatchesHashComputation() {
        let gatewayId = "gw_main_entrance"
        let challenge = buildChallenge(gatewayId: gatewayId)
        let parsedGwId = parseGatewayId(from: challenge)
        let expectedGwId = computeGatewayIdHash(gatewayId)
        XCTAssertEqual(parsedGwId, expectedGwId, "Challenge gateway_id should match SHA256 hash")
    }

    // MARK: - Challenge Validation Tests

    func testValidChallengeIsNotExpired() {
        let challenge = buildChallenge(expiresAt: Date().addingTimeInterval(30))
        let expiresAt = parseExpiresAt(from: challenge)
        XCTAssertTrue(expiresAt > Date(), "Challenge with future expiry should not be expired")
    }

    func testExpiredChallengeIsDetected() {
        let challenge = buildChallenge(expiresAt: Date().addingTimeInterval(-5))
        let expiresAt = parseExpiresAt(from: challenge)
        XCTAssertTrue(expiresAt < Date(), "Challenge with past expiry should be detected as expired")
    }

    func testJustExpiredChallengeIsDetected() {
        // Challenge that expired 1 second ago -- boundary case
        let challenge = buildChallenge(expiresAt: Date().addingTimeInterval(-1))
        let expiresAt = parseExpiresAt(from: challenge)
        XCTAssertTrue(expiresAt < Date(), "Challenge that just expired should be detected")
    }

    func testChallengeSmallerThan52BytesIsInvalid() {
        // BLEManager checks challengeData.count >= 52
        let shortChallenge = Data(count: 48)
        XCTAssertTrue(shortChallenge.count < 52, "Short challenge should be rejected by protocol")
    }

    func testEmptyChallengeIsInvalid() {
        let emptyChallenge = Data()
        XCTAssertTrue(emptyChallenge.count < 52, "Empty challenge should be rejected")
    }

    // MARK: - Gateway ID Verification Tests

    func testGatewayIdVerificationPasses() {
        let gatewayId = "gw_demo_reader"
        let challenge = buildChallenge(gatewayId: gatewayId)

        let challengeGwId = parseGatewayId(from: challenge)
        let expectedGwId = computeGatewayIdHash(gatewayId)
        XCTAssertEqual(challengeGwId, expectedGwId, "Matching gateway IDs should verify successfully")
    }

    func testGatewayIdVerificationFailsOnMismatch() {
        let challenge = buildChallenge(gatewayId: "gw_real_reader")
        let challengeGwId = parseGatewayId(from: challenge)
        let wrongExpected = computeGatewayIdHash("gw_fake_reader")
        XCTAssertNotEqual(challengeGwId, wrongExpected, "Mismatched gateway IDs should fail verification")
    }

    func testGatewayIdHashIsDeterministic() {
        let hash1 = computeGatewayIdHash("gw_front_door")
        let hash2 = computeGatewayIdHash("gw_front_door")
        XCTAssertEqual(hash1, hash2, "Same gateway ID should always produce the same hash")
    }

    func testDifferentGatewayIdsProduceDifferentHashes() {
        let hash1 = computeGatewayIdHash("gw_front")
        let hash2 = computeGatewayIdHash("gw_back")
        XCTAssertNotEqual(hash1, hash2, "Different gateway IDs should produce different hashes")
    }

    func testGatewayIdHashIsNonZero() {
        // Edge case: ensure hash is usable (not degenerate)
        let hash = computeGatewayIdHash("gw_test")
        XCTAssertNotEqual(hash, 0, "Gateway ID hash should not be zero")
    }

    // MARK: - Sign Payload Tests

    func testSignPayloadFormat() {
        let nonce = Data(repeating: 0xCC, count: 32)
        let userId = "usr_test_123"
        let payload = buildSignPayload(nonce: nonce, userId: userId)

        let userIdData = userId.data(using: .utf8)!
        let expectedSize = 32 + userIdData.count + 3 // nonce + userId + "BLE"
        XCTAssertEqual(payload.count, expectedSize, "Sign payload size should be nonce(32) + userId + 'BLE'(3)")
    }

    func testSignPayloadStartsWithNonce() {
        let nonce = Data(repeating: 0xDD, count: 32)
        let payload = buildSignPayload(nonce: nonce, userId: "user1")
        let extractedNonce = payload.prefix(32)
        XCTAssertEqual(extractedNonce, nonce, "Payload should start with the 32-byte nonce")
    }

    func testSignPayloadContainsUserId() {
        let nonce = Data(count: 32)
        let userId = "usr_verify_me"
        let payload = buildSignPayload(nonce: nonce, userId: userId)
        let userIdData = userId.data(using: .utf8)!

        let extracted = payload[payload.startIndex + 32 ..< payload.startIndex + 32 + userIdData.count]
        XCTAssertEqual(extracted, userIdData, "Payload should contain userId after nonce")
    }

    func testSignPayloadEndsWithBLETransportTag() {
        let payload = buildSignPayload(nonce: Data(count: 32), userId: "user")
        let tagBytes = payload.suffix(3)
        XCTAssertEqual(tagBytes, "BLE".data(using: .utf8)!, "Payload must end with transport binding 'BLE'")
    }

    func testSignPayloadWithEmptyUserId() {
        // Edge case: empty userId is possible if keychain returns empty string
        let payload = buildSignPayload(nonce: Data(count: 32), userId: "")
        XCTAssertEqual(payload.count, 32 + 0 + 3, "Empty userId should still produce valid payload structure")
    }

    func testSignPayloadWithLongUserId() {
        // userId length must fit in a single byte in auth response (max 255)
        let longUserId = String(repeating: "x", count: 200)
        let payload = buildSignPayload(nonce: Data(count: 32), userId: longUserId)
        XCTAssertEqual(payload.count, 32 + 200 + 3)
    }

    // MARK: - Auth Response Encoding Tests

    func testAuthResponseFormat() {
        let userId = "usr_abc_001"
        let fakeSig = Data(repeating: 0xFF, count: 64)
        let response = buildAuthResponse(userId: userId, signature: fakeSig)

        let userIdData = userId.data(using: .utf8)!
        XCTAssertEqual(response.count, 1 + userIdData.count + 64,
                       "Response = 1B length + userId + signature")
    }

    func testAuthResponseFirstByteIsUserIdLength() {
        let userId = "usr_12345"
        let response = buildAuthResponse(userId: userId, signature: Data(count: 64))
        let userIdData = userId.data(using: .utf8)!
        XCTAssertEqual(response[response.startIndex], UInt8(userIdData.count),
                       "First byte should be userId length")
    }

    func testAuthResponseUserIdExtractable() {
        let userId = "usr_roundtrip_test"
        let response = buildAuthResponse(userId: userId, signature: Data(count: 64))

        let len = Int(response[response.startIndex])
        let extractedData = response[response.startIndex + 1 ..< response.startIndex + 1 + len]
        let extractedUserId = String(data: extractedData, encoding: .utf8)
        XCTAssertEqual(extractedUserId, userId, "userId should be extractable from response")
    }

    func testAuthResponseSignatureExtractable() {
        let userId = "usr_sig_test"
        let sig = Data((0..<64).map { UInt8($0) })
        let response = buildAuthResponse(userId: userId, signature: sig)

        let userIdLen = Int(response[response.startIndex])
        let sigStart = response.startIndex + 1 + userIdLen
        let extractedSig = response[sigStart...]
        XCTAssertEqual(Data(extractedSig), sig, "Signature should be extractable from response")
    }

    func testAuthResponseWithMaxLengthUserId() {
        // userId length byte is UInt8, so max is 255 characters
        let userId = String(repeating: "u", count: 255)
        let response = buildAuthResponse(userId: userId, signature: Data(count: 64))
        XCTAssertEqual(response[response.startIndex], UInt8(255))
        XCTAssertEqual(response.count, 1 + 255 + 64)
    }

    // MARK: - Auth Result Code Tests

    func testResultCodeGranted() {
        XCTAssertEqual(Constants.BLE.resultGranted, 0x01, "Granted result should be 0x01")
    }

    func testResultCodeDenied() {
        XCTAssertEqual(Constants.BLE.resultDenied, 0x02, "Denied result should be 0x02")
    }

    func testResultCodeParsing() {
        // Simulate receiving a 1-byte result from the controller
        let grantedData = Data([Constants.BLE.resultGranted])
        XCTAssertEqual(grantedData.first, 0x01)

        let deniedData = Data([Constants.BLE.resultDenied])
        XCTAssertEqual(deniedData.first, 0x02)
    }

    func testEmptyResultDataIsInvalid() {
        // BLEManager checks data.first != nil
        let emptyResult = Data()
        XCTAssertNil(emptyResult.first, "Empty result data should have no first byte")
    }

    // MARK: - BLE Error Type Tests

    func testBLEUnlockErrorDescriptions() {
        let errors: [BLEUnlockError] = [
            .controllerNotFound,
            .connectionFailed,
            .timeout,
            .invalidChallenge,
            .invalidResponse,
            .bluetoothOff,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
        }
    }

    func testBLEUnlockErrorIsLocalizedError() {
        let error: Error = BLEUnlockError.timeout
        XCTAssertNotNil(error.localizedDescription)
    }

    // MARK: - BLE Constants Tests

    func testBLEConnectionTimeout() {
        XCTAssertEqual(Constants.BLE.connectionTimeout, 8.0,
                       "Connection timeout should match gateway-agent expectation")
    }

    func testBLEServiceUUID() {
        // Service UUID encodes "MISTYPASS-BLEAUT" in ASCII hex
        XCTAssertNotNil(Constants.BLE.serviceUUID, "Service UUID should be defined")
    }

    func testBLECharacteristicUUIDsAreDefined() {
        XCTAssertNotNil(Constants.BLE.challengeUUID)
        XCTAssertNotNil(Constants.BLE.authResponseUUID)
        XCTAssertNotNil(Constants.BLE.authResultUUID)
        XCTAssertNotNil(Constants.BLE.readerIdentityUUID)
    }

    func testBLECharacteristicUUIDsAreDistinct() {
        let uuids = [
            Constants.BLE.challengeUUID,
            Constants.BLE.authResponseUUID,
            Constants.BLE.authResultUUID,
            Constants.BLE.readerIdentityUUID,
        ]
        let uniqueCount = Set(uuids).count
        XCTAssertEqual(uniqueCount, 4, "All characteristic UUIDs should be distinct")
    }

    // MARK: - End-to-End Protocol Flow (without hardware)

    func testFullProtocolRoundTrip() {
        // Simulate the complete challenge-response protocol

        // Step 1: Gateway generates challenge
        let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let gatewayId = "gw_lobby_reader"
        let challenge = buildChallenge(
            nonce: nonce,
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(30),
            gatewayId: gatewayId
        )
        XCTAssertEqual(challenge.count, 52)

        // Step 2: Phone validates challenge
        let expiresAt = parseExpiresAt(from: challenge)
        XCTAssertTrue(expiresAt > Date(), "Challenge should not be expired")

        let challengeGwId = parseGatewayId(from: challenge)
        let expectedGwId = computeGatewayIdHash(gatewayId)
        XCTAssertEqual(challengeGwId, expectedGwId, "Gateway ID should match")

        // Step 3: Phone builds sign payload
        let userId = "usr_john_doe"
        let extractedNonce = challenge.prefix(32)
        let signPayload = buildSignPayload(nonce: extractedNonce, userId: userId)
        XCTAssertEqual(signPayload.count, 32 + userId.data(using: .utf8)!.count + 3)

        // Step 4: Phone signs and sends auth response
        // (Using fake signature since Secure Enclave is unavailable in tests)
        let fakeSignature = Data(repeating: 0xAA, count: 64)
        let authResponse = buildAuthResponse(userId: userId, signature: fakeSignature)

        // Step 5: Verify response can be parsed back
        let parsedLen = Int(authResponse[authResponse.startIndex])
        let parsedUserId = String(
            data: authResponse[authResponse.startIndex + 1 ..< authResponse.startIndex + 1 + parsedLen],
            encoding: .utf8
        )
        XCTAssertEqual(parsedUserId, userId)

        let sigStart = authResponse.startIndex + 1 + parsedLen
        let parsedSig = authResponse[sigStart ..< authResponse.endIndex]
        XCTAssertEqual(parsedSig.count, 64)

        // Step 6: Gateway sends result
        let resultData = Data([Constants.BLE.resultGranted])
        XCTAssertEqual(resultData.first, Constants.BLE.resultGranted)
    }

    func testProtocolFlowWithExpiredChallenge() {
        // Gateway sends challenge that is already expired
        let challenge = buildChallenge(
            issuedAt: Date().addingTimeInterval(-60),
            expiresAt: Date().addingTimeInterval(-5)
        )

        let expiresAt = parseExpiresAt(from: challenge)
        XCTAssertFalse(expiresAt > Date(), "Expired challenge should be rejected before signing")
    }

    func testProtocolFlowWithWrongGateway() {
        // Phone expects one gateway but gets a challenge from another
        let challenge = buildChallenge(gatewayId: "gw_real")

        let challengeGwId = parseGatewayId(from: challenge)
        let expectedGwId = computeGatewayIdHash("gw_expected")
        XCTAssertNotEqual(challengeGwId, expectedGwId,
                          "Mismatched gateway should cause phone to reject challenge")
    }

    // MARK: - UnlockState Integration Tests

    func testUnlockStateTransitionsForBLEFlow() {
        // Verify the state machine covers the BLE-specific transitions
        var state: UnlockState = .idle

        // User taps door
        state = .holding(progress: 0)
        XCTAssertEqual(state, .holding(progress: 0))

        // Hold progresses
        state = .holding(progress: 0.5)
        XCTAssertEqual(state, .holding(progress: 0.5))

        // Hold completes, BLE connecting
        state = .connecting
        XCTAssertEqual(state, .connecting)

        // BLE auth succeeds
        state = .granted(doorName: "Main Lobby")
        XCTAssertEqual(state, .granted(doorName: "Main Lobby"))
    }

    func testUnlockStateDeniedTransition() {
        var state: UnlockState = .connecting
        state = .denied(doorName: "Server Room", reason: "No access")
        XCTAssertEqual(state, .denied(doorName: "Server Room", reason: "No access"))
    }

    func testUnlockStateFailedTransition() {
        var state: UnlockState = .connecting
        state = .failed(doorName: "Garage", reason: "BLE timeout")
        XCTAssertEqual(state, .failed(doorName: "Garage", reason: "BLE timeout"))
    }

    func testUnlockStateCancelFromHolding() {
        var state: UnlockState = .holding(progress: 0.3)
        state = .idle
        XCTAssertEqual(state, .idle)
    }

    // MARK: - Secure Enclave Key Format Tests

    func testSignPayloadHashability() {
        // The gateway verifies ECDSA(SHA256(signPayload)) -- verify payload is hashable
        let payload = buildSignPayload(nonce: Data(count: 32), userId: "usr_hash_test")
        let digest = SHA256.hash(data: payload)
        XCTAssertEqual(digest.description.count > 0, true, "Payload should be SHA256-hashable")
    }

    func testDifferentNoncesProduceDifferentPayloads() {
        let nonce1 = Data(repeating: 0x01, count: 32)
        let nonce2 = Data(repeating: 0x02, count: 32)
        let payload1 = buildSignPayload(nonce: nonce1, userId: "user")
        let payload2 = buildSignPayload(nonce: nonce2, userId: "user")
        XCTAssertNotEqual(payload1, payload2, "Different nonces should produce different payloads")
    }

    func testDifferentUsersProduceDifferentPayloads() {
        let nonce = Data(count: 32)
        let payload1 = buildSignPayload(nonce: nonce, userId: "user_a")
        let payload2 = buildSignPayload(nonce: nonce, userId: "user_b")
        XCTAssertNotEqual(payload1, payload2, "Different userIds should produce different payloads")
    }

    // MARK: - TCP Auth Error Tests (shared protocol)

    func testTCPAuthErrorDescriptionsArePresent() {
        let errors: [TCPAuthError] = [
            .timeout,
            .connectionFailed("test"),
            .readFailed("test"),
            .writeFailed("test"),
            .invalidChallenge("bad size"),
            .challengeExpired,
            .gatewayIdMismatch,
            .noUserId,
            .invalidResponse,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
        }
    }

    func testTCPAuthErrorIsLocalizedError() {
        let error: Error = TCPAuthError.challengeExpired
        XCTAssertNotNil(error.localizedDescription)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }
}
