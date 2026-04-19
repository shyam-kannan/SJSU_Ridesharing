import Foundation
import Combine
import CoreLocation

// MARK: - Trip Request State Machine
// idle → submitting → searching → matched | failed

enum TripRequestState {
    case idle
    case submitting
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
                state = .searching(requestId: response.requestId)
                startPolling(requestId: response.requestId)
            } catch {
                state = .failed(message: error.localizedDescription)
            }
        }
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
}
