import Foundation
import Security

// MARK: - Keychain Manager for Secure Token Storage

class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    private let service = "com.lessgo.app"

    private enum Key: String {
        case accessToken
        case refreshToken
        case userId
    }

    // MARK: - Token Management

    func saveAccessToken(_ token: String) {
        save(token, for: .accessToken)
    }

    func getAccessToken() -> String? {
        get(for: .accessToken)
    }

    func deleteAccessToken() {
        delete(for: .accessToken)
    }

    func saveRefreshToken(_ token: String) {
        save(token, for: .refreshToken)
    }

    func getRefreshToken() -> String? {
        get(for: .refreshToken)
    }

    func deleteRefreshToken() {
        delete(for: .refreshToken)
    }

    func saveUserId(_ userId: String) {
        save(userId, for: .userId)
    }

    func getUserId() -> String? {
        get(for: .userId)
    }

    func deleteUserId() {
        delete(for: .userId)
    }

    func clearAll() {
        deleteAccessToken()
        deleteRefreshToken()
        deleteUserId()
    }

    func clearActiveSession() {
        clearAll()
    }

    // MARK: - Multi-account token storage

    func saveAccessToken(_ token: String, for userId: String) {
        save(token, forAccount: "saved_access_\(userId)")
    }

    func getAccessToken(for userId: String) -> String? {
        get(forAccount: "saved_access_\(userId)")
    }

    func deleteAccessToken(for userId: String) {
        delete(forAccount: "saved_access_\(userId)")
    }

    func saveRefreshToken(_ token: String, for userId: String) {
        save(token, forAccount: "saved_refresh_\(userId)")
    }

    func getRefreshToken(for userId: String) -> String? {
        get(forAccount: "saved_refresh_\(userId)")
    }

    func deleteRefreshToken(for userId: String) {
        delete(forAccount: "saved_refresh_\(userId)")
    }

    // MARK: - Private Helpers

    private func save(_ value: String, for key: Key) {
        save(value, forAccount: key.rawValue)
    }

    private func save(_ value: String, forAccount account: String) {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(for key: Key) -> String? {
        get(forAccount: key.rawValue)
    }

    private func get(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(for key: Key) {
        delete(forAccount: key.rawValue)
    }

    private func delete(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
