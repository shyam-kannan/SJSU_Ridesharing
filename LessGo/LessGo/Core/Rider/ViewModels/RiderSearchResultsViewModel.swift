import Foundation
import Combine
import _LocationEssentials

// MARK: - Rider Search Results ViewModel

@MainActor
class RiderSearchResultsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var trips: [TripWithDriver] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    @Published var total = 0

    // MARK: - Private State

    private let tripService = TripService.shared
    private var criteria: SearchCriteria
    private var offset = 0
    private let limit = 10

    // MARK: - Initialization

    init(criteria: SearchCriteria) {
        self.criteria = criteria
        isLoading = true
    }

    // MARK: - Public Methods

    func loadInitialResults() async {
        isLoading = true
        errorMessage = nil
        offset = 0

        defer { isLoading = false }

        do {
            let response = try await tripService.searchPostedTrips(
                direction: criteria.direction.rawValue,
                originLat: criteria.originCoordinate.latitude,
                originLng: criteria.originCoordinate.longitude,
                destinationLat: criteria.destinationCoordinate.latitude,
                destinationLng: criteria.destinationCoordinate.longitude,
                departureAfter: criteria.departureTime,
                limit: limit,
                offset: offset
            )

            trips = response.trips
            total = response.total
            hasMore = response.hasMore
            offset += response.trips.count

            if trips.isEmpty {
                errorMessage = "No rides found for your search. Try adjusting your time or location."
            }
        } catch let error as NetworkError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Failed to search for rides. Please try again."
        }
    }

    func loadMoreResults() async {
        guard !isLoadingMore && hasMore else { return }

        isLoadingMore = true

        defer { isLoadingMore = false }

        do {
            let response = try await tripService.searchPostedTrips(
                direction: criteria.direction.rawValue,
                originLat: criteria.originCoordinate.latitude,
                originLng: criteria.originCoordinate.longitude,
                destinationLat: criteria.destinationCoordinate.latitude,
                destinationLng: criteria.destinationCoordinate.longitude,
                departureAfter: criteria.departureTime,
                limit: limit,
                offset: offset
            )

            trips.append(contentsOf: response.trips)
            hasMore = response.hasMore
            offset += response.trips.count
        } catch {
            // Silently fail for pagination errors
            hasMore = false
        }
    }

    func refresh() async {
        await loadInitialResults()
    }
}
