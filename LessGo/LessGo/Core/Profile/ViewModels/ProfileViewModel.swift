import SwiftUI
import UIKit
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var ratings: [Rating] = []
    @Published var stats: UserStats?
    @Published var driverTrips: [Trip] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Edit form
    @Published var editName = ""
    @Published var editEmail = ""

    // Driver setup
    @Published var vehicleInfo = ""
    @Published var seatsAvailable = 3
    @Published var licensePlate = ""

    private let userService = UserService.shared
    private let tripService = TripService.shared

    // MARK: - Load Profile

    func loadProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let userTask = userService.getUserProfile(id: userId)
            async let ratingsTask = userService.getUserRatings(id: userId)
            async let statsTask = userService.getUserStats(id: userId)

            let (fetchedUser, ratingsResp, fetchedStats) = try await (userTask, ratingsTask, statsTask)
            user = fetchedUser
            ratings = ratingsResp.ratings
            stats = fetchedStats
            editName = fetchedUser.name
            editEmail = fetchedUser.email
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Update Profile

    func saveProfile(userId: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await userService.updateProfile(
                id: userId,
                name: editName.isEmpty ? nil : editName,
                email: editEmail.isEmpty ? nil : editEmail
            )
            user = updated
            successMessage = "Profile updated!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Setup Driver

    func setupDriver(userId: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await userService.setupDriverProfile(
                id: userId,
                vehicleInfo: vehicleInfo,
                seatsAvailable: seatsAvailable,
                licensePlate: licensePlate
            )
            user = updated
            successMessage = "Driver profile saved!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Load Driver Trips

    func loadDriverTrips(driverId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tripService.listTrips(driverId: driverId, status: .pending)
            driverTrips = response.trips
        } catch {}
    }

    // MARK: - Cancel Trip

    func cancelTrip(id: String) async {
        do {
            _ = try await tripService.cancelTrip(id: id)
            driverTrips.removeAll { $0.id == id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {}
    }

    // MARK: - Profile Picture Upload

    func uploadProfilePicture(userId: String, image: UIImage) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await userService.uploadProfilePicture(userId: userId, image: image)
            user = updated
            successMessage = "Profile picture updated!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    func removeProfilePicture(userId: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await userService.removeProfilePicture(userId: userId)
            user = updated
            successMessage = "Profile picture removed!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Driver Earnings

    struct DriverEarnings: Codable {
        let totalEarned: Double
        let tripsCompleted: Int
        let tripsActive: Int
        let thisMonthEarned: Double

        enum CodingKeys: String, CodingKey {
            case totalEarned = "total_earned"
            case tripsCompleted = "trips_completed"
            case tripsActive = "trips_active"
            case thisMonthEarned = "this_month_earned"
        }
    }

    @Published var earnings: DriverEarnings?

    func loadEarnings(userId: String) async {
        do {
            let earnings: DriverEarnings = try await NetworkManager.shared.request(
                endpoint: "/users/\(userId)/earnings",
                method: .get,
                requiresAuth: true
            )
            await MainActor.run { self.earnings = earnings }
        } catch {
            print("Failed to load earnings: \(error)")
        }
    }
}
