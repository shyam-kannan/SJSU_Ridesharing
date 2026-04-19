import Foundation

struct AppNotificationItem: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let message: String
    let data: NotificationPayloadData?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case message
        case data
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var isUnread: Bool { readAt == nil }
}

struct NotificationPayloadData: Codable, Equatable {
    let tripId: String?
    let bookingId: String?
    let status: String?
    let senderId: String?
    let riderName: String?
    let seatsBooked: Int?
    // Incoming ride-request fields (driver notifications)
    let matchId: String?
    let requestId: String?
    let riderRating: Double?
    let origin: String?
    let destination: String?
    let departureTime: String?
    let expiresInSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case bookingId = "booking_id"
        case status
        case senderId = "sender_id"
        case riderName = "rider_name"
        case seatsBooked = "seats_booked"
        case matchId = "match_id"
        case requestId = "request_id"
        case riderRating = "rider_rating"
        case origin, destination
        case departureTime = "departure_time"
        case expiresInSeconds = "expires_in_seconds"
    }
}

struct NotificationsListResponse: Codable {
    let notifications: [AppNotificationItem]
    let total: Int
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case notifications
        case total
        case unreadCount = "unread_count"
    }
}

