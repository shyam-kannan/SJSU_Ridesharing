import SwiftUI
import CoreLocation

// MARK: - Rider Search Results View

struct RiderSearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RiderSearchResultsViewModel
    private let criteria: SearchCriteria
    @State private var selectedTrip: TripWithDriver?

    init(criteria: SearchCriteria) {
        self.criteria = criteria
        _viewModel = StateObject(wrappedValue: RiderSearchResultsViewModel(criteria: criteria))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.trips.isEmpty {
                    routeLoadingView
                } else if viewModel.trips.isEmpty {
                    routeEmptyView(
                        message: viewModel.errorMessage ?? "No rides found for your search. Try adjusting your time or location."
                    )
                } else {
                    tripsList
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    }
                }
            }
            .task {
                await viewModel.loadInitialResults()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip, criteria: criteria)
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Loading View

    private var routeLoadingView: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                routeMapSection
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.62)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                loadingSheet
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var routeMapSection: some View {
        AnchorRouteMapView(
            origin: routeOrigin,
            destination: routeDestination,
            driver: nil,
            anchorPoints: [],
            showsUserLocation: true
        )
    }

    private var loadingSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 20)

            Text("Finding rides along this route")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Text("We’re loading current trips that match your path.")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 20)

            routeSummaryCard
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            HStack(spacing: 10) {
                ProgressView()
                    .tint(.brand)
                Text("Searching for rides...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 36)
        }
        .background(Color.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
    }

    private var routeSummaryCard: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.brandGold)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.25))
                    .frame(width: 2, height: 28)
                Circle()
                    .fill(Color.brand)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(routeOriginLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(routeDestinationLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(16)
        .background(DesignSystem.Colors.fieldBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
    }

    private func routeEmptyView(message: String) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                routeMapSection
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.62)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 14)
                        .padding(.bottom, 20)

                    Text("No rides available right now")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    routeSummaryCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    Button(action: { dismiss() }) {
                        Text("Modify Search")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.brand)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
                .background(Color.cardBackground)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var routeOrigin: CLLocationCoordinate2D? {
        switch criteria.direction {
        case .toSJSU:
            return criteria.coordinate
        case .fromSJSU:
            return AppConstants.sjsuCoordinate
        }
    }

    private var routeDestination: CLLocationCoordinate2D? {
        switch criteria.direction {
        case .toSJSU:
            return AppConstants.sjsuCoordinate
        case .fromSJSU:
            return criteria.coordinate
        }
    }

    private var routeOriginLabel: String {
        switch criteria.direction {
        case .toSJSU:
            return criteria.location
        case .fromSJSU:
            return "San Jose State University"
        }
    }

    private var routeDestinationLabel: String {
        switch criteria.direction {
        case .toSJSU:
            return "San Jose State University"
        case .fromSJSU:
            return criteria.location
        }
    }

    // MARK: - Trips List

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.trips) { trip in
                    TripCard(trip: trip)
                        .onTapGesture {
                            selectedTrip = trip
                        }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 20)
                } else if viewModel.hasMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreResults()
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Trip Card

struct TripCard: View {
    let trip: TripWithDriver

    var body: some View {
        HStack(spacing: 12) {
            // Driver photo
            AsyncImage(url: URL(string: trip.driverPhotoUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(trip.driverName.prefix(1).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.textSecondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }

            // Trip details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.driverName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f", trip.driverRating))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.brandGold)
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.brand)
                    Text(trip.origin)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.brandGreen)
                    Text(trip.destination)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(formatTime(trip.departureTime))
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("\(trip.seatsAvailable) seats")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }

                    if let detour = trip.detourMiles, detour > 0.1 {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10))
                            Text(String(format: "~%.1f mi detour", detour))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.brandGold)
                    }

                    Spacer()

                    Text(formatPrice(trip.costBreakdown?.perRiderSplit ?? trip.estimatedCost))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brand)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
}

// MARK: - Preview

#Preview {
    RiderSearchResultsView(criteria: SearchCriteria(
        direction: .toSJSU,
        location: "123 Main St",
        coordinate: CLLocationCoordinate2D(latitude: 37.3352, longitude: -121.8811),
        departureTime: Date()
    ))
}
