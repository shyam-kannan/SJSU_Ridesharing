import SwiftUI
import UIKit
import MapKit
import Combine

struct RiderHomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var viewModel = TripSearchViewModel()
    @StateObject private var locationManager = LocationManager.shared

    @State private var searchText = ""
    @State private var showViewToggle = false
    @State private var region = MKCoordinateRegion(
        center: AppConstants.sjsuCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selectedTrip: Trip?
    @State private var showVerificationAlert = false
    @State private var showIDVerificationSheet = false
    @State private var showAccountMenu = false
    @State private var showNotifications = false
    @State private var unreadNotificationCount = 0
    @State private var notificationChatDestination: NotificationChatDestination?
    private let notificationBadgeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    // Bottom sheet state
    @State private var isSheetExpanded = false
    @GestureState private var sheetDragTranslation: CGFloat = 0
    private let collapsedSheetPeek: CGFloat = 260

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {

                // 1. Map — always full-screen background
                mapBackground
                    .ignoresSafeArea()

                // 2. Floating trip preview card (above bottom sheet peek)
                if selectedTrip != nil {
                    mapOverlays
                }

                // 3. Floating search header over map
                VStack {
                    searchHeader
                        .padding(.top, VerifyBannerView.windowTopInset)
                    Spacer()
                }

                // 4. Bottom sheet — always visible, draggable
                bottomSheet
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .alert("Verification Required", isPresented: $showVerificationAlert) {
                Button("Verify Now") { showIDVerificationSheet = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please verify your SJSU ID before viewing trip details and booking rides.")
            }
            .sheet(isPresented: $showIDVerificationSheet) {
                IDVerificationView().environmentObject(authVM)
            }
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showNotifications) {
                RiderNotificationsSheet(
                    onRefresh: {
                    Task { await viewModel.refresh() }
                    },
                    onOpenNotification: { item in
                        guard item.type == "chat_message", let tripId = item.data?.tripId else { return }
                        let senderName = item.title
                            .replacingOccurrences(of: "New message from ", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        notificationChatDestination = NotificationChatDestination(
                            tripId: tripId,
                            otherPartyName: senderName.isEmpty ? "Driver" : senderName,
                            isDriver: false
                        )
                    }
                )
            }
            .sheet(item: $notificationChatDestination) { destination in
                ChatView(
                    tripId: destination.tripId,
                    otherPartyName: destination.otherPartyName,
                    isDriver: destination.isDriver,
                    includesTabBarClearance: false
                )
                .environmentObject(authVM)
            }
        }
        .navigationViewStyle(.stack)
        .task {
            viewModel.currentUserId = authVM.currentUser?.id
            await viewModel.searchNearby()
            await refreshNotificationBadge()
        }
        .onChange(of: authVM.currentUser?.id) { newUserId in
            viewModel.currentUserId = newUserId
            Task {
                await viewModel.refresh()
                await refreshNotificationBadge()
            }
        }
        .onAppear { Task { await refreshNotificationBadge() } }
        .onChange(of: showNotifications) { isPresented in
            if !isPresented { Task { await refreshNotificationBadge() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationBadge() }
        }
        .onReceive(notificationBadgeTimer) { _ in
            Task { await refreshNotificationBadge() }
        }
        .onChange(of: locationManager.currentLocation) { _ in
            if selectedTrip == nil, let coord = locationManager.currentLocation?.coordinate {
                withAnimation { region.center = coord }
            }
        }
        .onChange(of: selectedTrip?.id) { _ in
            guard let trip = selectedTrip else { return }
            let coord = pinCoordinate(for: trip)
            withAnimation(.easeInOut(duration: 0.3)) {
                region.center = coord
            }
        }
    }

    // MARK: - Map Background

    // Pin coordinate: "To SJSU" → rider is picked up at origin (Bay Area hub).
    //                 "From SJSU" → rider is dropped at destination (Bay Area hub).
    private func pinCoordinate(for trip: Trip) -> CLLocationCoordinate2D {
        switch viewModel.searchDirection {
        case .toSJSU:
            return trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        case .fromSJSU:
            return trip.destinationPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        }
    }

    private var mapBackground: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: viewModel.filteredTrips) { trip in
            MapAnnotation(coordinate: pinCoordinate(for: trip)) {
                TripMapMarker(trip: trip, isSelected: selectedTrip?.id == trip.id) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTrip = (selectedTrip?.id == trip.id) ? nil : trip
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 10) {
            // Verify Banner (in-flow above greeting so it pushes content down)
            if let user = authVM.currentUser, user.sjsuIdStatus != .verified {
                VerifyBannerView(status: user.sjsuIdStatus) {
                    showIDVerificationSheet = true
                }
            }

            headerTopBar

            // Variable location search bar + autocomplete
            locationSearchSection
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .cornerRadius(22, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
    }

    private var headerTopBar: some View {
        HStack(spacing: 10) {
            headerIconButton(systemName: "line.3.horizontal") {
                showAccountMenu = true
            }

            VStack(spacing: 1) {
                Text("Find a Ride")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Good \(greeting), \(authVM.currentUser?.name.components(separatedBy: " ").first ?? "there")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            headerBellButton
        }
        .padding(.horizontal, AppConstants.pagePadding)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var sheetTopControls: some View {
        VStack(spacing: 8) {
            mapListModeToggle
            directionToggle
            sjsuFixedPill
                .padding(.horizontal, AppConstants.pagePadding)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var headerBellButton: some View {
        Button(action: { showNotifications = true }) {
            iconButtonShell(systemName: "bell")
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
    }

    private var mapListModeToggle: some View {
        HStack(spacing: 8) {
            mapListButton(title: "Map View", icon: "map", isActive: !isSheetExpanded) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isSheetExpanded = false
                }
            }
            mapListButton(title: "List View", icon: "list.bullet", isActive: isSheetExpanded) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isSheetExpanded = true
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, AppConstants.pagePadding)
    }

    private var locationSearchSection: some View {
        VStack(spacing: 0) {
            locationSearchInput

            if viewModel.showSuggestions && !viewModel.locationSuggestions.isEmpty {
                suggestionsDropdown
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }

    private var locationSearchInput: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.searchDirection == .toSJSU ? "location.fill" : "mappin.and.ellipse")
                .foregroundColor(Color(hex: "84CC16"))
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22)

            TextField(viewModel.searchDirection.searchPlaceholder, text: $viewModel.searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .autocapitalization(.none)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.searchUsingTypedAddressIfPossible() } }
                .onTapGesture {
                    if !viewModel.searchText.isEmpty {
                        viewModel.showSuggestions = true
                    }
                }

            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                    viewModel.showSuggestions = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        )
        .cornerRadius(14, corners: viewModel.showSuggestions ? [.topLeft, .topRight] : .allCorners)
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.locationSuggestions.prefix(8), id: \.self) { suggestion in
                suggestionRow(suggestion)

                if suggestion != viewModel.locationSuggestions.prefix(8).last {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color.panelGradient)
        .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private func suggestionRow(_ suggestion: MKLocalSearchCompletion) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.selectSuggestion(suggestion)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .font(.system(size: 13))
                    .foregroundColor(.brand)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func headerIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            iconButtonShell(systemName: systemName)
        }
        .buttonStyle(.plain)
    }

    private func iconButtonShell(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 42, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func mapListButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isActive ? .white : Color(hex: "475569"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isActive ? AnyShapeStyle(Color(hex: "111827")) : AnyShapeStyle(Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Direction Toggle (segmented control)

    private var directionToggle: some View {
        HStack(spacing: 0) {
            ForEach([TripSearchViewModel.TravelDirection.toSJSU, .fromSJSU], id: \.self) { direction in
                let isSelected = viewModel.searchDirection == direction
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.searchDirection = direction
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: direction == .toSJSU ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                            .font(.system(size: 12))
                        Text(direction == .toSJSU ? "To SJSU" : "From SJSU")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? .white : Color(hex: "475569"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected ? Color(hex: "111827") : Color.clear)
                    )
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .cornerRadius(14)
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Fixed SJSU pill

    private var sjsuFixedPill: some View {
        let isToSJSU = viewModel.searchDirection == .toSJSU
        let pillColor: Color = isToSJSU ? Color(hex: "84CC16") : Color(hex: "111827")
        let icon = isToSJSU ? "mappin.circle.fill" : "building.columns.fill"
        let roleText = isToSJSU ? "Fixed destination" : "Fixed pickup"

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(pillColor)
            Text("San Jose State University")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
            Spacer()
            Text(roleText)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "64748B"))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "F8FAFC"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.searchDirection)
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.itemSpacing) {
                // Time/filter strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        rideFilterPill(title: "Nearby", isSelected: true)
                        rideFilterPill(title: "Today")
                        rideFilterPill(title: "Tomorrow")
                        rideFilterPill(title: "This Week")
                    }
                    .padding(.horizontal, AppConstants.pagePadding)
                }
                    .padding(.top, 10)
                    .padding(.bottom, 2)

                if viewModel.isLoading {
                    SkeletonTripList()
                        .padding(.top, 8)
                } else if viewModel.filteredTrips.isEmpty {
                    EmptyStateView(
                        icon: "car.2",
                        title: "No trips nearby",
                        message: "Check back later or expand your search radius",
                        actionTitle: "Refresh"
                    ) { Task { await viewModel.refresh() } }
                    .padding(.top, 60)
                } else {
                    ForEach(viewModel.filteredTrips) { trip in
                        // Verified users: navigate straight to trip details.
                        // Unverified users: show alert with "Verify Now" option.
                        if authVM.currentUser?.sjsuIdStatus == .verified {
                            NavigationLink(destination: TripDetailsView(trip: trip).environmentObject(authVM)) {
                                TripCardView(trip: trip)
                                    .padding(.horizontal, AppConstants.pagePadding)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { showVerificationAlert = true }) {
                                TripCardView(trip: trip)
                                    .padding(.horizontal, AppConstants.pagePadding)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 100) // tab bar clearance
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Map Overlays

    private var mapOverlays: some View {
        VStack {
            Spacer()
            if let trip = selectedTrip, !isSheetExpanded {
                TripPreviewCard(trip: trip) {
                    selectedTrip = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.bottom, collapsedSheetPeek + 10)
            }
        }
    }

    // MARK: - Bottom Sheet

    private var bottomSheet: some View {
        GeometryReader { geo in
            let collapsedOffset = geo.size.height - collapsedSheetPeek
            let expandedOffset: CGFloat = geo.size.height * 0.12
            let targetOffset = isSheetExpanded ? expandedOffset : collapsedOffset
            let currentOffset = max(expandedOffset, min(collapsedOffset, targetOffset + sheetDragTranslation))

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.08), Color.black.opacity(0.16)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                sheetTopControls

                // Collapsed header row: summary label + count badge
                if !isSheetExpanded {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available Rides")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "111827"))
                            Text("Nearby campus carpools")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                        Spacer()
                        Text(viewModel.searchDirection == .toSJSU ? "To SJSU" : "From SJSU")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "0F172A"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "EAF7C7"))
                            .cornerRadius(999)
                        Text("\(viewModel.filteredTrips.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Color(hex: "0B63C7"))
                            .cornerRadius(999)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }

                // Full list content
                listContent
            }
            .frame(maxWidth: .infinity)
            .frame(height: geo.size.height - expandedOffset + 40)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.bottomSheetCornerRadius, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.bottomSheetCornerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(
                        color: DesignSystem.Shadow.sheet.color,
                        radius: DesignSystem.Shadow.sheet.radius,
                        x: 0, y: DesignSystem.Shadow.sheet.y
                    )
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: currentOffset)
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .updating($sheetDragTranslation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        withAnimation(DesignSystem.Animation.sheetSnap) {
                            if value.translation.height < -60 {
                                isSheetExpanded = true
                            } else if value.translation.height > 60 {
                                isSheetExpanded = false
                            }
                        }
                    }
            )
            .animation(DesignSystem.Animation.sheetSnap, value: isSheetExpanded)
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "morning" }
        if h < 17 { return "afternoon" }
        return "evening"
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
            // Non-critical UI badge fetch
            print("Failed to load notification badge: \(error)")
        }
    }

    private func rideFilterPill(title: String, isSelected: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isSelected ? .white : Color(hex: "475569"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "0F172A") : Color(hex: "F8FAFC"))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.black.opacity(isSelected ? 0 : 0.07), lineWidth: 1)
            )
    }
}

private struct RiderNotificationsSheet: View {
    let onRefresh: () -> Void
    let onOpenNotification: (AppNotificationItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotificationItem] = []
    @State private var unreadCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Trip updates and booking alerts will appear here.")
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
                        Text("No notifications yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Booking, chat, and trip updates will appear here.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
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
                                    notificationRow(item)
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
                        Text("Refresh Rides")
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

    private func notificationRow(_ item: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor(for: item).opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor(for: item))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
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
                    .padding(.top, 6)
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
        case "booking_confirmed": return "checkmark.seal.fill"
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

private struct NotificationChatDestination: Identifiable {
    let tripId: String
    let otherPartyName: String
    let isDriver: Bool
    var id: String { "\(tripId)-\(isDriver ? "driver" : "rider")" }
}

// MARK: - Map Marker

struct TripMapMarker: View {
    let trip: Trip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.brandGreen : Color.brand)
                    .frame(width: isSelected ? 48 : 38, height: isSelected ? 48 : 38)
                    .shadow(color: (isSelected ? Color.brandGreen : Color.brand).opacity(0.5),
                            radius: isSelected ? 12 : 6, x: 0, y: 4)

                VStack(spacing: 0) {
                    Image(systemName: "car.fill")
                        .font(.system(size: isSelected ? 16 : 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(trip.seatsAvailable)")
                        .font(.system(size: isSelected ? 11 : 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Trip Preview Card (Map)

struct TripPreviewCard: View {
    let trip: Trip
    let onDismiss: () -> Void
    @EnvironmentObject var authVM: AuthViewModel

    private var anonymousDriverTitle: String { "Driver details after booking" }
    private var driverRating: Double { trip.driver?.rating ?? 0 }

    var body: some View {
        NavigationLink(destination: TripDetailsView(trip: trip).environmentObject(authVM)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$8.50")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(.brandGreen)
                    Text("per seat")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Text(trip.departureTime.countdownString)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.brandGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 84, alignment: .leading)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.brand.opacity(0.10))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.brand)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(anonymousDriverTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                StarRatingView(rating: driverRating, size: 8)
                                Text(String(format: "%.1f", driverRating))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        Spacer(minLength: 6)

                        Text(trip.departureTime.tripTimeString)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle().fill(Color.brand).frame(width: 6, height: 6)
                            Text(trip.origin)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.brandRed)
                            Text(trip.destination)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    HStack {
                        Text("\(trip.seatsAvailable) seats")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textSecondary)
                        Text("•")
                            .foregroundColor(.textTertiary)
                        Text(trip.departureTime.tripDateString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 5) {
                            Text("View")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(hex: "0F172A"))
                        .clipShape(Capsule())
                        .frame(minWidth: 74)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.system(size: 8))
                .foregroundColor(.brand)
                .frame(width: 12)
            configuration.title
        }
    }
}

private extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIconFix: TrailingIconLabelStyle { .init() }
}
