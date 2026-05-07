import SwiftUI
import MapKit

// MARK: - Trip Detail View

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var viewModel: TripDetailViewModel
    @State private var showChat = false
    @State private var anchorPoints: [AnchorPoint] = []

    private let fallbackRiderCoordinate: CLLocationCoordinate2D

    private var pickupCoordinate: CLLocationCoordinate2D? {
        if let pl = viewModel.booking?.pickupLocation {
            return CLLocationCoordinate2D(latitude: pl.lat, longitude: pl.lng)
        }
        return fallbackRiderCoordinate
    }

    init(trip: TripWithDriver, riderCoordinate: CLLocationCoordinate2D) {
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
        self.fallbackRiderCoordinate = riderCoordinate
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            if viewModel.isLoading {
                                loadingView
                            } else if let trip = viewModel.trip {
                                tripContent(trip: trip)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.large)
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
                await viewModel.checkExistingBooking()
                if let tripId = viewModel.trip?.id {
                    anchorPoints = (try? await TripService.shared.getAnchorPoints(tripId: tripId)) ?? []
                }
            }
            .onAppear {
                Task {
                    if let tripId = viewModel.trip?.id, anchorPoints.isEmpty {
                        anchorPoints = (try? await TripService.shared.getAnchorPoints(tripId: tripId)) ?? []
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
                Button("OK") {
                    // Dismiss the alert
                }
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $showChat) {
                if let trip = viewModel.trip {
                    ChatView(
                        tripId: trip.id,
                        otherPartyName: trip.driverName,
                        isDriver: false,
                        includesTabBarClearance: false
                    )
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading trip details...")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Trip Content

    private func tripContent(trip: TripWithDriver) -> some View {
        VStack(spacing: 20) {
            // Driver profile section
            driverProfileSection(trip: trip)

            // Trip details section
            tripDetailsSection(trip: trip)

            // Route map placeholder
            routeMapSection(trip: trip)

            // Cost breakdown
            costSection(trip: trip)

            // Booking action
            bookingActionSection(trip: trip)
        }
    }

    // MARK: - Driver Profile Section

    private func driverProfileSection(trip: TripWithDriver) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Driver photo
                AsyncImage(url: URL(string: trip.driverPhotoUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.textTertiary.opacity(0.2))
                            .frame(width: 64, height: 64)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Color.textTertiary.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(trip.driverName.prefix(1).uppercased())
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.textSecondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }

                // Driver info
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.driverName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text(String(format: "%.1f", trip.driverRating))
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.brandGold)

                    if let vehicleInfo = trip.vehicleInfo {
                        Text(vehicleInfo)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }

                    if let state = viewModel.bookingState {
                        bookingStateBadge(state)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Chat button
                Button(action: { showChat = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "message.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.brand)
                    }
                }
                .buttonStyle(.plain)
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

    // MARK: - Trip Details Section

    private func tripDetailsSection(trip: TripWithDriver) -> some View {
        VStack(spacing: 16) {
            // Origin
            tripDetailRow(
                icon: "mappin.circle.fill",
                iconColor: .brand,
                title: "Driver starts at",
                value: trip.origin
            )

            Divider()

            // Rider pickup (intermediate stop)
            let pickupAddress = viewModel.booking?.pickupLocation?.address
            tripDetailRow(
                icon: "figure.wave",
                iconColor: .brandGold,
                title: "Your Pickup",
                value: pickupAddress ?? "Your selected location"
            )

            Divider()

            // Destination
            tripDetailRow(
                icon: "location.fill",
                iconColor: .brandGreen,
                title: "Drop-off",
                value: trip.destination
            )

            Divider()

            // Departure time
            tripDetailRow(
                icon: "clock",
                iconColor: .textSecondary,
                title: "Departure",
                value: formatDateTime(trip.departureTime)
            )

            Divider()

            // Seats available
            tripDetailRow(
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

    private func tripDetailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
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
            }

            Spacer()
        }
    }

    // MARK: - Route Map Section

    private var myPickupETA: Date? {
        guard let riderId = authVM.currentUser?.id,
              let trip = viewModel.trip,
              let anchor = anchorPoints.first(where: { $0.riderId == riderId && $0.type == .pickup }),
              let etaOffset = anchor.etaOffsetSeconds else { return nil }
        return trip.departureTime.addingTimeInterval(etaOffset)
    }

    private func routeMapSection(trip: TripWithDriver) -> some View {
        let driverOrigin: CLLocationCoordinate2D? = trip.originLat.flatMap { lat in
            trip.originLng.map { lng in CLLocationCoordinate2D(latitude: lat, longitude: lng) }
        }
        let pickup = pickupCoordinate
        let destination = AppConstants.sjsuCoordinate

        let mapView: AnyView
        if !anchorPoints.isEmpty {
            mapView = AnyView(
                AnchorRouteMapView(
                    origin: driverOrigin,
                    destination: destination,
                    driver: nil,
                    anchorPoints: anchorPoints,
                    showsUserLocation: false,
                    ownRiderId: authVM.currentUser?.id
                )
            )
        } else {
            let fitCoords: [CLLocationCoordinate2D] = [driverOrigin, pickup, destination].compactMap { $0 }
            mapView = AnyView(
                RouteMapView(
                    origin: driverOrigin,
                    destination: destination,
                    driver: nil,
                    waypoint: pickup,
                    riders: pickup.map { [$0] } ?? [],
                    fitAnchors: fitCoords.isEmpty ? nil : fitCoords,
                    showsUserLocation: false
                )
            )
        }

        return VStack(spacing: 0) {
            mapView
                .frame(height: 180)
                .cornerRadius(12)
            if let eta = myPickupETA {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.brandGreen)
                    Text("Est. pickup \(eta.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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

    // MARK: - Cost Section

    private func costSection(trip: TripWithDriver) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Cost Breakdown")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(formatPrice(viewModel.booking?.fare ?? trip.costBreakdown?.perRiderSplit ?? trip.estimatedCost))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brand)
            }

            Divider()

            if let cb = trip.costBreakdown {
                costBreakdownRow(label: "Base fare", value: formatPrice(cb.baseFare))
                if cb.detourSurcharge > 0 {
                    if let detour = trip.detourMiles {
                        costBreakdownRow(
                            label: String(format: "Detour (%.1f mi)", detour),
                            value: "+\(formatPrice(cb.detourSurcharge))"
                        )
                    } else {
                        costBreakdownRow(label: "Detour surcharge", value: "+\(formatPrice(cb.detourSurcharge))")
                    }
                }
                if let original = trip.originalEtaMinutes,
                   let detour = trip.detourTimeMinutes,
                   let adjusted = trip.adjustedEtaMinutes {
                    costBreakdownRow(label: "Original trip time", value: "\(original) min")
                    costBreakdownRow(label: "+ Pickup detour", value: "+\(detour) min")
                    costBreakdownRow(label: "New total time", value: "\(adjusted) min")
                } else if let eta = trip.adjustedEtaMinutes {
                    costBreakdownRow(label: "ETA with detour", value: "\(eta) min")
                }
            } else {
                costBreakdownRow(label: "Estimated fare", value: formatPrice(trip.estimatedCost))
            }

            Divider()

            HStack {
                Text("Your share")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(formatPrice(viewModel.booking?.fare ?? trip.costBreakdown?.perRiderSplit ?? trip.estimatedCost))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.brand)
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

    private func costBreakdownRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Booking Action Section

    private func bookingActionSection(trip: TripWithDriver) -> some View {
        VStack(spacing: 12) {
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.brandRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Booking status
            bookingStatusView(trip: trip)
        }
    }

    private func bookingStatusView(trip: TripWithDriver) -> some View {
        AnyView(
            Group {
                switch viewModel.bookingState {
                case nil:
                    // Not booked - show request button + pre-booking chat
                    VStack(spacing: 10) {
                        Button(action: {
                            Task {
                                await viewModel.requestBooking()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if viewModel.isBooking {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "car.fill")
                                }
                                Text(viewModel.isBooking ? "Requesting..." : "Request Ride")
                            }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(viewModel.isBooking ? Color.brand.opacity(0.6) : Color.brand)
                            .cornerRadius(16)
                        }
                        .disabled(viewModel.isBooking || trip.seatsAvailable == 0)

                        Button(action: { showChat = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "message")
                                Text("Message Driver")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brand.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }

                case .pending:
                    // Pending - show awaiting approval with cancel button
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brandGold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Awaiting Approval")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("The driver will review your request shortly.")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )

                Button(action: {
                    Task {
                        await viewModel.cancelBooking()
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isCancelling {
                            ProgressView().tint(.brandRed)
                        } else {
                            Image(systemName: "xmark")
                        }
                        Text(viewModel.isCancelling ? "Cancelling..." : "Cancel Request")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandRed.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(viewModel.isCancelling)

                Button(action: { showChat = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                        Text("Chat with Driver")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand)
                    .cornerRadius(12)
                }
            }

        case .approved:
            // Approved - show payment authorization or confirmed status
            VStack(spacing: 12) {
                if viewModel.paymentAuthorized {
                    // Payment hold placed — show confirmed badge
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Payment Held — Ride Confirmed")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Your card has been authorized. Payment will be captured after the trip.")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.brandGreen.opacity(0.5), lineWidth: 1)
                    )
                } else {
                    // Driver approved — prompt rider to authorize payment
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Driver Approved Your Request!")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Confirm your spot by authorizing payment. Your card will only be charged after the trip.")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.brandGreen.opacity(0.5), lineWidth: 1)
                    )

                    Button(action: {
                        Task { await viewModel.authorizePayment() }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isAuthorizing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "lock.shield.fill")
                            }
                            if let fare = viewModel.booking?.fare {
                                Text(viewModel.isAuthorizing ? "Authorizing..." : String(format: "Confirm & Pay $%.2f", fare))
                            } else {
                                Text(viewModel.isAuthorizing ? "Authorizing..." : "Confirm & Pay")
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandGreen)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isAuthorizing)
                }

                Button(action: { showChat = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                        Text("Chat with Driver")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand)
                    .cornerRadius(12)
                }
            }

        case .rejected:
            // Rejected - show declined message
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brandRed)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Request Declined")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("The driver declined your request. Browse other rides.")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.brandRed.opacity(0.5), lineWidth: 1)
                )

                Button(action: { dismiss() }) {
                    Text("Browse Other Rides")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand)
                        .cornerRadius(12)
                }
            }

        case .cancelled:
            // Cancelled — distinguish timeout from rider-initiated
            let isExpired = viewModel.booking?.holdExpiresAt.map { $0 < Date() } ?? false
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isExpired ? "Request Expired" : "Request Cancelled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(isExpired
                             ? "The driver didn't respond in time. Your seat hold has expired."
                             : "You cancelled this booking request.")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )

                Button(action: { dismiss() }) {
                    Text("Browse Other Rides")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand)
                        .cornerRadius(12)
                }
            }

        case .completed:
            // Completed - show completed message
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brandGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip Completed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("This trip has been completed.")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.brandGreen.opacity(0.5), lineWidth: 1)
                )

                Button(action: { dismiss() }) {
                    Text("Back to Search")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand)
                        .cornerRadius(12)
                }
            }
        }
        }
        )
    }

    // MARK: - Booking State Badge

    @ViewBuilder
    private func bookingStateBadge(_ state: BookingState) -> some View {
        let (label, color): (String, Color) = {
            switch state {
            case .pending:   return ("Pending", .brandGold)
            case .approved:  return ("Confirmed", .brandGreen)
            case .rejected:  return ("Declined", .brandRed)
            case .cancelled: return ("Cancelled", .textTertiary)
            case .completed: return ("Completed", .brandGreen)
            }
        }()
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
}

// MARK: - Preview

#Preview {
    TripDetailView(
        trip: TripWithDriver(
            id: "trip-123",
            driverId: "driver-456",
            driverName: "John Doe",
            driverRating: 4.8,
            driverPhotoUrl: nil,
            vehicleInfo: "Tesla Model 3 - Blue",
            origin: "123 Main St, San Jose",
            destination: "San Jose State University",
            departureTime: Date().addingTimeInterval(3600),
            seatsAvailable: 3,
            estimatedCost: 12.50,
            featured: false,
            status: "pending"
        ),
        riderCoordinate: CLLocationCoordinate2D(latitude: 37.3382, longitude: -121.8863)
    )
    .environmentObject(AuthViewModel())
}
