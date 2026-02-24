import SwiftUI
import CoreLocation
import MapKit
import Combine

@MainActor
class TripSearchViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            locationCompleter.update(query: searchText)
            if !suppressSearchTextSideEffects {
                selectedSearchCoordinate = nil
            }
        }
    }
    @Published var locationSuggestions: [MKLocalSearchCompletion] = []
    @Published var showSuggestions = false
    @Published var selectedTrip: Trip?
    @Published var showTripDetails = false
    @Published var viewMode: ViewMode = .list
    @Published var currentUserId: String?
    @Published var selectedSearchCoordinate: CLLocationCoordinate2D?
    @Published var searchDirection: TravelDirection = .toSJSU {
        didSet {
            searchText = ""
            showSuggestions = false
            locationSuggestions = []
            selectedSearchCoordinate = nil
        }
    }

    enum ViewMode { case map, list }

    enum SortOption: String, CaseIterable, Identifiable {
        case all = "All"
        case leavingSoon = "Leaving Soon"
        case bestRated = "Best Rated"
        case cheapest = "Cheapest"
        var id: String { rawValue }
    }

    @Published var sortOption: SortOption = .all

    enum TravelDirection: Hashable {
        case toSJSU    // rider is picked up somewhere → dropped at SJSU
        case fromSJSU  // rider departs from SJSU → dropped somewhere

        var searchPlaceholder: String {
            switch self {
            case .toSJSU:   return "Where are you starting from?"
            case .fromSJSU: return "Where are you headed?"
            }
        }

        var fixedLocationLabel: String {
            switch self {
            case .toSJSU:   return "San Jose State University"
            case .fromSJSU: return "San Jose State University"
            }
        }

        var fixedLocationRole: String {
            switch self {
            case .toSJSU:   return "Destination"
            case .fromSJSU: return "Pickup"
            }
        }
    }

    private let tripService = TripService.shared
    private let locationManager = LocationManager.shared
    private var searchTask: Task<Void, Never>?
    private let locationCompleter = LocationCompleter()
    private let upcomingTripGraceWindow: TimeInterval = 5 * 60
    private var suppressSearchTextSideEffects = false
    private let smartNearbyRadiusMeters: CLLocationDistance = 8_000

    init() {
        locationCompleter.onResults = { [weak self] results in
            guard let self else { return }
            self.locationSuggestions = results
            self.showSuggestions = !results.isEmpty && !self.searchText.isEmpty
        }
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        let fullText = [suggestion.title, suggestion.subtitle]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
        suppressSearchTextSideEffects = true
        searchText = fullText.isEmpty ? suggestion.title : fullText
        suppressSearchTextSideEffects = false
        showSuggestions = false
        locationSuggestions = []
        Task { await resolveSelectedSuggestionAndSearch(suggestion) }
    }

    func searchUsingTypedAddressIfPossible() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if let selectedSearchCoordinate {
            await smartSearchNearSelectedCoordinate(selectedSearchCoordinate)
            return
        }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                selectedSearchCoordinate = coordinate
                await smartSearchNearSelectedCoordinate(coordinate)
            } else {
                await loadAllUpcoming()
            }
        } catch {
            await loadAllUpcoming()
        }
    }

    // MARK: - Search Near Location

    // Every trip in LessGo is connected to SJSU, so loading all upcoming active
    // trips is simpler and more reliable than a geospatial search with a fixed
    // radius (which misses Bay Area hubs 30–70 km from campus).
    // Client-side direction + text filtering in `filteredTrips` handles the rest.
    func searchNearby(radiusMeters: Int = AppConstants.defaultSearchRadiusMeters) async {
        await loadAllUpcoming()
    }

    func search(lat: Double, lng: Double, radius: Int = AppConstants.defaultSearchRadiusMeters) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let params = TripSearchParams(
            originLat: lat,
            originLng: lng,
            radiusMeters: radius,
            minSeats: 1,
            departureAfter: Date().addingTimeInterval(-upcomingTripGraceWindow),
            departureBefore: nil
        )

        do {
            let response = try await tripService.searchTrips(params: params)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                trips = response.trips
            }
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Refresh

    func refresh() async {
        if let selectedSearchCoordinate {
            await smartSearchNearSelectedCoordinate(selectedSearchCoordinate)
        } else {
            await searchNearby()
        }
    }

    // MARK: - All Trips (for list view)

    func loadAllUpcoming() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await tripService.listTrips(
                status: .pending,
                departureAfter: Date().addingTimeInterval(-upcomingTripGraceWindow)
            )
            withAnimation {
                trips = response.trips
            }
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Filtered results

    var filteredTrips: [Trip] {
        let visibleTrips = trips.filter { trip in
            guard let currentUserId else { return true }
            return trip.driverId != currentUserId
        }

        // First apply direction filter (client-side, since backend only supports origin search)
        let sjsuKeywords = ["sjsu", "san jose state", "san josé state"]
        let directionFiltered = visibleTrips.filter { trip in
            switch searchDirection {
            case .toSJSU:
                // Show trips whose destination is SJSU
                let dest = trip.destination.lowercased()
                return sjsuKeywords.contains(where: { dest.contains($0) })
            case .fromSJSU:
                // Show trips whose origin is SJSU
                let orig = trip.origin.lowercased()
                return sjsuKeywords.contains(where: { orig.contains($0) })
            }
        }

        // Apply text search filter on the variable end
        let textFiltered: [Trip]
        if searchText.isEmpty {
            textFiltered = directionFiltered
        } else {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            textFiltered = directionFiltered.filter { trip in
                let textMatch: Bool
                switch searchDirection {
                case .toSJSU:
                    textMatch = trip.origin.localizedCaseInsensitiveContains(query) ||
                        (trip.driver?.name.localizedCaseInsensitiveContains(query) ?? false)
                case .fromSJSU:
                    textMatch = trip.destination.localizedCaseInsensitiveContains(query) ||
                        (trip.driver?.name.localizedCaseInsensitiveContains(query) ?? false)
                }

                guard let selectedSearchCoordinate else { return textMatch }
                let nearbyMatch = distanceToVariableEndpoint(for: trip, from: selectedSearchCoordinate)
                    .map { $0 <= smartNearbyRadiusMeters }
                    ?? false
                return textMatch || nearbyMatch
            }
        }

        let sorted = sortTrips(textFiltered, by: sortOption)
        guard let selectedSearchCoordinate else { return sorted }

        return sorted.sorted {
            let d0 = distanceToVariableEndpoint(for: $0, from: selectedSearchCoordinate) ?? .greatestFiniteMagnitude
            let d1 = distanceToVariableEndpoint(for: $1, from: selectedSearchCoordinate) ?? .greatestFiniteMagnitude
            if abs(d0 - d1) > 50 { return d0 < d1 }
            return $0.departureTime < $1.departureTime
        }
    }

    func sortTrips(_ list: [Trip], by option: SortOption) -> [Trip] {
        switch option {
        case .all:
            return list
        case .leavingSoon:
            return list.sorted { $0.departureTime < $1.departureTime }
        case .bestRated:
            return list.sorted { ($0.driver?.rating ?? 0) > ($1.driver?.rating ?? 0) }
        case .cheapest:
            // Sort by most seats available (more seats = lower per-seat cost share)
            return list.sorted { $0.seatsAvailable > $1.seatsAvailable }
        }
    }

    private func distanceToVariableEndpoint(for trip: Trip, from coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        let endpoint: Coordinate?
        switch searchDirection {
        case .toSJSU:
            endpoint = trip.originPoint
        case .fromSJSU:
            endpoint = trip.destinationPoint
        }
        guard let endpoint else { return nil }
        let a = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let b = CLLocation(latitude: endpoint.lat, longitude: endpoint.lng)
        return a.distance(from: b)
    }

    private func resolveSelectedSuggestionAndSearch(_ suggestion: MKLocalSearchCompletion) async {
        do {
            let request = MKLocalSearch.Request(completion: suggestion)
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                selectedSearchCoordinate = coordinate
                await smartSearchNearSelectedCoordinate(coordinate)
            } else {
                selectedSearchCoordinate = nil
                await loadAllUpcoming()
            }
        } catch {
            selectedSearchCoordinate = nil
            await loadAllUpcoming()
        }
    }

    private func smartSearchNearSelectedCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let radii = [8_000, 16_000, 32_000, 64_000]
        for radius in radii {
            let params = TripSearchParams(
                originLat: coordinate.latitude,
                originLng: coordinate.longitude,
                radiusMeters: radius,
                minSeats: 1,
                departureAfter: Date().addingTimeInterval(-upcomingTripGraceWindow),
                departureBefore: nil
            )

            do {
                let response = try await tripService.searchTrips(params: params)
                trips = response.trips
                if !response.trips.isEmpty || radius == radii.last {
                    return
                }
            } catch let error as NetworkError {
                errorMessage = error.userMessage
                return
            } catch {
                errorMessage = (error as? NetworkError)?.userMessage ?? "Something went wrong. Please try again."
                return
            }
        }
    }
}

// MARK: - Location Completer (NSObject bridge for MKLocalSearchCompleterDelegate)

// MKLocalSearchCompleterDelegate requires NSObject, so we bridge via a
// dedicated class rather than polluting the @MainActor view model.
final class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var onResults: (([MKLocalSearchCompletion]) -> Void)?

    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address, .pointOfInterest, .query]
        c.pointOfInterestFilter = .includingAll
        return c
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        if query.isEmpty {
            onResults?([])
        } else {
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.onResults?(completer.results)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onResults?([])
        }
    }
}
