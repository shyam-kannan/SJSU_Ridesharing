import Foundation
import CoreLocation

// MARK: - Matching Service
// Handles the rider request flow and polls notification store for driver incoming requests.

class MatchingService {
    static let shared = MatchingService()
    private let network = NetworkManager.shared
    private let tripService = TripService.shared
    private let notificationService = NotificationService.shared

    private init() {}

    // MARK: - Submit Ride Request (rider)

    func submitRequest(
        origin: String,
        destination: String,
        originCoordinate: CLLocationCoordinate2D,
        destinationCoordinate: CLLocationCoordinate2D,
        departureTime: Date
    ) async throws -> RiderTripRequestResponse {
        try await tripService.requestTrip(
            origin: origin,
            destination: destination,
            originLat: originCoordinate.latitude,
            originLng: originCoordinate.longitude,
            destinationLat: destinationCoordinate.latitude,
            destinationLng: destinationCoordinate.longitude,
            departureTime: departureTime
        )
    }

    // MARK: - Poll for Match (rider-side, polling fallback)
    // Polls every 2 seconds for up to 60 seconds.

    func pollForMatch(requestId: String) async -> TripRequestStatus? {
        let maxAttempts = 30
        for _ in 0..<maxAttempts {
            if let status = try? await tripService.getTripRequest(id: requestId) {
                switch status.status {
                case "matched": return status
                case "expired", "cancelled": return nil
                default: break
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return nil
    }

    // MARK: - Poll for Incoming Requests (driver-side)
    // Scans the driver's unread notifications for `incoming_ride_request` type.
    // Called by DriverHomeView on a 3-second timer while available_for_rides = true.

    func checkForIncomingRequest(driverId: String) async -> IncomingMatchPayload? {
        guard let response = try? await notificationService.listNotifications(
            userId: driverId, limit: 10, unreadOnly: true
        ) else { return nil }

        for notification in response.notifications
            where notification.type == "incoming_ride_request" {
            guard let d = notification.data,
                  let matchId       = d.matchId,
                  let requestId     = d.requestId,
                  let riderName     = d.riderName,
                  let riderRating   = d.riderRating,
                  let origin        = d.origin,
                  let destination   = d.destination,
                  let departureTime = d.departureTime,
                  let expiresIn     = d.expiresInSeconds
            else { continue }

            let tripId = d.tripId ?? matchId   // fallback to matchId if trip_id not present

            // Mark as read so we don't re-surface it
            try? await notificationService.markRead(
                userId: driverId,
                notificationId: notification.id
            )

            return IncomingMatchPayload(
                matchId: matchId,
                requestId: requestId,
                tripId: tripId,
                riderName: riderName,
                riderRating: riderRating,
                origin: origin,
                destination: destination,
                departureTime: departureTime,
                expiresInSeconds: expiresIn
            )
        }
        return nil
    }
}
