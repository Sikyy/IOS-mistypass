import Foundation
import SwiftUI
import UIKit

@MainActor @Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    var user: UserProfile?

    init() {
        // Check for existing token
        if KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) != nil {
            isAuthenticated = true
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.login(email: email, password: password)

            // Store tokens
            try KeychainService.shared.save(response.tokens.accessToken, forKey: Constants.Keychain.accessTokenKey)
            try KeychainService.shared.save(response.tokens.refreshToken, forKey: Constants.Keychain.refreshTokenKey)

            user = response.user

            // Register device credential if no key exists
            if SecureEnclaveService.shared.getPrivateKey() == nil {
                try await registerDeviceCredential()
            }

            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        try? KeychainService.shared.delete(forKey: Constants.Keychain.accessTokenKey)
        try? KeychainService.shared.delete(forKey: Constants.Keychain.refreshTokenKey)
        user = nil
        isAuthenticated = false
    }

    private func registerDeviceCredential() async throws {
        _ = try SecureEnclaveService.shared.generateKeyPair()
        let publicKeyPEM = try SecureEnclaveService.shared.exportPublicKeyPEM()
        let deviceName = UIDevice.current.name
        _ = try await APIService.shared.registerCredential(
            publicKey: publicKeyPEM,
            deviceName: deviceName
        )
    }
}
