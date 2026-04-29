import SwiftUI

struct DriverTripDetailsView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var passengers: [BookingWithRider] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var totalSeatsBooked: Int {
        passengers.reduce(0) { $0 + $1.seatsBooked }
    }

    private var totalEarnings: Double {
        Double(totalSeatsBooked) * 8.50
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    RouteMapView(
                        origin: trip.originPoint?.clLocationCoordinate2D,
                        destination: trip.destinationPoint?.clLocationCoordinate2D,
                        driver: nil,
                        showsUserLocation: false
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                            Text("Route Preview")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                    headerStatsStrip

                    // Trip Overview Card
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Trip Details")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)

                        // Route
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(DesignSystem.Colors.sjsuBlue)
                                    .frame(width: 10, height: 10)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.25))
                                    .frame(width: 1.5, height: 40)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.brandRed)
                            }
                            .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(trip.origin)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(trip.destination)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(trip.departureTime.tripTimeString)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.sjsuBlue)
                                Text(trip.departureTime.tripDateString)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.sheetBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                                )
                        )

                        Divider()

                        // Stats
                        HStack(spacing: 20) {
                            StatItem(
                                icon: "person.2.fill",
                                label: "Passengers",
                                value: "\(totalSeatsBooked)/\(trip.seatsAvailable)",
                                color: DesignSystem.Colors.sjsuBlue
                            )

                            Divider().frame(height: 40)

                            StatItem(
                                icon: "dollarsign.circle.fill",
                                label: "Earnings",
                                value: String(format: "$%.2f", totalEarnings),
                                color: DesignSystem.Colors.sjsuGold
                            )
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    .padding(.horizontal, 24)

                    // Passengers Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Passengers")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("\(passengers.count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.cardBackground)
                                .overlay(Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 24)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(48)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal, 24)
                        } else if let error = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.brandRed)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(44)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                                        )
                            )
                            .padding(.horizontal, 24)
                        } else if passengers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.textTertiary)
                                Text("No passengers yet")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                Text("Share your trip to get riders!")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textTertiary)
                            }
                            .padding(44)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                                        )
                            )
                            .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(passengers) { passenger in
                                    PassengerCard(passenger: passenger)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer().frame(height: 96)
                }
            }
            .background(
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.accentLime.opacity(0.10))
                        .frame(width: 260)
                        .offset(x: 140, y: 580)
                        .ignoresSafeArea()
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .padding(8)
                            .background(Color.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Trip Passengers")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .task {
            await loadPassengers()
        }
    }

    private var headerStatsStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.brand)
                Text("\(passengers.count) riders")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .overlay(Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
            .clipShape(Capsule())

            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(DesignSystem.Colors.accentLime)
                Text(String(format: "$%.2f est.", totalEarnings))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .overlay(Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, -4)
    }

    private func loadPassengers() async {
        isLoading = true
        errorMessage = nil

        do {
            passengers = try await TripService.shared.getTripPassengers(tripId: trip.id)
            isLoading = false
        } catch {
            errorMessage = "Failed to load passengers"
            isLoading = false
            print("Error loading passengers: \(error)")
        }
    }
}

// MARK: - Stat Item Component

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
