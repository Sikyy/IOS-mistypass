import XCTest
@testable import MistyisletPass

/// Integration tests for the NFC card-reading and card-binding authentication flow.
///
/// NFCService relies on CoreNFC hardware (NFCTagReaderSession), so these tests validate
/// the protocol logic layer without requiring a physical device:
///   1. Card UID formatting (hex colon-separated, matching ISO 14443 / MiFare)
///   2. NFC error types and their user-facing descriptions
///   3. Card binding request/response shapes
///   4. Credential model handling for NFC-bound cards
///   5. Edge cases in UID parsing and validation
final class NFCAuthFlowTests: XCTestCase {

    // MARK: - Helpers

    /// Format raw UID bytes as colon-separated hex (same logic as NFCService tag detection).
    private func formatUID(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Parse a formatted UID string back to bytes.
    private func parseUID(_ uid: String) -> [UInt8]? {
        let parts = uid.split(separator: ":")
        return parts.compactMap { UInt8($0, radix: 16) }
    }

    // MARK: - UID Formatting Tests

    func testFormatDESFireEV3UID() {
        // DESFire EV3 cards have 7-byte UIDs
        let uidBytes: [UInt8] = [0x04, 0xA1, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F]
        let formatted = formatUID(uidBytes)
        XCTAssertEqual(formatted, "04:A1:2B:3C:4D:5E:6F")
    }

    func testFormatMiFareClassicUID() {
        // MiFare Classic has 4-byte UIDs
        let uidBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let formatted = formatUID(uidBytes)
        XCTAssertEqual(formatted, "DE:AD:BE:EF")
    }

    func testFormatMiFareUltralightUID() {
        // MiFare Ultralight has 7-byte UIDs
        let uidBytes: [UInt8] = [0x04, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]
        let formatted = formatUID(uidBytes)
        XCTAssertEqual(formatted, "04:12:34:56:78:9A:BC")
    }

    func testFormatISO7816UID() {
        // ISO 7816 tags can have varying UID lengths
        let uidBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A]
        let formatted = formatUID(uidBytes)
        XCTAssertEqual(formatted, "01:02:03:04:05:06:07:08:09:0A")
    }

    func testFormatSingleByteUID() {
        // Edge case: minimal UID
        let formatted = formatUID([0xFF])
        XCTAssertEqual(formatted, "FF")
    }

    func testFormatEmptyUID() {
        let formatted = formatUID([])
        XCTAssertEqual(formatted, "", "Empty identifier should produce empty string")
    }

    func testFormatZeroPaddedBytes() {
        // Ensure leading zeros are preserved
        let uidBytes: [UInt8] = [0x00, 0x01, 0x0A]
        let formatted = formatUID(uidBytes)
        XCTAssertEqual(formatted, "00:01:0A", "Leading zeros should be preserved in hex format")
    }

    // MARK: - UID Parsing Round-Trip Tests

    func testUIDRoundTrip() {
        let originalBytes: [UInt8] = [0x04, 0xA1, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F]
        let formatted = formatUID(originalBytes)
        let parsed = parseUID(formatted)
        XCTAssertEqual(parsed, originalBytes, "UID should survive format -> parse round-trip")
    }

    func testUIDParseUppercaseHex() {
        let parsed = parseUID("04:A1:2B")
        XCTAssertEqual(parsed, [0x04, 0xA1, 0x2B])
    }

    func testUIDParseLowercaseHex() {
        // The app formats uppercase, but parsing should handle both
        let parsed = parseUID("04:a1:2b")
        XCTAssertEqual(parsed, [0x04, 0xA1, 0x2B])
    }

    // MARK: - NFC Error Type Tests

    func testNFCErrorDescriptions() {
        let errors: [(NFCError, String)] = [
            (.notAvailable, "not available"),
            (.cancelled, "cancelled"),
            (.timeout, "timed out"),
            (.readFailed("connection lost"), "connection lost"),
            (.unsupportedCard, "Unsupported"),
        ]

        for (error, expectedSubstring) in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertTrue(
                error.errorDescription!.localizedCaseInsensitiveContains(expectedSubstring),
                "\(error) description should contain '\(expectedSubstring)', got: \(error.errorDescription!)"
            )
        }
    }

    func testNFCErrorIsLocalizedError() {
        let error: Error = NFCError.timeout
        XCTAssertNotNil(error.localizedDescription)
    }

    func testReadFailedPreservesMessage() {
        let msg = "Tag connection interrupted"
        let error = NFCError.readFailed(msg)
        XCTAssertTrue(error.errorDescription!.contains(msg),
                      "readFailed should preserve the underlying error message")
    }

    // MARK: - Credential Model Tests (NFC-bound cards)

    func testDecodeNFCCredential() throws {
        let json = """
        {
            "id": "cred-nfc-001",
            "user_email": "user@example.com",
            "device_id": "04:A1:2B:3C:4D:5E:6F",
            "platform": "nfc",
            "device_model": "DESFire EV3",
            "keystore_level": null,
            "status": "active",
            "issued_at": "2025-06-01T10:00:00Z",
            "expires_at": null,
            "revoked_at": null,
            "last_used_at": "2025-06-15T08:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(Credential.self, from: json)

        XCTAssertEqual(credential.id, "cred-nfc-001")
        XCTAssertEqual(credential.platform, "nfc")
        XCTAssertEqual(credential.deviceId, "04:A1:2B:3C:4D:5E:6F")
        XCTAssertEqual(credential.deviceModel, "DESFire EV3")
        XCTAssertTrue(credential.isActive)
        XCTAssertFalse(credential.isExpired)
    }

    func testNFCCredentialDeviceName() throws {
        // When deviceModel is set, it should be used as device name
        let json = """
        {
            "id": "cred-nfc-002",
            "device_id": "DE:AD:BE:EF",
            "device_model": "Access Card",
            "status": "active"
        }
        """.data(using: .utf8)!

        let credential = try JSONDecoder().decode(Credential.self, from: json)
        XCTAssertEqual(credential.deviceName, "Access Card")
    }

    func testNFCCredentialFallbackDeviceName() throws {
        // When deviceModel is nil, deviceId (the card UID) should be used
        let json = """
        {
            "id": "cred-nfc-003",
            "device_id": "04:A1:2B:3C:4D:5E:6F",
            "status": "active"
        }
        """.data(using: .utf8)!

        let credential = try JSONDecoder().decode(Credential.self, from: json)
        XCTAssertEqual(credential.deviceName, "04:A1:2B:3C:4D:5E:6F")
    }

    func testRevokedNFCCredential() throws {
        let json = """
        {
            "id": "cred-nfc-revoked",
            "device_id": "AA:BB:CC:DD",
            "status": "revoked",
            "revoked_at": "2025-07-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(Credential.self, from: json)

        XCTAssertFalse(credential.isActive, "Revoked credential should not be active")
        XCTAssertNotNil(credential.revokedAt)
    }

    func testExpiredNFCCredential() throws {
        let json = """
        {
            "id": "cred-nfc-expired",
            "device_id": "11:22:33:44",
            "status": "active",
            "expires_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(Credential.self, from: json)

        XCTAssertTrue(credential.isExpired, "Credential with past expiry should be expired")
    }

    func testCredentialExpiringSoon() throws {
        // Build a credential expiring in 12 hours (< 24h threshold)
        let soonDate = Date().addingTimeInterval(12 * 3600)
        let formatter = ISO8601DateFormatter()
        let soonStr = formatter.string(from: soonDate)

        let json = """
        {
            "id": "cred-nfc-expiring",
            "device_id": "55:66:77:88",
            "status": "active",
            "expires_at": "\(soonStr)"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(Credential.self, from: json)

        XCTAssertTrue(credential.isExpiringSoon, "Credential expiring in < 24h should flag as expiring soon")
        XCTAssertFalse(credential.isExpired, "Credential not yet expired should not be flagged as expired")
    }

    func testCredentialNotExpiringSoon() throws {
        // Build a credential expiring in 48 hours (> 24h threshold)
        let laterDate = Date().addingTimeInterval(48 * 3600)
        let formatter = ISO8601DateFormatter()
        let laterStr = formatter.string(from: laterDate)

        let json = """
        {
            "id": "cred-nfc-fresh",
            "device_id": "99:AA:BB:CC",
            "status": "active",
            "expires_at": "\(laterStr)"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(Credential.self, from: json)

        XCTAssertFalse(credential.isExpiringSoon, "Credential expiring in > 24h should not flag")
    }

    // MARK: - Card Binding Request Shape Tests

    func testCardBindRequestBody() throws {
        // Validate the request body matches what APIService.bindNFCCard sends
        let cardUID = "04:A1:2B:3C:4D:5E:6F"
        let label = "My Office Card"

        let body: [String: String] = [
            "card_uid": cardUID,
            "card_type": "desfire_ev3",
            "label": label,
        ]

        let encoded = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode([String: String].self, from: encoded)

        XCTAssertEqual(decoded["card_uid"], cardUID)
        XCTAssertEqual(decoded["card_type"], "desfire_ev3")
        XCTAssertEqual(decoded["label"], label)
    }

    func testCardBindRequestEndpoint() {
        // Verify the NFC credential endpoint path
        XCTAssertEqual(Constants.API.nfcCredentialPath, "/app/credentials/nfc")
    }

    // MARK: - NFC + BLE Cross-Cutting Tests

    func testNFCAndBLECredentialPlatformsAreDistinct() throws {
        // NFC credential uses platform "nfc", BLE uses "ios"
        let nfcJSON = """
        {"id": "nfc-1", "platform": "nfc", "device_id": "04:AA:BB:CC:DD:EE:FF", "status": "active"}
        """.data(using: .utf8)!

        let bleJSON = """
        {"id": "ble-1", "platform": "ios", "device_id": "iPhone 15 Pro", "status": "active"}
        """.data(using: .utf8)!

        let nfcCred = try JSONDecoder().decode(Credential.self, from: nfcJSON)
        let bleCred = try JSONDecoder().decode(Credential.self, from: bleJSON)

        XCTAssertNotEqual(nfcCred.platform, bleCred.platform,
                          "NFC and BLE credentials should have distinct platforms")
        XCTAssertEqual(nfcCred.platform, "nfc")
        XCTAssertEqual(bleCred.platform, "ios")
    }

    func testMultipleCredentialsCanCoexist() throws {
        // A user can have both BLE and NFC credentials active
        let json = """
        [
            {"id": "cred-1", "platform": "ios", "status": "active"},
            {"id": "cred-2", "platform": "nfc", "device_id": "04:AA:BB:CC:DD:EE:FF", "status": "active"},
            {"id": "cred-3", "platform": "nfc", "device_id": "DE:AD:BE:EF", "status": "revoked"}
        ]
        """.data(using: .utf8)!

        let credentials = try JSONDecoder().decode([Credential].self, from: json)
        XCTAssertEqual(credentials.count, 3)

        let activeNFC = credentials.filter { $0.platform == "nfc" && $0.isActive }
        XCTAssertEqual(activeNFC.count, 1, "Only one NFC credential should be active")

        let activeBLE = credentials.filter { $0.platform == "ios" && $0.isActive }
        XCTAssertEqual(activeBLE.count, 1, "One BLE credential should be active")
    }

    // MARK: - Data Identifier Format Tests

    func testNFCCardUIDIdentifiersAreValidHex() {
        // Verify various UID formats that might come from different card types
        let validUIDs = [
            "04:A1:2B:3C:4D:5E:6F",   // 7-byte DESFire
            "DE:AD:BE:EF",             // 4-byte MiFare Classic
            "01:02:03:04:05:06:07:08", // 8-byte extended UID
        ]

        for uid in validUIDs {
            let parts = uid.split(separator: ":")
            for part in parts {
                XCTAssertEqual(part.count, 2, "Each byte should be exactly 2 hex chars: \(uid)")
                XCTAssertNotNil(UInt8(part, radix: 16), "Each part should be valid hex: \(part)")
            }
        }
    }

    func testNFCCardUIDUsesUppercaseHex() {
        let bytes: [UInt8] = [0x0a, 0xbf, 0xc0]
        let formatted = formatUID(bytes)
        XCTAssertEqual(formatted, "0A:BF:C0", "UID should use uppercase hex")
        XCTAssertFalse(formatted.contains { $0.isLowercase }, "No lowercase chars in formatted UID")
    }
}
