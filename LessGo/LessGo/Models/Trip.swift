import Foundation
import CoreLocation

// MARK: - Trip Models

struct Trip: Codable, Identifiable {
    let id: String
    let driverId: String
    let origin: String
    let destination: String
    let originPoint: Coordinate?
    let destinationPoint: Coordinate?
    let departureTime: Date
    let seatsAvailable: Int
    let recurrence: String?
    let status: TripStatus
    let createdAt: Date
    let updatedAt: Date
    let driver: User?

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case driverId = "driver_id"
        case origin, destination
        case originPoint = "origin_point"
        case destinationPoint = "destination_point"
        case departureTime = "departure_time"
        case seatsAvailable = "seats_available"
        case recurrence, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case driver
    }
}

struct Coordinate: Codable {
    let lat: Double
    let lng: Double

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

enum TripStatus: String, Codable {
    case pending        // Trip created, waiting for driver to start
    case enRoute = "en_route"       // Driver heading to pickup location
    case arrived        // Driver at pickup location
    case inProgress = "in_progress" // Rider in car, heading to destination
    case completed      // Trip finished
    case cancelled      // Trip cancelled

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .enRoute: return "En Route to Pickup"
        case .arrived: return "Arrived at Pickup"
        case .inProgress: return "Trip in Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .enRoute: return "car.fill"
        case .arrived: return "location.fill"
        case .inProgress: return "arrow.triangle.turn.up.right.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "brandGold"
        case .enRoute: return "brand"
        case .arrived: return "brandGreen"
        case .inProgress: return "brand"
        case .completed: return "brandGreen"
        case .cancelled: return "brandRed"
        }
    }
}

// MARK: - Trip Request/Response Models

struct CreateTripRequest: Codable {
    let origin: String
    let destination: String
    let departureTime: Date
    let seatsAvailable: Int
    let recurrence: String?

    enum CodingKeys: String, CodingKey {
        case origin, destination
        case departureTime = "departure_time"
        case seatsAvailable = "seats_available"
        case recurrence
    }
}

struct UpdateTripRequest: Codable {
    let departureTime: Date?
    let seatsAvailable: Int?
    let recurrence: String?

    enum CodingKeys: String, CodingKey {
        case departureTime = "departure_time"
        case seatsAvailable = "seats_available"
        case recurrence
    }
}

struct TripSearchParams {
    let originLat: Double
    let originLng: Double
    let radiusMeters: Int
    let minSeats: Int?
    let departureAfter: Date?
    let departureBefore: Date?
}

struct TripListResponse: Codable {
    let trips: [Trip]
    let total: Int
}
