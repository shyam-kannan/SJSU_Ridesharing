import Foundation

// MARK: - Booking Models

struct Booking: Codable, Identifiable {
    let id: String
    let tripId: String
    let riderId: String
    let seatsBooked: Int
    let status: BookingStatus
    let createdAt: Date
    let updatedAt: Date
    let trip: Trip?
    let rider: User?
    let quote: Quote?
    let payment: Payment?

    enum CodingKeys: String, CodingKey {
        case id = "booking_id"
        case tripId = "trip_id"
        case riderId = "rider_id"
        case seatsBooked = "seats_booked"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case trip, rider, quote, payment
    }
}

enum BookingStatus: String, Codable {
    case pending
    case confirmed
    case cancelled
    case completed
}

struct Quote: Codable {
    let id: String
    let bookingId: String
    let maxPrice: Double
    let finalPrice: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "quote_id"
        case bookingId = "booking_id"
        case maxPrice = "max_price"
        case finalPrice = "final_price"
        case createdAt = "created_at"
    }

    // Postgres DECIMAL columns arrive as strings from the pg library.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        bookingId = try c.decode(String.self, forKey: .bookingId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)

        maxPrice  = Self.decodeDouble(c, key: .maxPrice) ?? 0.0
        finalPrice = Self.decodeDouble(c, key: .finalPrice)
    }

    private static func decodeDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }
}

// MARK: - Booking Request/Response Models

struct CreateBookingRequest: Codable {
    let tripId: String
    let seatsBooked: Int

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case seatsBooked = "seats_booked"
    }
}

struct CreateBookingResponse: Codable {
    let booking: Booking
    let quote: Quote?
}

struct BookingListResponse: Codable {
    let bookings: [Booking]
    let total: Int
}

// MARK: - Rating Models

struct Rating: Codable, Identifiable {
    let id: String
    let bookingId: String
    let raterId: String
    let rateeId: String
    let score: Int
    let comment: String?
    let createdAt: Date
    let rater: User?

    enum CodingKeys: String, CodingKey {
        case id = "rating_id"
        case bookingId = "booking_id"
        case raterId = "rater_id"
        case rateeId = "ratee_id"
        case score, comment
        case createdAt = "created_at"
        case rater
    }
}

struct CreateRatingRequest: Codable {
    let score: Int
    let comment: String?
}
