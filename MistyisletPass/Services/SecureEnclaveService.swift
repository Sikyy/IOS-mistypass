import Foundation
import Security

enum SecureEnclaveError: Error, LocalizedError {
    case keyGenerationFailed(String)
    case signingFailed(String)
    case publicKeyExportFailed
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let msg): return "Key generation failed: \(msg)"
        case .signingFailed(let msg): return "Signing failed: \(msg)"
        case .publicKeyExportFailed: return "Public key export failed"
        case .notAvailable: return "Secure Enclave not available"
        }
    }
}

final class SecureEnclaveService {
    nonisolated(unsafe) static let shared = SecureEnclaveService()
    private let tag = Data(Constants.Keychain.credentialTag.utf8)

    private init() {}

    // MARK: - Key Management

    /// Generate EC P-256 key pair in Secure Enclave (or software fallback)
    func generateKeyPair() throws -> SecKey {
        // Remove existing key if any
        deleteKeyPair()

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &accessError
        ) else {
            throw SecureEnclaveError.keyGenerationFailed(
                accessError?.takeRetainedValue().localizedDescription ?? "Access control creation failed"
            )
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access,
            ] as [String: Any],
        ]

        // Try Secure Enclave first
        if isSecureEnclaveAvailable() {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            // Fallback to software keychain if Secure Enclave fails
            if attributes[kSecAttrTokenID as String] != nil {
                attributes.removeValue(forKey: kSecAttrTokenID as String)
                guard let fallbackKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                    throw SecureEnclaveError.keyGenerationFailed(
                        error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                    )
                }
                return fallbackKey
            }
            throw SecureEnclaveError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            )
        }

        return privateKey
    }

    /// Get existing private key from keychain
    func getPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else { return nil }
        return item as? SecKey
    }

    /// Get the public key from the stored private key
    func getPublicKey() -> SecKey? {
        guard let privateKey = getPrivateKey() else { return nil }
        return SecKeyCopyPublicKey(privateKey)
    }

    /// Export public key as PEM-encoded PKIX (SubjectPublicKeyInfo).
    ///
    /// The Go backend (`parseBLEPublicKey` in `ble_protocol.go`) expects PEM with
    /// `-----BEGIN PUBLIC KEY-----` headers wrapping a DER-encoded PKIX structure.
    /// `SecKeyCopyExternalRepresentation` returns raw X9.63 (`0x04 || X || Y`),
    /// so we prepend the standard P-256 SubjectPublicKeyInfo header to convert.
    func exportPublicKeyPEM() throws -> String {
        guard let publicKey = getPublicKey() else {
            throw SecureEnclaveError.publicKeyExportFailed
        }

        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw SecureEnclaveError.publicKeyExportFailed
        }

        // ASN.1 SubjectPublicKeyInfo prefix for an EC P-256 (prime256v1) public key.
        // Decoded structure:
        //   SEQUENCE { SEQUENCE { OID ecPublicKey, OID prime256v1 }, BIT STRING (66 bytes) }
        let pkixPrefix: [UInt8] = [
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
            0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
            0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
            0x42, 0x00,
        ]
        let der = Data(pkixPrefix) + raw
        let b64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PUBLIC KEY-----\n\(b64)\n-----END PUBLIC KEY-----\n"
    }

    /// Delete the stored key pair
    func deleteKeyPair() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Signing

    /// Sign data using ECDSA with SHA-256
    func sign(data: Data) throws -> Data {
        guard let privateKey = getPrivateKey() else {
            throw SecureEnclaveError.signingFailed("No private key found")
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw SecureEnclaveError.signingFailed(
                error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            )
        }

        return signature
    }

    // MARK: - Helpers

    private lazy var _secureEnclaveAvailable: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        // All iPhones with A7+ (iPhone 5s and later) support Secure Enclave.
        // All devices supported by iOS 26 have Secure Enclave.
        return true
        #endif
    }()

    private func isSecureEnclaveAvailable() -> Bool {
        _secureEnclaveAvailable
    }
}
