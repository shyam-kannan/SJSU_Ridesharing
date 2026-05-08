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

    enum CodingKeys: String, CodingKey {
        case id
        case trimName = "trim_name"
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
    let defaultSeats: Int

    enum CodingKeys: String, CodingKey {
        case make, model, year, trims
        case seatingCapacity = "seating_capacity"
        case defaultSeats    = "default_seats"
    }
}
