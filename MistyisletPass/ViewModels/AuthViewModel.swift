import Foundation
import SwiftUI
import UIKit

@MainActor @Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    var user: UserProfile?

    // Multi-step login state
    var authStep: AuthStep = .emailEntry
    var email = ""
    var orgDomain = ""
    var orgConfig: OrgAuthConfig?
    var magicLinkSent = false

    enum AuthStep {
        case emailEntry
        case domainEntry
        case credentials
        case magicLinkSent
    }

    init() {
        if KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) != nil {
            isAuthenticated = true
        }
    }

    #if DEBUG
    func devAutoLogin() async {
        guard Constants.AppEnvironment.current == .dev, !isAuthenticated else { return }
        await login(email: "siky@mistyislet.com", password: "65552588")
    }
    #endif

    // MARK: - Step 1: Magic Link

    func requestMagicLink() async {
        guard !email.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            _ = try await APIService.shared.requestMagicLink(email: email)
            magicLinkSent = true
            authStep = .magicLinkSent
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func goToManualSignIn() {
        errorMessage = nil
        authStep = .domainEntry
    }

    // MARK: - Step 2: Organization Domain

    func lookupOrganization() async {
        guard !orgDomain.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            orgConfig = try await APIService.shared.lookupOrg(domain: orgDomain)
            authStep = .credentials
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func skipDomain() {
        orgConfig = nil
        authStep = .credentials
    }

    // MARK: - Step 3: Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.login(email: email, password: password)

            try KeychainService.shared.save(response.accessToken, forKey: Constants.Keychain.accessTokenKey)
            try KeychainService.shared.save(response.refreshToken, forKey: Constants.Keychain.refreshTokenKey)

            user = response.user

            if SecureEnclaveService.shared.getPrivateKey() == nil {
                do {
                    try await registerDeviceCredential()
                } catch {
                    AppLogger.auth.error("Device credential registration failed: \(error.localizedDescription)")
                }
            }

            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Password Recovery

    func restorePassword(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await APIService.shared.restorePassword(email: email)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Navigation

    func goBack() {
        errorMessage = nil
        switch authStep {
        case .domainEntry:
            authStep = .emailEntry
        case .credentials:
            authStep = .domainEntry
        case .magicLinkSent:
            authStep = .emailEntry
            magicLinkSent = false
        case .emailEntry:
            break
        }
    }

    func resetFlow() {
        authStep = .emailEntry
        email = ""
        orgDomain = ""
        orgConfig = nil
        magicLinkSent = false
        errorMessage = nil
    }

    // MARK: - Logout

    func logout() {
        do {
            try KeychainService.shared.delete(forKey: Constants.Keychain.accessTokenKey)
        } catch {
            AppLogger.auth.warning("Failed to delete access token from keychain: \(error.localizedDescription)")
        }
        do {
            try KeychainService.shared.delete(forKey: Constants.Keychain.refreshTokenKey)
        } catch {
            AppLogger.auth.warning("Failed to delete refresh token from keychain: \(error.localizedDescription)")
        }
        user = nil
        isAuthenticated = false
        resetFlow()
    }

    // MARK: - Private

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
