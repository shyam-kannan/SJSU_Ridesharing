import Foundation

// MARK: - Vehicle Lookup API Models

struct VehicleMakesResponse: Decodable {
    let makes: [String]
}

struct VehicleModelsResponse: Decodable {
    let models: [String]
}

struct VehicleTrim: Decodable, Identifiable {
    let id: String
    let trimName: String
    let cityMpg: Int?
    let highwayMpg: Int?
    let combinedMpg: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case trimName     = "trim_name"
        case cityMpg      = "city_mpg"
        case highwayMpg   = "highway_mpg"
        case combinedMpg  = "combined_mpg"
    }
}

struct VehiclePhotoResponse: Decodable {
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
    }
}

struct VehicleSpecs: Decodable {
    let make: String
    let model: String
    let year: Int
    let seatingCapacity: Int
    let trims: [VehicleTrim]
    let defaultMpg: Int?
    let defaultSeats: Int
    let mpgSource: MpgSource

    enum MpgSource: String, Decodable {
        case doe
        case unavailable
    }

    enum CodingKeys: String, CodingKey {
        case make, model, year, trims
        case seatingCapacity = "seating_capacity"
        case defaultMpg      = "default_mpg"
        case defaultSeats    = "default_seats"
        case mpgSource       = "mpg_source"
    }
}
