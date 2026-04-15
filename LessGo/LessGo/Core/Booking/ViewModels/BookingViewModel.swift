import SwiftUI
import UIKit
import Combine

enum BookingErrorKind {
    case noConnection
    case authRequired
    case serverDown
    case other
}

@MainActor
class BookingViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var currentBooking: Booking?
    @Published var currentPayment: Payment?
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var errorKind: BookingErrorKind? = nil
    @Published var showSuccess = false
    @Published var bookingSuccessMessage = ""

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
            print("[TripsView] Bookings fetch failed: \(error)")
            errorMessage = error.userMessage
            errorKind = errorKindFor(error)
        } catch {
            print("[TripsView] Bookings fetch failed (unknown): \(error)")
            errorMessage = "Something went wrong. Please try again."
            errorKind = .other
        }
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
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Confirm Booking + Create Payment Intent

    func confirmAndPay(bookingId: String, amount: Double) async -> Bool {
        _ = amount // Kept for call-site compatibility; backend computes/creates payment on confirm.
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Backend confirm flow creates/returns payment intent and updates booking status.
            let booking = try await bookingService.confirmBooking(id: bookingId)
            currentBooking = booking
            currentPayment = booking.payment

            showSuccess = true
            bookingSuccessMessage = "Your ride is confirmed!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch let error as NetworkError {
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
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
            errorMessage = error.userMessage
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        } catch {
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
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
            return false
        }
    }
}
