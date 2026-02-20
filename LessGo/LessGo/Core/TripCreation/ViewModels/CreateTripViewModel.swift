import SwiftUI
import UIKit
import CoreLocation
import Combine

enum TripDirection: String, CaseIterable {
    case toSJSU = "To SJSU"
    case fromSJSU = "From SJSU"
}

@MainActor
class CreateTripViewModel: ObservableObject {
    // MARK: - Form State
    @Published var tripDirection: TripDirection = .toSJSU
    @Published var userLocation = ""  // The one location user enters
    @Published var origin = ""
    @Published var destination = ""
    @Published var departureDate = Date().addingTimeInterval(3600)
    @Published var seatsAvailable = 2
    @Published var isRecurring = false
    @Published var recurrenceDays: Set<Int> = []  // 1=Mon ... 7=Sun

    // MARK: - Step
    @Published var currentStep = 0
    let totalSteps = 4  // Direction, Location, Schedule, Details

    // MARK: - Loading/Error
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdTrip: Trip?
    @Published var isSuccess = false

    private let tripService = TripService.shared

    // MARK: - Day names
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let dayNumbers = [2, 3, 4, 5, 6, 7, 1]  // Calendar weekday values

    // MARK: - Validation

    var isStep0Valid: Bool { true }  // Direction is always valid
    var isStep1Valid: Bool { !userLocation.isEmpty && userLocation.count >= 3 }
    var isStep2Valid: Bool { departureDate > Date() }
    var isStep3Valid: Bool { seatsAvailable >= 1 }

    var canProceed: Bool {
        switch currentStep {
        case 0: return isStep0Valid
        case 1: return isStep1Valid
        case 2: return isStep2Valid
        case 3: return isStep3Valid
        default: return true
        }
    }

    // MARK: - Sync Origin/Destination

    func syncOriginDestination() {
        switch tripDirection {
        case .toSJSU:
            origin = userLocation
            destination = "San Jose State University"
        case .fromSJSU:
            origin = "San Jose State University"
            destination = userLocation
        }
    }

    // MARK: - Navigation

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep += 1
        }
    }

    func prevStep() {
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep -= 1
        }
    }

    // MARK: - Recurrence String

    var recurrenceString: String? {
        guard isRecurring, !recurrenceDays.isEmpty else { return nil }
        if recurrenceDays.count == 5 && !recurrenceDays.contains(1) && !recurrenceDays.contains(7) {
            return "weekdays"
        }
        if recurrenceDays.count == 7 { return "daily" }
        let sortedDays = recurrenceDays.sorted()
        let names = sortedDays.compactMap { day -> String? in
            guard let idx = dayNumbers.firstIndex(of: day) else { return nil }
            return dayNames[idx]
        }
        return names.joined(separator: ",").lowercased()
    }

    // MARK: - Submit

    func createTrip() async {
        // Sync origin/destination based on direction
        syncOriginDestination()

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trip = try await tripService.createTrip(
                origin: origin,
                destination: destination,
                departureTime: departureDate,
                seatsAvailable: seatsAvailable,
                recurrence: recurrenceString
            )
            createdTrip = trip
            withAnimation { isSuccess = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset

    func reset() {
        tripDirection = .toSJSU
        userLocation = ""
        origin = ""
        destination = ""
        departureDate = Date().addingTimeInterval(3600)
        seatsAvailable = 2
        isRecurring = false
        recurrenceDays = []
        currentStep = 0
        isSuccess = false
        createdTrip = nil
        errorMessage = nil
    }
}
