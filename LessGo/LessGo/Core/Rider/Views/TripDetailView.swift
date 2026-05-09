import SwiftUI
import MapKit
import CoreLocation

// MARK: - Trip Detail View

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TripDetailViewModel
    @State private var showChat = false
    @State private var showSuccessMessage = false
    private let criteria: SearchCriteria?

    init(trip: TripWithDriver, criteria: SearchCriteria? = nil) {
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
        self.criteria = criteria
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if showSuccessMessage {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.brandGreen)
                                Text("Booking cancelled successfully")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.brandGreen.opacity(0.1))

                            Divider()
                        }
                    }

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
                await viewModel.loadTripDetails()
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
        // Derive rider-specific pickup/dropoff labels from search criteria.
        // to SJSU:   driver starts at trip.origin, rider boards at criteria.location, drops off at SJSU
        // from SJSU: driver starts at SJSU (= trip.origin), rider boards at SJSU, drops off at criteria.location
        let driverStart: String
        let riderPickup: String
        let riderDropoff: String

        if let c = criteria {
            switch c.direction {
            case .toSJSU:
                driverStart  = trip.origin
                riderPickup  = c.location
                riderDropoff = "San Jose State University"
            case .fromSJSU:
                driverStart  = trip.origin
                riderPickup  = "San Jose State University"
                riderDropoff = c.location
            }
        } else {
            driverStart  = trip.origin
            riderPickup  = trip.origin
            riderDropoff = trip.destination
        }

        return VStack(spacing: 16) {
            tripDetailRow(icon: "car.fill",        iconColor: .brand,          title: "Driver starts at", value: driverStart)
            Divider()
            tripDetailRow(icon: "mappin.circle.fill", iconColor: .brandGold,   title: "Your pickup",      value: riderPickup)
            Divider()
            tripDetailRow(icon: "location.fill",   iconColor: .brandGreen,     title: "Your drop-off",    value: riderDropoff)
            Divider()
            tripDetailRow(icon: "clock",           iconColor: .textSecondary,  title: "Departure",        value: formatDateTime(trip.departureTime))
            Divider()
            tripDetailRow(icon: "person.2.fill",   iconColor: .textSecondary,  title: "Seats Available",  value: "\(trip.seatsAvailable)")
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

    private func routeMapSection(trip: TripWithDriver) -> some View {
        // Full driver route: driver origin → rider pickup → destination
        // Coordinates:
        //   driver origin  = trip.originLat/Lng (from search enrichment)
        //   rider pickup   = criteria.coordinate (to SJSU) or AppConstants.sjsuCoordinate (from SJSU)
        //   final dest     = AppConstants.sjsuCoordinate (to SJSU) or criteria.coordinate (from SJSU)
        let driverOrigin: CLLocationCoordinate2D? = {
            guard let lat = trip.originLat, let lng = trip.originLng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()

        let (mapOrigin, riderAnchor, mapDest): (CLLocationCoordinate2D?, CLLocationCoordinate2D?, CLLocationCoordinate2D?)
        if let c = criteria {
            switch c.direction {
            case .toSJSU:
                mapOrigin   = driverOrigin
                riderAnchor = c.coordinate
                mapDest     = AppConstants.sjsuCoordinate
            case .fromSJSU:
                mapOrigin   = AppConstants.sjsuCoordinate
                riderAnchor = AppConstants.sjsuCoordinate  // pickup = SJSU, no detour leg
                mapDest     = c.coordinate
            }
        } else {
            mapOrigin   = driverOrigin
            riderAnchor = nil
            mapDest     = AppConstants.sjsuCoordinate
        }

        // Build anchor points so AnchorRouteMapView draws the detour leg
        let anchors: [AnchorPoint] = {
            guard let c = criteria, let anchor = riderAnchor else { return [] }
            switch c.direction {
            case .toSJSU:
                return [AnchorPoint(lat: anchor.latitude, lng: anchor.longitude, type: .pickup, riderId: nil, label: nil, etaOffsetSeconds: nil)]
            case .fromSJSU:
                return []
            }
        }()

        return AnchorRouteMapView(
            origin: mapOrigin,
            destination: mapDest,
            driver: nil,
            anchorPoints: anchors,
            showsUserLocation: false
        )
        .frame(height: 200)
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
                Text("Fare Breakdown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(formatPrice(trip.costBreakdown?.perRiderSplit ?? trip.estimatedCost))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brand)
            }

            Divider()

            if let bd = trip.costBreakdown {
                let timeCost = bd.durationHours * 15.0
                let distCost = max(bd.tripCost - timeCost, 0)

                costBreakdownRow(
                    label: String(format: "%.1f mi × $0.67/mi", distCost / 0.67),
                    value: formatPrice(distCost)
                )
                costBreakdownRow(
                    label: String(format: "%.0f min × $0.25/min", bd.durationHours * 60),
                    value: formatPrice(timeCost)
                )
                if bd.detourFee > 0.01 {
                    costBreakdownRow(
                        label: String(format: "Detour %.1f mi × $0.84/mi", bd.detourFee / (0.67 * 1.25)),
                        value: formatPrice(bd.detourFee)
                    )
                }

                Divider()

                HStack {
                    Text("Your share")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(formatPrice(bd.perRiderSplit))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brand)
                }
            } else {
                costBreakdownRow(label: "Estimated fare", value: formatPrice(trip.estimatedCost))
                Divider()
                HStack {
                    Text("Your share")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(formatPrice(trip.estimatedCost))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brand)
                }
            }

            Text("Final charge split among confirmed riders — you'll only pay your share.")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    // Not booked - show request button
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
                        if viewModel.cancellationSuccess {
                            showSuccessMessage = true
                            // Dismiss after showing success
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                dismiss()
                            }
                        }
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
            }

        case .approved:
            // Approved - show confirmed status with cancel option
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brandGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ride Confirmed!")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Your ride has been confirmed by the driver.")
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

                let paymentDone = viewModel.paymentAuthorized || viewModel.booking?.paymentIntentId != nil

                // Payment deadline banner — shown when payment has not yet been completed
                if !paymentDone, let deadline = viewModel.paymentDeadlineAt {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.brandOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Payment required")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Complete payment by \(formatDeadline(deadline)) to keep your seat.")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.brandOrange.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.brandOrange.opacity(0.35), lineWidth: 1)
                    )
                }

                // Confirm & Pay button — hidden once payment is done
                if !paymentDone {
                    Button(action: {
                        Task { await viewModel.authorizePayment() }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isAuthorizing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "creditcard.fill")
                            }
                            Text(viewModel.isAuthorizing ? "Processing..." : "Confirm & Pay")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.isAuthorizing ? Color.brand.opacity(0.6) : Color.brand)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isAuthorizing)
                } else {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.brandOrange)
                            Text("Payment Held")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.brandOrange)
                        }
                        Text("You'll only be charged when the trip completes")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandOrange.opacity(0.1))
                    .cornerRadius(12)
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

                Text("Cancellation after payment may take 3–5 days to refund.")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    Task {
                        await viewModel.cancelBooking()
                        if viewModel.cancellationSuccess {
                            showSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                dismiss()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isCancelling {
                            ProgressView().tint(.brandRed)
                        } else {
                            Image(systemName: "xmark")
                        }
                        Text(viewModel.isCancelling ? "Cancelling..." : "Cancel Booking")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandRed.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(viewModel.isCancelling)
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
            // Cancelled - show cancelled message
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Request Cancelled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(viewModel.cancellationReason == "payment_not_completed"
                             ? "Your booking was cancelled because payment wasn't completed before the deadline."
                             : "You cancelled this booking request.")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Helpers

    private func formatDeadline(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if calendar.isDateInToday(date) || calendar.isDateInTomorrow(date) {
            return formatter.string(from: date)
        }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

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
    TripDetailView(trip: TripWithDriver(
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
    ))
}
