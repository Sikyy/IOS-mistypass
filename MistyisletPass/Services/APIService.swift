import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String?)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg ?? "Unknown")"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .decodingError(let err): return "Data error: \(err.localizedDescription)"
        }
    }
}

@Observable
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Coordinates concurrent token refreshes so two parallel 401s don't
    /// race and burn the refresh token twice. Access only via `refreshLock`.
    private let refreshLock = TokenRefreshLock()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(email: email, password: password)
        return try await post(path: Constants.API.loginPath, body: body, authenticated: false)
    }

    func refreshToken(refreshToken: String) async throws -> AuthTokens {
        let body = ["refresh_token": refreshToken]
        return try await post(path: Constants.API.refreshPath, body: body, authenticated: false)
    }

    // MARK: - Doors

    func fetchDoors() async throws -> [Door] {
        try await get(path: Constants.API.doorsPath)
    }

    /// Remote (server-side) unlock. Backend dispatches to the relevant gateway.
    /// Body shape matches Android `UnlockRequest` and Go `appUnlockDoor` handler.
    func remoteUnlock(doorId: String) async throws -> RemoteUnlockResponse {
        let body = UnlockRequestBody(lockId: doorId, bleToken: nil)
        return try await post(path: Constants.API.unlockPath, body: body)
    }

    // MARK: - Credentials

    /// Register a BLE mobile credential public key with the backend.
    /// Payload shape matches Android `RegisterMobileCredentialRequest`.
    func registerCredential(publicKey: String, deviceName: String) async throws -> Credential {
        let body = RegisterMobileCredentialBody(
            publicKeyPem: publicKey,
            platform: "ios",
            deviceId: deviceName,
            deviceModel: deviceName,
            keystoreLevel: "secure_enclave",
            attestationCertChain: []
        )
        let response: RegisterMobileCredentialResponse = try await post(
            path: Constants.API.mobileCredentialRegisterPath,
            body: body
        )
        return response.credential
    }

    func fetchCredentials() async throws -> [Credential] {
        try await get(path: Constants.API.mobileCredentialsPath)
    }

    func revokeCredential(id: String) async throws {
        let _: Empty = try await delete(path: "\(Constants.API.mobileCredentialsPath)/\(id)")
    }

    // MARK: - Events

    func fetchEvents(offset: Int = 0, limit: Int = 20) async throws -> [AccessEvent] {
        try await get(path: "\(Constants.API.logsPath)?offset=\(offset)&limit=\(limit)")
    }

    // MARK: - Visitors

    func fetchVisitors() async throws -> [Visitor] {
        try await get(path: Constants.API.visitorPassesPath)
    }

    func createVisitor(_ request: CreateVisitorRequest) async throws -> Visitor {
        try await post(path: Constants.API.visitorPassesPath, body: request)
    }

    // MARK: - Profile

    func fetchProfile() async throws -> UserProfile {
        try await get(path: Constants.API.mePath)
    }

    // MARK: - Generic Request Methods

    private func get<T: Decodable>(path: String, authenticated: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", authenticated: authenticated)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(
        path: String,
        body: B?,
        authenticated: Bool = true
    ) async throws -> T {
        var request = try buildRequest(path: path, method: "POST", authenticated: authenticated)
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await execute(request)
    }

    private func delete<T: Decodable>(path: String, authenticated: Bool = true) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE", authenticated: authenticated)
        return try await execute(request)
    }

    private func buildRequest(path: String, method: String, authenticated: Bool) throws -> URLRequest {
        guard let url = URL(string: Constants.API.baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if authenticated {
            if let token = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest, retryOnUnauthorized: Bool = true) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0, "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            if retryOnUnauthorized {
                let refreshed = await refreshLock.refresh { [weak self] in
                    await self?.performTokenRefresh() ?? false
                }
                if refreshed {
                    var retryRequest = request
                    if let newToken = KeychainService.shared.readString(forKey: Constants.Keychain.accessTokenKey) {
                        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    }
                    return try await execute(retryRequest, retryOnUnauthorized: false)
                }
            }
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Performs the actual token refresh. Called at most once per concurrent
    /// burst of 401s — see `TokenRefreshLock`.
    private func performTokenRefresh() async -> Bool {
        guard let storedRefresh = KeychainService.shared.readString(forKey: Constants.Keychain.refreshTokenKey) else {
            return false
        }

        do {
            let tokens = try await refreshToken(refreshToken: storedRefresh)
            try KeychainService.shared.save(tokens.accessToken, forKey: Constants.Keychain.accessTokenKey)
            try KeychainService.shared.save(tokens.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
            return true
        } catch {
            return false
        }
    }
}

/// Coalesces concurrent token refresh attempts into a single in-flight Task.
/// Without this, two parallel 401 responses would each fire a refresh call
/// and the second one would invalidate the first's refresh token mid-flight.
private actor TokenRefreshLock {
    private var inFlight: Task<Bool, Never>?

    func refresh(_ work: @Sendable @escaping () async -> Bool) async -> Bool {
        if let existing = inFlight {
            return await existing.value
        }
        let task = Task { await work() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}

// Helper for endpoints that return no meaningful body
private struct Empty: Codable {}
