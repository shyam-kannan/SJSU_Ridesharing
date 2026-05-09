import SwiftUI
import UIKit
import Combine
import StripePaymentSheet

enum BookingErrorKind {
    case noConnection
    case authRequired
    case serverDown
    case other
}

@MainActor
class BookingViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var postedTrips: [Trip] = []
    @Published var currentBooking: Booking?
    @Published var currentPayment: Payment?
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var errorKind: BookingErrorKind? = nil
    @Published var showSuccess = false
    @Published var bookingSuccessMessage = ""
    @Published var shouldPresentPaymentSheet = false
    private(set) var pendingBookingIdForPayment: String?

    private let bookingService = BookingService.shared

    // MARK: - Load Bookings

    func loadBookings(asDriver: Bool = false) async {
        isLoading = true
        errorMessage = nil
        errorKind = nil
        defer { isLoading = false }
        do {
            let response = try await bookingService.listBookings(asDriver: asDriver)
            withAnimation {
                bookings = response.bookings
            }
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to load bookings: \(error)")
            #endif
            errorMessage = error.userMessage
            errorKind = errorKindFor(error)
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to load bookings: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            errorKind = .other
        }
    }

    func loadPostedTrips(driverId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await TripService.shared.listTrips(driverId: driverId, limit: 50)
            let cutoff = Date().addingTimeInterval(-24 * 3600)

            // Auto-cancel pending trips whose departure time is more than 24 hours ago
            for trip in response.trips where trip.status == .pending && trip.departureTime < cutoff {
                _ = try? await TripService.shared.cancelTrip(id: trip.id)
            }

            // Filter: only show pending trips, hide anything departed > 24 hrs ago
            withAnimation {
                postedTrips = response.trips.filter { trip in
                    guard trip.departureTime >= cutoff else { return false }
                    return trip.status == .pending
                }
            }
        } catch {
            postedTrips = []
        }
    }

    func cancelPostedTrip(id: String) async {
        _ = try? await TripService.shared.cancelTrip(id: id)
        postedTrips.removeAll { $0.id == id }
    }

    func deletePostedTrip(id: String) async {
        try? await TripService.shared.deleteTrip(tripId: id)
        postedTrips.removeAll { $0.id == id }
        bookings.removeAll { $0.tripId == id }
    }

    func updatePostedTrip(id: String, departureTime: Date, seatsAvailable: Int) async -> Bool {
        do {
            let updated = try await TripService.shared.updateTrip(
                id: id,
                departureTime: departureTime,
                seatsAvailable: seatsAvailable
            )
            if let index = postedTrips.firstIndex(where: { $0.id == id }) {
                postedTrips[index] = updated
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Grouped Bookings (Driver View)

    /// Groups driver-view bookings by trip_id, preserving the most-recent booking order.
    var bookingsGroupedByTrip: [(trip: Trip, bookings: [Booking])] {
        var seen = Set<String>()
        var groups: [(trip: Trip, bookings: [Booking])] = []
        for booking in bookings {
            guard let trip = booking.trip else { continue }
            if seen.contains(trip.id) {
                if let idx = groups.firstIndex(where: { $0.trip.id == trip.id }) {
                    groups[idx].bookings.append(booking)
                }
            } else {
                seen.insert(trip.id)
                groups.append((trip: trip, bookings: [booking]))
            }
        }
        return groups
    }

    private func errorKindFor(_ error: NetworkError) -> BookingErrorKind {
        switch error {
        case .noConnection: return .noConnection
        case .unauthorized, .forbidden: return .authRequired
        case .serverError, .unknown: return .serverDown
        default: return .other
        }
    }

    // MARK: - Create Booking

    func createBooking(tripId: String, seats: Int) async -> Bool {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let response = try await bookingService.createBooking(tripId: tripId, seatsBooked: seats)
            currentBooking = response.booking
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to create booking: \(error)")
            #endif
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to create booking: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Confirm Booking + Create Payment Intent

    func confirmAndPay(bookingId: String, amount: Double) async -> Bool {
        _ = amount
        isLoading = true
        errorMessage = nil
        do {
            let result = try await bookingService.authorizePayment(bookingId: bookingId)
            StripePaymentManager.shared.preparePaymentSheet(clientSecret: result.clientSecret)
            pendingBookingIdForPayment = bookingId
            shouldPresentPaymentSheet = true
            isLoading = false
            return true
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            isLoading = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    @MainActor
    func handlePaymentResult(_ result: PaymentSheetResult) async {
        guard let bookingId = pendingBookingIdForPayment else { return }
        pendingBookingIdForPayment = nil
        shouldPresentPaymentSheet = false

        switch result {
        case .completed:
            isLoading = true
            do {
                try await bookingService.confirmPayment(bookingId: bookingId)
                showSuccess = true
                bookingSuccessMessage = "Your ride is confirmed!"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "Payment confirmed but server update failed: \(error.localizedDescription)"
            }
            isLoading = false

        case .canceled:
            break

        case .failed(let error):
            errorMessage = "Payment failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Cancel Booking

    func cancelBooking(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let booking = try await bookingService.cancelBooking(id: id)
            // Update in list
            if let index = bookings.firstIndex(where: { $0.id == id }) {
                bookings[index] = booking
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to cancel booking: \(error)")
            #endif
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to cancel booking: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Approve Booking (Driver Only)

    func approveBooking(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let booking = try await bookingService.approveBooking(id: id)
            // Update in list
            if let index = bookings.firstIndex(where: { $0.id == id }) {
                bookings[index] = booking
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to approve booking: \(error)")
            #endif
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to approve booking: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Reject Booking (Driver Only)

    func rejectBooking(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let booking = try await bookingService.rejectBooking(id: id)
            // Update in list
            if let index = bookings.firstIndex(where: { $0.id == id }) {
                bookings[index] = booking
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to reject booking: \(error)")
            #endif
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to reject booking: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Rate

    func rateBooking(id: String, score: Int, comment: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await bookingService.rateBooking(id: id, score: score, comment: comment)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            #if DEBUG
            print("[BookingViewModel] Failed to rate booking: \(error)")
            #endif
            errorMessage = error.userMessage
            return false
        } catch {
            #if DEBUG
            print("[BookingViewModel] Failed to rate booking: \(error)")
            #endif
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }
}
