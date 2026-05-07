import Foundation
import CoreLocation

// MARK: - Trip Service

class TripService {
    static let shared = TripService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Helper Methods

    /// Builds query string from URLQueryItems
    private func buildQueryString(from items: [URLQueryItem]) -> String {
        guard !items.isEmpty else { return "" }
        var components = URLComponents()
        components.queryItems = items
        return components.string ?? ""
    }

    /// Formats a Date as ISO8601 string
    private func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    // MARK: - Create Trip

    func createTrip(
        origin: String,
        destination: String,
        departureTime: Date,
        seatsAvailable: Int,
        recurrence: String? = nil
    ) async throws -> Trip {
        let request = CreateTripRequest(
            origin: origin,
            destination: destination,
            departureTime: departureTime,
            seatsAvailable: seatsAvailable,
            recurrence: recurrence
        )

        do {
            let trip: Trip = try await network.request(
                endpoint: "/trips",
                method: .post,
                body: request
            )
            return trip
        } catch let error as NetworkError {
            // Role is enforced from JWT claims in backend middleware. If the user
            // just switched roles, refresh the token and retry once.
            if case .serverError(let apiError) = error,
               apiError.message.localizedCaseInsensitiveContains("Driver role required") {
                _ = try? await AuthService.shared.refreshAccessToken()
                let retriedTrip: Trip = try await network.request(
                    endpoint: "/trips",
                    method: .post,
                    body: request
                )
                return retriedTrip
            }
            if case .forbidden = error {
                _ = try? await AuthService.shared.refreshAccessToken()
                let retriedTrip: Trip = try await network.request(
                    endpoint: "/trips",
                    method: .post,
                    body: request
                )
                return retriedTrip
            }
            throw error
        }
    }

    // MARK: - Get Trip

    func getTrip(id: String) async throws -> Trip {
        let trip: Trip = try await network.request(
            endpoint: "/trips/\(id)",
            method: .get,
            requiresAuth: false
        )
        return trip
    }

    // MARK: - List Trips

    func listTrips(
        driverId: String? = nil,
        status: TripStatus? = nil,
        departureAfter: Date? = nil,
        limit: Int? = nil
    ) async throws -> TripListResponse {
        var queryItems: [URLQueryItem] = []

        if let driverId = driverId {
            queryItems.append(URLQueryItem(name: "driver_id", value: driverId))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let departureAfter = departureAfter {
            queryItems.append(URLQueryItem(name: "departure_after", value: formatDate(departureAfter)))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        let endpoint = "/trips" + buildQueryString(from: queryItems)

        // Require authentication when requesting driver-specific trips
        let needsAuth = driverId != nil
        let response: TripListResponse = try await network.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: needsAuth
        )

        return response
    }

    // MARK: - Search Trips (Posted Rides)

    func searchPostedTrips(
        direction: String,
        originLat: Double,
        originLng: Double,
        destinationLat: Double? = nil,
        destinationLng: Double? = nil,
        departureAfter: Date? = nil,
        departureBefore: Date? = nil,
        minSeats: Int? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> TripSearchResultsResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sjsu_direction", value: direction),
            URLQueryItem(name: "origin_lat", value: "\(originLat)"),
            URLQueryItem(name: "origin_lng", value: "\(originLng)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        if let destinationLat = destinationLat {
            queryItems.append(URLQueryItem(name: "destination_lat", value: "\(destinationLat)"))
        }
        if let destinationLng = destinationLng {
            queryItems.append(URLQueryItem(name: "destination_lng", value: "\(destinationLng)"))
        }
        if let minSeats = minSeats {
            queryItems.append(URLQueryItem(name: "min_seats", value: "\(minSeats)"))
        }
        if let departureAfter = departureAfter {
            queryItems.append(URLQueryItem(name: "departure_after", value: formatDate(departureAfter)))
        }
        if let departureBefore = departureBefore {
            queryItems.append(URLQueryItem(name: "departure_before", value: formatDate(departureBefore)))
        }

        let endpoint = "/trips/search" + buildQueryString(from: queryItems)

        let response: TripSearchResultsResponse = try await network.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: false
        )

        return response
    }

    // MARK: - Search Trips (Legacy On-Demand)

    func searchTrips(params: TripSearchParams) async throws -> TripListResponse {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "origin_lat", value: "\(params.originLat)"),
            URLQueryItem(name: "origin_lng", value: "\(params.originLng)"),
            URLQueryItem(name: "radius_meters", value: "\(params.radiusMeters)")
        ]

        if let minSeats = params.minSeats {
            queryItems.append(URLQueryItem(name: "min_seats", value: "\(minSeats)"))
        }

        if let departureAfter = params.departureAfter {
            queryItems.append(URLQueryItem(name: "departure_after", value: formatDate(departureAfter)))
        }

        if let departureBefore = params.departureBefore {
            queryItems.append(URLQueryItem(name: "departure_before", value: formatDate(departureBefore)))
        }

        let endpoint = "/trips/search" + buildQueryString(from: queryItems)

        let response: TripListResponse = try await network.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: false
        )

        return response
    }

    // MARK: - Update Trip

    func updateTrip(
        id: String,
        departureTime: Date? = nil,
        seatsAvailable: Int? = nil,
        recurrence: String? = nil
    ) async throws -> Trip {
        let request = UpdateTripRequest(
            departureTime: departureTime,
            seatsAvailable: seatsAvailable,
            recurrence: recurrence
        )

        let trip: Trip = try await network.request(
            endpoint: "/trips/\(id)",
            method: .put,
            body: request
        )

        return trip
    }

    // MARK: - Cancel Trip

    func cancelTrip(id: String) async throws -> Trip {
        let trip: Trip = try await network.request(
            endpoint: "/trips/\(id)",
            method: .delete
        )
        return trip
    }

    // MARK: - Get Trip Passengers

    func getTripPassengers(tripId: String) async throws -> [BookingWithRider] {
        let response: TripBookingsResponse = try await network.request(
            endpoint: "/trips/\(tripId)/bookings",
            method: .get
        )
        return response.bookings
    }

    // MARK: - Request a Ride (on-demand matching)

    func requestTrip(
        origin: String,
        destination: String,
        originLat: Double,
        originLng: Double,
        destinationLat: Double,
        destinationLng: Double,
        departureTime: Date
    ) async throws -> RiderTripRequestResponse {
        let request = RiderTripRequest(
            origin: origin,
            destination: destination,
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            departureTime: departureTime
        )
        let response: RiderTripRequestResponse = try await network.request(
            endpoint: "/trips/request",
            method: .post,
            body: request
        )
        return response
    }

    // MARK: - Poll Trip Request Status

    func getTripRequest(id: String) async throws -> TripRequestStatus {
        let status: TripRequestStatus = try await network.request(
            endpoint: "/trips/request/\(id)",
            method: .get
        )
        return status
    }

    // MARK: - Anchor Points

    func getAnchorPoints(tripId: String) async throws -> [AnchorPoint] {
        let response: AnchorPointsResponse = try await network.request(
            endpoint: "/trips/\(tripId)/anchor-points",
            method: .get,
            requiresAuth: false
        )
        return response.anchorPoints
    }

    // MARK: - Frequent Routes

    func getFrequentRoutes(driverId: String) async throws -> [FrequentRouteSegment] {
        let response: FrequentRoutesResponse = try await network.request(
            endpoint: "/trips/driver/\(driverId)/frequent-routes",
            method: .get,
            requiresAuth: false
        )
        return response.routes
    }

    // MARK: - Accept / Decline Match (driver)

    func acceptMatch(tripId: String, matchId: String) async throws {
        struct Body: Encodable { let match_id: String }
        let _: EmptyResponse = try await network.request(
            endpoint: "/trips/\(tripId)/accept-match",
            method: .post,
            body: Body(match_id: matchId)
        )
    }

    func declineMatch(tripId: String, matchId: String) async throws {
        struct Body: Encodable { let match_id: String }
        let _: EmptyResponse = try await network.request(
            endpoint: "/trips/\(tripId)/decline-match",
            method: .post,
            body: Body(match_id: matchId)
        )
    }

    // MARK: - Delete Trip (permanent removal, distinct from cancel)

    func deleteTrip(tripId: String) async throws {
        let _: EmptyResponse = try await network.request(
            endpoint: "/trips/\(tripId)/delete",
            method: .delete
        )
    }

    // MARK: - Update Trip State

    func updateTripState(tripId: String, status: TripStatus) async throws -> TripStateUpdateResponse {
        struct StateUpdate: Encodable {
            let status: String
        }

        let response: TripStateUpdateResponse = try await network.request(
            endpoint: "/trips/\(tripId)/state",
            method: .put,
            body: StateUpdate(status: status.rawValue),
            requiresAuth: true
        )
        return response
    }
}
