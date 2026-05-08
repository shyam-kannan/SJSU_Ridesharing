import SwiftUI
import MapKit
import Combine

struct DriverTripDetailsView: View {
    let trip: Trip
    var onTripDeleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var passengers: [BookingWithRider] = []
    @State private var isLoading = true
    @State private var isLoadingPassengers = false
    @State private var errorMessage: String?
    @State private var cancelTripError: String?
    @State private var chatDestination: DriverNotificationChatDestination?
    @State private var showCancelTripConfirm = false
    @State private var isCancellingTrip = false
    @State private var showDeleteTripConfirm = false
    @State private var isDeletingTrip = false
    @State private var deleteTripError: String?
    @State private var anchorPoints: [AnchorPoint] = []
    @State private var isLoadingAnchors = true

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

    private var approvedPickupCoords: [CLLocationCoordinate2D] {
        approvedBookings.compactMap { booking in
            guard let pl = booking.pickupLocation else { return nil }
            return CLLocationCoordinate2D(latitude: pl.lat, longitude: pl.lng)
        }
    }

    @ViewBuilder
    private var routeMapWithPassengers: some View {
        let origin = trip.originPoint?.clLocationCoordinate2D
        let destination = trip.destinationPoint?.clLocationCoordinate2D

        // Use AnchorRouteMapView when we have anchor points, otherwise fall back to RouteMapView
        if !anchorPoints.isEmpty {
            AnchorRouteMapView(
                origin: origin,
                destination: destination,
                driver: nil,
                anchorPoints: anchorPoints,
                showsUserLocation: true
            )
        } else {
            // Fallback to existing RouteMapView for simple trips
            routeMapViewFallback(origin: origin, destination: destination)
        }
    }

    private func routeMapViewFallback(origin: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D?) -> some View {
        let pickups = approvedPickupCoords
        let waypoint = pickups.first
        var fitCoords: [CLLocationCoordinate2D] = []
        if let o = origin { fitCoords.append(o) }
        if let d = destination { fitCoords.append(d) }
        fitCoords.append(contentsOf: pickups)

        return RouteMapView(
            origin: origin,
            destination: destination,
            driver: nil,
            waypoint: waypoint,
            riders: pickups,
            fitAnchors: fitCoords.isEmpty ? nil : fitCoords,
            showsUserLocation: true
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Route map card
                    routeMapWithPassengers
                        .frame(height: 150)
                        .cornerRadius(12)
                        .disabled(true)
                        .padding(.top, 8)

                    // Trip details card
                    tripDetailsCard

                    // Stats card
                    statsCard

                    // Passengers section
                    passengersSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                await loadPassengers()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Trip Passengers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if trip.status == .cancelled || trip.status == .completed {
                        Button(action: { showDeleteTripConfirm = true }) {
                            if isDeletingTrip {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Delete Trip")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.brandRed)
                            }
                        }
                        .disabled(isDeletingTrip)
                    } else {
                        Button(action: { showCancelTripConfirm = true }) {
                            if isCancellingTrip {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Cancel Trip")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.brandRed)
                            }
                        }
                        .disabled(isCancellingTrip)
                    }
                }
            }
            .confirmationDialog("Cancel this trip?", isPresented: $showCancelTripConfirm, titleVisibility: .visible) {
                Button("Cancel Trip", role: .destructive) {
                    Task { await cancelTrip() }
                }
                Button("Keep Trip", role: .cancel) {}
            } message: {
                Text("This will cancel the trip and notify all passengers.")
            }
            .alert("Cancel Failed", isPresented: Binding(
                get: { cancelTripError != nil },
                set: { if !$0 { cancelTripError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cancelTripError ?? "")
            }
            .confirmationDialog("Delete this trip?", isPresented: $showDeleteTripConfirm, titleVisibility: .visible) {
                Button("Delete Trip", role: .destructive) {
                    Task { await deleteTrip() }
                }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("This will permanently remove the trip from your history.")
            }
            .alert("Delete Failed", isPresented: Binding(
                get: { deleteTripError != nil },
                set: { if !$0 { deleteTripError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteTripError ?? "")
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await loadPassengers()
            await loadAnchorPoints()
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

    private var tripDetailsCard: some View {
        VStack(spacing: 16) {
            detailRow(
                icon: "mappin.circle.fill",
                iconColor: .brand,
                title: "Pickup",
                value: trip.origin
            )
            Divider()
            detailRow(
                icon: "location.fill",
                iconColor: .brandGreen,
                title: "Drop-off",
                value: trip.destination
            )
            Divider()
            detailRow(
                icon: "clock",
                iconColor: .textSecondary,
                title: "Departure",
                value: formatDateTime(trip.departureTime)
            )
            Divider()
            detailRow(
                icon: "person.2.fill",
                iconColor: .textSecondary,
                title: "Seats Available",
                value: "\(trip.seatsAvailable)"
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
    }

    private func detailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var statsCard: some View {
        let statusColor: Color = approvedBookings.isEmpty ? .brandGold : .brandGreen
        let statusLabel = approvedBookings.isEmpty ? "Pending" : "Confirmed"

        return VStack(spacing: 16) {
            detailRow(
                icon: "person.2.fill",
                iconColor: .brand,
                title: "Passengers",
                value: "\(totalSeatsBooked) booked / \(trip.seatsAvailable) seats"
            )
            Divider()
            detailRow(
                icon: "dollarsign.circle.fill",
                iconColor: .brandGreen,
                title: "Estimated Earnings",
                value: String(format: "$%.2f", totalEarnings)
            )
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                    Text(statusLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
    }

    private var passengersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Passengers")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                if !pendingBookings.isEmpty {
                    Text("\(pendingBookings.count) pending")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandRed)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(48)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
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
                .frame(maxWidth: .infinity)
                .padding(44)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
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
                .frame(maxWidth: .infinity)
                .padding(44)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
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

                    let archivedBookings = passengers.filter {
                        $0.bookingState == .completed || $0.bookingState == .cancelled || $0.bookingState == .rejected
                    }
                    if !archivedBookings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Past Requests")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 2)
                            ForEach(archivedBookings) { booking in
                                archivedTripRow(booking)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func archivedTripRow(_ booking: BookingWithRider) -> some View {
        let stateLabel: String = {
            switch booking.bookingState {
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            case .rejected:  return "Declined"
            default:         return booking.bookingState.displayName
            }
        }()
        let stateColor: Color = booking.bookingState == .completed ? .brandGreen : .textSecondary

        return HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(booking.riderName.prefix(1)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textSecondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.riderName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(stateLabel)
                    .font(.system(size: 12))
                    .foregroundColor(stateColor)
            }
            Spacer()
            Button {
                Task {
                    try? await BookingService.shared.deleteBooking(bookingId: booking.id)
                    passengers.removeAll { $0.id == booking.id }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func loadPassengers() async {
        guard !isLoadingPassengers else { return }

        if trip.status == .cancelled {
            passengers = []
            isLoading = false
            isLoadingPassengers = false
            return
        }

        isLoadingPassengers = true
        isLoading = true
        errorMessage = nil

        do {
            passengers = try await TripService.shared.getTripPassengers(tripId: trip.id)
        } catch {
            errorMessage = "Failed to load passengers"
            print("Error loading passengers: \(error)")
        }
        isLoading = false
        isLoadingPassengers = false
    }

    private func loadAnchorPoints() async {
        isLoadingAnchors = true
        do {
            anchorPoints = try await TripService.shared.getAnchorPoints(tripId: trip.id)
            isLoadingAnchors = false
        } catch {
            print("Error loading anchor points: \(error)")
            isLoadingAnchors = false
        }
    }

    private func approveBooking(_ passenger: BookingWithRider) async {
        do {
            let updated = try await BookingService.shared.approveBooking(id: passenger.id)
            if let idx = passengers.firstIndex(where: { $0.id == updated.id }) {
                passengers[idx] = passengers[idx].withBookingState(updated.bookingState)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Error approving booking: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func rejectBooking(_ passenger: BookingWithRider) async {
        do {
            let updated = try await BookingService.shared.rejectBooking(id: passenger.id)
            if let idx = passengers.firstIndex(where: { $0.id == updated.id }) {
                passengers[idx] = passengers[idx].withBookingState(updated.bookingState)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Error rejecting booking: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func deleteTrip() async {
        isDeletingTrip = true
        do {
            try await TripService.shared.deleteTrip(tripId: trip.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onTripDeleted?()
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            deleteTripError = "Failed to delete trip. Please try again."
        }
        isDeletingTrip = false
    }

    private func openChat(with passenger: BookingWithRider) {
        chatDestination = DriverNotificationChatDestination(
            tripId: trip.id,
            otherPartyName: passenger.riderName
        )
    }

    private func cancelTrip() async {
        isCancellingTrip = true
        do {
            _ = try await TripService.shared.cancelTrip(id: trip.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            cancelTripError = "Failed to cancel trip. Please try again."
        }
        isCancellingTrip = false
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
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var timeRemaining: String? {
        guard let expires = passenger.holdExpiresAt else { return nil }
        let diff = expires.timeIntervalSince(now)
        guard diff > 0 else { return "Expired" }
        let hours = Int(diff) / 3600
        let mins = (Int(diff) % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m left" }
        return "\(mins)m left"
    }

    private var countdownColor: Color {
        guard let expires = passenger.holdExpiresAt else { return .textTertiary }
        let diff = expires.timeIntervalSince(now)
        if diff <= 0 { return .brandRed }
        if diff <= 1800 { return .brandRed }
        if diff <= 3600 { return .brandOrange }
        return .textTertiary
    }

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
                    if let remaining = timeRemaining {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(remaining)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(countdownColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(countdownColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
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

                // Payment status badge
                paymentBadge(for: passenger)
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
        .onReceive(timer) { _ in now = Date() }
    }
}

// MARK: - Payment Badge Helper

private func formatDeadlineLabel(_ date: Date) -> String {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    if calendar.isDateInToday(date) || calendar.isDateInTomorrow(date) {
        return formatter.string(from: date)
    }
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

private func paymentBadge(for passenger: BookingWithRider) -> some View {
    let held = passenger.paymentIntentId != nil
    return VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 4) {
            Image(systemName: held ? "lock.shield.fill" : "clock.badge.exclamationmark.fill")
                .font(.system(size: 10))
            Text(held ? "Payment Held" : "Awaiting Payment")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(held ? .brandGreen : .brandGold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((held ? Color.brandGreen : Color.brandGold).opacity(0.12))
        .cornerRadius(8)

        if !held, let deadline = passenger.paymentDeadlineAt {
            Text("Due by \(formatDeadlineLabel(deadline))")
                .font(.system(size: 10))
                .foregroundColor(.brandOrange)
                .padding(.horizontal, 4)
        }
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
