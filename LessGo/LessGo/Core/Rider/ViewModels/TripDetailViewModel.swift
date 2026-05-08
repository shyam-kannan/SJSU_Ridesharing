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
    @Published var isAuthorizing = false
    @Published var paymentAuthorized = false
    @Published var paymentDeadlineAt: Date? = nil
    @Published var cancellationReason: String? = nil

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
            // Preserve the original TripWithDriver (which has costBreakdown from search),
            // only refreshing mutable fields that may have changed since search.
            if let existing = trip {
                trip = TripWithDriver(
                    id: existing.id,
                    driverId: existing.driverId,
                    driverName: loadedTrip.driver?.name ?? existing.driverName,
                    driverRating: loadedTrip.driver?.rating ?? existing.driverRating,
                    driverPhotoUrl: loadedTrip.driver?.profilePicture ?? existing.driverPhotoUrl,
                    vehicleInfo: loadedTrip.driver?.vehicleInfo ?? existing.vehicleInfo,
                    origin: existing.origin,
                    destination: existing.destination,
                    departureTime: existing.departureTime,
                    seatsAvailable: loadedTrip.seatsAvailable,
                    estimatedCost: existing.estimatedCost,
                    featured: existing.featured,
                    status: loadedTrip.status.rawValue,
                    originLat: existing.originLat,
                    originLng: existing.originLng,
                    detourMiles: existing.detourMiles,
                    adjustedEtaMinutes: existing.adjustedEtaMinutes,
                    originalEtaMinutes: existing.originalEtaMinutes,
                    detourTimeMinutes: existing.detourTimeMinutes,
                    costBreakdown: existing.costBreakdown
                )
            }

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

            // Navigate rider to Trips tab and deep-link into the new booking
            NotificationCenter.default.post(name: .navigateToBookingsTab, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(
                    name: .openBookingDetail,
                    object: nil,
                    userInfo: ["bookingId": response.booking.id]
                )
            }

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

    func authorizePayment() async {
        guard let bookingId = booking?.id else { return }
        isAuthorizing = true
        errorMessage = nil

        defer { isAuthorizing = false }

        do {
            // Step 1: Create PaymentIntent on backend (authorize / card hold)
            _ = try await bookingService.authorizePayment(bookingId: bookingId)

            // Step 2: Confirm the PaymentIntent server-side so it moves to
            // requires_capture, ready for driver-triggered capture at trip end.
            try await bookingService.confirmPayment(bookingId: bookingId)

            paymentAuthorized = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = "Failed to authorize payment. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Private Methods

    func checkExistingBooking() async {
        do {
            let existingBooking = try await bookingService.getBookingForTrip(tripId: tripId)
            if let existingBooking = existingBooking,
               existingBooking.bookingState == .cancelled || existingBooking.bookingState == .rejected {
                booking = nil
                bookingState = nil
                // Still surface cancellation reason if available (e.g. payment_not_completed)
                cancellationReason = existingBooking.cancellationReason
                paymentDeadlineAt = nil
            } else {
                booking = existingBooking
                if let existingBooking = existingBooking {
                    let state = existingBooking.bookingState
                    self.bookingState = state
                    self.paymentDeadlineAt = existingBooking.paymentDeadlineAt
                    self.cancellationReason = existingBooking.cancellationReason
                    if state == .pending {
                        startPolling()
                    } else {
                        // Terminal or settled state — stop polling
                        stopPolling()
                    }
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

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
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

