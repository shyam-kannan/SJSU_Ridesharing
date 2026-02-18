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

    // This app is exclusively for rides TO or FROM SJSU.
    // Always search around SJSU coordinates so we surface all campus-connected trips.
    func searchNearby(radiusMeters: Int = AppConstants.defaultSearchRadiusMeters) async {
        await search(
            lat: AppConstants.sjsuCoordinate.latitude,
            lng: AppConstants.sjsuCoordinate.longitude,
            radius: radiusMeters
        )
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

        // Then apply text search filter on the variable end
        guard !searchText.isEmpty else { return directionFiltered }
        return directionFiltered.filter { trip in
            switch searchDirection {
            case .toSJSU:
                // Filter by pickup (origin) text
                return trip.origin.localizedCaseInsensitiveContains(searchText) ||
                       (trip.driver?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            case .fromSJSU:
                // Filter by drop-off (destination) text
                return trip.destination.localizedCaseInsensitiveContains(searchText) ||
                       (trip.driver?.name.localizedCaseInsensitiveContains(searchText) ?? false)
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
