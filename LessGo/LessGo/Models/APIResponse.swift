import Foundation

// MARK: - Generic API Response Wrapper

struct APIResponse<T: Codable>: Codable {
    let status: String
    let message: String?
    let data: T?
    let errors: [String]?
}

// MARK: - Empty Response

struct EmptyResponse: Codable {}

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
    case forbidden
    case notFound
    case tooManyRequests
    case timeout
    case noConnection
    case unknown(Error)

    /// User-friendly error message suitable for display in alerts
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .noData:
            return "No response from server. Please try again."
        case .decodingError:
            return "Something went wrong. Please try again."
        case .serverError(let apiError):
            return Self.friendlyMessage(from: apiError)
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .forbidden:
            return "You don't have permission for this action."
        case .notFound:
            return "This item no longer exists."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .timeout:
            return "Connection timed out. Please check your internet and try again."
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .unknown(let error):
            if let urlError = error as? URLError {
                return Self.friendlyMessage(from: urlError)
            }
            return "Something went wrong. Please try again."
        }
    }

    /// Maps raw API error messages to user-friendly text
    private static func friendlyMessage(from apiError: APIError) -> String {
        let msg = apiError.message.lowercased()

        // Auth errors
        if msg.contains("invalid credentials") || msg.contains("invalid password") || msg.contains("incorrect password") {
            return "Invalid email or password. Please try again."
        }
        if msg.contains("user not found") || msg.contains("no user found") {
            return "No account found with this email."
        }
        if msg.contains("already exists") || msg.contains("already registered") || msg.contains("duplicate") {
            if msg.contains("email") {
                return "This email is already registered. Try logging in instead."
            }
            return "This account already exists."
        }

        // Validation errors
        if msg.contains("validation") {
            if let errors = apiError.errors, !errors.isEmpty {
                return errors.first ?? "Please check your information and try again."
            }
            return "Please check your information and try again."
        }
        if msg.contains("required") {
            return apiError.message // Use the specific backend message
        }

        // Trip errors
        if msg.contains("not available for booking") || msg.contains("not active") {
            return "This trip is no longer available for booking."
        }
        if msg.contains("not enough seats") {
            return "Not enough seats available for this trip."
        }
        if msg.contains("already have a trip") || msg.contains("overlap") {
            return "You already have a trip scheduled at this time."
        }
        if msg.contains("complete your driver profile") || msg.contains("vehicle") {
            return "Please complete your driver profile before creating trips."
        }

        // Booking errors
        if msg.contains("quote") || msg.contains("calculate price") {
            return "Unable to calculate the price. Please try again."
        }
        if msg.contains("payment") {
            return "Payment unsuccessful. Please try again."
        }

        // Upload errors
        if msg.contains("upload") || msg.contains("file") {
            return "File upload failed. Please try again with a smaller image."
        }

        // Generic - use backend message if it's short and clear enough
        if apiError.message.count < 80 && !msg.contains("error") {
            return apiError.message
        }

        return "Something went wrong. Please try again."
    }

    /// Maps URLError codes to friendly messages
    private static func friendlyMessage(from urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "No internet connection. Please check your network settings."
        case .timedOut:
            return "Connection timed out. Please try again."
        case .cannotFindHost, .cannotConnectToHost:
            return "Unable to reach the server. Please try again later."
        case .secureConnectionFailed:
            return "Secure connection failed. Please try again."
        default:
            return "Connection error. Please check your internet and try again."
        }
    }
}
