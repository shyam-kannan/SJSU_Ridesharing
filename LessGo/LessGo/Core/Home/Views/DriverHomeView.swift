import SwiftUI

struct DriverHomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showCreateTrip = false
    @State private var showVerificationAlert = false
    @State private var showIDVerificationSheet = false
    @State private var recentBookings: [(booking: BookingWithRider, trip: Trip)] = []
    @State private var showTripDetails: Trip?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Hero Create Button ──
                    createTripCard
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, 16)

                    // ── Stats Row ──
                    if let user = authVM.currentUser {
                        statsRow(user: user)
                            .padding(.horizontal, AppConstants.pagePadding)
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
                            ForEach(profileVM.driverTrips) { trip in
                                CompactTripCard(trip: trip) {
                                    Task { await profileVM.cancelTrip(id: trip.id) }
                                }
                                .padding(.horizontal, AppConstants.pagePadding)
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { navTitle } }
            .refreshable {
                if let id = authVM.currentUser?.id {
                    await profileVM.loadDriverTrips(driverId: id)
                    await loadRecentBookings()
                }
            }
            .task {
                if let id = authVM.currentUser?.id {
                    await profileVM.loadDriverTrips(driverId: id)
                    await loadRecentBookings()
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
        }
    }

    // MARK: - Load Recent Bookings
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

    // MARK: - Nav Title
    private var navTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "car.2.fill").foregroundColor(.brand)
            Text("Driver Dashboard").font(.system(size: 17, weight: .bold))
        }
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
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 56, height: 56)
                    Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create New Trip").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Text("Pick up SJSU commuters").font(.system(size: 14)).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .background(Color.brandGradient)
            .cornerRadius(20)
            .shadow(color: Color.brand.opacity(0.35), radius: 14, x: 0, y: 7)
        }
        .scaleEffect(1)
    }

    // MARK: - Stats Row
    private func statsRow(user: User) -> some View {
        HStack(spacing: 12) {
            DriverStatCard(icon: "star.fill", value: String(format: "%.1f", user.rating),
                           label: "Rating", color: .brandOrange)
            DriverStatCard(icon: "person.2.fill",
                           value: "\(profileVM.driverTrips.count)",
                           label: "Active Trips", color: .brand)
            DriverStatCard(icon: "car.fill",
                           value: "\(user.seatsAvailable ?? 0)",
                           label: "Seats", color: .brandGreen)
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
        .background(Color.cardBackground)
        .cornerRadius(AppConstants.cardRadius)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
