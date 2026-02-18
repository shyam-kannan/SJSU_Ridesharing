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

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
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
        guard authService.isLoggedIn else { isAuthenticated = false; return }
        do {
            currentUser = try await authService.getCurrentUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            KeychainManager.shared.clearAll()
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
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
    }

    // MARK: - Refresh current user

    /// Refreshes `currentUser` from `/auth/me`. Call this after any action that
    /// may change verification status, profile info, or role.
    func refreshCurrentUser() async {
        do {
            currentUser = try await authService.getCurrentUser()
        } catch {}
    }

    /// Alias kept for call-site compatibility.
    func refreshUser() async { await refreshCurrentUser() }

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
}
