import SwiftUI
import UIKit
import MapKit

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

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {

                // ── Background: Map or List ──
                if viewModel.viewMode == .map {
                    mapBackground
                } else {
                    Color.appBackground.ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // ── Search Header (includes verify banner + greeting + toggle + search) ──
                    searchHeader
                        .padding(.top, VerifyBannerView.windowTopInset)

                    if viewModel.viewMode == .list {
                        listContent
                    }
                }

                // ── Map Markers + Floating Trip Card ──
                if viewModel.viewMode == .map {
                    mapOverlays
                }

                // ── View Toggle ──
                viewToggleButton
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            // Alert and sheet must be inside NavigationView for reliable presentation
            .alert("Verification Required", isPresented: $showVerificationAlert) {
                Button("Verify Now") { showIDVerificationSheet = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please verify your SJSU ID before viewing trip details and booking rides.")
            }
            .sheet(isPresented: $showIDVerificationSheet) {
                IDVerificationView().environmentObject(authVM)
            }
        }
        .navigationViewStyle(.stack)
        .task { await viewModel.searchNearby() }
        .onChange(of: locationManager.currentLocation) { _ in
            if let coord = locationManager.currentLocation?.coordinate {
                withAnimation { region.center = coord }
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
        VStack(spacing: 14) {
            // ── Verify Banner (in-flow above greeting so it pushes content down) ──
            if let user = authVM.currentUser, user.sjsuIdStatus != .verified {
                VerifyBannerView(status: user.sjsuIdStatus) {
                    showIDVerificationSheet = true
                }
            }

            // Greeting row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good \(greeting),")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text(authVM.currentUser?.name.components(separatedBy: " ").first ?? "there")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                // Avatar
                ZStack {
                    Circle().fill(Color.brand.opacity(0.15)).frame(width: 42, height: 42)
                    Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.brand)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)

            // ── Direction toggle ──
            directionToggle

            // ── Fixed SJSU pill (role flips with direction) ──
            sjsuFixedPill

            // ── Variable location search bar + autocomplete ──
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.searchDirection == .toSJSU ? "location.fill" : "mappin.and.ellipse")
                        .foregroundColor(.brand)
                    TextField(viewModel.searchDirection.searchPlaceholder, text: $viewModel.searchText)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
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
                            Image(systemName: "xmark.circle.fill").foregroundColor(.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.cardBackground)
                .cornerRadius(viewModel.showSuggestions ? 16 : 16,
                              corners: viewModel.showSuggestions
                                  ? [.topLeft, .topRight]
                                  : .allCorners)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                // Autocomplete suggestions dropdown
                if viewModel.showSuggestions && !viewModel.locationSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.locationSuggestions.prefix(5), id: \.self) { suggestion in
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

                            if suggestion != viewModel.locationSuggestions.prefix(5).last {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
        .padding(.bottom, 14)
        .background(
            Color.cardBackground.opacity(viewModel.viewMode == .map ? 0.92 : 1)
                .blur(radius: viewModel.viewMode == .map ? 0 : 0)
        )
        .cornerRadius(viewModel.viewMode == .map ? 24 : 0, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
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
                    HStack(spacing: 6) {
                        Image(systemName: direction == .toSJSU ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                            .font(.system(size: 13))
                        Text(direction == .toSJSU ? "To SJSU" : "From SJSU")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? .white : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.brand : Color.clear)
                    )
                }
            }
        }
        .padding(3)
        .background(Color.appBackground)
        .cornerRadius(13)
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Fixed SJSU pill

    private var sjsuFixedPill: some View {
        let isToSJSU = viewModel.searchDirection == .toSJSU
        let pillColor: Color = isToSJSU ? .brandGreen : .brand
        let icon = isToSJSU ? "mappin.circle.fill" : "building.columns.fill"
        let roleText = isToSJSU ? "Fixed destination" : "Fixed pickup"

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(pillColor)
            Text("San Jose State University")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(pillColor)
            Spacer()
            Text(roleText)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(pillColor.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(pillColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, AppConstants.pagePadding)
        .animation(.easeInOut(duration: 0.25), value: viewModel.searchDirection)
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.itemSpacing) {
                // Nearby chip bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ChipButton(title: "Nearby", isSelected: true) {}
                        ChipButton(title: "Today") {}
                        ChipButton(title: "Tomorrow") {}
                        ChipButton(title: "This Week") {}
                    }
                    .padding(.horizontal, AppConstants.pagePadding)
                }
                .padding(.top, 16)

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
            if let trip = selectedTrip {
                TripPreviewCard(trip: trip) {
                    selectedTrip = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Toggle Button

    private var viewToggleButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        viewModel.viewMode = viewModel.viewMode == .map ? .list : .map
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.viewMode == .map ? "list.bullet" : "map")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.viewMode == .map ? "List" : "Map")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.brand)
                    .cornerRadius(22)
                    .shadow(color: .brand.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 110)
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "morning" }
        if h < 17 { return "afternoon" }
        return "evening"
    }
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

    var body: some View {
        NavigationLink(destination: TripDetailsView(trip: trip).environmentObject(authVM)) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.brand).frame(width: 8, height: 8)
                            Text(trip.origin).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }
                        Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1, height: 10).padding(.leading, 3.5)
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill").foregroundColor(.brandGreen).font(.system(size: 10))
                            Text(trip.destination).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(trip.departureTime.tripTimeString)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.textPrimary)
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill").font(.system(size: 11))
                            Text("\(trip.seatsAvailable) seats")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.textSecondary)
                    }
                }

                Divider()

                HStack {
                    if let driver = trip.driver {
                        HStack(spacing: 8) {
                            Circle().fill(Color.brand.opacity(0.15)).frame(width: 30, height: 30).overlay(
                                Text(driver.name.prefix(1).uppercased()).font(.system(size: 13, weight: .bold)).foregroundColor(.brand)
                            )
                            Text(driver.name).font(.system(size: 13, weight: .medium)).foregroundColor(.textPrimary)
                            StarRatingView(rating: driver.rating, size: 11)
                        }
                    }
                    Spacer()
                    Text("View Details →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brand)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

