import Foundation

// MARK: - Payment Models

struct Payment: Codable, Identifiable {
    let id: String
    let bookingId: String
    let stripePaymentIntentId: String?
    let amount: Double
    let status: PaymentStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "payment_id"
        case bookingId = "booking_id"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case amount, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum PaymentStatus: String, Codable {
    case pending
    case captured
    case refunded
    case failed
}

// MARK: - Payment Request/Response Models

struct CreatePaymentIntentRequest: Codable {
    let bookingId: String
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case bookingId = "booking_id"
        case amount
    }
}
