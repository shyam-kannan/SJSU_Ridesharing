import SwiftUI
import CoreLocation
import Combine

struct BookingConfirmationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var bookingVM: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let seats: Int
    var onBookingFinished: (() -> Void)? = nil

    @State private var showSuccess = false
    @State private var showVerificationAlert = false
    @State private var showIDVerificationSheet = false
    @State private var isBookingComplete = false

    // quote.maxPrice is the per-rider price from the cost service
    private var perSeatPrice: Double {
        bookingVM.currentBooking?.quote?.maxPrice ?? 8.50
    }

    private var totalPrice: Double {
        perSeatPrice * Double(seats)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.canvasGradient.ignoresSafeArea()

                if showSuccess {
                    BookingSuccessView(trip: trip, bookingId: bookingVM.currentBooking?.id) {
                        dismiss()
                        onBookingFinished?()
                    }
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                removal: .opacity))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // ── Summary Header ──
                            VStack(spacing: 6) {
                                VStack(spacing: 8) {
                                    Text("Confirm Booking")
                                        .font(DesignSystem.Typography.title1)
                                        .foregroundColor(.textPrimary)
                                    Rectangle()
                                        .fill(DesignSystem.Colors.sjsuBlue)
                                        .frame(width: 40, height: 4)
                                        .cornerRadius(2)
                                }
                                Text("Review your trip details")
                                    .font(.system(size: 15))
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 28)
                            .padding(.horizontal, AppConstants.pagePadding)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // ── Trip Summary ──
                            VStack(spacing: 0) {
                                // Route
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(spacing: 0) {
                                        Circle().fill(Color.brand).frame(width: 10, height: 10)
                                        Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1.5, height: 36)
                                        Image(systemName: "mappin.circle.fill").font(.system(size: 13)).foregroundColor(.brandRed)
                                    }.padding(.top, 3)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(trip.origin).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                                        Text(trip.destination).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 10) {
                                        Text(trip.departureTime.tripTimeString)
                                            .font(.system(size: 14, weight: .bold)).foregroundColor(.brand)
                                        Text(trip.departureTime.tripDateString)
                                            .font(.system(size: 12)).foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(AppConstants.cardPadding)

                                Divider().padding(.horizontal)

                                // Driver info
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(DesignSystem.Colors.sjsuBlue.opacity(0.35), lineWidth: 2)
                                            .frame(width: 46, height: 46)
                                        Circle().fill(Color.brand.opacity(0.12)).frame(width: 42, height: 42)
                                        Text(trip.driver?.name.prefix(1).uppercased() ?? "?")
                                            .font(.system(size: 17, weight: .bold)).foregroundColor(.brand)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(trip.driver?.name ?? "Driver")
                                            .font(.system(size: 14, weight: .semibold))
                                        StarRatingView(rating: trip.driver?.rating ?? 0, size: 12)
                                    }
                                    Spacer()
                                    Text("\(seats) seat\(seats == 1 ? "" : "s")")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.brandGreen)
                                        .cornerRadius(10)
                                }
                                .padding(AppConstants.cardPadding)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.panelGradient)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .strokeBorder(Color.brand.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
                            .padding(.horizontal, AppConstants.pagePadding)

                            // ── Price Breakdown ──
                            VStack(spacing: 12) {
                                Text("Price Breakdown")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                PriceRow(label: "Per seat", value: String(format: "$%.2f", perSeatPrice))
                                PriceRow(label: "Seats", value: "× \(seats)")
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.sjsuGold, DesignSystem.Colors.sjsuGold.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1.5)
                                    .cornerRadius(1)
                                PriceRow(label: "Total", value: String(format: "$%.2f", totalPrice), isBold: true)
                            }
                            .padding(16)
                            .elevatedCard(cornerRadius: 20)
                            .padding(.horizontal, AppConstants.pagePadding)

                            // ── Error ──
                            if let err = bookingVM.errorMessage {
                                ToastBanner(message: err, type: .error)
                                    .padding(.horizontal, AppConstants.pagePadding)
                            }

                            // ── Policy note ──
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle").foregroundColor(.textTertiary)
                                Text("Free cancellation up to 1 hour before departure.")
                                    .font(.system(size: 12)).foregroundColor(.textTertiary)
                            }
                            .padding(.horizontal, AppConstants.pagePadding)

                            Spacer().frame(height: 100)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        // ── Confirm Button ──
                        VStack(spacing: 0) {
                            Divider()
                            PrimaryButton(
                                title: isBookingComplete ? "✓ Booking Complete" : "Confirm & Pay \(String(format: "$%.2f", totalPrice))",
                                icon: isBookingComplete ? "checkmark" : "lock.fill",
                                isLoading: bookingVM.isCreating || bookingVM.isLoading,
                                isEnabled: !isBookingComplete
                            ) { confirmBooking() }
                            .padding(.horizontal, AppConstants.pagePadding)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .overlay(alignment: .top) { Divider().opacity(0.3) }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary).padding(8).background(Color.panelGradient).clipShape(Circle())
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: showSuccess)
        .alert("Verification Required", isPresented: $showVerificationAlert) {
            Button("Verify Now") { showIDVerificationSheet = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your SJSU ID must be verified before booking. Please complete verification first.")
        }
        .sheet(isPresented: $showIDVerificationSheet) {
            IDVerificationView().environmentObject(authVM)
                .onDisappear { Task { await authVM.refreshCurrentUser() } }
        }
    }

    private func confirmBooking() {
        // Prevent duplicate bookings from multiple taps
        guard !isBookingComplete, !bookingVM.isCreating else { return }

        // Client-side verification guard — catches unverified users before the network call
        guard authVM.currentUser?.sjsuIdStatus == .verified else {
            showVerificationAlert = true
            return
        }

        // Set flag immediately to prevent race condition
        isBookingComplete = true

        Task {
            let success = await bookingVM.createBooking(tripId: trip.id, seats: seats)
            if success, let bookingId = bookingVM.currentBooking?.id {
                let paid = await bookingVM.confirmAndPay(bookingId: bookingId, amount: totalPrice)
                if paid {
                    withAnimation { showSuccess = true }
                } else {
                    // Payment failed - allow retry
                    isBookingComplete = false
                }
            } else {
                // Booking creation failed - allow retry
                isBookingComplete = false

                if let errMsg = bookingVM.errorMessage,
                   errMsg.lowercased().contains("verif") {
                    // Backend also rejects unverified bookings — surface the verification flow
                    bookingVM.errorMessage = nil
                    showVerificationAlert = true
                }
            }
        }
    }
}

// MARK: - Price Row

private struct PriceRow: View {
    let label: String
    let value: String
    var isBold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: isBold ? 16 : 14, weight: isBold ? .bold : .regular))
                .foregroundColor(isBold ? .textPrimary : .textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: isBold ? 20 : 14, weight: isBold ? .bold : .medium))
                .foregroundColor(isBold ? .brandGreen : .textPrimary)
        }
    }
}

// MARK: - Booking Success View

struct BookingSuccessView: View {
    let trip: Trip
    let bookingId: String?
    let onDone: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var showManualAddress = false
    @State private var manualAddress = ""
    @State private var isUpdatingLocation = false
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.8

    @StateObject private var locationManager = LocationManager.shared

    private var isToSJSU: Bool {
        trip.destination.lowercased().contains("sjsu") ||
        trip.destination.lowercased().contains("san jose state")
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.sjsuGold.opacity(glowOpacity), lineWidth: 2)
                    .frame(width: 160, height: 160)
                    .scaleEffect(glowScale)
                Circle().fill(Color.brandGreen.opacity(0.1)).frame(width: 130, height: 130)
                Circle().fill(Color.brandGreen.opacity(0.2)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brandGreen)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 10) {
                Text("Booking Confirmed!")
                    .font(DesignSystem.Typography.title1)
                    .foregroundColor(.textPrimary)
                Text("Your ride to \(trip.destination) is booked.\nHave a great trip!")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Trip summary pill
            HStack(spacing: 12) {
                Image(systemName: "clock.fill").foregroundColor(.brand)
                Text(trip.departureTime.tripDateTimeString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.brand.opacity(0.12), Color.brand.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(18)

            // Location sharing prompt (only for To SJSU trips)
            if isToSJSU && !showManualAddress {
                VStack(spacing: 12) {
                    Text("Share Pickup Location?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Help your driver find you easily")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)

                    HStack(spacing: 12) {
                        Button(action: shareCurrentLocation) {
                            HStack(spacing: 6) {
                                if isUpdatingLocation {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text("Use Current Location")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.sjsuBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isUpdatingLocation)

                        Button(action: { showManualAddress = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.cursor")
                                Text("Enter Address")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(16)
                .elevatedCard(cornerRadius: 20)
                .padding(.horizontal, 20)
            }

            // Manual address entry
            if showManualAddress {
                VStack(spacing: 12) {
                    TextField("Enter pickup address", text: $manualAddress)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showManualAddress = false
                            manualAddress = ""
                        }
                        .foregroundColor(.textSecondary)

                        Button(action: shareManualAddress) {
                            if isUpdatingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Share")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.sjsuBlue)
                        .cornerRadius(12)
                        .disabled(manualAddress.isEmpty || isUpdatingLocation)
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            PrimaryButton(title: "Done", icon: "checkmark") { onDone() }
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1; opacity = 1
            }
            withAnimation(DesignSystem.Animation.successExpand.delay(0.3)) {
                glowScale = 1.3
                glowOpacity = 0
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        }
    }

    private func shareCurrentLocation() {
        guard let bookingId else { return }
        isUpdatingLocation = true
        locationManager.startUpdating()

        // Wait a moment for location to be available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let location = locationManager.currentLocation {
                Task {
                    do {
                        _ = try await BookingService.shared.updatePickupLocation(
                            id: bookingId,
                            lat: location.coordinate.latitude,
                            lng: location.coordinate.longitude,
                            address: nil
                        )
                        isUpdatingLocation = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        print("Failed to update pickup location: \(error)")
                        isUpdatingLocation = false
                    }
                }
            } else {
                isUpdatingLocation = false
            }
        }
    }

    private func shareManualAddress() {
        guard !manualAddress.isEmpty else { return }
        guard let bookingId else { return }
        isUpdatingLocation = true

        Task {
            do {
                // Use default SJSU coordinates with manual address
                _ = try await BookingService.shared.updatePickupLocation(
                    id: bookingId,
                    lat: AppConstants.sjsuCoordinate.latitude,
                    lng: AppConstants.sjsuCoordinate.longitude,
                    address: manualAddress
                )
                isUpdatingLocation = false
                showManualAddress = false
            } catch {
                print("Failed to update pickup location: \(error)")
                isUpdatingLocation = false
            }
        }
    }
}

// MARK: - Booking List View

private enum DriverTab { case passengers, postedTrips }

struct BookingListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = BookingViewModel()
    @State private var showAsDriver = false
    @State private var driverTab: DriverTab = .passengers
    @State private var editingTrip: Trip? = nil
    @State private var showAccountMenu = false
    @State private var showReportUser = false
    @State private var reportedUserId: String?
    @State private var reportedUserName: String?
    @State private var reportTripId: String?
    @State private var deepLinkedBooking: Booking? = nil

    private var filteredBookings: [Booking] {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        return vm.bookings.filter { booking in
            // Hide bookings whose trip departed more than 24 hours ago
            if let departure = booking.trip?.departureTime, departure < cutoff {
                return false
            }
            // Hide completed bookings older than 24 hours
            if booking.status == .completed {
                return booking.updatedAt >= cutoff
            }
            return true
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                bookingsHeader

                if vm.isLoading {
                    SkeletonTripList().padding(.top, 12)
                    Spacer()
                } else if showAsDriver && driverTab == .postedTrips {
                    postedTripsContent
                } else if let kind = vm.errorKind {
                    // Contextual error state with pull-to-refresh
                    ScrollView {
                        bookingsErrorState(kind: kind)
                            .padding(.top, 60)
                            .padding(.horizontal, AppConstants.pagePadding)
                    }
                    .refreshable { await refreshCurrentTab() }
                } else if (showAsDriver && driverTab == .passengers) ? vm.bookingsGroupedByTrip.isEmpty : filteredBookings.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: "No bookings yet",
                            message: showAsDriver ? "Your passengers will appear here" : "Find a ride and get going!",
                            actionTitle: showAsDriver ? nil : "Find Rides"
                        ) {
                            NotificationCenter.default.post(name: .navigateToHomeTab, object: nil)
                        }
                        .padding(.top, 60)
                    }
                    .refreshable { await refreshCurrentTab() }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if showAsDriver && driverTab == .passengers {
                                ForEach(vm.bookingsGroupedByTrip, id: \.trip.id) { group in
                                    DriverTripGroupRow(
                                        trip: group.trip,
                                        bookings: group.bookings,
                                        onDeleteCancelled: { Task { await vm.deletePostedTrip(id: group.trip.id) } }
                                    )
                                    .padding(.horizontal, AppConstants.pagePadding)
                                }
                            } else {
                                ForEach(filteredBookings) { booking in
                                    BookingRow(booking: booking, vm: vm, showAsDriver: showAsDriver) { userId, userName, tripId in
                                        reportedUserId = userId
                                        reportedUserName = userName
                                        reportTripId = tripId
                                        showReportUser = true
                                    }
                                    .padding(.horizontal, AppConstants.pagePadding)
                                }
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 100)
                    }
                    .refreshable { await refreshCurrentTab() }
                }
            }
            .background(
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.accentLime.opacity(0.10))
                        .frame(width: 260)
                        .offset(x: 140, y: 520)
                        .ignoresSafeArea()
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .task {
                if authVM.isDriver { showAsDriver = true }
                await refreshCurrentTab()
            }
            .onAppear {
                Task {
                    if authVM.isDriver, !showAsDriver {
                        showAsDriver = true
                    }
                    await refreshCurrentTab()
                }
            }
            .onChange(of: showAsDriver) { _ in
                Task { await refreshCurrentTab() }
            }
            .onChange(of: driverTab) { _ in
                Task { await refreshCurrentTab() }
            }
            .onChange(of: authVM.currentUser?.id) { _ in
                Task {
                    showAsDriver = authVM.isDriver
                    await refreshCurrentTab()
                }
            }
            .sheet(isPresented: $showReportUser) {
                if let userId = reportedUserId, let userName = reportedUserName {
                    ReportUserView(reportedUserId: userId, reportedUserName: userName, tripId: reportTripId)
                        .environmentObject(authVM)
                }
            }
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView()
                    .environmentObject(authVM)
            }
            .sheet(item: $editingTrip) { trip in
                EditPostedTripSheet(trip: trip, vm: vm)
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let booking = deepLinkedBooking {
                            BookingRideDetailView(booking: booking, vm: vm, showAsDriver: false)
                        }
                    },
                    isActive: Binding(
                        get: { deepLinkedBooking != nil },
                        set: { if !$0 { deepLinkedBooking = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
            .onReceive(NotificationCenter.default.publisher(for: .openBookingDetail)) { notification in
                guard let bookingId = notification.userInfo?["bookingId"] as? String else { return }
                // Wait briefly to allow the tab switch animation to complete, then reload and open
                Task {
                    await vm.loadBookings(asDriver: false)
                    if let matched = vm.bookings.first(where: { $0.id == bookingId }) {
                        deepLinkedBooking = matched
                    }
                }
            }
        }
    }

    private func refreshCurrentTab() async {
        if showAsDriver && driverTab == .postedTrips {
            if let id = authVM.currentUser?.id {
                await vm.loadPostedTrips(driverId: id)
            }
        } else {
            await vm.loadBookings(asDriver: showAsDriver)
        }
    }

    @ViewBuilder
    private var postedTripsContent: some View {
        if vm.postedTrips.isEmpty {
            ScrollView {
                EmptyStateView(
                    icon: "car.fill",
                    title: "No posted trips",
                    message: "Trips you post will appear here"
                ) {}
                .padding(.top, 60)
            }
            .refreshable {
                if let id = authVM.currentUser?.id { await vm.loadPostedTrips(driverId: id) }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(vm.postedTrips) { trip in
                        PostedTripRow(
                            trip: trip,
                            onEdit: { editingTrip = trip },
                            onDelete: { Task { await vm.cancelPostedTrip(id: trip.id) } },
                            onDeletePermanent: { Task { await vm.deletePostedTrip(id: trip.id) } }
                        )
                        .padding(.horizontal, AppConstants.pagePadding)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .refreshable {
                if let id = authVM.currentUser?.id { await vm.loadPostedTrips(driverId: id) }
            }
        }
    }

    private var bookingsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showAsDriver ? "Passenger Rides" : "My Trips")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(showAsDriver ? "Manage riders and trip activity" : "Track upcoming and past bookings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
                Spacer()
                Button(action: { showAccountMenu = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignSystem.Colors.onDark.opacity(0.08))
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.top, 14)

            if authVM.isDriver {
                VStack(spacing: 8) {
                    Picker("View", selection: $showAsDriver) {
                        Text("As Rider").tag(false)
                        Text("As Driver").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAsDriver)

                    if showAsDriver {
                        Picker("Driver Tab", selection: $driverTab) {
                            Text("Passengers").tag(DriverTab.passengers)
                            Text("Posted Trips").tag(DriverTab.postedTrips)
                        }
                        .pickerStyle(.segmented)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                                )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: driverTab)
                    }
                }
                .padding(.horizontal, AppConstants.pagePadding)
            }

            HStack(spacing: 8) {
                headerChip(showAsDriver ? "Passengers" : "Rider History", icon: showAsDriver ? "person.2.fill" : "car.fill")
                headerChip("Live Chat", icon: "message.fill")
                headerChip("Tracking", icon: "location.fill")
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func bookingsErrorState(kind: BookingErrorKind) -> some View {
        let (icon, title, subtitle): (String, String, String) = {
            switch kind {
            case .noConnection:
                return ("wifi.slash", "No connection", "Check your internet and pull down to refresh")
            case .authRequired:
                return ("lock.fill", "Session expired", "Please log out and log back in")
            case .serverDown:
                return ("exclamationmark.triangle", "Service unavailable", "We're working on it. Pull down to refresh")
            case .other:
                return ("exclamationmark.circle", "Something went wrong", "Pull down to refresh")
            }
        }()

        VStack(spacing: 20) {
            ZStack {
                Circle().fill(DesignSystem.Colors.textPrimary.opacity(0.06)).frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if kind == .authRequired {
                Button(action: { Task { await authVM.logout() } }) {
                    Text("Log Out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandRed)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.brandRed.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func headerChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(DesignSystem.Colors.onDark.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.onDark.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Posted Trip Row

private struct PostedTripRow: View {
    let trip: Trip
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onDeletePermanent: (() -> Void)? = nil
    @State private var showDeleteConfirm = false
    @State private var showPermanentDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.origin)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("→ \(trip.destination)")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Text(trip.status.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor(trip.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(trip.status).opacity(0.12))
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                Label(Self.dateFormatter.string(from: trip.departureTime), systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                Label("\(trip.seatsAvailable) seat\(trip.seatsAvailable == 1 ? "" : "s")", systemImage: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
            let payout = trip.totalPayout ?? 0
            let quoted = trip.totalQuoted ?? 0
            if payout > 0 || quoted > 0 {
                HStack(spacing: 12) {
                    if payout > 0 {
                        Label(String(format: "$%.2f payout", payout), systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.brandGreen)
                    }
                    if quoted > 0 {
                        Label(String(format: "$%.2f quoted", quoted), systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.brandOrange)
                    }
                }
            }
            HStack(spacing: 10) {
                Spacer()
                if trip.status == .cancelled {
                    Button(action: { showPermanentDeleteConfirm = true }) {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cardBackground)
                            .overlay(Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: { showDeleteConfirm = true }) {
                        Label("Cancel", systemImage: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppConstants.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
        )
        .confirmationDialog("Cancel this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Cancel Trip", role: .destructive, action: onDelete)
            Button("Keep Trip", role: .cancel) {}
        } message: {
            Text("This will cancel the trip and notify any passengers.")
        }
        .confirmationDialog("Delete this trip?", isPresented: $showPermanentDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Trip", role: .destructive) { onDeletePermanent?() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This will permanently remove the cancelled trip from your history.")
        }
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .pending:   return .orange
        case .enRoute, .inProgress, .arrived: return .blue
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

// MARK: - Driver Trip Group Row

private struct DriverTripGroupRow: View {
    let trip: Trip
    let bookings: [Booking]
    var onDeleteCancelled: (() -> Void)? = nil
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showDetail = false
    @State private var showDeleteConfirm = false

    private var pendingCount: Int {
        bookings.filter { $0.bookingState == .pending }.count
    }
    private var approvedCount: Int {
        bookings.filter { $0.bookingState == .approved }.count
    }
    private var riderNames: String {
        bookings.compactMap { $0.rider?.name.components(separatedBy: " ").first }
                .joined(separator: ", ")
    }

    private func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .pending:   return .brandOrange
        case .enRoute, .inProgress, .arrived: return .brand
        case .completed: return .textTertiary
        case .cancelled: return .brandRed
        }
    }

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.origin) → \(trip.destination)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        Text(trip.departureTime, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Text(trip.status.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tripStatusColor(trip.status))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(tripStatusColor(trip.status).opacity(0.12))
                        .clipShape(Capsule())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                HStack(spacing: 8) {
                    if pendingCount > 0 {
                        Label("\(pendingCount) pending", systemImage: "clock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    if approvedCount > 0 {
                        Label("\(approvedCount) confirmed", systemImage: "person.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.brandGreen)
                            .clipShape(Capsule())
                    }
                }
                if !riderNames.isEmpty {
                    Text(riderNames)
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }

                if trip.status == .cancelled {
                    HStack {
                        Spacer()
                        Button(action: { showDeleteConfirm = true }) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.brandRed)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.brandRed.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppConstants.cardPadding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            DriverTripDetailsView(trip: trip, onTripDeleted: onDeletePermanent).environmentObject(authVM)
        }
        .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Trip", role: .destructive) { onDeleteCancelled?() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This will permanently remove the cancelled trip from your history.")
        }
    }
}

// MARK: - Edit Posted Trip Sheet

private struct EditPostedTripSheet: View {
    let trip: Trip
    @ObservedObject var vm: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var departureTime: Date
    @State private var seats: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(trip: Trip, vm: BookingViewModel) {
        self.trip = trip
        self.vm = vm
        _departureTime = State(initialValue: trip.departureTime)
        _seats = State(initialValue: trip.seatsAvailable)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Departure Time") {
                    DatePicker("Departure", selection: $departureTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                }
                Section("Seats Available") {
                    Stepper("\(seats) seat\(seats == 1 ? "" : "s")", value: $seats, in: 1...8)
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let ok = await vm.updatePostedTrip(id: trip.id, departureTime: departureTime, seatsAvailable: seats)
                            isSaving = false
                            if ok { dismiss() } else { errorMessage = "Failed to update trip. Please try again." }
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Booking Row

private struct BookingRow: View {
    let booking: Booking
    @ObservedObject var vm: BookingViewModel
    let showAsDriver: Bool
    var onReport: ((String, String, String?) -> Void)?

    @State private var showDeleteConfirm = false

    private var chatAvailable: Bool {
        let activeStates = booking.bookingState == .pending
            || booking.bookingState == .approved
            || booking.status == .confirmed
        let recentlyCompleted = booking.status == .completed
            && (booking.trip?.departureTime ?? Date()) > Date().addingTimeInterval(-86400)
        return activeStates || recentlyCompleted
    }

    var statusColor: Color {
        switch booking.bookingState {
        case .pending:   return .brandOrange
        case .approved:  return .brandGreen
        case .cancelled: return .brandRed
        case .rejected:  return .brandRed
        case .completed: return .textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 10, height: 10)
                    Text(booking.bookingState.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                Spacer()
                Text(booking.createdAt.timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }

            if let trip = booking.trip {
                NavigationLink(
                    destination: BookingRideDetailView(booking: booking, vm: vm, showAsDriver: showAsDriver)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View Ride Details")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(0.8)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(DesignSystem.Colors.actionDarkSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.onDark.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.brand).frame(width: 7, height: 7)
                        Text(trip.origin)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.brandRed)
                            .font(.system(size: 12))
                        Text(trip.destination)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .background(Color.sheetBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
                .cornerRadius(12)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 12))
                        Text(trip.departureTime.tripDateTimeString)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundColor(.textSecondary)
                    Spacer()
                    if let amount = booking.fare ?? booking.quote?.maxPrice {
                        HStack(spacing: 6) {
                            Text(String(format: "$%.2f", amount))
                                .font(.system(size: 14, weight: .bold))
                            Text(paymentStatusLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(paymentStatusPillColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(paymentStatusPillColor.opacity(0.12))
                                .cornerRadius(999)
                        }
                        .foregroundColor(.textPrimary)
                    }
                }
            }

            // Driver details for confirmed/completed bookings
            if (booking.status == .confirmed || booking.status == .completed),
               let trip = booking.trip, let driver = trip.driver {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.brand.opacity(0.12)).frame(width: 40, height: 40)
                            Text(driver.name.prefix(1).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.brand)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if let vehicle = driver.vehicleInfo {
                                Text(vehicle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                            }
                            if let plate = driver.licensePlate {
                                HStack(spacing: 4) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 9))
                                    Text("License: \(plate)")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brandGold.opacity(0.15))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }

            // Track / simulate ride entry (confirmed bookings)
            if booking.status == .confirmed, let trip = booking.trip {
                NavigationLink(destination: ActiveTripView(trip: trip, booking: booking, isDriver: showAsDriver)) {
                    HStack(spacing: 8) {
                        Image(systemName: [.enRoute, .arrived, .inProgress].contains(trip.status) ? "location.fill" : "sparkles")
                        Text([.enRoute, .arrived, .inProgress].contains(trip.status) ? "Track Trip Live" : "Simulate Ride")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.sjsuBlue, DesignSystem.Colors.sjsuTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }

            // Chat button for active/recently-completed bookings so riders can reopen chat history
            if chatAvailable, let trip = booking.trip {
                if showAsDriver, let rider = booking.rider {
                    NavigationLink(destination: ChatView(tripId: trip.id, otherPartyName: rider.name, isDriver: true)) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Chat with \(rider.name)")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(10)
                    }
                } else if !showAsDriver {
                    NavigationLink(destination: ChatView(tripId: trip.id, otherPartyName: trip.driver?.name ?? "Driver", isDriver: false)) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Chat with Driver")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }

            // Cancel button for pending/approved bookings (riders only)
            if !showAsDriver && (booking.bookingState == .pending || booking.bookingState == .approved) {
                Button(action: {
                    Task {
                        let success = await vm.cancelBooking(id: booking.id)
                        if success {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            // Reload bookings to refresh the list
                            await vm.loadBookings(asDriver: showAsDriver)
                        }
                    }
                }) {
                    Text("Cancel Booking")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.brandRed.opacity(0.08))
                        .cornerRadius(10)
                }
            }

            // Report button for completed bookings
            if booking.status == .completed, let trip = booking.trip, let driver = trip.driver {
                Button(action: {
                    onReport?(driver.id, driver.name, trip.id)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text("Report Issue")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandRed.opacity(0.08))
                    .cornerRadius(10)
                }
            }

            // Remove button for cancelled/rejected bookings
            if booking.bookingState == .cancelled || booking.bookingState == .rejected {
                HStack {
                    Spacer()
                    Button(action: { showDeleteConfirm = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Remove")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.brandRed.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandRed.opacity(0.07))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(statusColor == .brandGreen ? DesignSystem.Colors.accentLime.opacity(0.6) : DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [statusColor.opacity(0.10), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
        )
        .shadow(color: .black.opacity(0.045), radius: 10, x: 0, y: 4)
        .confirmationDialog("Remove this booking?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await BookingService.shared.deleteBooking(bookingId: booking.id)
                    await vm.loadBookings(asDriver: showAsDriver)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the booking from your history.")
        }
    }

    private var paymentStatusLabel: String {
        switch booking.payment?.status {
        case .captured: return "Paid"
        case .pending: return "Payment Held"
        case .refunded: return "Refunded"
        case .failed: return "Failed"
        case .none: return "Quoted"
        }
    }

    private var paymentStatusPillColor: Color {
        switch booking.payment?.status {
        case .captured: return .brandGreen
        case .pending: return .brandOrange
        case .refunded: return .brand
        case .failed: return .brandRed
        case .none: return .textSecondary
        }
    }
}

// MARK: - Booking Ride Detail View

private struct BookingRideDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let booking: Booking
    @ObservedObject var vm: BookingViewModel
    let showAsDriver: Bool

    @State private var anchorPoints: [AnchorPoint] = []
    @State private var isLoadingAnchors = true
    @State private var isAuthorizing = false
    @State private var authError: String?

    private var currentBooking: Booking {
        vm.bookings.first(where: { $0.id == booking.id }) ?? booking
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let trip = currentBooking.trip {
                    Group {
                        if !anchorPoints.isEmpty {
                            AnchorRouteMapView(
                                origin: trip.originPoint?.clLocationCoordinate2D,
                                destination: trip.destinationPoint?.clLocationCoordinate2D,
                                driver: nil,
                                anchorPoints: anchorPoints,
                                showsUserLocation: true
                            )
                        } else {
                            RouteMapView(
                                origin: trip.originPoint?.clLocationCoordinate2D,
                                destination: trip.destinationPoint?.clLocationCoordinate2D,
                                driver: nil,
                                showsUserLocation: true
                            )
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if !showAsDriver {
                            statusBadge
                                .padding(14)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    bookingStatusTimeline
                        .padding(.horizontal, 20)

                    routeCard(trip: trip)
                        .padding(.horizontal, 20)

                    if showAsDriver {
                        unifiedRiderCard(trip: trip)
                            .padding(.horizontal, 20)
                    } else {
                        counterpartCard(trip: trip)
                            .padding(.horizontal, 20)

                        paymentCard
                            .padding(.horizontal, 20)
                    }

                    actionsCard(trip: trip)
                        .padding(.horizontal, 20)
                } else {
                    EmptyStateView(
                        icon: "car.2",
                        title: "Ride details unavailable",
                        message: "We couldn't load the trip details for this booking.",
                        actionTitle: nil
                    ) {}
                    .padding(.top, 60)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 124)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAnchorPoints()
        }
    }

    private func loadAnchorPoints() async {
        isLoadingAnchors = true
        do {
            anchorPoints = try await TripService.shared.getAnchorPoints(tripId: booking.tripId)
            isLoadingAnchors = false
        } catch {
            print("Error loading anchor points: \(error)")
            isLoadingAnchors = false
        }
    }

    private var bookingStateLabel: String {
        switch booking.bookingState {
        case .pending:   return "Awaiting Approval"
        case .approved:  return booking.payment == nil ? "Approved — Pay Now" : "Approved"
        case .cancelled: return "Cancelled"
        case .rejected:  return "Rejected"
        case .completed: return "Completed"
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(bookingStateLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cardBackground)
        .overlay(Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var paymentStatusBadge: some View {
        let (label, color): (String, Color) = {
            switch booking.payment?.status {
            case .captured:  return ("Paid", .brandGreen)
            case .pending:   return ("Payment Held", .brandOrange)
            case .refunded:  return ("Refunded", .brand)
            case .failed:    return ("Failed", .brandRed)
            case .none:      return ("Quoted", .textSecondary)
            }
        }()
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private var bookingStatusTimeline: some View {
        let approvedDone = booking.bookingState == .approved || booking.bookingState == .completed
        let paymentDone = booking.payment != nil
        let completeDone = booking.bookingState == .completed
        let steps: [(String, String, Bool)] = [
            ("Requested", "paperplane.fill",      true),
            ("Approved",  "checkmark.circle.fill", approvedDone),
            ("Payment",   "creditcard.fill",       paymentDone),
            ("Complete",  "flag.checkered",        completeDone),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step.2 ? Color.brandGreen : Color.sheetBackground)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(step.2 ? Color.brandGreen : DesignSystem.Colors.border, lineWidth: 1.5))
                        Image(systemName: step.1)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(step.2 ? .white : .textTertiary)
                    }
                    Text(step.0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(step.2 ? .textPrimary : .textTertiary)
                        .fixedSize()
                }
                if idx < steps.count - 1 {
                    let nextDone = steps[idx + 1].2
                    Rectangle()
                        .fill(nextDone ? Color.brandGreen : DesignSystem.Colors.border.opacity(0.5))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 14)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cardBackground.cornerRadius(16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
    }

    private func unifiedRiderCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.brand.opacity(0.12)).frame(width: 46, height: 46)
                    Text((booking.rider?.name ?? "R").prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.brand)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.rider?.name ?? "Rider")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                    StarRatingView(rating: booking.rider?.rating ?? 0, size: 12)
                }
                Spacer()
                Text("\(booking.seatsBooked) seat\(booking.seatsBooked == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.brandGreen).clipShape(Capsule())
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Booking ID")
                        .font(.system(size: 11)).foregroundColor(.textTertiary)
                    Text("\(String(booking.id.prefix(8)))…")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.textPrimary)
                }
                Spacer()
                paymentStatusBadge
            }

            if let fare = booking.fare ?? booking.quote?.maxPrice {
                HStack {
                    Text("Fare")
                        .font(.system(size: 13)).foregroundColor(.textSecondary)
                    Spacer()
                    Text(String(format: "$%.2f", fare))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.brandGreen)
                }
            }

            Divider()

            if chatAvailable {
                NavigationLink(destination: ChatView(tripId: trip.id, otherPartyName: booking.rider?.name ?? "Rider", isDriver: true)) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                        Text("Chat with \(booking.rider?.name ?? "Rider")")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).opacity(0.55)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            if booking.bookingState == .pending {
                HStack(spacing: 10) {
                    Button(action: {
                        Task {
                            _ = await vm.rejectBooking(id: booking.id)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                        }
                    }) {
                        Label("Decline", systemImage: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.brandRed.opacity(0.1))
                            .cornerRadius(10)
                    }
                    Button(action: {
                        Task {
                            _ = await vm.approveBooking(id: booking.id)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                        }
                    }) {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.brandGreen.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .cardStyle(padding: 20, cornerRadius: 20)
    }

    private func authorizePayment() async {
        isAuthorizing = true
        _ = try? await BookingService.shared.authorizePayment(bookingId: booking.id)
        await vm.loadBookings(asDriver: false)
        isAuthorizing = false
    }

    private func routeCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Trip")

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 4) {
                    Circle().fill(Color.brand).frame(width: 10, height: 10)
                    Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 2, height: 22)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.brandGreen)
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(trip.origin)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(trip.destination)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
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

            HStack(spacing: 10) {
                infoPill(icon: "calendar", text: trip.departureTime.tripDateString, tint: .textSecondary)
                Spacer(minLength: 8)
                infoPill(icon: "clock", text: trip.departureTime.tripTimeString, tint: .brand)
            }
        }
        .cardStyle(padding: 20, cornerRadius: 20)
    }

    private func counterpartCard(trip: Trip) -> some View {
        let title = showAsDriver ? "Rider" : "Driver"
        let name = showAsDriver ? (booking.rider?.name ?? "Rider") : (trip.driver?.name ?? "Driver")
        let rating = showAsDriver ? (booking.rider?.rating ?? 0) : (trip.driver?.rating ?? 0)
        let vehicle = trip.driver?.vehicleInfo
        let plate = trip.driver?.licensePlate

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.brand.opacity(0.12)).frame(width: 46, height: 46)
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.brand)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    StarRatingView(rating: rating, size: 12)
                    if !showAsDriver, let vehicle {
                        Text(vehicle)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    if !showAsDriver, let plate {
                        Text("Plate: \(plate)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                Spacer()
                Text("\(booking.seatsBooked) seat\(booking.seatsBooked == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.brandGreen)
                    .clipShape(Capsule())
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
        }
        .cardStyle(padding: 20, cornerRadius: 20)
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Booking & Payment")

            VStack(spacing: 10) {
                detailRow(label: "Booking ID", value: "\(String(booking.id.prefix(8)))…")

                if let quote = booking.quote {
                    detailRow(
                        label: "Quoted Total",
                        value: String(format: "$%.2f", quote.maxPrice),
                        valueColor: .brandGreen,
                        valueWeight: .bold
                    )
                }

                if let payment = booking.payment {
                    HStack {
                        Text("Payment Status")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text(paymentStatusLabel(payment.status))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(paymentStatusColor(payment.status))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(paymentStatusColor(payment.status).opacity(0.10))
                            .clipShape(Capsule())
                    }
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
        }
        .cardStyle(padding: 20, cornerRadius: 20)
    }

    private var cancelledBannerInfo: (icon: String, title: String, subtitle: String)? {
        guard booking.bookingState == .cancelled else { return nil }
        if let expires = booking.holdExpiresAt, expires < Date() {
            return ("clock.badge.xmark.fill", "Request Expired", "Driver didn't respond in time")
        } else {
            return ("xmark.circle.fill", "Request Cancelled", "You cancelled this booking")
        }
    }

    @ViewBuilder
    private func actionsCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Actions")

            if let banner = cancelledBannerInfo {
                HStack(spacing: 12) {
                    Image(systemName: banner.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.brandRed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandRed)
                        Text(banner.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.brandRed.opacity(0.07))
                .cornerRadius(12)
            }

            if booking.status == .confirmed, [.enRoute, .arrived, .inProgress].contains(trip.status) {
                NavigationLink(destination: ActiveTripView(trip: trip, booking: booking, isDriver: showAsDriver)) {
                    actionPill(title: "Track Live Ride", icon: "location.fill", fill: Color.brand, fg: .white)
                }
            }

            if !showAsDriver && chatAvailable {
                NavigationLink(destination: ChatView(tripId: trip.id, otherPartyName: trip.driver?.name ?? "Driver", isDriver: false)) {
                    actionPill(title: "Chat with Driver", icon: "message.fill", fill: Color.brand.opacity(0.1), fg: .brand)
                }
            }

            // Rider: authorize payment hold after driver approves
            if !showAsDriver && booking.bookingState == .approved && booking.payment == nil {
                Button(action: { Task { await authorizePayment() } }) {
                    actionPill(
                        title: isAuthorizing ? "Authorizing…" : "Confirm & Pay Hold",
                        icon: "creditcard.fill",
                        fill: Color.brandGreen,
                        fg: .white
                    )
                }
                .disabled(isAuthorizing)
            }

            if !showAsDriver && booking.status == .pending {
                Button(action: {
                    Task {
                        _ = await vm.cancelBooking(id: booking.id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                }) {
                    actionPill(title: "Cancel Booking", icon: "xmark.circle.fill", fill: Color.brandRed.opacity(0.08), fg: .brandRed)
                }
            }

            // Driver can cancel any booking on their posted trips (except completed)
            if showAsDriver && booking.status != .completed && booking.status != .cancelled {
                Button(action: {
                    Task {
                        _ = await vm.cancelBooking(id: booking.id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                }) {
                    actionPill(title: "Cancel Booking", icon: "xmark.circle.fill", fill: Color.brandRed.opacity(0.08), fg: .brandRed)
                }
            }
        }
        .cardStyle(padding: 20, cornerRadius: 20)
    }

    private func actionPill(title: String, icon: String, fill: Color, fg: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .opacity(fg == .white ? 0.85 : 0.55)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(fg)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(fill)
        .cornerRadius(10)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.textPrimary)
    }

    private func infoPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.sheetBackground)
        .overlay(
            Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = .textPrimary,
        valueWeight: Font.Weight = .medium
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: valueWeight))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var chatAvailable: Bool {
        let activeStates = booking.bookingState == .pending
            || booking.bookingState == .approved
            || booking.status == .confirmed
        let recentlyCompleted = booking.status == .completed
            && (booking.trip?.departureTime ?? Date()) > Date().addingTimeInterval(-86400)
        return activeStates || recentlyCompleted
    }

    private var statusColor: Color {
        switch booking.bookingState {
        case .pending:   return .brandOrange
        case .approved:  return .brandGreen
        case .cancelled: return .brandRed
        case .rejected:  return .brandRed
        case .completed: return .textTertiary
        }
    }

    private func paymentStatusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .pending: return .brandOrange
        case .captured: return .brandGreen
        case .refunded: return .brand
        case .failed: return .brandRed
        }
    }

    private func paymentStatusLabel(_ status: PaymentStatus) -> String {
        switch status {
        case .pending:  return "Payment Held"
        case .captured: return "Paid"
        case .refunded: return "Refunded"
        case .failed:   return "Failed"
        }
    }
}
