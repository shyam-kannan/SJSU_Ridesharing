import Foundation
import CoreLocation

// MARK: - Trip Service

class TripService {
    static let shared = TripService()
    private let network = NetworkManager.shared

    private init() {}

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

        let trip: Trip = try await network.request(
            endpoint: "/trips",
            method: .post,
            body: request
        )

        return trip
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
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "departure_after", value: formatter.string(from: departureAfter)))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        var endpoint = "/trips"
        if !queryItems.isEmpty {
            var components = URLComponents()
            components.queryItems = queryItems
            endpoint += components.string ?? ""
        }

        let response: TripListResponse = try await network.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: false
        )

        return response
    }

    // MARK: - Search Trips

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
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "departure_after", value: formatter.string(from: departureAfter)))
        }

        if let departureBefore = params.departureBefore {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "departure_before", value: formatter.string(from: departureBefore)))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        let endpoint = "/trips/search" + (components.string ?? "")

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
}
