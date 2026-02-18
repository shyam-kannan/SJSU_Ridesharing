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
    case active
    case completed
    case cancelled
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
