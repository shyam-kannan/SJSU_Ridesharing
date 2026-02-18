import Foundation

// MARK: - Generic API Response Wrapper

struct APIResponse<T: Codable>: Codable {
    let status: String
    let message: String?
    let data: T?
    let errors: [String]?
}

// MARK: - API Error

struct APIError: Error, Codable {
    let status: String
    let message: String
    let errors: [String]?

    var localizedDescription: String {
        if let errors = errors, !errors.isEmpty {
            return errors.joined(separator: "\n")
        }
        return message
    }
}

// MARK: - Network Error

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(APIError)
    case unauthorized
    case unknown(Error)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let apiError):
            return apiError.localizedDescription
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
