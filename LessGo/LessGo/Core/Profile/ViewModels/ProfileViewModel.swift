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

    // Driver setup — raw fields (used as fallback / submission values)
    @Published var vehicleInfo = ""
    @Published var seatsAvailable = 3
    @Published var licensePlate = ""

    // ── Vehicle picker state ──────────────────────────────────────────────────
    @Published var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @Published var pickerMake: String = ""
    @Published var pickerModel: String = ""
    @Published var pickerTrimId: String = ""

    // Lookup results
    @Published var availableMakes: [String] = []
    @Published var availableModels: [String] = []
    @Published var vehicleSpecs: VehicleSpecs? = nil

    // Loading flags
    @Published var isLoadingMakes = false
    @Published var isLoadingModels = false
    @Published var isLoadingSpecs = false
    @Published var vehicleLookupFailed = false

    // Driver can override auto-populated seats
    @Published var seatsOverride: Int? = nil

    // Vehicle photo
    @Published var vehiclePhotoURL: String? = nil
    @Published var isLoadingPhoto = false

    // ── Computed helpers ──────────────────────────────────────────────────────

    var selectedTrim: VehicleTrim? {
        vehicleSpecs?.trims.first { $0.id == pickerTrimId }
    }

    var effectiveSeats: Int {
        if let override = seatsOverride { return override }
        return vehicleSpecs?.seatingCapacity ?? seatsAvailable
    }

    var formattedVehicleInfo: String {
        guard !pickerMake.isEmpty, !pickerModel.isEmpty else { return vehicleInfo }
        let trimName = selectedTrim?.trimName
        // Use String(pickerYear) to avoid locale-formatted "2,024" on some devices
        return [String(pickerYear), pickerMake, pickerModel, trimName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var vehiclePickerIsActive: Bool {
        !pickerMake.isEmpty && !pickerModel.isEmpty
    }

    private let vehicleService = VehicleService.shared

    private let userService = UserService.shared
    private let tripService = TripService.shared

    // MARK: - Load Profile

    func loadProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetchedUser = try await userService.getUserProfile(id: userId)
            user = fetchedUser
            editName = fetchedUser.name
            editEmail = fetchedUser.email

            async let ratingsTask = userService.getUserRatings(id: userId)
            async let statsTask = userService.getUserStats(id: userId)

            do {
                let ratingsResp = try await ratingsTask
                ratings = ratingsResp.ratings
            } catch {
                #if DEBUG
                print("[ProfileViewModel] Failed to load ratings: \(error)")
                #endif
            }

            do {
                let fetchedStats = try await statsTask
                stats = fetchedStats
            } catch {
                #if DEBUG
                print("[ProfileViewModel] Failed to load stats: \(error)")
                #endif
            }
        } catch let error as NetworkError {
            #if DEBUG
            print("[ProfileViewModel] Failed to load profile: \(error)")
            #endif
            errorMessage = error.userMessage
        } catch {
            #if DEBUG
            print("[ProfileViewModel] Failed to load profile: \(error)")
            #endif
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
            
            // Auto-dismiss success message after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.successMessage = nil
            }
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Setup Driver

    func setupDriver(userId: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Use picker values if a vehicle was selected; fall back to raw fields
        let finalVehicleInfo = vehiclePickerIsActive ? formattedVehicleInfo : vehicleInfo
        let finalSeats = vehiclePickerIsActive ? effectiveSeats : seatsAvailable

        do {
            let updated = try await userService.setupDriverProfile(
                id: userId,
                vehicleInfo: finalVehicleInfo,
                seatsAvailable: finalSeats,
                licensePlate: licensePlate
            )
            user = updated
            successMessage = "Driver profile saved!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Auto-dismiss success message after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.successMessage = nil
            }
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Vehicle Picker Lookups

    func loadMakes() async {
        guard availableMakes.isEmpty else { return }
        isLoadingMakes = true
        vehicleLookupFailed = false
        defer { isLoadingMakes = false }
        do {
            availableMakes = try await vehicleService.fetchMakes()
        } catch {
            vehicleLookupFailed = true
            errorMessage = (error as? VehicleError)?.errorDescription ?? "Vehicle lookup unavailable. Please enter details manually."
        }
    }

    func loadModels(make: String, year: Int) async {
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            availableModels = try await vehicleService.fetchModels(make: make, year: year)
        } catch {
            availableModels = []
            vehicleLookupFailed = true
        }
    }

    func loadSpecs(make: String, model: String, year: Int) async {
        isLoadingSpecs = true
        vehicleSpecs = nil
        defer { isLoadingSpecs = false }
        do {
            let specs = try await vehicleService.fetchSpecs(make: make, model: model, year: year)
            vehicleSpecs = specs
            // Auto-select single trim
            if specs.trims.count == 1 {
                pickerTrimId = specs.trims[0].id
            }
            // Apply seating if not overridden
            if seatsOverride == nil {
                seatsAvailable = specs.seatingCapacity
            }
            // Kick off photo load concurrently (non-blocking)
            Task { await loadPhoto(make: make, model: model, year: year) }
        } catch {
            vehicleLookupFailed = true
        }
    }

    func retrySpecsLookup() async {
        // Only retry if we have make, model, and year values
        guard !pickerMake.isEmpty, !pickerModel.isEmpty, pickerYear > 0 else {
            return
        }

        // Clear error state and retry
        vehicleLookupFailed = false
        await loadSpecs(make: pickerMake, model: pickerModel, year: pickerYear)
    }

    func loadPhoto(make: String, model: String, year: Int) async {
        isLoadingPhoto = true
        vehiclePhotoURL = nil
        defer { isLoadingPhoto = false }
        vehiclePhotoURL = try? await vehicleService.fetchPhoto(make: make, model: model, year: year)
    }

    func clearPickerMake() {
        pickerMake = ""
        pickerModel = ""
        pickerTrimId = ""
        availableModels = []
        vehicleSpecs = nil
        vehiclePhotoURL = nil
        seatsOverride = nil
    }

    func clearPickerModel() {
        pickerModel = ""
        pickerTrimId = ""
        vehicleSpecs = nil
        vehiclePhotoURL = nil
        seatsOverride = nil
    }

    /// Try to pre-populate the picker from an existing vehicle_info string.
    /// Expected format: "{year} {make} {model} {optional trim...}"
    func parseExistingVehicleInfo(_ info: String) {
        guard !info.isEmpty else { return }
        let parts = info.split(separator: " ", maxSplits: 3).map(String.init)
        guard parts.count >= 3,
              let year = Int(parts[0]),
              year >= 2000,
              year <= Calendar.current.component(.year, from: Date()) + 1
        else { return }

        pickerYear = year
        pickerMake = parts[1]
        pickerModel = parts[2]
        // Trim is optional — if present it will be matched after specs load
        if parts.count == 4 { pickerTrimId = parts[3] }
    }

    // MARK: - Load Driver Trips

    func loadDriverTrips(driverId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Load all trips for this driver (no status filter) so the driver home
            // screen can compute active trips, today's completions, etc. locally.
            let response = try await tripService.listTrips(driverId: driverId, limit: 50)
            driverTrips = response.trips
        } catch {
            #if DEBUG
            print("[ProfileViewModel] Failed to load driver trips: \(error)")
            #endif
            // Surface a user-friendly message so the driver dashboard can show
            // an empty/error state instructing the user to pull-to-refresh.
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Pull down to refresh"
            // Clear trips to ensure UI shows empty state
            driverTrips = []
        }
    }

    // MARK: - Cancel Trip

    func cancelTrip(id: String) async {
        do {
            _ = try await tripService.cancelTrip(id: id)
            driverTrips.removeAll { $0.id == id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            #if DEBUG
            print("[ProfileViewModel] Failed to cancel trip: \(error)")
            #endif
        }
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.successMessage = nil
            }
        } catch let error as NetworkError {
            #if DEBUG
            print("[ProfileViewModel] Failed to upload profile picture: \(error)")
            #endif
            errorMessage = error.userMessage
        } catch {
            #if DEBUG
            print("[ProfileViewModel] Failed to upload profile picture: \(error)")
            #endif
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.successMessage = nil
            }
        } catch let error as NetworkError {
            #if DEBUG
            print("[ProfileViewModel] Failed to remove profile picture: \(error)")
            #endif
            errorMessage = error.userMessage
        } catch {
            #if DEBUG
            print("[ProfileViewModel] Failed to remove profile picture: \(error)")
            #endif
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
            #if DEBUG
            print("[ProfileViewModel] Failed to load earnings: \(error)")
            #endif
        }
    }
}
