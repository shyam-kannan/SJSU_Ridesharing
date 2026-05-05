import Foundation

// MARK: - Network Manager

class NetworkManager {
    static let shared = NetworkManager()

    private init() {}

    // Reads the API base URL from configuration so the app can target
    // localhost in development and GKE in production/testing.
    private let baseURL = APIConfig.baseURL

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private func restoreSavedSessionIfNeeded() {
        guard KeychainManager.shared.getAccessToken() == nil ||
                KeychainManager.shared.getRefreshToken() == nil,
              let userId = KeychainManager.shared.getUserId() else {
            return
        }

        if KeychainManager.shared.getAccessToken() == nil,
           let savedAccess = KeychainManager.shared.getAccessToken(for: userId) {
            KeychainManager.shared.saveAccessToken(savedAccess)
        }

        if KeychainManager.shared.getRefreshToken() == nil,
           let savedRefresh = KeychainManager.shared.getRefreshToken(for: userId) {
            KeychainManager.shared.saveRefreshToken(savedRefresh)
        }
    }

    // MARK: - Generic Request Method

    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        contentType: String = "application/json"
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Add auth token if required
        if requiresAuth {
            restoreSavedSessionIfNeeded()
            if let accessToken = KeychainManager.shared.getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                // No token in keychain — attempt a silent refresh before giving up.
                // This handles the case where the access token was cleared but a
                // refresh token still exists (e.g. app restart, token eviction).
                if let refreshed = try? await refreshAccessToken() {
                    request.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                } else {
                    throw NetworkError.unauthorized
                }
            }
        }

        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        // ── DEBUG LOGGING ──────────────────────────────────────────────────
        #if DEBUG
        print("\n[API] ▶ \(method.rawValue) \(url)")
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[API] Request body: \(bodyString)")
        }
        #endif
        // ───────────────────────────────────────────────────────────────────

        do {
            return try await performRequest(
                request: request,
                url: url,
                logPrefix: "[API]",
                requiresAuth: requiresAuth
            )
        } catch let error as NetworkError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Multipart Request (for file uploads)

    func uploadMultipart<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .post,
        parameters: [String: String] = [:],
        files: [String: (Data, String)] = [:],
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Add auth token if required
        if requiresAuth {
            restoreSavedSessionIfNeeded()
            if let accessToken = KeychainManager.shared.getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                if let refreshed = try? await refreshAccessToken() {
                    request.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                } else {
                    throw NetworkError.unauthorized
                }
            }
        }

        // Build multipart body
        var body = Data()

        // Add parameters
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        // Add files
        for (key, (data, filename)) in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        // ── DEBUG LOGGING ──────────────────────────────────────────────────
        #if DEBUG
        print("\n[API] ▶ MULTIPART \(method.rawValue) \(url)")
        print("[API] Content-Type: multipart/form-data; boundary=\(boundary)")
        print("[API] Body size: \(body.count) bytes")
        for (key, value) in parameters {
            print("[API] Form field '\(key)': \(value)")
        }
        for (key, (data, filename)) in files {
            print("[API] File field '\(key)': \(filename) (\(data.count) bytes)")
        }
        #endif
        // ───────────────────────────────────────────────────────────────────

        do {
            return try await performRequest(
                request: request,
                url: url,
                logPrefix: "[API]",
                requiresAuth: requiresAuth
            )
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Private Helpers

    private func decodeResponse<T: Codable>(from data: Data) throws -> T {
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            if let responseData = apiResponse.data {
                return responseData
            } else {
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                #if DEBUG
                print("[API] ⚠ Decode succeeded but data field is null. Full response: \(String(data: data, encoding: .utf8) ?? "")")
                #endif
                throw NetworkError.noData
            }
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[API] ✖ Decoding failed for \(T.self):")
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                print("  keyNotFound: '\(key.stringValue)' – \(ctx.debugDescription)")
            case .typeMismatch(let type, let ctx):
                print("  typeMismatch: expected \(type) – \(ctx.debugDescription)")
            case .valueNotFound(let type, let ctx):
                print("  valueNotFound: \(type) – \(ctx.debugDescription)")
            case .dataCorrupted(let ctx):
                print("  dataCorrupted: \(ctx.debugDescription)")
            @unknown default:
                print("  \(decodingError)")
            }
            #endif
            throw NetworkError.decodingError(decodingError)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    private func performRequest<T: Codable>(
        request: URLRequest,
        url: URL,
        logPrefix: String,
        requiresAuth: Bool
    ) async throws -> T {
        var request = request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "Invalid response", code: 0))
        }

        // ── DEBUG LOGGING ────────────────────────────────────────────
        #if DEBUG
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
        print("\(logPrefix) ◀ HTTP \(httpResponse.statusCode) \(url.path)")
        print("\(logPrefix) Response body: \(rawBody)")
        #endif
        // ─────────────────────────────────────────────────────────────

        if shouldRefreshToken(for: httpResponse.statusCode, data: data) {
            if requiresAuth, let refreshed = try? await refreshAccessToken() {
                request.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHttpResponse.statusCode) else {
                    if let retryHttpResponse = retryResponse as? HTTPURLResponse {
                        throw networkError(for: retryHttpResponse.statusCode, data: retryData)
                    }
                    throw NetworkError.unknown(NSError(domain: "Invalid response", code: 0))
                }
                return try decodeResponse(from: retryData)
            } else {
                throw NetworkError.unauthorized
            }
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw networkError(for: httpResponse.statusCode, data: data)
        }

        return try decodeResponse(from: data)
    }

    private func shouldRefreshToken(for statusCode: Int, data: Data) -> Bool {
        guard statusCode == 401 || statusCode == 403 else { return false }
        guard statusCode == 403 else { return true }

        if let apiError = try? decoder.decode(APIError.self, from: data) {
            let message = apiError.message.lowercased()
            return message.contains("expired token") ||
                message.contains("token expired") ||
                message.contains("invalid or expired token")
        }

        return false
    }

    private func networkError(for statusCode: Int, data: Data) -> NetworkError {
        switch statusCode {
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 408:
            return .timeout
        case 429:
            return .tooManyRequests
        default:
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                return .serverError(apiError)
            }
            return .unknown(NSError(domain: "HTTP \(statusCode)", code: statusCode))
        }
    }

    private func refreshAccessToken() async throws -> String {
        restoreSavedSessionIfNeeded()
        guard let refreshToken = KeychainManager.shared.getRefreshToken() else {
            throw NetworkError.unauthorized
        }

        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let tokenData: RefreshTokenResponse = try await self.request(
            endpoint: "/auth/refresh",
            method: .post,
            body: request,
            requiresAuth: false
        )

        KeychainManager.shared.saveAccessToken(tokenData.accessToken)
        if let userId = KeychainManager.shared.getUserId() {
            KeychainManager.shared.saveAccessToken(tokenData.accessToken, for: userId)
        }
        return tokenData.accessToken
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - Data Extension

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
