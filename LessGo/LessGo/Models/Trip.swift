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
    let maxRiders: Int?
    let pendingBookingCount: Int?
    let totalPayout: Double?
    let totalQuoted: Double?
    let recurrence: String?
    let status: TripStatus
    let createdAt: Date
    let updatedAt: Date
    let driver: User?

    init(
        id: String,
        driverId: String,
        origin: String,
        destination: String,
        originPoint: Coordinate?,
        destinationPoint: Coordinate?,
        departureTime: Date,
        seatsAvailable: Int,
        maxRiders: Int? = nil,
        pendingBookingCount: Int? = nil,
        totalPayout: Double? = nil,
        totalQuoted: Double? = nil,
        recurrence: String?,
        status: TripStatus,
        createdAt: Date,
        updatedAt: Date,
        driver: User?
    ) {
        self.id = id
        self.driverId = driverId
        self.origin = origin
        self.destination = destination
        self.originPoint = originPoint
        self.destinationPoint = destinationPoint
        self.departureTime = departureTime
        self.seatsAvailable = seatsAvailable
        self.maxRiders = maxRiders
        self.pendingBookingCount = pendingBookingCount
        self.totalPayout = totalPayout
        self.totalQuoted = totalQuoted
        self.recurrence = recurrence
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.driver = driver
    }

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case driverId = "driver_id"
        case origin, destination
        case originPoint = "origin_point"
        case destinationPoint = "destination_point"
        case departureTime = "departure_time"
        case seatsAvailable = "seats_available"
        case maxRiders = "max_riders"
        case pendingBookingCount = "pending_booking_count"
        case totalPayout = "total_payout"
        case totalQuoted = "total_quoted"
        case recurrence, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case driver
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        driverId = try container.decode(String.self, forKey: .driverId)
        origin = try container.decode(String.self, forKey: .origin)
        destination = try container.decode(String.self, forKey: .destination)
        originPoint = try container.decodeIfPresent(Coordinate.self, forKey: .originPoint)
        destinationPoint = try container.decodeIfPresent(Coordinate.self, forKey: .destinationPoint)
        departureTime = try container.decode(Date.self, forKey: .departureTime)
        seatsAvailable = try container.decode(Int.self, forKey: .seatsAvailable)
        maxRiders = try container.decodeIfPresent(Int.self, forKey: .maxRiders)
        pendingBookingCount = try container.decodeIfPresent(Int.self, forKey: .pendingBookingCount)
        totalPayout = try container.decodeIfPresent(Double.self, forKey: .totalPayout)
        totalQuoted = try container.decodeIfPresent(Double.self, forKey: .totalQuoted)
        recurrence = try container.decodeIfPresent(String.self, forKey: .recurrence)
        status = try Self.decodeStatus(from: container)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        driver = try container.decodeIfPresent(User.self, forKey: .driver)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(driverId, forKey: .driverId)
        try c.encode(origin, forKey: .origin)
        try c.encode(destination, forKey: .destination)
        try c.encodeIfPresent(originPoint, forKey: .originPoint)
        try c.encodeIfPresent(destinationPoint, forKey: .destinationPoint)
        try c.encode(departureTime, forKey: .departureTime)
        try c.encode(seatsAvailable, forKey: .seatsAvailable)
        try c.encodeIfPresent(maxRiders, forKey: .maxRiders)
        try c.encodeIfPresent(pendingBookingCount, forKey: .pendingBookingCount)
        try c.encodeIfPresent(totalPayout, forKey: .totalPayout)
        try c.encodeIfPresent(totalQuoted, forKey: .totalQuoted)
        try c.encodeIfPresent(recurrence, forKey: .recurrence)
        try c.encode(status, forKey: .status)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(driver, forKey: .driver)
    }

    private static func decodeStatus(from container: KeyedDecodingContainer<CodingKeys>) throws -> TripStatus {
        let rawValue = try container.decode(String.self, forKey: .status)
        if let status = TripStatus(rawValue: rawValue) {
            return status
        }

        if rawValue.lowercased() == "active" {
            return .pending
        }

        throw DecodingError.dataCorruptedError(
            forKey: .status,
            in: container,
            debugDescription: "Unknown trip status: \(rawValue)"
        )
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

// MARK: - On-demand Rider Request Models

struct RiderTripRequest: Codable {
    let origin: String
    let destination: String
    let originLat: Double
    let originLng: Double
    let destinationLat: Double
    let destinationLng: Double
    let departureTime: Date

    enum CodingKeys: String, CodingKey {
        case origin, destination
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destinationLat = "destination_lat"
        case destinationLng = "destination_lng"
        case departureTime = "departure_time"
    }
}

struct RiderTripRequestResponse: Codable {
    let requestId: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case createdAt = "created_at"
    }
}

struct TripRequestStatus: Codable {
    let requestId: String
    let riderId: String
    let status: String           // pending | matched | expired | cancelled
    let origin: String
    let destination: String
    let departureTime: Date
    let matchedTripId: String?
    let driverId: String?
    let driverName: String?
    let driverRating: Double?
    let driverVehicleInfo: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case riderId = "rider_id"
        case status, origin, destination
        case departureTime = "departure_time"
        case matchedTripId = "matched_trip_id"
        case driverId = "driver_id"
        case driverName = "driver_name"
        case driverRating = "driver_rating"
        case driverVehicleInfo = "driver_vehicle_info"
    }
}

// MARK: - Anchor Point (multi-passenger route merging)

struct AnchorPoint: Codable, Identifiable {
    var id: String { "\(lat),\(lng),\(type)" }
    let lat: Double
    let lng: Double
    let type: AnchorType
    let riderId: String?
    let label: String?
    let etaOffsetSeconds: Double?

    enum AnchorType: String, Codable {
        case pickup, dropoff
    }

    enum CodingKeys: String, CodingKey {
        case lat, lng, type
        case riderId = "rider_id"
        case label
        case etaOffsetSeconds = "eta_offset_seconds"
    }
}

struct AnchorPointsResponse: Codable {
    let tripId: String
    let anchorPoints: [AnchorPoint]

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case anchorPoints = "anchor_points"
    }
}

// MARK: - Frequent Route Segment (GPS trajectory mining, He et al. 2014)

struct FrequentRouteCenter: Codable {
    let lat: Double
    let lng: Double
}

struct FrequentRouteSegment: Codable {
    let originZone:   Int
    let destZone:     Int
    let timeBin:      Int
    let frequency:    Int
    let routeScore:   Double
    let originCenter: FrequentRouteCenter
    let destCenter:   FrequentRouteCenter

    enum CodingKeys: String, CodingKey {
        case originZone   = "originZone"
        case destZone     = "destZone"
        case timeBin      = "timeBin"
        case frequency
        case routeScore   = "routeScore"
        case originCenter = "originCenter"
        case destCenter   = "destCenter"
    }
}

struct FrequentRoutesResponse: Codable {
    let driverId: String
    let routes:   [FrequentRouteSegment]

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case routes
    }
}

// MARK: - Incoming match notification payload

struct IncomingMatchPayload: Codable {
    let matchId: String
    let requestId: String
    let tripId: String
    let riderName: String
    let riderRating: Double
    let origin: String
    let destination: String
    let departureTime: String
    let expiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case requestId = "request_id"
        case tripId = "trip_id"
        case riderName = "rider_name"
        case riderRating = "rider_rating"
        case origin, destination
        case departureTime = "departure_time"
        case expiresInSeconds = "expires_in_seconds"
    }
}

// MARK: - Trip Settlement (Dynamic Trip Settlement System)

struct TripSettlement: Codable {
    let tripId: String
    let totalCost: Double
    let driverEarnings: Double
    let riderCount: Int
    let breakdown: SettlementBreakdown
    let riders: [RiderSettlement]

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case totalCost = "total_cost"
        case driverEarnings = "driver_earnings"
        case riderCount = "rider_count"
        case breakdown, riders
    }
}

struct SettlementBreakdown: Codable {
    let basePrice: Double
    let directDistanceMiles: Double
    let fuelPricePerGal: Double
    let detourMultiplier: Double

    enum CodingKeys: String, CodingKey {
        case basePrice = "base_price"
        case directDistanceMiles = "direct_distance_miles"
        case fuelPricePerGal = "fuel_price_per_gal"
        case detourMultiplier = "detour_multiplier"
    }
}

struct RiderSettlement: Codable {
    let riderId: String
    let riderName: String
    let amountPaid: Double
    let status: String
    let detourMiles: Double
    let breakdown: String

    enum CodingKeys: String, CodingKey {
        case riderId = "rider_id"
        case riderName = "rider_name"
        case amountPaid = "amount_paid"
        case detourMiles = "detour_miles"
        case status, breakdown
    }
}

// MARK: - Trip State Update Response (wraps trip + optional settlement)

struct TripStateUpdateResponse: Codable {
    let trip: Trip
    let settlement: TripSettlement?
}
