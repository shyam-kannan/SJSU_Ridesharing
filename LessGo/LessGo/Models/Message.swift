import Foundation

// MARK: - Message Models

struct Message: Codable, Identifiable {
    let id: String
    let tripId: String
    let senderId: String
    let messageText: String
    let createdAt: Date
    let readAt: Date?
    let senderName: String?
    let senderRole: String?

    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case tripId = "trip_id"
        case senderId = "sender_id"
        case messageText = "message_text"
        case createdAt = "created_at"
        case readAt = "read_at"
        case senderName = "sender_name"
        case senderRole = "sender_role"
    }

    var isFromDriver: Bool {
        senderRole?.lowercased() == "driver"
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }
}

struct SendMessageRequest: Codable {
    let message: String
}

struct MessagesResponse: Codable {
    let messages: [Message]
    let total: Int
}

// Quick message templates for common phrases
enum QuickMessage: String, CaseIterable {
    case arrivedPickup = "I'm here! 🚗"
    case onMyWay = "On my way!"
    case runningLate = "Running 5 min late"
    case atLocation = "Arrived at location"
    case thankYou = "Thank you! ⭐"
    case callMe = "Please call me"

    var icon: String {
        switch self {
        case .arrivedPickup: return "car.fill"
        case .onMyWay: return "arrow.right.circle.fill"
        case .runningLate: return "clock.fill"
        case .atLocation: return "location.fill"
        case .thankYou: return "hand.thumbsup.fill"
        case .callMe: return "phone.fill"
        }
    }
}
