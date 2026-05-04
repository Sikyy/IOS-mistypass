import Foundation

@MainActor @Observable
final class ProfileViewModel {
    var user: UserProfile?
    var credentials: [Credential] = []
    var isLoading = false
    var errorMessage: String?

    func fetchProfile() async {
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

    func revokeCredential(_ credential: Credential) async {
        do {
            try await APIService.shared.revokeCredential(id: credential.id)
            credentials.removeAll { $0.id == credential.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
