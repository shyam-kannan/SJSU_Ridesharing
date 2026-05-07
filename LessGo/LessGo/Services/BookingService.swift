import Foundation

// MARK: - Booking Service

class BookingService {
    static let shared = BookingService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Create Booking

    func createBooking(tripId: String, seatsBooked: Int, fare: Double? = nil) async throws -> CreateBookingResponse {
        let request = CreateBookingRequest(tripId: tripId, seatsBooked: seatsBooked, fare: fare)

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

    // MARK: - Approve Booking (Driver Only)

    func approveBooking(id: String) async throws -> Booking {
        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)/approve",
            method: .patch
        )
        return booking
    }

    // MARK: - Reject Booking (Driver Only)

    func rejectBooking(id: String) async throws -> Booking {
        let booking: Booking = try await network.request(
            endpoint: "/bookings/\(id)/reject",
            method: .patch
        )
        return booking
    }

    // MARK: - Delete Booking

    func deleteBooking(bookingId: String) async throws {
        let _: EmptyResponse = try await network.request(
            endpoint: "/bookings/\(bookingId)",
            method: .delete
        )
    }

    // MARK: - Authorize Payment (Rider Only)

    func authorizePayment(bookingId: String) async throws -> [String: Any] {
        struct AuthorizePaymentResponse: Codable {
            let status: String
            let data: AuthorizePaymentData?
            struct AuthorizePaymentData: Codable {
                let clientSecret: String
                let paymentIntentId: String
                enum CodingKeys: String, CodingKey {
                    case clientSecret = "clientSecret"
                    case paymentIntentId = "paymentIntentId"
                }
            }
        }

        let response: AuthorizePaymentResponse = try await network.request(
            endpoint: "/bookings/\(bookingId)/authorize-payment",
            method: .post
        )

        guard let data = response.data else {
            throw NetworkError.serverError(APIError(status: "error", message: "No payment data returned", errors: nil))
        }

        return [
            "clientSecret": data.clientSecret,
            "paymentIntentId": data.paymentIntentId,
        ]
    }

    // MARK: - Get Booking for Trip

    func getBookingForTrip(tripId: String) async throws -> Booking? {
        let response: BookingListResponse = try await network.request(
            endpoint: "/bookings/trip/\(tripId)",
            method: .get
        )
        return response.bookings.first
    }
}
