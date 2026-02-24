import SwiftUI
import UIKit
import Combine

struct DriverHomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showCreateTrip = false
    @State private var showVerificationAlert = false
    @State private var showIDVerificationSheet = false
    @State private var recentBookings: [(booking: BookingWithRider, trip: Trip)] = []
    @State private var showTripDetails: Trip?
    @State private var showAccountMenu = false
    @State private var isPulsing = false
    @State private var showNotifications = false
    @State private var unreadNotificationCount = 0
    @State private var notificationChatDestination: DriverNotificationChatDestination?
    private let notificationBadgeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    dashboardHeader
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, 14)

                    // ── Hero Create Button ──
                    createTripCard
                        .padding(.horizontal, AppConstants.pagePadding)

                    // ── Stats Row ──
                    if let user = authVM.currentUser {
                        statsRow(user: user)
                            .padding(.horizontal, AppConstants.pagePadding)
                            .staggeredAppear(index: 0)
                    }

                    // ── Recent Activity ──
                    if !recentBookings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activity")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, AppConstants.pagePadding)

                            ForEach(recentBookings.prefix(5), id: \.booking.id) { item in
                                Button(action: {
                                    showTripDetails = item.trip
                                }) {
                                    RecentActivityCard(passenger: item.booking, trip: item.trip)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, AppConstants.pagePadding)
                            }
                        }
                    }

                    // ── Upcoming Trips ──
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Upcoming Trips", actionTitle: "See All") {}

                        if profileVM.isLoading {
                            ForEach(0..<2, id: \.self) { _ in
                                SkeletonTripCard().padding(.horizontal, AppConstants.pagePadding)
                            }
                        } else if profileVM.driverTrips.isEmpty {
                            EmptyStateView(
                                icon: "car.badge.plus",
                                title: "No trips yet",
                                message: "Create your first trip to start earning",
                                actionTitle: "Create Trip"
                            ) { showCreateTrip = true }
                        } else {
                            ForEach(Array(profileVM.driverTrips.enumerated()), id: \.element.id) { i, trip in
                                if [.enRoute, .arrived, .inProgress].contains(trip.status) {
                                    VStack(spacing: 8) {
                                        NavigationLink(destination: ActiveTripView(trip: trip, isDriver: true)) {
                                            CompactTripCard(trip: trip) {
                                                Task { await profileVM.cancelTrip(id: trip.id) }
                                            }
                                            .cornerRadius(20)
                                            .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                                        }
                                        .buttonStyle(.plain)

                                        Button(action: { showTripDetails = trip }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "list.bullet.rectangle")
                                                Text("View Trip Details")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.brand)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.brand.opacity(0.08))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)

                                        NavigationLink(destination: ActiveTripView(trip: trip, isDriver: true)) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "sparkles")
                                                Text("Simulate Ride")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.brand)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.brand.opacity(0.08))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, AppConstants.pagePadding)
                                    .staggeredAppear(index: i)
                                } else {
                                    VStack(spacing: 8) {
                                        Button(action: { showTripDetails = trip }) {
                                            CompactTripCard(trip: trip) {
                                                Task { await profileVM.cancelTrip(id: trip.id) }
                                            }
                                            .cornerRadius(20)
                                            .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                                        }
                                        .buttonStyle(.plain)

                                        NavigationLink(destination: ActiveTripView(trip: trip, isDriver: true)) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "sparkles")
                                                Text("Simulate Ride")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.brand)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.brand.opacity(0.08))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, AppConstants.pagePadding)
                                    .staggeredAppear(index: i)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 100)
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
                Task {
                    await refreshDashboardData()
                    await refreshNotificationBadge()
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView()
                    .onDisappear {
                        Task {
                            if let id = authVM.currentUser?.id {
                                await profileVM.loadDriverTrips(driverId: id)
                            }
                        }
                    }
            }
            .alert("Verification Required", isPresented: $showVerificationAlert) {
                Button("Verify Now") { showIDVerificationSheet = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please verify your SJSU ID before creating trips.")
            }
            .sheet(isPresented: $showIDVerificationSheet) {
                IDVerificationView().environmentObject(authVM)
                    .onDisappear { Task { await authVM.refreshCurrentUser() } }
            }
            .sheet(item: $showTripDetails) { trip in
                DriverTripDetailsView(trip: trip)
            }
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showNotifications) {
                DriverNotificationsSheet(
                    onRefresh: {
                        if let id = authVM.currentUser?.id {
                            Task {
                                await profileVM.loadDriverTrips(driverId: id)
                                await loadRecentBookings()
                                await refreshNotificationBadge()
                            }
                        }
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
            .onAppear {
                Task { await refreshNotificationBadge() }
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
        }
    }

    // MARK: - Load Recent Bookings
    private func refreshDashboardData() async {
        guard let id = authVM.currentUser?.id else { return }
        await profileVM.loadDriverTrips(driverId: id)
        await loadRecentBookings()
    }

    private func loadRecentBookings() async {
        var allBookings: [(booking: BookingWithRider, trip: Trip)] = []

        // Load bookings for each active trip
        for trip in profileVM.driverTrips.prefix(10) {
            do {
                let bookings = try await TripService.shared.getTripPassengers(tripId: trip.id)
                for booking in bookings {
                    allBookings.append((booking: booking, trip: trip))
                }
            } catch {
                print("Failed to load bookings for trip \(trip.id): \(error)")
            }
        }

        // Sort by creation date (most recent first) and take top 5
        recentBookings = allBookings
            .sorted { $0.booking.createdAt > $1.booking.createdAt }
            .prefix(5)
            .map { $0 }
    }

    private func refreshNotificationBadge() async {
        guard let userId = authVM.currentUser?.id else {
            unreadNotificationCount = 0
            return
        }
        do {
            let response = try await NotificationService.shared.listNotifications(userId: userId, limit: 1)
            unreadNotificationCount = response.unreadCount
        } catch {
            print("Failed to load driver notification badge: \(error)")
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Driver Dashboard")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Manage your trips, riders, and earnings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
            Spacer()
            Button(action: { showNotifications = true }) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
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
                        .fill(Color.white.opacity(0.08))
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

    // MARK: - Create Trip Card
    private var createTripCard: some View {
        Button(action: {
            if authVM.currentUser?.sjsuIdStatus == .verified {
                showCreateTrip = true
            } else {
                showVerificationAlert = true
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    // Pulsing outer ring
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 68, height: 68)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                isPulsing = true
                            }
                        }

                    // Inner circle + icon
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 56, height: 56)
                    Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create New Trip").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    Text("Pick up SJSU commuters").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.78))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "0F172A"), Color(hex: "111827")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .scaleEffect(1)
    }

    // MARK: - Stats Row
    private func statsRow(user: User) -> some View {
        HStack(spacing: 0) {
            DriverStatCard(icon: "star.fill", value: String(format: "%.1f", user.rating),
                           label: "Rating", color: .brandOrange)
            Divider().frame(height: 44)
            DriverStatCard(icon: "person.2.fill",
                           value: "\(profileVM.driverTrips.count)",
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
}

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
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
                        .background(Color(hex: "F8FAFC"))
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
                            .background(Color(hex: "0F172A"))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "F4F6F2").ignoresSafeArea())
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
                .fill(item.isUnread ? Color.white : Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
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
        case "chat_message": return "message.fill"
        case "booking_confirmed": return "person.2.fill"
        case "booking_cancelled": return "xmark.seal.fill"
        case "trip_status": return "location.fill"
        default: return "bell.fill"
        }
    }

    private func iconColor(for item: AppNotificationItem) -> Color {
        switch item.type {
        case "chat_message": return .brand
        case "booking_confirmed": return .brandGreen
        case "booking_cancelled": return .brandRed
        case "trip_status": return .brandOrange
        default: return .brand
        }
    }
}

private struct DriverNotificationChatDestination: Identifiable {
    let tripId: String
    let otherPartyName: String
    var id: String { tripId }
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

// MARK: - Section Header
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
