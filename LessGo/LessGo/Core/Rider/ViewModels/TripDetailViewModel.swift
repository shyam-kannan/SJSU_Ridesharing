import Foundation
import Combine
import UIKit

// MARK: - Trip Detail ViewModel

@MainActor
class TripDetailViewModel: ObservableObject {
    // MARK: - Published State

    @Published var trip: TripWithDriver?
    @Published var booking: Booking?
    @Published var isLoading = false
    @Published var isBooking = false
    @Published var isCancelling = false
    @Published var errorMessage: String?
    @Published var bookingState: BookingState? = nil
    @Published var cancellationSuccess = false
    @Published var bookingSucceeded = false

    // MARK: - Private State

    private let tripService = TripService.shared
    private let bookingService = BookingService.shared
    private var pollingTimer: Timer?
    private var tripId: String

    // MARK: - Initialization

    init(trip: TripWithDriver) {
        self.trip = trip
        self.tripId = trip.id
    }

    // MARK: - Deinitialization

    deinit {
        Task { @MainActor [weak self] in
            self?.stopPolling()
        }
    }

    // MARK: - Public Methods

    func loadTripDetails() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let loadedTrip = try await tripService.getTrip(id: tripId)
            // Convert Trip to TripWithDriver (simplified for now)
            trip = TripWithDriver(
                id: loadedTrip.id,
                driverId: loadedTrip.driverId,
                driverName: loadedTrip.driver?.name ?? "Driver",
                driverRating: loadedTrip.driver?.rating ?? 0.0,
                driverPhotoUrl: loadedTrip.driver?.profilePicture,
                vehicleInfo: loadedTrip.driver?.vehicleInfo,
                origin: loadedTrip.origin,
                destination: loadedTrip.destination,
                departureTime: loadedTrip.departureTime,
                seatsAvailable: loadedTrip.seatsAvailable,
                estimatedCost: 10.0,
                featured: false,
                status: loadedTrip.status.rawValue
            )

            // Check for existing booking
            await checkExistingBooking()
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Failed to load trip details."
        }
    }

    func requestBooking() async {
        guard !isBooking else { return }
        isBooking = true
        errorMessage = nil

        defer { isBooking = false }

        do {
            let fare = trip?.costBreakdown?.perRiderSplit ?? trip?.estimatedCost
            let response = try await bookingService.createBooking(tripId: tripId, seatsBooked: 1, fare: fare)
            booking = response.booking
            bookingState = .pending

            // Start polling for booking status updates
            startPolling()

            NotificationCenter.default.post(name: .navigateToBookingsTab, object: nil)
            NotificationCenter.default.post(
                name: .openBookingDetail,
                object: nil,
                userInfo: ["bookingId": response.booking.id]
            )
            bookingSucceeded = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = "Failed to request ride. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func cancelBooking() async {
        guard let bookingId = booking?.id else { 
            errorMessage = "No booking to cancel"
            return 
        }

        isCancelling = true
        errorMessage = nil

        defer { isCancelling = false }

        do {
            _ = try await bookingService.cancelBooking(id: bookingId)
            booking = nil
            bookingState = nil
            stopPolling()
            cancellationSuccess = true

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = "Failed to cancel booking. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Private Methods

    func checkExistingBooking() async {
        do {
            let existingBooking = try await bookingService.getBookingForTrip(tripId: tripId)
            booking = existingBooking
            if let bookingState = existingBooking?.bookingState {
                self.bookingState = bookingState
                if bookingState == .pending {
                    startPolling()
                }
            }
        } catch {
            // No existing booking
            booking = nil
            bookingState = nil
        }
    }

    private func startPolling() {
        stopPolling()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkExistingBooking()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

