import Foundation

// MARK: - Vehicle Lookup Service
// Calls the vehicle proxy endpoints hosted on the user-service (/api/vehicles/*).
// All endpoints are public (no JWT required).
// All calls use a 10-second timeout as specified.

final class VehicleService {
    static let shared = VehicleService()
    private init() {}

    // MARK: - Config

    // Match NetworkManager's base URL: http://127.0.0.1:3000/api
    private let baseURL = "http://127.0.0.1:3000/api"

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        return d
    }

    // MARK: - Makes

    func fetchMakes() async throws -> [String] {
        let url = try makeURL("/vehicles/makes")
        let (data, response) = try await fetch(url: url)
        try validate(response: response)
        let decoded = try decoder().decode(VehicleMakesResponse.self, from: data)
        return decoded.makes
    }

    // MARK: - Models

    func fetchModels(make: String, year: Int) async throws -> [String] {
        var components = URLComponents(string: "\(baseURL)/vehicles/models")!
        components.queryItems = [
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "year", value: "\(year)"),
        ]
        guard let url = components.url else { throw VehicleError.invalidURL }
        let (data, response) = try await fetch(url: url)
        try validate(response: response)
        let decoded = try decoder().decode(VehicleModelsResponse.self, from: data)
        return decoded.models
    }

    // MARK: - Specs

    func fetchSpecs(make: String, model: String, year: Int) async throws -> VehicleSpecs {
        var components = URLComponents(string: "\(baseURL)/vehicles/specs")!
        components.queryItems = [
            URLQueryItem(name: "make",  value: make),
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "year",  value: "\(year)"),
        ]
        guard let url = components.url else { throw VehicleError.invalidURL }
        let (data, response) = try await fetch(url: url)
        try validate(response: response)
        return try decoder().decode(VehicleSpecs.self, from: data)
    }

    // MARK: - Photo

    /// Returns a Wikipedia thumbnail URL for the vehicle, or nil if none found.
    func fetchPhoto(make: String, model: String, year: Int) async throws -> String? {
        var components = URLComponents(string: "\(baseURL)/vehicles/photo")!
        components.queryItems = [
            URLQueryItem(name: "make",  value: make),
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "year",  value: String(year)),
        ]
        guard let url = components.url else { throw VehicleError.invalidURL }
        let (data, response) = try await fetch(url: url)
        try validate(response: response)
        let decoded = try decoder().decode(VehiclePhotoResponse.self, from: data)
        return decoded.photoURL
    }

    // MARK: - Internals

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw VehicleError.invalidURL
        }
        return url
    }

    private func fetch(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await URLSession.shared.data(for: request)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 429: throw VehicleError.rateLimited
        case 502, 503: throw VehicleError.serviceUnavailable
        default: throw VehicleError.httpError(http.statusCode)
        }
    }
}

// MARK: - Errors

enum VehicleError: LocalizedError {
    case invalidURL
    case rateLimited
    case serviceUnavailable
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid vehicle lookup URL."
        case .rateLimited:         return "Too many vehicle lookups. Please wait a moment."
        case .serviceUnavailable:  return "Vehicle lookup unavailable. Please enter details manually."
        case .httpError(let code): return "Vehicle lookup failed (HTTP \(code))."
        }
    }
}
