import Foundation

struct SavedLoginProfile: Codable, Identifiable, Equatable {
    let id: String           // userId
    let userId: String
    let name: String
    let email: String
    let role: UserRole
    let createdAt: Date
    var lastUsedAt: Date

    init(id: String, userId: String, name: String, email: String, role: UserRole, createdAt: Date, lastUsedAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    init(user: User, now: Date = Date()) {
        self.id = user.id
        self.userId = user.id
        self.name = user.name
        self.email = user.email
        self.role = user.role
        self.createdAt = now
        self.lastUsedAt = now
    }
}

final class SavedAccountManager {
    static let shared = SavedAccountManager()

    private let defaults = UserDefaults.standard
    private let profilesKey = "saved_login_profiles_v1"

    private init() {}

    func profiles() -> [SavedLoginProfile] {
        guard let data = defaults.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([SavedLoginProfile].self, from: data) else {
            return []
        }
        return profiles.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    func saveSession(user: User, accessToken: String, refreshToken: String) {
        KeychainManager.shared.saveAccessToken(accessToken, for: user.id)
        KeychainManager.shared.saveRefreshToken(refreshToken, for: user.id)

        var items = profiles()
        if let idx = items.firstIndex(where: { $0.userId == user.id }) {
            items[idx] = SavedLoginProfile(
                id: user.id,
                userId: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                createdAt: items[idx].createdAt,
                lastUsedAt: Date()
            )
        } else {
            items.append(SavedLoginProfile(user: user))
        }
        persist(items)
    }

    func markUsed(_ userId: String) {
        var items = profiles()
        guard let idx = items.firstIndex(where: { $0.userId == userId }) else { return }
        items[idx].lastUsedAt = Date()
        persist(items)
    }

    func activateProfile(_ userId: String) -> Bool {
        guard let access = KeychainManager.shared.getAccessToken(for: userId),
              let refresh = KeychainManager.shared.getRefreshToken(for: userId) else {
            return false
        }
        KeychainManager.shared.saveAccessToken(access)
        KeychainManager.shared.saveRefreshToken(refresh)
        KeychainManager.shared.saveUserId(userId)
        markUsed(userId)
        return true
    }

    func removeProfile(_ userId: String) {
        var items = profiles()
        items.removeAll { $0.userId == userId }
        persist(items)
        KeychainManager.shared.deleteAccessToken(for: userId)
        KeychainManager.shared.deleteRefreshToken(for: userId)
    }

    private func persist(_ profiles: [SavedLoginProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
    }
}
