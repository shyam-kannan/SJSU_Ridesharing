import SwiftUI

struct DriverListBottomSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var viewModel: TripSearchViewModel
    let locationName: String
    @Binding var selectedTrip: Trip?
    @Binding var showTripDetails: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.filteredTrips.count) driver\(viewModel.filteredTrips.count == 1 ? "" : "s") available")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                    if !locationName.isEmpty {
                        Text("near \(locationName)")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Sort filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TripSearchViewModel.SortOption.allCases) { option in
                        SortPill(
                            title: option.rawValue,
                            isSelected: viewModel.sortOption == option
                        ) {
                            withAnimation { viewModel.sortOption = option }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)

            Divider()

            // Trip list
            if viewModel.filteredTrips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.textTertiary)
                    Text("No trips available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Try adjusting your search or check back later")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredTrips) { trip in
                            DriverListCard(trip: trip) {
                                guard authVM.currentUser?.sjsuIdStatus == .verified else { return }
                                selectedTrip = trip
                                showTripDetails = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
    }
}

// MARK: - Driver List Card

private struct DriverListCard: View {
    let trip: Trip
    let onTap: () -> Void

    private var minutesUntilDeparture: Int {
        max(0, Int(trip.departureTime.timeIntervalSinceNow / 60))
    }

    private var isLeavingSoon: Bool { minutesUntilDeparture < 30 }

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onTap() }) {
            HStack(alignment: .top, spacing: 14) {
                // Driver avatar
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: 48, height: 48)
                    Text(trip.driver?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Driver + rating
                    HStack(alignment: .center) {
                        Text(trip.driver?.name ?? "Driver")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if isLeavingSoon {
                            LeavingSoonBadge(minutes: minutesUntilDeparture)
                        } else {
                            Text(trip.departureTime, style: .relative)
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                    }

                    // Stars
                    if let driver = trip.driver {
                        StarRatingView(rating: driver.rating, size: 11)
                    }

                    // Vehicle info
                    if let vehicle = trip.driver?.vehicleInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                            Text(vehicle)
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Route
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                            .foregroundColor(.brand)
                        Text("\(trip.origin) → \(trip.destination)")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Seats badge
                VStack(spacing: 2) {
                    Text("\(trip.seatsAvailable)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.brand)
                    Text("seats")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Sort Pill

private struct SortPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.brand : Color.appBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Leaving Soon Badge

private struct LeavingSoonBadge: View {
    let minutes: Int
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(Color.brandGreen).frame(width: 6, height: 6)
            Text(minutes == 0 ? "Now" : "In \(minutes) min")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.brandGreen)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.brandGreen.opacity(0.12))
        .cornerRadius(20)
    }
}

