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
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
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
                seatsAvailable: seatsAvailable
            )
            user = updated
            successMessage = "Driver profile saved!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Driver Trips

    func loadDriverTrips(driverId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tripService.listTrips(driverId: driverId, status: .active)
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
}
