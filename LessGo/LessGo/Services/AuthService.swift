import Foundation
import UIKit

// MARK: - Auth Service

class AuthService {
    static let shared = AuthService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Authentication

    func register(name: String, email: String, password: String, role: UserRole) async throws -> AuthResponse {
        let request = RegisterRequest(
            name: name,
            email: email,
            password: password,
            role: role
        )

        #if DEBUG
        let encoder = JSONEncoder()
        if let bodyData = try? encoder.encode(request),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[AuthService] register() payload: \(bodyString)")
        }
        #endif

        do {
            let response: AuthResponse = try await network.request(
                endpoint: "/auth/register",
                method: .post,
                body: request,
                requiresAuth: false
            )

            // Save tokens
            KeychainManager.shared.saveAccessToken(response.accessToken)
            KeychainManager.shared.saveRefreshToken(response.refreshToken)
            KeychainManager.shared.saveUserId(response.user.id)

            #if DEBUG
            print("[AuthService] register() success – userId: \(response.user.id)")
            #endif

            return response
        } catch {
            #if DEBUG
            print("[AuthService] register() failed: \(error)")
            #endif
            throw error
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(email: email, password: password)

        let response: AuthResponse = try await network.request(
            endpoint: "/auth/login",
            method: .post,
            body: request,
            requiresAuth: false
        )

        // Save tokens
        KeychainManager.shared.saveAccessToken(response.accessToken)
        KeychainManager.shared.saveRefreshToken(response.refreshToken)
        KeychainManager.shared.saveUserId(response.user.id)

        return response
    }

    func logout() async throws {
        let _: EmptyResponse = try await network.request(
            endpoint: "/auth/logout",
            method: .post
        )

        // Clear all stored credentials
        KeychainManager.shared.clearAll()
    }

    func getCurrentUser() async throws -> User {
        let user: User = try await network.request(
            endpoint: "/auth/me",
            method: .get
        )
        return user
    }

    func verifyToken() async throws -> User {
        let response: TokenVerificationResponse = try await network.request(
            endpoint: "/auth/verify",
            method: .get
        )
        return response.user
    }

    // MARK: - SJSU ID Verification

    func uploadSJSUID(image: UIImage, userId: String) async throws -> User {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.unknown(NSError(domain: "Image conversion failed", code: 0))
        }

        let filename = "sjsu_id_\(userId)_\(Date().timeIntervalSince1970).jpg"

        let user: User = try await network.uploadMultipart(
            endpoint: "/auth/verify-id",
            parameters: ["userId": userId],
            files: ["sjsuId": (imageData, filename)]
        )

        return user
    }

    // MARK: - Debug: instant verification

    #if DEBUG
    /// Calls the dev-only endpoint that immediately sets the user's SJSU ID status to "verified".
    /// Only available in debug builds — the endpoint is disabled in production.
    func testVerifyUser(userId: String) async throws -> User {
        let user: User = try await network.request(
            endpoint: "/auth/test/verify/\(userId)",
            method: .post
        )
        return user
    }
    #endif

    // MARK: - Change Password

    func changePassword(currentPassword: String, newPassword: String) async throws {
        struct ChangePasswordRequest: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        let _: EmptyResponse = try await network.request(
            endpoint: "/auth/change-password",
            method: .put,
            body: ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        )
    }

    // MARK: - Helpers

    var isLoggedIn: Bool {
        KeychainManager.shared.getAccessToken() != nil
    }
}

// MARK: - Helper Models

struct TokenVerificationResponse: Codable {
    let valid: Bool
    let user: User
}

struct EmptyResponse: Codable {}
