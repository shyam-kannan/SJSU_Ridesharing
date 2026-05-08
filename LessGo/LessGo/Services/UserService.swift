import Foundation
import UIKit

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
            requiresAuth: true
        )
        return user
    }

    func getCurrentUserProfile() async throws -> User {
        let user: User = try await network.request(
            endpoint: "/users/me",
            method: .get,
            requiresAuth: true
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
            body: body,
            requiresAuth: true
        )

        return user
    }

    // MARK: - Setup Driver Profile

    func setupDriverProfile(id: String, vehicleInfo: String, seatsAvailable: Int, licensePlate: String) async throws -> User {
        let body = DriverSetupRequest(vehicleInfo: vehicleInfo, seatsAvailable: seatsAvailable, licensePlate: licensePlate)

        let user: User = try await network.request(
            endpoint: "/users/\(id)/driver-setup",
            method: .put,
            body: body,
            requiresAuth: true
        )

        return user
    }

    // MARK: - Device Token

    func registerDeviceToken(userId: String, token: String) async throws {
        struct TokenRequest: Encodable { let deviceToken: String }
        let _: EmptyResponse = try await network.request(
            endpoint: "/users/\(userId)/device-token",
            method: .post,
            body: TokenRequest(deviceToken: token),
            requiresAuth: true
        )
    }

    // MARK: - Notification Preferences

    func updateNotificationPreferences(userId: String, emailNotifications: Bool, pushNotifications: Bool) async throws {
        struct PrefsRequest: Encodable { let emailNotifications: Bool; let pushNotifications: Bool }
        let _: EmptyResponse = try await network.request(
            endpoint: "/users/\(userId)/preferences",
            method: .put,
            body: PrefsRequest(emailNotifications: emailNotifications, pushNotifications: pushNotifications),
            requiresAuth: true
        )
    }

    // MARK: - Get User Ratings

    func getUserRatings(id: String) async throws -> UserRatingsResponse {
        let response: UserRatingsResponse = try await network.request(
            endpoint: "/users/\(id)/ratings",
            method: .get,
            requiresAuth: true
        )
        return response
    }

    // MARK: - Get User Stats

    func getUserStats(id: String) async throws -> UserStats {
        let stats: UserStats = try await network.request(
            endpoint: "/users/\(id)/stats",
            method: .get,
            requiresAuth: true
        )
        return stats
    }

    // MARK: - Role Switching

    func updateUserRole(userId: String, role: UserRole) async throws -> User {
        struct RoleUpdateRequest: Encodable {
            let role: String
        }

        let user: User = try await network.request(
            endpoint: "/users/\(userId)/role",
            method: .put,
            body: RoleUpdateRequest(role: role.rawValue),
            requiresAuth: true
        )

        return user
    }

    // MARK: - Profile Picture Upload

    func uploadProfilePicture(userId: String, image: UIImage) async throws -> User {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.unknown(NSError(domain: "Image conversion failed", code: 0))
        }

        let filename = "profile_\(userId)_\(Date().timeIntervalSince1970).jpg"

        let user: User = try await network.uploadMultipart(
            endpoint: "/users/\(userId)/profile-picture",
            parameters: [:],
            files: ["image": (imageData, filename)],
            requiresAuth: true
        )

        return user
    }

    func removeProfilePicture(userId: String) async throws -> User {
        let user: User = try await network.request(
            endpoint: "/users/\(userId)/profile-picture",
            method: .delete,
            requiresAuth: true
        )

        return user
    }

    // MARK: - Stripe Connect

    func startStripeOnboarding() async throws -> URL {
        struct OnboardResponse: Codable {
            let status: String
            let data: OnboardData
            struct OnboardData: Codable {
                let url: String
            }
        }
        let response: OnboardResponse = try await network.request(
            endpoint: "/users/driver/stripe-onboard",
            method: .post,
            requiresAuth: true
        )
        guard let url = URL(string: response.data.url) else {
            throw NetworkError.decodingError(NSError(domain: "Invalid Stripe onboarding URL", code: 0))
        }
        return url
    }

    func getStripeDashboardUrl() async throws -> URL {
        struct DashResponse: Codable {
            let status: String
            let data: DashData
            struct DashData: Codable {
                let url: String
            }
        }
        let response: DashResponse = try await network.request(
            endpoint: "/users/driver/stripe-dashboard",
            method: .get,
            requiresAuth: true
        )
        guard let url = URL(string: response.data.url) else {
            throw NetworkError.decodingError(NSError(domain: "Invalid Stripe dashboard URL", code: 0))
        }
        return url
    }

    // MARK: - Driver Availability

    func updateAvailability(userId: String, available: Bool) async throws {
        struct AvailabilityRequest: Encodable {
            let available_for_rides: Bool
        }
        let _: EmptyResponse = try await network.request(
            endpoint: "/users/\(userId)/availability",
            method: .patch,
            body: AvailabilityRequest(available_for_rides: available),
            requiresAuth: true
        )
    }

}

// MARK: - Helper Models

struct DriverSetupRequest: Codable {
    let vehicleInfo: String
    let seatsAvailable: Int
    let licensePlate: String

    enum CodingKeys: String, CodingKey {
        case vehicleInfo = "vehicle_info"
        case seatsAvailable = "seats_available"
        case licensePlate = "license_plate"
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
    let totalRatings: Int
    let averageRating: Double
    let totalTripsAsDriver: Int?
    let totalBookingsAsRider: Int?

    enum CodingKeys: String, CodingKey {
        case totalRatings = "total_ratings"
        case averageRating = "average_rating"
        case totalTripsAsDriver = "total_trips_as_driver"
        case totalBookingsAsRider = "total_bookings_as_rider"
    }
}
