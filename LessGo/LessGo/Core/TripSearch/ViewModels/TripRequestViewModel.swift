import Foundation
import Combine
import CoreLocation

// MARK: - Trip Request State Machine
//
// idle → submitting → selectingDriver  (backend returned ≥1 ranked driver)
//                   → searching        (no immediate candidates; request is pooled)
//                                       ↓ (after rider picks a driver or skips)
//                                    searching → matched | failed

enum TripRequestState: Equatable {
    case idle
    case submitting
    case selectingDriver(requestId: String, drivers: [CandidateDriver])
    case searching(requestId: String)
    case matched(status: TripRequestStatus)
    case failed(message: String)
}

@MainActor
class TripRequestViewModel: ObservableObject {
    @Published var state: TripRequestState = .idle
    @Published var origin: String = ""
    @Published var destination: String = ""
    @Published var departureTime: Date = Date().addingTimeInterval(900) // default: 15 min from now
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?

    private let matchingService = MatchingService.shared
    private var pollTask: Task<Void, Never>?

    // MARK: - Submit

    func submit() {
        guard !origin.isEmpty, !destination.isEmpty else { return }

        let originCoord      = originCoordinate ?? AppConstants.sjsuCoordinate
        let destinationCoord = destinationCoordinate

        guard let destinationCoord else {
            state = .failed(message: "Please enter a valid destination.")
            return
        }

        state = .submitting
        pollTask?.cancel()

        Task {
            do {
                let response = try await matchingService.submitRequest(
                    origin: origin,
                    destination: destination,
                    originCoordinate: originCoord,
                    destinationCoordinate: destinationCoord,
                    departureTime: departureTime
                )

                if response.availableDrivers.isEmpty {
                    // No immediate candidates — enter pooled waiting state
                    state = .searching(requestId: response.requestId)
                    startPolling(requestId: response.requestId)
                } else {
                    // Ranked candidates returned — present selection UI
                    state = .selectingDriver(requestId: response.requestId, drivers: response.availableDrivers)
                }
            } catch {
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Select Driver (rider-initiated marketplace)

    func selectDriver(requestId: String, tripId: String, driverId: String) {
        pollTask?.cancel()
        Task {
            do {
                try await matchingService.selectDriver(requestId: requestId, tripId: tripId, driverId: driverId)
                state = .searching(requestId: requestId)
                startPolling(requestId: requestId)
            } catch {
                state = .failed(message: "Could not send request: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Skip driver selection, enter pool

    func skipToPool(requestId: String) {
        pollTask?.cancel()
        state = .searching(requestId: requestId)
        startPolling(requestId: requestId)
    }

    // MARK: - Polling

    private func startPolling(requestId: String) {
        pollTask = Task {
            if let matched = await matchingService.pollForMatch(requestId: requestId) {
                state = .matched(status: matched)
            } else {
                state = .failed(message: "No driver available right now. Please try again.")
            }
        }
    }

    // MARK: - Geocode destination string to coordinate

    func geocodeDestination(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, _ in
            if let coord = placemarks?.first?.location?.coordinate {
                Task { @MainActor in
                    self.destinationCoordinate = coord
                }
            }
        }
    }

    // MARK: - Reset

    func reset() {
        pollTask?.cancel()
        state = .idle
        origin = ""
        destination = ""
        originCoordinate = nil
        destinationCoordinate = nil
        departureTime = Date().addingTimeInterval(900)
    }

    // MARK: - Dev Tool
    
    func devForceMatch(requestId: String) {
        pollTask?.cancel()
        let dummyStatus = TripRequestStatus(
            requestId: requestId,
            riderId: "dev_rider_123",
            status: "matched",
            origin: self.origin.isEmpty ? "SJSU" : self.origin,
            destination: self.destination.isEmpty ? "Target" : self.destination,
            departureTime: self.departureTime,
            matchedTripId: "dev_trip_123",
            driverId: "dev_driver_123",
            driverName: "Sammy Spartan",
            driverRating: 4.9,
            driverVehicleInfo: "Tesla Model 3, White"
        )
        state = .matched(status: dummyStatus)
    }
}
