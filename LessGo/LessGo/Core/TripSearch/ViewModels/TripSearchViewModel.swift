import SwiftUI
import CoreLocation
import MapKit
import Combine

@MainActor
class TripSearchViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" { didSet { locationCompleter.update(query: searchText) } }
    @Published var locationSuggestions: [MKLocalSearchCompletion] = []
    @Published var showSuggestions = false
    @Published var selectedTrip: Trip?
    @Published var showTripDetails = false
    @Published var viewMode: ViewMode = .list
    @Published var searchDirection: TravelDirection = .toSJSU {
        didSet {
            searchText = ""
            showSuggestions = false
            locationSuggestions = []
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

    init() {
        locationCompleter.onResults = { [weak self] results in
            guard let self else { return }
            self.locationSuggestions = results
            self.showSuggestions = !results.isEmpty && !self.searchText.isEmpty
        }
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        searchText = suggestion.title
        showSuggestions = false
        locationSuggestions = []
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
            departureAfter: Date(),
            departureBefore: nil
        )

        do {
            let response = try await tripService.searchTrips(params: params)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                trips = response.trips
            }
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await searchNearby()
    }

    // MARK: - All Trips (for list view)

    func loadAllUpcoming() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await tripService.listTrips(
                status: .active,
                departureAfter: Date()
            )
            withAnimation {
                trips = response.trips
            }
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filtered results

    var filteredTrips: [Trip] {
        // First apply direction filter (client-side, since backend only supports origin search)
        let sjsuKeywords = ["sjsu", "san jose state", "san josé state"]
        let directionFiltered = trips.filter { trip in
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
            textFiltered = directionFiltered.filter { trip in
                switch searchDirection {
                case .toSJSU:
                    return trip.origin.localizedCaseInsensitiveContains(searchText) ||
                           (trip.driver?.name.localizedCaseInsensitiveContains(searchText) ?? false)
                case .fromSJSU:
                    return trip.destination.localizedCaseInsensitiveContains(searchText) ||
                           (trip.driver?.name.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        // Apply sort
        return sortTrips(textFiltered, by: sortOption)
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
}

// MARK: - Location Completer (NSObject bridge for MKLocalSearchCompleterDelegate)

// MKLocalSearchCompleterDelegate requires NSObject, so we bridge via a
// dedicated class rather than polluting the @MainActor view model.
final class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var onResults: (([MKLocalSearchCompletion]) -> Void)?

    private let completer: MKLocalSearchCompleter = {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address, .pointOfInterest]
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
