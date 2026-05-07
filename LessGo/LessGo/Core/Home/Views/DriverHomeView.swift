import SwiftUI
import UIKit
import Combine

struct DriverHomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()

    // ── Incoming Requests ──────────────────────────────────────────────────────
    @State private var incomingRequest: IncomingMatchPayload? = nil
    @State private var showIncomingRequest = false
    @State private var isOnlinePulsing = false

    // ── Accepted trip navigation ───────────────────────────────────────────────
    @State private var acceptedActiveTrip: Trip? = nil
    @State private var showAcceptedTripNav = false

    // ── Posted rides navigation ────────────────────────────────────────────────
    @State private var showCreateTrip = false
    @State private var selectedTripForDetail: Trip? = nil
    @State private var selectedDriverTab: Int = 0

    // ── Notifications ──────────────────────────────────────────────────────────
    @State private var showAccountMenu = false
    @State private var showNotifications = false
    @State private var unreadNotificationCount = 0
    @State private var notificationChatDestination: DriverNotificationChatDestination?

    // ── Today stats ────────────────────────────────────────────────────────────
    @State private var todayTripCount = 0
    @AppStorage("hasCompletedFirstTrip") private var hasCompletedFirstTrip = false

    // ── Delete cancelled trip ──────────────────────────────────────────────────
    @State private var tripPendingDelete: Trip? = nil
    @State private var showDeleteTripConfirm = false

    // ── Timers ─────────────────────────────────────────────────────────────────
    private let notificationBadgeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let matchPollingTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // ── Computed helpers ───────────────────────────────────────────────────────

    private var activeDriverTrips: [Trip] {
        profileVM.driverTrips.filter {
            [TripStatus.enRoute, .arrived, .inProgress].contains($0.status)
        }
    }

    private var currentActiveTrip: Trip? { activeDriverTrips.first }

    private var todayCompletedTrips: [Trip] {
        profileVM.driverTrips.filter {
            $0.status == .completed &&
            Calendar.current.isDateInToday($0.departureTime)
        }
    }

    // ── Body ───────────────────────────────────────────────────────────────────

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    dashboardHeader
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, 14)

                    // Post a Ride button
                    postRideButton
                        .padding(.horizontal, AppConstants.pagePadding)

                    postedRidesSection
                        .padding(.horizontal, AppConstants.pagePadding)

                    if let user = authVM.currentUser {
                        statsRow(user: user)
                            .padding(.horizontal, AppConstants.pagePadding)
                            .staggeredAppear(index: 0)
                    }

                    if !hasCompletedFirstTrip {
                        howItWorksSection
                            .padding(.horizontal, AppConstants.pagePadding)
                    }

                    earningsTodayCard
                        .padding(.horizontal, AppConstants.pagePadding)

                    // Extra space so tab bar (and optional active-ride banner) never
                    // obscure the last card. 160 pt clears both.
                    Spacer().frame(height: 160)
                }
            }
            .background(
                ZStack {
                    Color.canvasGradient.ignoresSafeArea()
                    LinearGradient(
                        colors: [Color.brand.opacity(0.10), .clear, Color.brandTeal.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .refreshable {
                await refreshDashboardData()
            }
            .task {
                await refreshDashboardData()
            }
            .onAppear {
                Task { await refreshDashboardData() }
            }
            .onChange(of: authVM.currentUser?.id) { _ in
                Task { await refreshDashboardData() }
            }
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showNotifications) {
                DriverNotificationsSheet(
                    onRefresh: {
                        Task { await refreshDashboardData() }
                    },
                    onOpenNotification: { item in
                        guard item.type == "chat_message", let tripId = item.data?.tripId else { return }
                        let senderName = item.title
                            .replacingOccurrences(of: "New message from ", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        notificationChatDestination = DriverNotificationChatDestination(
                            tripId: tripId,
                            otherPartyName: senderName.isEmpty ? "Rider" : senderName
                        )
                    }
                )
            }
            .sheet(item: $notificationChatDestination) { destination in
                ChatView(
                    tripId: destination.tripId,
                    otherPartyName: destination.otherPartyName,
                    isDriver: true,
                    includesTabBarClearance: false
                )
                .environmentObject(authVM)
            }
            .onChange(of: showNotifications) { isPresented in
                if !isPresented { Task { await refreshNotificationBadge() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await refreshNotificationBadge() }
            }
            .onReceive(notificationBadgeTimer) { _ in
                Task { await refreshNotificationBadge() }
            }
            .onReceive(matchPollingTimer) { _ in
                guard !showIncomingRequest,
                      let driverId = authVM.currentUser?.id else { return }
                Task {
                    if let payload = await MatchingService.shared.checkForIncomingRequest(driverId: driverId) {
                        incomingRequest = payload
                        showIncomingRequest = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showIncomingRequest) {
                if let request = incomingRequest {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .onTapGesture {}
                        IncomingRideRequestView(
                            payload: request,
                            onAccept: {
                                showIncomingRequest = false
                                Task {
                                    try? await TripService.shared.acceptMatch(
                                        tripId: request.tripId,
                                        matchId: request.matchId
                                    )
                                    if let trip = try? await TripService.shared.getTrip(id: request.tripId) {
                                        await MainActor.run {
                                            acceptedActiveTrip = trip
                                            showAcceptedTripNav = true
                                        }
                                    }
                                }
                            },
                            onDecline: {
                                showIncomingRequest = false
                                Task {
                                    try? await TripService.shared.declineMatch(
                                        tripId: request.tripId,
                                        matchId: request.matchId
                                    )
                                }
                            }
                        )
                    }
                }
            }
            .fullScreenCover(isPresented: $showAcceptedTripNav) {
                if let trip = acceptedActiveTrip {
                    NavigationView {
                        ActiveTripView(trip: trip, isDriver: true)
                            .environmentObject(authVM)
                    }
                }
            }
            // ── Active Ride Banner ─────────────────────────────────────────────
            .overlay(alignment: .bottom) {
                if let trip = currentActiveTrip {
                    activeRideBanner(trip: trip)
                }
            }
            // ── Navigation Modifiers ─────────────────────────────────────────────
            .fullScreenCover(isPresented: $showCreateTrip, onDismiss: {
                Task { await refreshDashboardData() }
            }) {
                CreateTripView()
            }
            .sheet(item: $selectedTripForDetail) { trip in
                DriverTripDetailsView(trip: trip)
                    .environmentObject(authVM)
            }
        }
    }

    // MARK: - Active Ride Banner

    private func activeRideBanner(trip: Trip) -> some View {
        Button(action: {
            acceptedActiveTrip = trip
            showAcceptedTripNav = true
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "car.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Ride")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("To \(trip.destination)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Open")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.brand, Color.brand.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.brand.opacity(0.45), radius: 14, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 90) // clears the custom tab bar (~88 pt incl. safe area)
    }

    // MARK: - How It Works Section

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 0) {
                howItWorksRow(
                    icon: "bell.badge",
                    title: "Wait for a ride request",
                    subtitle: "We'll notify you instantly when a rider is matched to you"
                )
                Divider()
                    .padding(.leading, 74)
                howItWorksRow(
                    icon: "car.fill",
                    title: "Accept and pick up",
                    subtitle: "Accept the request and navigate to your passenger"
                )
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }

    private func howItWorksRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.brand)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Earnings Today Card

    private var earningsTodayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earnings Today")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(todayTripCount == 0 ? "–" : "\(todayTripCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(todayTripCount == 0 ? .textSecondary : .textPrimary)
                    Text(todayTripCount == 1 ? "trip" : "trips")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44)

                VStack(spacing: 6) {
                    Text(todayTripCount == 0
                         ? "$0.00"
                         : String(format: "$%.2f", Double(todayTripCount) * 5.0))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(todayTripCount == 0 ? .textSecondary : .brandGreen)
                    Text("estimated")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 4)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - Data Loading

    private func refreshDashboardData() async {
        guard let id = authVM.currentUser?.id else { return }
        await profileVM.loadDriverTrips(driverId: id)
        await refreshNotificationBadge()

        todayTripCount = todayCompletedTrips.count

        // Once the driver has completed any trip, permanently dismiss the onboarding section.
        if !hasCompletedFirstTrip &&
           !profileVM.driverTrips.filter({ $0.status == .completed }).isEmpty {
            hasCompletedFirstTrip = true
        }
    }

    private func refreshNotificationBadge() async {
        guard let userId = authVM.currentUser?.id else {
            unreadNotificationCount = 0
            return
        }
        do {
            let response = try await NotificationService.shared.listNotifications(userId: userId, limit: 1)
            unreadNotificationCount = response.unreadCount
        } catch is CancellationError {
            // Benign: view/task lifecycle cancelled the in-flight request.
            return
        } catch let error as NetworkError {
            if case .unknown(let underlying) = error,
               let urlError = underlying as? URLError,
               urlError.code == .cancelled {
                // Benign URLSession cancellation (-999); avoid noisy logs.
                return
            }
            print("Failed to load driver notification badge: \(error)")
        } catch {
            print("Failed to load driver notification badge: \(error)")
        }
    }

    // MARK: - Dashboard Header

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Driver Dashboard")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                if isOnlinePulsing {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.brandGreen.opacity(0.35))
                                .frame(width: 16, height: 16)
                                .scaleEffect(isOnlinePulsing ? 1.6 : 1.0)
                                .opacity(isOnlinePulsing ? 0 : 1)
                                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isOnlinePulsing)
                            Circle()
                                .fill(Color.brandGreen)
                                .frame(width: 8, height: 8)
                        }
                        .onAppear { isOnlinePulsing = true }
                        .onDisappear { isOnlinePulsing = false }
                        Text("Online — accepting rides")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.brandGreen)
                    }
                } else {
                    Text("Toggle availability to receive ride requests")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            Spacer()
            Button(action: { showNotifications = true }) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignSystem.Colors.onDark.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay {
                        Image(systemName: "bell")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .overlay(alignment: .topTrailing) {
                        if unreadNotificationCount > 0 {
                            Circle()
                                .fill(Color.brandRed)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1))
                                .offset(x: -3, y: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            Button(action: { showAccountMenu = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.Colors.onDark.opacity(0.08))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    // MARK: - Stats Row

    private func statsRow(user: User) -> some View {
        HStack(spacing: 0) {
            DriverStatCard(icon: "star.fill", value: String(format: "%.1f", Double(user.rating)),
                           label: "Rating", color: .brandOrange)
            Divider().frame(height: 44)
            DriverStatCard(icon: "person.2.fill",
                           value: "\(activeDriverTrips.count)",
                           label: "Active Trips", color: .brand)
            Divider().frame(height: 44)
            DriverStatCard(icon: "car.fill",
                           value: "\(user.seatsAvailable ?? 0)",
                           label: "Seats", color: .brandGreen)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .luxuryCard(cornerRadius: 22)
    }

    // MARK: - Your Posted Rides Section

    private var scheduledTrips: [Trip] {
        profileVM.driverTrips.filter { $0.status == .pending }
    }

    private var cancelledTrips: [Trip] {
        profileVM.driverTrips.filter { $0.status == .cancelled }
    }

    private var completedTrips: [Trip] {
        profileVM.driverTrips.filter { $0.status == .completed }
    }

    private var tripsWithPassengers: [Trip] {
        scheduledTrips.filter { trip in
            guard let maxRiders = trip.maxRiders else { return false }
            return trip.seatsAvailable < maxRiders
        }
    }

    private var postedRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Posted Rides")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            Picker("", selection: $selectedDriverTab) {
                Text("Passengers").tag(0)
                Text("Posted Trips").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedDriverTab == 0 {
                passengersTabContent
            } else {
                postedTripsTabContent
            }
        }
        .confirmationDialog("Remove this trip?", isPresented: $showDeleteTripConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                guard let trip = tripPendingDelete else { return }
                Task {
                    try? await TripService.shared.deleteTrip(tripId: trip.id)
                    tripPendingDelete = nil
                    await refreshDashboardData()
                }
            }
            Button("Cancel", role: .cancel) { tripPendingDelete = nil }
        } message: {
            Text("This will permanently remove the trip from your history.")
        }
    }

    private var passengersTabContent: some View {
        Group {
            if tripsWithPassengers.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 24))
                        .foregroundColor(Color.brand.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No confirmed passengers yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Passengers appear here once you approve their requests")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardBackground)
                )
            } else {
                ForEach(tripsWithPassengers) { trip in
                    Button(action: { selectedTripForDetail = trip }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(trip.origin) → \(trip.destination)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(trip.departureTime, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let maxRiders = trip.maxRiders {
                                let confirmedCount = maxRiders - trip.seatsAvailable
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 11))
                                    Text("\(confirmedCount)")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brandGreen)
                                .clipShape(Capsule())
                            }
                            if let count = trip.pendingBookingCount, count > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                    Text("\(count) pending")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var postedTripsTabContent: some View {
        Group {
            if scheduledTrips.isEmpty && cancelledTrips.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "car.rear.road.lane.dashed")
                        .font(.system(size: 24))
                        .foregroundColor(Color.brand.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No posted rides yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Tap 'Post a Ride' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardBackground)
                )
            } else {
                ForEach(scheduledTrips) { trip in
                    Button(action: { selectedTripForDetail = trip }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(trip.origin) → \(trip.destination)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(trip.departureTime, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                + Text(" · \(trip.seatsAvailable) seat\(trip.seatsAvailable == 1 ? "" : "s") left")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !cancelledTrips.isEmpty {
                    Text("Cancelled Trips")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    ForEach(cancelledTrips) { trip in
                        archivedTripRow(trip: trip, label: "Cancelled", labelColor: .red)
                    }
                }

                if !completedTrips.isEmpty {
                    Text("Completed Trips")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    ForEach(completedTrips) { trip in
                        archivedTripRow(trip: trip, label: "Completed", labelColor: .brandGreen)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func archivedTripRow(trip: Trip, label: String, labelColor: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(trip.origin) → \(trip.destination)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(trip.departureTime, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(labelColor.opacity(0.10))
                .clipShape(Capsule())
            Button(action: {
                tripPendingDelete = trip
                showDeleteTripConfirm = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground)
        )
    }

    // MARK: - Post Ride Button

    private var postRideButton: some View {
        Button(action: { showCreateTrip = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Post a Ride")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Create a scheduled trip for riders to book")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.brand, Color.brand.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.brand.opacity(0.35), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Driver Notifications Sheet

private struct DriverNotificationsSheet: View {
    let onRefresh: () -> Void
    let onOpenNotification: (AppNotificationItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotificationItem] = []
    @State private var unreadCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Driver Notifications")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Trip requests, rider messages, and trip status updates.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                        )
                )

                if let errorMessage {
                    ToastBanner(message: errorMessage, type: .error)
                }

                if isLoading {
                    ProgressView().padding(.top, 20)
                    Spacer()
                } else if notifications.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 28))
                            .foregroundColor(.textTertiary)
                        Text("No driver notifications yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Booking requests, chat messages, and trip updates will appear here.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            if unreadCount > 0 {
                                HStack {
                                    Text("\(unreadCount) unread")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                    Button("Mark all read") {
                                        Task { await markAllRead() }
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.brand)
                                }
                                .padding(.horizontal, 2)
                            }

                            ForEach(notifications) { item in
                                Button(action: {
                                    if item.isUnread {
                                        Task { await markRead(item) }
                                    }
                                    if item.type == "chat_message" && item.data?.tripId != nil {
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                            onOpenNotification(item)
                                        }
                                    }
                                }) {
                                    driverNotificationRow(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.sheetBackground)
                        .cornerRadius(12)

                    Button(action: {
                        onRefresh()
                        dismiss()
                    }) {
                        Text("Refresh Dashboard")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.actionDarkSurface)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await loadNotifications() }
        }
        .navigationViewStyle(.stack)
    }

    private func driverNotificationRow(_ item: AppNotificationItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor(for: item).opacity(0.10)).frame(width: 34, height: 34)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor(for: item))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary)
                Text(item.message)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.createdAt.timeAgo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            Spacer()
            if item.isUnread {
                Circle().fill(Color.brandRed).frame(width: 7, height: 7)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.isUnread ? Color.cardBackground : Color.sheetBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
    }

    private func loadNotifications() async {
        guard let userId = KeychainManager.shared.getUserId() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await NotificationService.shared.listNotifications(userId: userId, limit: 50)
            notifications = response.notifications
            unreadCount = response.unreadCount
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to load notifications"
        }
    }

    private func markAllRead() async {
        guard let userId = KeychainManager.shared.getUserId() else { return }
        do {
            try await NotificationService.shared.markAllRead(userId: userId)
            await loadNotifications()
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to mark notifications read"
        }
    }

    private func markRead(_ item: AppNotificationItem) async {
        guard let userId = KeychainManager.shared.getUserId() else { return }
        do {
            try await NotificationService.shared.markRead(userId: userId, notificationId: item.id)
            if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
                notifications[idx] = AppNotificationItem(
                    id: notifications[idx].id,
                    userId: notifications[idx].userId,
                    type: notifications[idx].type,
                    title: notifications[idx].title,
                    message: notifications[idx].message,
                    data: notifications[idx].data,
                    createdAt: notifications[idx].createdAt,
                    readAt: Date()
                )
                unreadCount = max(0, unreadCount - 1)
            } else {
                await loadNotifications()
            }
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to mark notification read"
        }
    }

    private func iconName(for item: AppNotificationItem) -> String {
        switch item.type {
        case "chat_message":       return "message.fill"
        case "booking_confirmed":  return "person.2.fill"
        case "booking_cancelled":  return "xmark.seal.fill"
        case "trip_status":        return "location.fill"
        default:                   return "bell.fill"
        }
    }

    private func iconColor(for item: AppNotificationItem) -> Color {
        switch item.type {
        case "chat_message":       return .brand
        case "booking_confirmed":  return .brandGreen
        case "booking_cancelled":  return .brandRed
        case "trip_status":        return .brandOrange
        default:                   return .brand
        }
    }
}

// MARK: - Driver Stat Card

private struct DriverStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.textPrimary)
            Text(label).font(.system(size: 11)).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Section Header (shared across driver views)

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.textPrimary)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle).font(.system(size: 14, weight: .semibold)).foregroundColor(.brand)
                }
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }
}
