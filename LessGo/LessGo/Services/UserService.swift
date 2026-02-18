import Foundation

// MARK: - User Service

class UserService {
    static let shared = UserService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Get User Profile

    func getUserProfile(id: String) async throws -> User {
        let user: User = try await network.request(
            endpoint: "/users/\(id)",
            method: .get,
            requiresAuth: false
        )
        return user
    }

    func getCurrentUserProfile() async throws -> User {
        let user: User = try await network.request(
            endpoint: "/users/me",
            method: .get
        )
        return user
    }

    // MARK: - Update Profile

    func updateProfile(id: String, name: String? = nil, email: String? = nil) async throws -> User {
        var body: [String: String] = [:]
        if let name = name {
            body["name"] = name
        }
        if let email = email {
            body["email"] = email
        }

        let user: User = try await network.request(
            endpoint: "/users/\(id)",
            method: .put,
            body: body
        )

        return user
    }

    // MARK: - Setup Driver Profile

    func setupDriverProfile(id: String, vehicleInfo: String, seatsAvailable: Int) async throws -> User {
        let body = DriverSetupRequest(vehicleInfo: vehicleInfo, seatsAvailable: seatsAvailable)

        let user: User = try await network.request(
            endpoint: "/users/\(id)/driver-setup",
            method: .put,
            body: body
        )

        return user
    }

    // MARK: - Get User Ratings

    func getUserRatings(id: String) async throws -> UserRatingsResponse {
        let response: UserRatingsResponse = try await network.request(
            endpoint: "/users/\(id)/ratings",
            method: .get,
            requiresAuth: false
        )
        return response
    }

    // MARK: - Get User Stats

    func getUserStats(id: String) async throws -> UserStats {
        let stats: UserStats = try await network.request(
            endpoint: "/users/\(id)/stats",
            method: .get,
            requiresAuth: false
        )
        return stats
    }
}

// MARK: - Helper Models

struct DriverSetupRequest: Codable {
    let vehicleInfo: String
    let seatsAvailable: Int

    enum CodingKeys: String, CodingKey {
        case vehicleInfo = "vehicle_info"
        case seatsAvailable = "seats_available"
    }
}

struct UserRatingsResponse: Codable {
    let ratings: [Rating]
    let totalRatings: Int
    let averageRating: Double

    enum CodingKeys: String, CodingKey {
        case ratings
        case totalRatings = "total_ratings"
        case averageRating = "average_rating"
    }
}

struct UserStats: Codable {
    let totalTripsCompleted: Int
    let totalBookings: Int
    let averageRating: Double
    let totalDistanceMiles: Double

    enum CodingKeys: String, CodingKey {
        case totalTripsCompleted = "total_trips_completed"
        case totalBookings = "total_bookings"
        case averageRating = "average_rating"
        case totalDistanceMiles = "total_distance_miles"
    }
}
