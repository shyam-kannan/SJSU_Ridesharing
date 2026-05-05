import SwiftUI
import UIKit
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showIDVerification = false
    @Published var savedLoginProfiles: [SavedLoginProfile] = []

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        refreshSavedLoginProfiles()
        Task { await checkAuthentication() }
        // Re-fetch the user whenever the app returns to foreground so
        // verification status and profile data are always current.
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.isAuthenticated else { return }
                Task { await self.refreshCurrentUser() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Auth State Check

    func checkAuthentication() async {
        refreshSavedLoginProfiles()
        guard authService.isLoggedIn else {
            currentUser = nil
            isAuthenticated = false
            return
        }
        do {
            currentUser = try await authService.getCurrentUser()
            // Keep JWT claims (role / verification status) in sync with current DB user.
            _ = try? await authService.refreshAccessToken()
            isAuthenticated = true
        } catch let error as NetworkError {
            if shouldInvalidateSession(for: error) {
                currentUser = nil
                isAuthenticated = false
                KeychainManager.shared.clearActiveSession()
            } else {
                // Keep user logged in for transient failures (offline/cancelled/timeouts).
                isAuthenticated = true
            }
        } catch is CancellationError {
            isAuthenticated = authService.isLoggedIn
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                isAuthenticated = authService.isLoggedIn
            } else {
                currentUser = nil
                isAuthenticated = false
                KeychainManager.shared.clearActiveSession()
            }
        }
    }

    private func shouldInvalidateSession(for error: NetworkError) -> Bool {
        switch error {
        case .unauthorized, .forbidden:
            return true
        case .noConnection, .timeout:
            return false
        case .unknown(let underlying):
            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .cancelled, .notConnectedToInternet, .networkConnectionLost, .timedOut:
                    return false
                default:
                    return true
                }
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await authService.login(email: email, password: password)
            currentUser = response.user
            isAuthenticated = true
            // Always fetch latest record so sjsuIdStatus is current, not JWT-cached.
            await refreshCurrentUser()
            refreshSavedLoginProfiles()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Register

    func register(name: String, email: String, password: String, role: UserRole) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await authService.register(name: name, email: email, password: password, role: role)
            currentUser = response.user
            isAuthenticated = true
            refreshSavedLoginProfiles()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Logout

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.logout()
        } catch { /* ignore — clear locally anyway */ }
        currentUser = nil
        isAuthenticated = false
        KeychainManager.shared.clearActiveSession()
        refreshSavedLoginProfiles()
    }

    func loginWithSavedProfile(_ profile: SavedLoginProfile) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard SavedAccountManager.shared.activateProfile(profile.userId) else {
            refreshSavedLoginProfiles()
            errorMessage = "Saved account is missing local session tokens. Remove it or log in again."
            return
        }

        await checkAuthentication()
        if !isAuthenticated {
            refreshSavedLoginProfiles()
            errorMessage = "Saved session is no longer valid. Log in again or remove this saved account."
        }
    }

    func removeSavedLoginProfile(_ profile: SavedLoginProfile) {
        let isCurrent = currentUser?.id == profile.userId || KeychainManager.shared.getUserId() == profile.userId
        if isCurrent {
            KeychainManager.shared.clearActiveSession()
            currentUser = nil
            isAuthenticated = false
        }
        SavedAccountManager.shared.removeProfile(profile.userId)
        refreshSavedLoginProfiles()
    }

    // MARK: - Refresh current user

    /// Refreshes `currentUser` from `/auth/me`. Call this after any action that
    /// may change verification status, profile info, or role.
    func refreshCurrentUser() async {
        do {
            currentUser = try await authService.getCurrentUser()
            _ = try? await authService.refreshAccessToken()
            if let currentUser, let access = KeychainManager.shared.getAccessToken(), let refresh = KeychainManager.shared.getRefreshToken() {
                SavedAccountManager.shared.saveSession(user: currentUser, accessToken: access, refreshToken: refresh)
            }
            refreshSavedLoginProfiles()
        } catch {}
    }

    /// Alias kept for call-site compatibility.
    func refreshUser() async { await refreshCurrentUser() }

    // MARK: - Role Switching

    /// Switch user role between Driver and Rider
    /// - Parameter newRole: The role to switch to
    /// - Throws: Error if switching to Driver without complete profile
    func switchRole(to newRole: UserRole) async throws {
        guard let user = currentUser else {
            throw NetworkError.unauthorized
        }

        // Validate driver requirements
        if newRole == .driver {
            guard user.vehicleInfo != nil,
                  user.licensePlate != nil else {
                errorMessage = "Complete driver setup before switching to driver mode"
                throw NetworkError.serverError(APIError(
                    status: "error",
                    message: "Complete driver setup before switching to driver mode",
                    errors: nil
                ))
            }
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updatedUser = try await UserService.shared.updateUserRole(userId: user.id, role: newRole)
            // Role is encoded in JWT claims and checked by backend middleware.
            _ = try? await authService.refreshAccessToken()
            currentUser = updatedUser
            await refreshCurrentUser()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Failed to switch role"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            throw error
        }
    }

    // MARK: - Debug: instant SJSU ID approval

    #if DEBUG
    /// Immediately sets the current user's SJSU ID status to "verified" via the
    /// dev-only backend endpoint. Call after a successful test ID upload in debug builds.
    func autoVerifyForDebug() async {
        guard let userId = currentUser?.id else { return }
        do {
            let verified = try await authService.testVerifyUser(userId: userId)
            currentUser = verified
        } catch {
            print("[DEBUG] autoVerifyForDebug failed: \(error)")
        }
    }
    #endif

    // MARK: - Validation Helpers

    static func validateEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Email is required" }
        guard trimmed.contains("@") && trimmed.contains(".") else { return "Enter a valid email" }
        return nil
    }

    static func validatePassword(_ password: String) -> String? {
        guard password.count >= 8 else { return "At least 8 characters required" }
        guard password.first(where: { $0.isUppercase }) != nil else { return "Include at least one uppercase letter" }
        guard password.first(where: { $0.isNumber }) != nil else { return "Include at least one number" }
        return nil
    }

    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Name is required" }
        guard trimmed.count >= 2 else { return "Name must be at least 2 characters" }
        return nil
    }

    var isVerified: Bool {
        currentUser?.sjsuIdStatus == .verified
    }

    var isDriver: Bool {
        currentUser?.role == .driver
    }

    func refreshSavedLoginProfiles() {
        savedLoginProfiles = SavedAccountManager.shared.profiles()
    }
}
