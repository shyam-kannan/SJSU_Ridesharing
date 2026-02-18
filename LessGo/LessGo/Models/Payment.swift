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

    // Postgres DECIMAL columns arrive as strings from the pg library.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(String.self, forKey: .id)
        bookingId             = try c.decode(String.self, forKey: .bookingId)
        stripePaymentIntentId = try? c.decode(String.self, forKey: .stripePaymentIntentId)
        status                = try c.decode(PaymentStatus.self, forKey: .status)
        createdAt             = try c.decode(Date.self, forKey: .createdAt)
        updatedAt             = try c.decode(Date.self, forKey: .updatedAt)

        if let v = try? c.decode(Double.self, forKey: .amount) {
            amount = v
        } else if let s = try? c.decode(String.self, forKey: .amount), let v = Double(s) {
            amount = v
        } else {
            amount = 0.0
        }
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
