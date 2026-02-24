import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private let network = NetworkManager.shared

    private init() {}

    func listNotifications(userId: String, limit: Int = 50, unreadOnly: Bool = false) async throws -> NotificationsListResponse {
        let endpoint = "/notifications/user/\(userId)?limit=\(limit)&unread_only=\(unreadOnly ? "true" : "false")"
        let response: NotificationsListResponse = try await network.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
        return response
    }

    func markAllRead(userId: String) async throws {
        let _: EmptyResponse = try await network.request(
            endpoint: "/notifications/user/\(userId)/read-all",
            method: .post,
            requiresAuth: true
        )
    }

    func markRead(userId: String, notificationId: String) async throws {
        let _: EmptyResponse = try await network.request(
            endpoint: "/notifications/user/\(userId)/\(notificationId)/read",
            method: .post,
            requiresAuth: true
        )
    }
}

