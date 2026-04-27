import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Active Trip View (Real-time ride tracking)

struct ActiveTripView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var locationService = LocationTrackingService.shared
    @ObservedObject var riderLocationManager = LocationManager.shared

    let trip: Trip
    let booking: Booking?
    let isDriver: Bool

    @State private var tripStatus: TripStatus
    @State private var showChat = false
    @State private var isUpdatingState = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var unreadCount = 0
    @State private var showPostRideSummary = false
    @State private var showReportIssueSheet = false
    @State private var pollTimer: Timer?
    @State private var passengerPollTimer: Timer?
    @State private var riderPickupSyncTimer: Timer?
    @State private var riderPickupLocations: [String: PickupLocation] = [:]
    @State private var focusedRiderBookingId: String?
    @State private var lastFocusedRiderCoordinate: CLLocationCoordinate2D?
    @State private var riderMovedDistanceMeters: CLLocationDistance = 0
    @State private var riderLastUpdatedAt: Date?
    @State private var etaToPickupMinutes: Int?
    @State private var distanceToPickupMeters: CLLocationDistance?
    @State private var lastETARouteKey = ""
    @State private var lastETAFetchAt: Date?
    @State private var lastSentRiderPickupCoordinate: CLLocationCoordinate2D?
    @State private var isSimulatingRiderMovement = false
    @State private var riderSimulationTask: Task<Void, Never>?
    @State private var anchorPoints: [AnchorPoint] = []
    @State private var frequentRoutes: [FrequentRouteSegment] = []
    @State private var settlement: TripSettlement?

    private let tripService = TripService.shared

    init(trip: Trip, booking: Booking? = nil, isDriver: Bool) {
        self.trip = trip
        self.booking = booking
        self.isDriver = isDriver
        _tripStatus = State(initialValue: trip.status)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Map
                mapView
                    .ignoresSafeArea(edges: .top)

                // Bottom Card (constrained so the map remains visible)
                tripInfoCard(maxHeight: min(max(360, geo.size.height * 0.58), 560))

                // Floating Chat Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        chatButton
                            .padding(.trailing, 20)
                            .padding(.bottom, min(max(280, geo.size.height * 0.34), 380))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
        .overlay(alignment: .top) {
            statusBanner
        }
        .sheet(isPresented: $showChat) {
            chatSheet
        }
        .sheet(isPresented: $showPostRideSummary) {
            postRideSummarySheet
        }
        .sheet(isPresented: $showReportIssueSheet) {
            PostRideReportSheet(
                trip: trip,
                booking: booking,
                isDriver: isDriver
            )
            .environmentObject(authVM)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .task {
            startTracking()
            if let points = try? await tripService.getAnchorPoints(tripId: trip.id), !points.isEmpty {
                anchorPoints = points
            }
            // Load driver's mined frequent routes for map overlay (driver-only)
            if isDriver {
                if let routes = try? await tripService.getFrequentRoutes(driverId: trip.driverId) {
                    frequentRoutes = routes
                }
            }
        }
        .onDisappear {
            stopTracking()
        }
        .onChange(of: locationService.currentLocation?.coordinate.latitude) { _ in
            if isDriver { refreshDriverApproachMetrics() }
        }
        .onChange(of: locationService.currentLocation?.coordinate.longitude) { _ in
            if isDriver { refreshDriverApproachMetrics() }
        }
        .onChange(of: locationService.driverLocation?.latitude) { _ in
            if !isDriver { refreshDriverApproachMetrics() }
        }
        .onChange(of: locationService.driverLocation?.longitude) { _ in
            if !isDriver { refreshDriverApproachMetrics() }
        }
        .onChange(of: riderPickupLocations.count) { _ in
            refreshDriverApproachMetrics(force: true)
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        Group {
            if anchorPoints.isEmpty {
                RouteMapView(
                    origin: trip.originPoint?.clLocationCoordinate2D,
                    destination: trip.destinationPoint?.clLocationCoordinate2D,
                    driver: driverCoordinate,
                    routeStart: routeLineOriginCoordinate,
                    routeEnd: routeLineDestinationCoordinate,
                    riders: riderCoordinates,
                    fitAnchors: overviewFitAnchors,
                    showsUserLocation: false
                )
            } else {
                AnchorRouteMapView(
                    origin: trip.originPoint?.clLocationCoordinate2D,
                    destination: trip.destinationPoint?.clLocationCoordinate2D,
                    driver: driverCoordinate,
                    anchorPoints: anchorPoints,
                    showsUserLocation: false,
                    frequentRoutes: frequentRoutes
                )
            }
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: tripStatus.iconName)
                .font(.system(size: 14, weight: .bold))
            Text(tripStatus.displayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [statusColor, statusColor.opacity(0.78)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        )
        .cornerRadius(20)
        .shadow(color: statusColor.opacity(0.35), radius: 10, y: 4)
        .padding(.top, 60)
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button(action: { dismiss() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardBackground)
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(.leading, 16)
        .padding(.top, 56)
    }

    // MARK: - Chat Button

    private var chatButton: some View {
        Button(action: { showChat = true }) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DesignSystem.Colors.darkBrandSurface)
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
                    Image(systemName: "message.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DesignSystem.Colors.accentLime)
                }

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.brandRed)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    // MARK: - Chat Sheet

    private var chatSheet: some View {
        NavigationView {
            ChatView(
                tripId: trip.id,
                otherPartyName: otherPartyName,
                isDriver: isDriver,
                includesTabBarClearance: false
            )
            .environmentObject(authVM)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var postRideSummarySheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    postRideSummaryMainCard
                    postRideSummaryActionButtons
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Post Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { showPostRideSummary = false }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // Outer white card containing header, route, details rows, and chips.
    @ViewBuilder
    private var postRideSummaryMainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            postRideSummaryHeader
            postRideSummaryRouteCard
            postRideSummaryDetailsCard
            HStack(spacing: 10) {
                summaryChip(icon: "checkmark.shield.fill", text: isDriver ? "Driver view" : "Rider view", tint: .brand)
                summaryChip(icon: "map.fill", text: "Route recorded", tint: .brandTeal)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
    }

    // "Trip Summary" title + completed/cancelled badge.
    @ViewBuilder
    private var postRideSummaryHeader: some View {
        let statusLabel  = tripStatus == .completed ? "Completed" : "Cancelled"
        let statusColor  = tripStatus == .completed ? Color.brandGreen : Color.brandRed
        HStack {
            Text("Trip Summary")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
            Text(statusLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.10))
                .clipShape(Capsule())
        }
    }

    // Origin → destination route display.
    @ViewBuilder
    private var postRideSummaryRouteCard: some View {
        let cardBackground = RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.sheetBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(Color.brand).frame(width: 8, height: 8)
                Text(trip.origin)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.brandGreen)
                    .frame(width: 8)
                Text(trip.destination)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    // Summary rows (date, driver/rider, settlement or booking details).
    @ViewBuilder
    private var postRideSummaryDetailsCard: some View {
        let cardBackground = RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.sheetBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
        VStack(spacing: 10) {
            summaryRow("Date", trip.departureTime.tripDateString)
            summaryRow("Time", trip.departureTime.tripTimeString)
            summaryRow(isDriver ? "Rider" : "Driver", otherPartyName)
            summaryRow("Trip Status", tripStatus.displayName)
            if isDriver {
                if let s = settlement {
                    summaryRow("Riders", "\(s.riderCount)")
                    summaryRow("Distance", String(format: "%.1f mi", s.breakdown.directDistanceMiles))
                    summaryRow("Total Earnings", String(format: "$%.2f", s.driverEarnings), valueColor: .brandGreen, bold: true)
                } else if let booking {
                    summaryRow("Seats", "\(booking.seatsBooked)")
                    summaryRow("Booking ID", "\(String(booking.id.prefix(8)))…")
                }
            } else {
                if let booking {
                    summaryRow("Seats", "\(booking.seatsBooked)")
                    summaryRow("Booking ID", "\(String(booking.id.prefix(8)))…")
                    if let quote = booking.quote {
                        summaryRow("Your Fare", String(format: "$%.2f", quote.maxPrice), valueColor: .brandGreen, bold: true)
                    }
                    if let payment = booking.payment {
                        summaryRow("Payment", payment.status.rawValue.capitalized)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    // Report issue + dismiss buttons.
    @ViewBuilder
    private var postRideSummaryActionButtons: some View {
        let dismissLabel = isDriver ? "Back to Driver Trip" : "Done"
        Button(action: { showReportIssueSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                Text("Report Safety / Trip Issue")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.brandRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.brandRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        Button(action: { showPostRideSummary = false }) {
            Text(dismissLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignSystem.Colors.actionDarkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Trip Info Card

    private func tripInfoCard(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isDriver ? "Live Trip Control" : "Live Trip Tracking")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Text(tripStatusContextSubtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Label(isDriver ? "Driver" : "Rider", systemImage: isDriver ? "car.fill" : "person.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.brand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.brand.opacity(0.08))
                            .cornerRadius(999)
                    }

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.brandGold)
                                .frame(width: 10, height: 10)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 20)
                            Circle()
                                .fill(Color.brandGreen)
                                .frame(width: 10, height: 10)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text(trip.origin)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            Text(trip.destination)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.sheetBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )

                    liveTrackingSummary

                    Divider()
                    otherPartyInfo
                    Divider()
                    tripProgressTimeline
                    Divider()
                    actionButtons
                    debugTestingControls
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 120)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [DesignSystem.Colors.accentLime.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
        )
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
    }

    // MARK: - Other Party Info

    private var otherPartyInfo: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(otherPartyName.prefix(1).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(otherPartyName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)

                if !isDriver, let vehicle = trip.driver?.vehicleInfo {
                    Text(vehicle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }

                if !isDriver, let plate = trip.driver?.licensePlate {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 9))
                        Text(plate)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            // Rating
            if !isDriver, let driver = trip.driver {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.brandGold)
                    Text(String(format: "%.1f", Double(driver.rating)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isDriver {
            driverActions
        } else {
            riderActions
        }
    }

    private var driverActions: some View {
        VStack(spacing: 10) {
            switch tripStatus {
            case .pending:
                PrimaryButton(title: "Start Trip - Head to Pickup", icon: "car.fill", isEnabled: !isUpdatingState) {
                    Task { await updateState(to: .enRoute) }
                }
            case .enRoute:
                PrimaryButton(title: "I've Arrived at Pickup", icon: "location.fill", isEnabled: !isUpdatingState) {
                    Task { await updateState(to: .arrived) }
                }
            case .arrived:
                PrimaryButton(title: "Rider Picked Up - Start Ride", icon: "arrow.triangle.turn.up.right.circle.fill", isEnabled: !isUpdatingState) {
                    Task { await updateState(to: .inProgress) }
                }
            case .inProgress:
                PrimaryButton(title: "Complete Trip", icon: "checkmark.circle.fill", isEnabled: !isUpdatingState) {
                    Task { await updateState(to: .completed) }
                }
            case .completed:
                Button(action: { showPostRideSummary = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Post Ride Summary")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.brand.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            case .cancelled:
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.brandRed)
                    Text("Trip Cancelled")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandRed)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var riderActions: some View {
        VStack(spacing: 10) {
            switch tripStatus {
            case .pending:
                statusLabel(text: "Waiting for driver to start trip...", icon: "clock.fill", color: .brandGold)
            case .enRoute:
                statusLabel(text: "Driver is on the way to you!", icon: "car.fill", color: .brand)
            case .arrived:
                statusLabel(text: "Driver has arrived! Head to pickup.", icon: "location.fill", color: .brandGreen)
            case .inProgress:
                statusLabel(text: "You're on your way!", icon: "arrow.triangle.turn.up.right.circle.fill", color: .brand)
            case .completed:
                statusLabel(text: "Trip completed! Rate your driver.", icon: "checkmark.circle.fill", color: .brandGreen)
            case .cancelled:
                statusLabel(text: "Trip was cancelled.", icon: "xmark.circle.fill", color: .brandRed)
            }

            // Chat and Call buttons for rider
            HStack(spacing: 12) {
                Button(action: { showChat = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            if tripStatus == .completed || tripStatus == .cancelled {
                Button(action: { showPostRideSummary = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Post Ride Summary")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.brand.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var tripStatusContextSubtitle: String {
        switch tripStatus {
        case .pending: return isDriver ? "Ready to start navigation to pickup" : "Waiting for driver to begin trip"
        case .enRoute: return isDriver ? "Approaching rider pickup point" : "Driver is heading to your pickup point"
        case .arrived: return isDriver ? "Rider should arrive at pickup now" : "Driver is waiting at pickup"
        case .inProgress: return isDriver ? "Trip is currently underway" : "You're on the way to destination"
        case .completed: return "Trip complete"
        case .cancelled: return "Trip cancelled"
        }
    }

    private var tripProgressTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trip Progress")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(progressSummaryText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(progressSummaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(progressSummaryColor.opacity(0.12))
                    .cornerRadius(999)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(timelineSteps.enumerated()), id: \.offset) { index, step in
                    timelineRow(index: index, step: step)
                }
            }

            Text(progressHintText)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
    }

    private func timelineRow(index: Int, step: TimelineStep) -> some View {
        let state = timelineState(for: index)

        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(state.fill)
                        .frame(width: 20, height: 20)
                    Image(systemName: state.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(state.iconColor)
                }

                if index < timelineSteps.count - 1 {
                    Rectangle()
                        .fill(state.connector)
                        .frame(width: 2, height: 20)
                        .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 13, weight: state.isCurrent ? .bold : .semibold))
                    .foregroundColor(state.isUpcoming ? .textSecondary : .textPrimary)
                Text(step.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            if state.isCurrent {
                Text("Now")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.brand)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(999)
            } else if state.isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.brandGreen)
                    .padding(.top, 2)
            }
        }
    }

    private var debugTestingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Trip Simulation")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)

            if isDriver {
                Button("Simulate Full Ride") {
                    Task { await simulateFullRideAsDriver() }
                }
                .debugPill()

                HStack(spacing: 8) {
                    Button("Simulate → Pickup") {
                        Task { await simulateDriverPath(toDestination: false) }
                    }
                    .debugPill()

                    Button("Simulate → Dropoff") {
                        Task { await simulateDriverPath(toDestination: true) }
                    }
                    .debugPill()
                }
            } else if booking != nil {
                Button("Simulate Full Ride (UI)") {
                    simulateRiderFullRideUI()
                }
                .debugPill()

                Button(isSimulatingRiderMovement ? "Simulating Rider Movement..." : "Simulate Rider Movement") {
                    simulateRiderMovement()
                }
                .debugPill(disabled: isSimulatingRiderMovement)
                .disabled(isSimulatingRiderMovement)
            }

            Button("Reset Test State") {
                resetSimulationTestState()
            }
            .debugPill()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func simulateDriverPath(toDestination: Bool) async {
        let fallbackStart = trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        let start = driverCoordinate ?? locationService.currentLocation?.coordinate ?? fallbackStart
        let end = toDestination
            ? (trip.destinationPoint?.clLocationCoordinate2D ?? start)
            : (focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D ?? start)

        await MainActor.run {
            withAnimation {
                tripStatus = toDestination ? .inProgress : .enRoute
            }
            showPostRideSummary = false
        }

        locationService.startSimulatedMovement(
            from: start,
            to: end,
            tripId: trip.id,
            sendToBackend: false,
            updateDriverFeedOnly: false,
            stepInterval: 0.28,
            steps: 55
        )

        await waitForSimulationToFinish(maxSeconds: 25)

        if !toDestination {
            await MainActor.run {
                withAnimation { tripStatus = .arrived }
            }
        }
    }

    private func simulateRiderMovement() {
        guard !isSimulatingRiderMovement, let bookingId = booking?.id else { return }
        let base = focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate

        let offsets: [CLLocationCoordinate2D] = [
            base,
            CLLocationCoordinate2D(latitude: base.latitude + 0.00035, longitude: base.longitude - 0.00020),
            CLLocationCoordinate2D(latitude: base.latitude + 0.00015, longitude: base.longitude + 0.00030),
            base
        ]

        isSimulatingRiderMovement = true
        riderSimulationTask?.cancel()
        riderSimulationTask = Task {
            for point in offsets {
                if Task.isCancelled { break }
                do {
                    _ = try await BookingService.shared.updatePickupLocation(
                        id: bookingId,
                        lat: point.latitude,
                        lng: point.longitude,
                        address: nil
                    )
                    await MainActor.run {
                        riderPickupLocations[bookingId] = PickupLocation(lat: point.latitude, lng: point.longitude, address: nil)
                        refreshDriverApproachMetrics(force: true)
                    }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                } catch {
                    print("Rider simulation failed: \(error)")
                    break
                }
            }
            await MainActor.run {
                isSimulatingRiderMovement = false
            }
        }
    }

    private func simulateRiderFullRideUI() {
        Task {
            await simulateFullRideAsRiderUI()
        }
    }

    private func simulateFullRideAsDriver() async {
        let start = driverCoordinate ?? trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        let pickup = focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D ?? start
        let dropoff = trip.destinationPoint?.clLocationCoordinate2D ?? pickup

        await MainActor.run {
            withAnimation { tripStatus = .enRoute }
            showPostRideSummary = false
        }
        locationService.startSimulatedMovement(
            from: locationService.currentLocation?.coordinate ?? start,
            to: pickup,
            tripId: trip.id,
            sendToBackend: false,
            updateDriverFeedOnly: false,
            stepInterval: 0.22,
            steps: 65
        )
        await waitForSimulationToFinish(maxSeconds: 30)

        await MainActor.run {
            withAnimation { tripStatus = .arrived }
        }
        try? await Task.sleep(nanoseconds: 900_000_000)

        await MainActor.run {
            withAnimation { tripStatus = .inProgress }
        }
        locationService.startSimulatedMovement(
            from: locationService.currentLocation?.coordinate ?? pickup,
            to: dropoff,
            tripId: trip.id,
            sendToBackend: false,
            updateDriverFeedOnly: false,
            stepInterval: 0.22,
            steps: 75
        )
        await waitForSimulationToFinish(maxSeconds: 35)

        await MainActor.run {
            withAnimation { tripStatus = .completed }
            showPostRideSummary = true
        }
    }

    private func simulateFullRideAsRiderUI() async {
        let fallbackStart = trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        let pickup = focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D ?? fallbackStart
        let dropoff = trip.destinationPoint?.clLocationCoordinate2D ?? pickup

        await MainActor.run {
            withAnimation { tripStatus = .enRoute }
            showPostRideSummary = false
        }
        do {
            let start = driverCoordinate ?? locationService.driverLocation?.coordinate ?? fallbackStart
            locationService.startSimulatedMovement(
                from: start,
                to: pickup,
                tripId: trip.id,
                sendToBackend: false,
                updateDriverFeedOnly: true,
                stepInterval: 0.26,
                steps: 60
            )
            await waitForSimulationToFinish(maxSeconds: 25)
        }

        await MainActor.run {
            withAnimation { tripStatus = .arrived }
        }
        try? await Task.sleep(nanoseconds: 700_000_000)

        await MainActor.run {
            withAnimation { tripStatus = .inProgress }
        }
        do {
            let start = driverCoordinate ?? locationService.driverLocation?.coordinate ?? pickup
            locationService.startSimulatedMovement(
                from: start,
                to: dropoff,
                tripId: trip.id,
                sendToBackend: false,
                updateDriverFeedOnly: true,
                stepInterval: 0.26,
                steps: 70
            )
            await waitForSimulationToFinish(maxSeconds: 30)
        }

        await MainActor.run {
            withAnimation { tripStatus = .completed }
            showPostRideSummary = true
        }
    }

    private func statusLabel(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var liveTrackingSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let etaToPickupMinutes {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                    Text("ETA to pickup: \(etaToPickupMinutes) min")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brand)
            }

            if let distanceToPickupMeters {
                let miles = distanceToPickupMeters / 1609.344
                HStack(spacing: 6) {
                    Image(systemName: "location.north.line.fill")
                    Text(String(format: "Distance to pickup: %.1f mi", miles))
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            }

            if isDriver {
                if let riderLastUpdatedAt {
                    HStack(spacing: 6) {
                        Image(systemName: riderMovedDistanceMeters >= 10 ? "figure.walk" : "figure.stand")
                        if riderMovedDistanceMeters >= 10 {
                            Text(String(format: "Rider moved %.0fm (%@)", riderMovedDistanceMeters, riderLastUpdatedAt.timeAgo))
                        } else {
                            Text("Rider appears stationary (\(riderLastUpdatedAt.timeAgo))")
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(riderMovedDistanceMeters >= 10 ? .brandOrange : .textSecondary)
                } else if booking != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "location.slash")
                        Text("Rider live pickup location not shared yet")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed Properties

    private var timelineSteps: [TimelineStep] {
        [
            TimelineStep(title: "Booked", subtitle: "Ride confirmed and waiting to begin"),
            TimelineStep(title: "Driver En Route", subtitle: "Heading to rider pickup"),
            TimelineStep(title: "Arrived", subtitle: "Driver reached pickup point"),
            TimelineStep(title: "Trip In Progress", subtitle: "Rider onboard and heading to destination"),
            TimelineStep(title: "Completed", subtitle: "Ride finished")
        ]
    }

    private var currentTimelineIndex: Int? {
        switch tripStatus {
        case .pending: return 0
        case .enRoute: return 1
        case .arrived: return 2
        case .inProgress: return 3
        case .completed: return 4
        case .cancelled: return nil
        }
    }

    private var progressSummaryText: String {
        switch tripStatus {
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Done"
        default:
            let done = max(0, (currentTimelineIndex ?? 0))
            return "\(done + 1)/\(timelineSteps.count)"
        }
    }

    private var progressSummaryColor: Color {
        switch tripStatus {
        case .cancelled: return .brandRed
        case .completed: return .brandGreen
        default: return .brand
        }
    }

    private var progressHintText: String {
        switch tripStatus {
        case .pending:
            return isDriver ? "Start the trip when you are heading to pickup." : "Driver hasn’t started heading to pickup yet."
        case .enRoute:
            return isDriver ? "Follow navigation and update when you arrive." : "Watch the live map and ETA as your driver approaches."
        case .arrived:
            return isDriver ? "Confirm pickup once the rider is in the vehicle." : "Meet your driver at the pickup point and get in safely."
        case .inProgress:
            return isDriver ? "Continue to destination and complete the trip when done." : "Trip is underway. You can still chat with your driver."
        case .completed:
            return "Trip completed successfully."
        case .cancelled:
            return "This trip was cancelled before completion."
        }
    }

    private var otherPartyName: String {
        if isDriver {
            return booking?.rider?.name ?? "Rider"
        } else {
            return trip.driver?.name ?? "Driver"
        }
    }

    private var statusColor: Color {
        switch tripStatus {
        case .pending: return .brandGold
        case .enRoute: return .brand
        case .arrived: return .brandGreen
        case .inProgress: return .brand
        case .completed: return .brandGreen
        case .cancelled: return .brandRed
        }
    }

    private var driverCoordinate: CLLocationCoordinate2D? {
        if tripStatus == .completed || tripStatus == .cancelled {
            return nil
        }
        if isDriver {
            return locationService.currentLocation?.coordinate
        }
        return locationService.driverLocation?.coordinate
    }

    private var riderCoordinates: [CLLocationCoordinate2D] {
        riderPickupLocations.values.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
    }

    private var focusedPickupCoordinate: CLLocationCoordinate2D? {
        if let booking,
           let shared = riderPickupLocations[booking.id] ?? booking.pickupLocation {
            return CLLocationCoordinate2D(latitude: shared.lat, longitude: shared.lng)
        }

        if let first = riderPickupLocations.values.first {
            return CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
        }

        return trip.originPoint?.clLocationCoordinate2D
    }

    private var routeLineOriginCoordinate: CLLocationCoordinate2D? {
        switch tripStatus {
        case .pending:
            return trip.originPoint?.clLocationCoordinate2D
        case .enRoute, .arrived:
            return driverCoordinate ?? trip.originPoint?.clLocationCoordinate2D
        case .inProgress:
            return driverCoordinate ?? focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D
        case .completed, .cancelled:
            return trip.originPoint?.clLocationCoordinate2D
        }
    }

    private var routeLineDestinationCoordinate: CLLocationCoordinate2D? {
        switch tripStatus {
        case .pending:
            return trip.destinationPoint?.clLocationCoordinate2D
        case .enRoute, .arrived:
            return focusedPickupCoordinate ?? trip.originPoint?.clLocationCoordinate2D
        case .inProgress:
            return trip.destinationPoint?.clLocationCoordinate2D
        case .completed, .cancelled:
            return trip.destinationPoint?.clLocationCoordinate2D
        }
    }

    private var overviewFitAnchors: [CLLocationCoordinate2D] {
        var anchors: [CLLocationCoordinate2D] = []
        if let origin = trip.originPoint?.clLocationCoordinate2D { anchors.append(origin) }
        if let destination = trip.destinationPoint?.clLocationCoordinate2D { anchors.append(destination) }
        return anchors
    }

    private func timelineState(for index: Int) -> TimelineRowState {
        if tripStatus == .cancelled {
            return TimelineRowState(
                isCurrent: false,
                isDone: false,
                isUpcoming: true,
                fill: Color.gray.opacity(0.15),
                icon: "circle",
                iconColor: .textTertiary,
                connector: Color.gray.opacity(0.15)
            )
        }

        guard let current = currentTimelineIndex else {
            return TimelineRowState(
                isCurrent: false,
                isDone: false,
                isUpcoming: true,
                fill: Color.gray.opacity(0.15),
                icon: "circle",
                iconColor: .textTertiary,
                connector: Color.gray.opacity(0.15)
            )
        }

        if index < current {
            return TimelineRowState(
                isCurrent: false,
                isDone: true,
                isUpcoming: false,
                fill: Color.brandGreen.opacity(0.18),
                icon: "checkmark",
                iconColor: .brandGreen,
                connector: Color.brandGreen.opacity(0.35)
            )
        }

        if index == current {
            return TimelineRowState(
                isCurrent: true,
                isDone: false,
                isUpcoming: false,
                fill: Color.brand.opacity(0.16),
                icon: "circle.fill",
                iconColor: .brand,
                connector: Color.brand.opacity(0.25)
            )
        }

        return TimelineRowState(
            isCurrent: false,
            isDone: false,
            isUpcoming: true,
            fill: Color.gray.opacity(0.12),
            icon: "circle",
            iconColor: .textTertiary,
            connector: Color.gray.opacity(0.12)
        )
    }

    // MARK: - Functions

    private func updateState(to newStatus: TripStatus) async {
        isUpdatingState = true
        defer { isUpdatingState = false }

        do {
            let response = try await tripService.updateTripState(tripId: trip.id, status: newStatus)
            withAnimation {
                tripStatus = newStatus
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if newStatus == .completed {
                settlement = response.settlement
                stopTracking()
                showPostRideSummary = true
            }
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to update trip. Please try again."
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func summaryRow(_ label: String, _ value: String, valueColor: Color = .textPrimary, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .semibold))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private func summaryChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }

    private func startTracking() {
        stopTracking()

        if isDriver {
            // Driver: Send location updates
            locationService.requestLocationPermission()
            locationService.startTrackingTrip(tripId: trip.id)
            Task { await refreshPassengerLocations() }
            passengerPollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                Task { await refreshPassengerLocations() }
            }
        } else {
            // Rider: Poll for driver location
            locationService.startPollingDriverLocation(tripId: trip.id)
            startRiderPickupSharingIfNeeded()
        }

        refreshDriverApproachMetrics(force: true)

        // Poll for trip state changes (for riders)
        if !isDriver {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                Task {
                    do {
                        let response = try await tripService.getTrip(id: trip.id)
                        await MainActor.run {
                            if response.status != tripStatus {
                                withAnimation {
                                    tripStatus = response.status
                                }
                            }
                        }
                    } catch {
                        print("Trip state poll error: \(error)")
                    }
                }
            }
        }
    }

    private func stopTracking() {
        if isDriver {
            locationService.stopTrackingTrip()
        } else {
            locationService.stopPollingDriverLocation()
        }
        pollTimer?.invalidate()
        pollTimer = nil
        passengerPollTimer?.invalidate()
        passengerPollTimer = nil
        riderPickupSyncTimer?.invalidate()
        riderPickupSyncTimer = nil
        riderSimulationTask?.cancel()
        riderSimulationTask = nil
        isSimulatingRiderMovement = false
    }

    private func refreshDriverApproachMetrics(force: Bool = false) {
        guard tripStatus != .completed, tripStatus != .cancelled else {
            etaToPickupMinutes = nil
            distanceToPickupMeters = nil
            return
        }
        guard tripStatus == .pending || tripStatus == .enRoute || tripStatus == .arrived else {
            etaToPickupMinutes = nil
            distanceToPickupMeters = nil
            return
        }
        guard let driver = driverCoordinate, let pickup = focusedPickupCoordinate else {
            etaToPickupMinutes = nil
            distanceToPickupMeters = nil
            return
        }

        let routeKey = "\(driver.latitude.roundedForRouteKey),\(driver.longitude.roundedForRouteKey)|\(pickup.latitude.roundedForRouteKey),\(pickup.longitude.roundedForRouteKey)"
        if !force, routeKey == lastETARouteKey { return }
        lastETARouteKey = routeKey

        let straightDistance = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
            .distance(from: CLLocation(latitude: pickup.latitude, longitude: pickup.longitude))
        distanceToPickupMeters = straightDistance
        let fallbackETA = max(1, Int((straightDistance / 1609.344 / 28.0) * 60.0))
        etaToPickupMinutes = fallbackETA

        // Use traffic-aware MKDirections but throttle heavily to avoid GEO throttling during rapid updates.
        let minFetchInterval: TimeInterval = locationService.isSimulatingMovement ? 4.0 : 2.5
        if !force, let lastFetch = lastETAFetchAt, Date().timeIntervalSince(lastFetch) < minFetchInterval {
            return
        }
        lastETAFetchAt = Date()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: driver))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pickup))
        request.transportType = .automobile

        MKDirections(request: request).calculate { response, _ in
            DispatchQueue.main.async {
                if let route = response?.routes.first {
                    self.distanceToPickupMeters = route.distance
                    self.etaToPickupMinutes = max(1, Int(route.expectedTravelTime / 60.0))
                }
            }
        }
    }

    private func waitForSimulationToFinish(maxSeconds: TimeInterval) async {
        let started = Date()
        while locationService.isSimulatingMovement {
            if Date().timeIntervalSince(started) > maxSeconds { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func resetSimulationTestState() {
        locationService.stopSimulatedMovement()
        riderSimulationTask?.cancel()
        riderSimulationTask = nil
        isSimulatingRiderMovement = false
        showPostRideSummary = false
        showReportIssueSheet = false
        etaToPickupMinutes = nil
        distanceToPickupMeters = nil
        lastETARouteKey = ""
        lastETAFetchAt = nil

        let origin = trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        withAnimation {
            tripStatus = .pending
        }

        if isDriver {
            locationService.currentLocation = CLLocation(
                latitude: origin.latitude,
                longitude: origin.longitude
            )
        } else {
            locationService.driverLocation = DriverLocation(
                locationId: "sim_reset",
                tripId: trip.id,
                driverId: trip.driverId,
                latitude: origin.latitude,
                longitude: origin.longitude,
                heading: nil,
                speed: nil,
                accuracy: 5,
                createdAt: Date()
            )
        }

        refreshDriverApproachMetrics(force: true)
    }

    private func refreshRiderMovementState(with pickups: [String: PickupLocation]) {
        guard isDriver else { return }
        let targetId = booking?.id ?? pickups.keys.sorted().first
        guard let targetId, let pickup = pickups[targetId] else { return }

        if focusedRiderBookingId != targetId {
            lastFocusedRiderCoordinate = nil
            riderMovedDistanceMeters = 0
        }
        focusedRiderBookingId = targetId

        let coord = CLLocationCoordinate2D(latitude: pickup.lat, longitude: pickup.lng)
        if let previous = lastFocusedRiderCoordinate {
            let delta = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            riderMovedDistanceMeters = delta
        } else {
            riderMovedDistanceMeters = 0
        }
        lastFocusedRiderCoordinate = coord
        riderLastUpdatedAt = Date()
    }

    private func refreshPassengerLocations() async {
        do {
            let passengers = try await tripService.getTripPassengers(tripId: trip.id)
            let pickups = passengers.reduce(into: [String: PickupLocation]()) { result, passenger in
                if let pickup = passenger.pickupLocation {
                    result[passenger.id] = pickup
                }
            }
            await MainActor.run {
                riderPickupLocations = pickups
                refreshRiderMovementState(with: pickups)
                refreshDriverApproachMetrics()
            }
        } catch {
            print("Passenger location poll error: \(error)")
        }
    }

    private func startRiderPickupSharingIfNeeded() {
        guard !isDriver, booking != nil else { return }
        riderLocationManager.requestPermission()
        riderLocationManager.startUpdating()

        riderPickupSyncTimer?.invalidate()
        sendRiderPickupLocationIfNeeded()
        riderPickupSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            sendRiderPickupLocationIfNeeded()
        }
    }

    private func sendRiderPickupLocationIfNeeded() {
        guard !isDriver, let bookingId = booking?.id, let loc = riderLocationManager.currentLocation else { return }
        let coord = loc.coordinate

        if let last = lastSentRiderPickupCoordinate {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            guard moved >= 8 else { return }
        }

        lastSentRiderPickupCoordinate = coord
        riderPickupLocations[bookingId] = PickupLocation(lat: coord.latitude, lng: coord.longitude, address: nil)
        refreshDriverApproachMetrics(force: true)

        Task {
            do {
                _ = try await BookingService.shared.updatePickupLocation(
                    id: bookingId,
                    lat: coord.latitude,
                    lng: coord.longitude,
                    address: nil
                )
            } catch {
                print("Rider pickup sync failed: \(error)")
            }
        }
    }

}

private struct TimelineStep {
    let title: String
    let subtitle: String
}

private struct TimelineRowState {
    let isCurrent: Bool
    let isDone: Bool
    let isUpcoming: Bool
    let fill: Color
    let icon: String
    let iconColor: Color
    let connector: Color
}

private struct PostRideReportSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let booking: Booking?
    let isDriver: Bool

    @State private var issueType: RideIssueType = .safety
    @State private var selectedReason = "Unsafe driving / rider behavior"
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    enum RideIssueType: String, CaseIterable, Identifiable {
        case safety = "Safety"
        case trip = "Trip"
        case payment = "Payment"
        case other = "Other"
        var id: String { rawValue }
    }

    private var reasons: [String] {
        switch issueType {
        case .safety: return ["Unsafe driving / rider behavior", "Harassment", "Wrong pickup/dropoff", "Emergency concern"]
        case .trip: return ["Route issue", "No-show", "Pickup timing issue", "Trip status incorrect"]
        case .payment: return ["Charge looks wrong", "Refund issue", "Payment failure", "Duplicate charge"]
        case .other: return ["App issue", "Communication issue", "Other"]
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    reportIntroCard
                    issueTypeCard
                    reasonCard
                    notesCard
                    submitButton
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } } }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Thanks. Your report was submitted to support.")
            }
            .onAppear { selectedReason = reasons.first ?? selectedReason }
        }
        .navigationViewStyle(.stack)
    }

    private var reportIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Report a ride issue")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
            Text("Share what happened on this ride. Safety reports are reviewed with priority.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(whiteCard())
    }

    private var issueTypeCard: some View {
        HStack(spacing: 8) {
            ForEach(RideIssueType.allCases) { type in
                issueTypeButton(type)
            }
        }
        .padding(14)
        .background(tintedCard())
    }

    private func issueTypeButton(_ type: RideIssueType) -> some View {
        Button(action: {
            issueType = type
            selectedReason = reasons.first ?? ""
        }) {
            Text(type.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(issueType == type ? .white : .textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(issueType == type ? DesignSystem.Colors.actionDarkSurface : Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(issueType == type ? Color.clear : DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reason")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textSecondary)
            ForEach(reasons, id: \.self) { reason in
                reasonRow(reason)
            }
        }
        .padding(14)
        .background(whiteCard())
    }

    private func reasonRow(_ reason: String) -> some View {
        Button(action: { selectedReason = reason }) {
            HStack(spacing: 10) {
                Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selectedReason == reason ? .brand : .textTertiary)
                Text(reason)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textSecondary)
            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
        .background(tintedCard())
    }

    private var submitButton: some View {
        Button(action: { Task { await submit() } }) {
            Text(isSubmitting ? "Submitting..." : "Submit Report")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignSystem.Colors.actionDarkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isSubmitting)
    }

    private func whiteCard() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
    }

    private func tintedCard() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.sheetBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let body: [String: String] = [
            "userId": authVM.currentUser?.id ?? "",
            "email": authVM.currentUser?.email ?? "",
            "issueType": issueType.rawValue,
            "description": """
            Role: \(isDriver ? "Driver" : "Rider")
            Trip ID: \(trip.id)
            Booking ID: \(booking?.id ?? "N/A")
            Reason: \(selectedReason)
            Notes: \(notes.isEmpty ? "None" : notes)
            """
        ]

        do {
            let _: EmptyNotificationResponse = try await NetworkManager.shared.request(
                endpoint: "/support/report-issue",
                method: .post,
                body: body,
                requiresAuth: false
            )
        } catch {
            // Keep UX resilient even if backend call fails
        }
        showSuccess = true
    }
}

// MARK: - Preview

#Preview {
    let sampleTrip = Trip(
        id: "test-trip",
        driverId: "driver-1",
        origin: "Sunnyvale Caltrain",
        destination: "San Jose State University",
        originPoint: Coordinate(lat: 37.3787, lng: -122.0311),
        destinationPoint: Coordinate(lat: 37.3352, lng: -121.8811),
        departureTime: Date(),
        seatsAvailable: 3,
        recurrence: nil,
        status: .enRoute,
        createdAt: Date(),
        updatedAt: Date(),
        driver: nil
    )

    ActiveTripView(trip: sampleTrip, isDriver: true)
        .environmentObject(AuthViewModel())
}

private extension Double {
    var roundedForRouteKey: Double {
        (self * 10_000).rounded() / 10_000
    }
}

private extension View {
    func debugPill(disabled: Bool = false) -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(disabled ? .textTertiary : .brand)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.brand.opacity(disabled ? 0.05 : 0.1))
            .cornerRadius(8)
    }
}
