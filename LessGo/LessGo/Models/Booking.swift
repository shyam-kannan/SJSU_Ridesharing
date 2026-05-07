import Foundation

// MARK: - Booking Models

struct Booking: Codable, Identifiable {
    let id: String
    let tripId: String
    let riderId: String
    let seatsBooked: Int
    let status: BookingStatus
    let bookingState: BookingState
    let createdAt: Date
    let updatedAt: Date
    let trip: Trip?
    let rider: User?
    let pickupLocation: PickupLocation?
    let quote: Quote?
    let payment: Payment?
    let fare: Double?

    enum CodingKeys: String, CodingKey {
        case id = "booking_id"
        case tripId = "trip_id"
        case riderId = "rider_id"
        case seatsBooked = "seats_booked"
        case status
        case bookingState = "booking_state"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case trip, rider
        case pickupLocation = "pickup_location"
        case quote, payment, fare
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        tripId = try c.decode(String.self, forKey: .tripId)
        riderId = try c.decode(String.self, forKey: .riderId)
        seatsBooked = try c.decode(Int.self, forKey: .seatsBooked)
        status = try c.decode(BookingStatus.self, forKey: .status)
        // backend may omit booking_state for older endpoints — default to .pending
        bookingState = try c.decodeIfPresent(BookingState.self, forKey: .bookingState) ?? .pending
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        trip = try c.decodeIfPresent(Trip.self, forKey: .trip)
        rider = try c.decodeIfPresent(User.self, forKey: .rider)
        pickupLocation = try c.decodeIfPresent(PickupLocation.self, forKey: .pickupLocation)
        quote = try c.decodeIfPresent(Quote.self, forKey: .quote)
        payment = try c.decodeIfPresent(Payment.self, forKey: .payment)
        // fare = max_price from the quotes table, returned directly on the booking by some endpoints
        if let fareDouble = try? c.decode(Double.self, forKey: .fare) {
            fare = fareDouble
        } else if let fareString = try? c.decode(String.self, forKey: .fare), let parsed = Double(fareString) {
            fare = parsed
        } else {
            fare = nil
        }
    }
}

enum BookingStatus: String, Codable {
    case pending
    case confirmed
    case cancelled
    case completed
}

// MARK: - Booking State (for driver approval flow)

enum BookingState: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case cancelled = "cancelled"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .pending: return "Awaiting Approval"
        case .approved: return "Confirmed"
        case .rejected: return "Declined"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .completed: return "checkmark.seal.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "brandGold"
        case .approved: return "brandGreen"
        case .rejected: return "brandRed"
        case .cancelled: return "brandRed"
        case .completed: return "brandGreen"
        }
    }
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
    let fare: Double?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case seatsBooked = "seats_booked"
        case fare
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

// MARK: - Driver Models

struct BookingWithRider: Codable, Identifiable {
    let id: String
    let tripId: String
    let riderId: String
    let riderName: String
    let riderEmail: String?
    let riderPhone: String?
    let riderRating: Double
    let riderPicture: String?
    let seatsBooked: Int
    let status: BookingStatus
    let bookingState: BookingState
    let pickupLocation: PickupLocation?
    let createdAt: Date
    let scostBreakdown: ScostBreakdown?
    let fare: Double?
    let paymentIntentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case riderId = "rider_id"
        case riderName = "rider_name"
        case riderEmail = "rider_email"
        case riderPhone = "rider_phone"
        case riderRating = "rider_rating"
        case riderPicture = "rider_picture"
        case seatsBooked = "seats_booked"
        case status
        case bookingState = "booking_state"
        case pickupLocation = "pickup_location"
        case createdAt = "created_at"
        case scostBreakdown = "scost_breakdown"
        case fare
        case paymentIntentId = "payment_intent_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tripId = try container.decode(String.self, forKey: .tripId)
        riderId = try container.decode(String.self, forKey: .riderId)
        riderName = try container.decode(String.self, forKey: .riderName)
        riderEmail = try container.decodeIfPresent(String.self, forKey: .riderEmail)
        riderPhone = try container.decodeIfPresent(String.self, forKey: .riderPhone)
        riderPicture = try container.decodeIfPresent(String.self, forKey: .riderPicture)
        seatsBooked = try container.decode(Int.self, forKey: .seatsBooked)
        status = try container.decode(BookingStatus.self, forKey: .status)
        bookingState = try container.decodeIfPresent(BookingState.self, forKey: .bookingState) ?? .pending
        pickupLocation = try container.decodeIfPresent(PickupLocation.self, forKey: .pickupLocation)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        scostBreakdown = try container.decodeIfPresent(ScostBreakdown.self, forKey: .scostBreakdown)
        paymentIntentId = try container.decodeIfPresent(String.self, forKey: .paymentIntentId)
        if let fareDouble = try? container.decode(Double.self, forKey: .fare) {
            fare = fareDouble
        } else if let fareString = try? container.decode(String.self, forKey: .fare), let parsed = Double(fareString) {
            fare = parsed
        } else {
            fare = nil
        }

        // Backend sends rating as String ("0.00") or occasionally as Double
        if let ratingDouble = try? container.decode(Double.self, forKey: .riderRating) {
            riderRating = ratingDouble
        } else if let ratingString = try? container.decode(String.self, forKey: .riderRating),
                  let parsed = Double(ratingString) {
            riderRating = parsed
        } else {
            riderRating = 0.0
        }
    }
}

struct PickupLocation: Codable {
    let lat: Double
    let lng: Double
    let address: String?
}

// MARK: - Scost Breakdown Models

struct ScostBreakdown: Codable {
    let travel: Double
    let walk: Double
    let detour: Double
    let advance: Double
    let social: Double
    let total: Double
}

// Response wrapper for trip bookings endpoint
struct TripBookingsResponse: Codable {
    let bookings: [BookingWithRider]
    let total: Int
}
