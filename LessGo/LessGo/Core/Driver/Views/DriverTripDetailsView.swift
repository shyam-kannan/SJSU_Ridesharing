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
                VStack(spacing: 20) {
                    // Trip Overview Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trip Details")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)

                        // Route
                        HStack(alignment: .top, spacing: 12) {
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
                                Text(trip.destination)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.textPrimary)
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
                    .cardStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Passengers Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Passengers (\(passengers.count))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 20)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(40)
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
                            .padding(40)
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
                            .padding(40)
                        } else {
                            ForEach(passengers) { passenger in
                                PassengerCard(passenger: passenger)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .padding(8)
                            .background(Color.appBackground)
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Trip Passengers")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                }
            }
        }
        .task {
            await loadPassengers()
        }
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
