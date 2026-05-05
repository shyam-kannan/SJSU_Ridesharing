import Foundation

// MARK: - Trip with Driver Model

struct TripWithDriver: Identifiable, Codable {
    let id: String
    let driverId: String
    let driverName: String
    let driverRating: Double
    let driverPhotoUrl: String?
    let vehicleInfo: String?
    let origin: String
    let destination: String
    let departureTime: Date
    let seatsAvailable: Int
    let estimatedCost: Double
    let featured: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case driverId = "driver_id"
        case driverName = "driver_name"
        case driverRating = "driver_rating"
        case driverPhotoUrl = "driver_photo_url"
        case vehicleInfo = "vehicle_info"
        case origin, destination
        case departureTime = "departure_time"
        case seatsAvailable = "seats_available"
        case estimatedCost = "estimated_cost"
        case featured, status
    }

    init(
        id: String,
        driverId: String,
        driverName: String,
        driverRating: Double,
        driverPhotoUrl: String?,
        vehicleInfo: String?,
        origin: String,
        destination: String,
        departureTime: Date,
        seatsAvailable: Int,
        estimatedCost: Double,
        featured: Bool,
        status: String
    ) {
        self.id = id
        self.driverId = driverId
        self.driverName = driverName
        self.driverRating = driverRating
        self.driverPhotoUrl = driverPhotoUrl
        self.vehicleInfo = vehicleInfo
        self.origin = origin
        self.destination = destination
        self.departureTime = departureTime
        self.seatsAvailable = seatsAvailable
        self.estimatedCost = estimatedCost
        self.featured = featured
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        driverId = try container.decode(String.self, forKey: .driverId)
        driverName = try container.decode(String.self, forKey: .driverName)
        driverPhotoUrl = try container.decodeIfPresent(String.self, forKey: .driverPhotoUrl)
        vehicleInfo = try container.decodeIfPresent(String.self, forKey: .vehicleInfo)
        origin = try container.decode(String.self, forKey: .origin)
        destination = try container.decode(String.self, forKey: .destination)
        departureTime = try container.decode(Date.self, forKey: .departureTime)
        seatsAvailable = try container.decode(Int.self, forKey: .seatsAvailable)
        featured = try container.decode(Bool.self, forKey: .featured)
        status = try container.decode(String.self, forKey: .status)

        // Backend sends rating and cost as String ("0.00") or Double
        if let ratingDouble = try? container.decode(Double.self, forKey: .driverRating) {
            driverRating = ratingDouble
        } else if let ratingString = try? container.decode(String.self, forKey: .driverRating),
                  let parsed = Double(ratingString) {
            driverRating = parsed
        } else {
            driverRating = 0.0
        }

        if let costDouble = try? container.decode(Double.self, forKey: .estimatedCost) {
            estimatedCost = costDouble
        } else if let costString = try? container.decode(String.self, forKey: .estimatedCost),
                  let parsed = Double(costString) {
            estimatedCost = parsed
        } else {
            estimatedCost = 0.0
        }
    }
}

// MARK: - Search Results Response

struct TripSearchResultsResponse: Codable {
    let trips: [TripWithDriver]
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case trips, total
        case hasMore = "has_more"
    }
}
