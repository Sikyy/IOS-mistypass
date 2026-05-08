import Foundation

@MainActor @Observable
final class ProfileViewModel {
    var user: UserProfile?
    var credentials: [Credential] = []
    var logins: [UserLogin] = []
    var isLoading = false
    var isLoadingLogins = false
    var errorMessage: String?
    var successMessage: String?

    func fetchProfile() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true

        do {
            async let profileResult = APIService.shared.fetchProfile()
            async let credentialsResult = APIService.shared.fetchCredentials()
            user = try await profileResult
            credentials = try await credentialsResult
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func fetchLogins() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoadingLogins = true
        do {
            logins = try await APIService.shared.fetchMyLogins()
        } catch {
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        if logins.isEmpty { logins = PreviewData.logins }
        #endif
        isLoadingLogins = false
    }

    func remoteLogout(_ login: UserLogin) async {
        do {
            try await APIService.shared.remoteLogout(loginId: login.id)
            logins.removeAll { $0.id == login.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokeCredential(_ credential: Credential) async {
        do {
            try await APIService.shared.revokeCredential(id: credential.id)
            credentials.removeAll { $0.id == credential.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadAvatar(_ imageData: Data) async {
        do {
            user = try await APIService.shared.uploadAvatar(imageData: imageData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        do {
            try await APIService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            successMessage = "Password changed successfully"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setPrimaryDevice() async {
        do {
            try await APIService.shared.setPrimaryDevice()
            successMessage = "This device is now your primary device"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
