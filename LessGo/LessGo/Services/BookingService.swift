import Foundation

// MARK: - Booking Service

class BookingService {
    static let shared = BookingService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Create Booking

    func createBooking(tripId: String, seatsBooked: Int) async throws -> CreateBookingResponse {
        let request = CreateBookingRequest(tripId: tripId, seatsBooked: seatsBooked)

        let response: CreateBookingResponse = try await network.request(
            endpoint: "/bookings",
            method: .post,
            body: request
        )

        return response
    }

    // MARK: - Get Booking

    func getBooking(id: String) async throws -> Booking {
        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)",
            method: .get,
            requiresAuth: false
        )
        return booking
    }

    // MARK: - List Bookings

    func listBookings(asDriver: Bool = false) async throws -> BookingListResponse {
        var endpoint = "/bookings"
        if asDriver {
            endpoint += "?as_driver=true"
        }

        let response: BookingListResponse = try await network.request(
            endpoint: endpoint,
            method: .get
        )

        return response
    }

    // MARK: - Confirm Booking

    func confirmBooking(id: String) async throws -> Booking {
        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)/confirm",
            method: .put
        )
        return booking
    }

    // MARK: - Cancel Booking

    func cancelBooking(id: String) async throws -> Booking {
        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)/cancel",
            method: .put
        )
        return booking
    }

    // MARK: - Rate Booking

    func rateBooking(id: String, score: Int, comment: String? = nil) async throws -> Rating {
        let request = CreateRatingRequest(score: score, comment: comment)

        let rating: Rating = try await network.request(
            endpoint: "/bookings/\(id)/rate",
            method: .post,
            body: request
        )

        return rating
    }

    // MARK: - Update Pickup Location

    func updatePickupLocation(id: String, lat: Double, lng: Double, address: String?) async throws -> Booking {
        struct PickupLocationRequest: Codable {
            let lat: Double
            let lng: Double
            let address: String?
        }

        let request = PickupLocationRequest(lat: lat, lng: lng, address: address)

        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)/pickup-location",
            method: .put,
            body: request
        )

        return booking
    }
}
