import Foundation

// MARK: - Network Manager

class NetworkManager {
    static let shared = NetworkManager()

    private init() {}

    // For development (simulator): 127.0.0.1
    // For production: will be updated later
    private let baseURL = "http://127.0.0.1:3000/api"

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
            if let accessToken = KeychainManager.shared.getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                throw NetworkError.unauthorized
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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid response", code: 0))
            }

            // ── DEBUG LOGGING ────────────────────────────────────────────
            #if DEBUG
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            print("[API] ◀ HTTP \(httpResponse.statusCode) \(url.path)")
            print("[API] Response body: \(rawBody)")
            #endif
            // ─────────────────────────────────────────────────────────────

            // Handle 401 - Token expired, try to refresh
            if httpResponse.statusCode == 401 {
                if requiresAuth, let refreshed = try? await refreshAccessToken() {
                    // Retry request with new token
                    request.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                    let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                          (200...299).contains(retryHttpResponse.statusCode) else {
                        throw NetworkError.unauthorized
                    }
                    return try decodeResponse(from: retryData)
                } else {
                    throw NetworkError.unauthorized
                }
            }

            // Handle error responses
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw NetworkError.serverError(apiError)
                }
                throw NetworkError.unknown(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
            }

            return try decodeResponse(from: data)

        } catch let error as NetworkError {
            throw error
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
            if let accessToken = KeychainManager.shared.getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                throw NetworkError.unauthorized
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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid response", code: 0))
            }

            // ── DEBUG LOGGING ────────────────────────────────────────────
            #if DEBUG
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            print("[API] ◀ MULTIPART HTTP \(httpResponse.statusCode) \(url.path)")
            print("[API] Response body: \(rawBody)")
            #endif
            // ─────────────────────────────────────────────────────────────

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw NetworkError.serverError(apiError)
                }
                throw NetworkError.unknown(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
            }

            return try decodeResponse(from: data)

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

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainManager.shared.getRefreshToken() else {
            throw NetworkError.unauthorized
        }

        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let response: RefreshTokenResponse = try await self.request(
            endpoint: "/auth/refresh",
            method: .post,
            body: request,
            requiresAuth: false
        )

        KeychainManager.shared.saveAccessToken(response.accessToken)
        return response.accessToken
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
