import SwiftUI

struct DriverTripDetailsView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var passengers: [BookingWithRider] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var chatDestination: DriverNotificationChatDestination?

    private var totalSeatsBooked: Int {
        passengers.reduce(0) { $0 + $1.seatsBooked }
    }

    private var totalEarnings: Double {
        let confirmedFares = approvedBookings.compactMap { $0.fare }
        if !confirmedFares.isEmpty {
            return confirmedFares.reduce(0, +)
        }
        // Fall back to pending+approved when no fare data
        return passengers
            .filter { $0.bookingState == .approved || $0.bookingState == .pending }
            .compactMap { $0.fare }
            .reduce(0, +)
    }

    private var pendingBookings: [BookingWithRider] {
        passengers.filter { $0.bookingState == .pending }
    }

    private var approvedBookings: [BookingWithRider] {
        passengers.filter { $0.bookingState == .approved }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    RouteMapView(
                        origin: trip.originPoint?.clLocationCoordinate2D,
                        destination: trip.destinationPoint?.clLocationCoordinate2D,
                        driver: nil,
                        showsUserLocation: true
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
                            HStack(spacing: 6) {
                                Text("\(passengers.count)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                if !pendingBookings.isEmpty {
                                    Circle()
                                        .fill(Color.brandRed)
                                        .frame(width: 6, height: 6)
                                    Text("\(pendingBookings.count) pending")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.brandRed)
                                }
                            }
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
                                // Pending bookings first
                                if !pendingBookings.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Pending Requests")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.brandRed)
                                            .padding(.horizontal, 2)
                                        ForEach(pendingBookings) { passenger in
                                            PendingBookingCard(
                                                passenger: passenger,
                                                onApprove: { await approveBooking(passenger) },
                                                onReject: { await rejectBooking(passenger) },
                                                onChat: { openChat(with: passenger) }
                                            )
                                        }
                                    }
                                }

                                // Approved bookings
                                if !approvedBookings.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Confirmed Passengers")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.brandGreen)
                                            .padding(.horizontal, 2)
                                        ForEach(approvedBookings) { passenger in
                                            PassengerCard(passenger: passenger, onChat: { openChat(with: passenger) })
                                        }
                                    }
                                }

                                // Other bookings (completed, cancelled, etc.)
                                let otherBookings = passengers.filter { $0.bookingState != .pending && $0.bookingState != .approved }
                                if !otherBookings.isEmpty {
                                    ForEach(otherBookings) { passenger in
                                        PassengerCard(passenger: passenger, onChat: { openChat(with: passenger) })
                                    }
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
        .sheet(item: $chatDestination) { destination in
            ChatView(
                tripId: trip.id,
                otherPartyName: destination.otherPartyName,
                isDriver: true,
                includesTabBarClearance: false
            )
            .environmentObject(authVM)
        }
    }

    private var headerStatsStrip: some View {
        let statusColor: Color = approvedBookings.isEmpty ? .brandGold : .brandGreen
        let statusLabel = approvedBookings.isEmpty ? "Pending" : "Confirmed"

        return HStack(spacing: 12) {
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

            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusLabel)
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

    private func approveBooking(_ passenger: BookingWithRider) async {
        do {
            _ = try await BookingService.shared.approveBooking(id: passenger.id)
            await loadPassengers()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Error approving booking: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func rejectBooking(_ passenger: BookingWithRider) async {
        do {
            _ = try await BookingService.shared.rejectBooking(id: passenger.id)
            await loadPassengers()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Error rejecting booking: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func openChat(with passenger: BookingWithRider) {
        chatDestination = DriverNotificationChatDestination(
            tripId: trip.id,
            otherPartyName: passenger.riderName
        )
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

// MARK: - Pending Booking Card

private struct PendingBookingCard: View {
    let passenger: BookingWithRider
    let onApprove: () async -> Void
    let onReject: () async -> Void
    let onChat: () -> Void

    @State private var isApproving = false
    @State private var isRejecting = false

    var body: some View {
        HStack(spacing: 12) {
            // Rider avatar
            AsyncImage(url: URL(string: passenger.riderPicture ?? "")) { image in
                image.resizable()
            } placeholder: {
                Circle()
                    .fill(Color.brand.opacity(0.15))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            // Rider info
            VStack(alignment: .leading, spacing: 4) {
                Text(passenger.riderName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.brandOrange)
                    Text(String(format: "%.1f", passenger.riderRating))
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                Text("\(passenger.seatsBooked) seat\(passenger.seatsBooked > 1 ? "s" : "")")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)

                // Fare and scost breakdown information
                if passenger.fare != nil || passenger.scostBreakdown != nil {
                    HStack(spacing: 12) {
                        if let fare = passenger.fare {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.brandGreen)
                                Text(String(format: "$%.2f", fare))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        if let scost = passenger.scostBreakdown {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.turn.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.brandOrange)
                                Text(formatScostDistance(scost.walk))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textPrimary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.brand)
                                Text(formatScostTime(scost.advance))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onChat) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.brand)
                        .frame(width: 36, height: 36)
                        .background(Color.brand.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        isRejecting = true
                        await onReject()
                        isRejecting = false
                    }
                }) {
                    if isRejecting {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.brandRed)
                            .frame(width: 36, height: 36)
                            .background(Color.brandRed.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRejecting)

                Button(action: {
                    Task {
                        isApproving = true
                        await onApprove()
                        isApproving = false
                    }
                }) {
                    if isApproving {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.brandGreen)
                            .frame(width: 36, height: 36)
                            .background(Color.brandGreen.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isApproving)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.brandRed.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Helper Functions

func formatScostDistance(_ meters: Double) -> String {
    if meters < 1000 {
        return String(format: "%.0fm", meters)
    } else {
        return String(format: "%.1fkm", meters / 1000)
    }
}

func formatScostTime(_ seconds: Double) -> String {
    if seconds < 60 {
        return String(format: "%.0fs", seconds)
    } else if seconds < 3600 {
        return String(format: "%.0fm", seconds / 60)
    } else {
        return String(format: "%.1fh", seconds / 3600)
    }
}

