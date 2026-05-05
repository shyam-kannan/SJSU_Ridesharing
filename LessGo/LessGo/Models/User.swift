import Foundation

// MARK: - User Models

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let role: UserRole
    let sjsuIdStatus: SJSUIDStatus
    let rating: Double
    let vehicleInfo: String?
    let seatsAvailable: Int?
    let licensePlate: String?
    let mpg: Double?
    let profilePicture: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name, email, role
        case sjsuIdStatus = "sjsu_id_status"
        case rating
        case vehicleInfo = "vehicle_info"
        case seatsAvailable = "seats_available"
        case licensePlate = "license_plate"
        case mpg
        case profilePicture = "profile_picture_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        name: String,
        email: String,
        role: UserRole,
        sjsuIdStatus: SJSUIDStatus,
        rating: Double,
        vehicleInfo: String? = nil,
        seatsAvailable: Int? = nil,
        licensePlate: String? = nil,
        mpg: Double? = nil,
        profilePicture: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.sjsuIdStatus = sjsuIdStatus
        self.rating = rating
        self.vehicleInfo = vehicleInfo
        self.seatsAvailable = seatsAvailable
        self.licensePlate = licensePlate
        self.mpg = mpg
        self.profilePicture = profilePicture
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id           = try container.decode(String.self, forKey: .id)
        name         = try container.decode(String.self, forKey: .name)
        email        = try container.decode(String.self, forKey: .email)
        role         = try container.decode(UserRole.self, forKey: .role)
        sjsuIdStatus = try container.decode(SJSUIDStatus.self, forKey: .sjsuIdStatus)
        vehicleInfo  = try container.decodeIfPresent(String.self, forKey: .vehicleInfo)
        seatsAvailable = try container.decodeIfPresent(Int.self, forKey: .seatsAvailable)
        licensePlate = try container.decodeIfPresent(String.self, forKey: .licensePlate)
        profilePicture = try container.decodeIfPresent(String.self, forKey: .profilePicture)
        createdAt    = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt    = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // Backend sends rating as a String ("0.00") or occasionally as a Double.
        if let ratingDouble = try? container.decode(Double.self, forKey: .rating) {
            rating = ratingDouble
        } else if let ratingString = try? container.decode(String.self, forKey: .rating),
                  let parsed = Double(ratingString) {
            rating = parsed
        } else {
            rating = 0.0
        }

        // mpg may come as Double or String from Postgres DECIMAL
        if let mpgDouble = try? container.decode(Double.self, forKey: .mpg) {
            mpg = mpgDouble
        } else if let mpgString = try? container.decode(String.self, forKey: .mpg),
                  let parsed = Double(mpgString) {
            mpg = parsed
        } else {
            mpg = nil
        }
    }
}

enum UserRole: String, Codable {
    case driver = "Driver"
    case rider = "Rider"
}

enum SJSUIDStatus: String, Codable {
    case pending
    case verified
    case rejected
}

// MARK: - Authentication Models

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
    let role: UserRole
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
}
