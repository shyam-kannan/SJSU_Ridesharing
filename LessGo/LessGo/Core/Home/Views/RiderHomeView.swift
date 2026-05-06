import SwiftUI
import MapKit
import Combine
import CoreLocation

// MARK: - Direction Choice

private enum DirectionChoice: Equatable {
    case none
    case toSJSU    // origin = editable, destination = locked (SJSU)
    case fromSJSU  // origin = locked (SJSU), destination = editable
}

// MARK: - RiderHomeView

struct RiderHomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var requestVM = TripRequestViewModel()
    @StateObject private var locationManager = LocationManager.shared

    @State private var region = MKCoordinateRegion(
        center: AppConstants.sjsuCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var trackingMode: MapUserTrackingMode = .follow
    @State private var hasInitiallyCentered = false
    @State private var showAccountMenu = false
    @State private var showNotifications = false
    @State private var showFinding = false
    @State private var showMatchedRide = false
    @State private var matchedTripStatus: TripRequestStatus? = nil
    @State private var showIDVerificationSheet = false
    @State private var unreadNotificationCount = 0
    @State private var notificationChatDestination: NotificationChatDestination?
    @State private var useLeaveNow = true

    // Posted rides search flow
    @State private var showSearchResults = false
    @State private var searchCriteria: SearchCriteria?

    // Direction-first flow
    @State private var directionChoice: DirectionChoice = .none
    @State private var editableQuery = ""
    @State private var autocompleteResults: [DestinationPlace] = []
    @State private var isAutocompleting = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @FocusState private var editableFieldFocused: Bool

    // Sheet drag state
    // BUG 2 FIX: sheet has two defined heights; DragGesture on handle toggles between them.
    @State private var sheetExpanded = false
    @State private var liveDragDelta: CGFloat = 0   // positive = user dragging down (shrink), negative = up (grow)

    private let collapsedSheetHeight: CGFloat = 390  // direction-choice screen
    private let expandedSheetHeight: CGFloat = 530   // input + departure + button (no autocomplete)
    private let maxSheetHeight: CGFloat = 720        // ceiling when user drags up hard

    private var currentSheetHeight: CGFloat {
        let base: CGFloat = sheetExpanded ? expandedSheetHeight : collapsedSheetHeight
        // liveDragDelta < 0 means dragging up = bigger sheet
        let adjusted = base - liveDragDelta
        return min(maxSheetHeight, max(collapsedSheetHeight, adjusted))
    }

    private let sjsuName = "San Jose State University"

    private let notificationBadgeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Map constrained to upper half
                    VStack(spacing: 0) {
                        ZStack {
                            Map(
                                coordinateRegion: $region,
                                interactionModes: .all,
                                showsUserLocation: true,
                                userTrackingMode: $trackingMode
                            )

                            // Locate me button
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        if let coord = locationManager.currentLocation?.coordinate {
                                            centerMap(on: coord)
                                            trackingMode = .follow
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 44, height: 44)
                                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.brand)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                        .frame(height: geometry.size.height - currentSheetHeight)
                        Spacer()
                    }
                    .ignoresSafeArea()

                    // Floating header
                    VStack {
                        floatingHeader
                            .padding(.horizontal, AppConstants.pagePadding)
                            .padding(.top, 56)
                        Spacer()
                    }

                    // Fixed-height bottom sheet
                    requestSheet
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView().environmentObject(authVM)
            }
            .sheet(isPresented: $showNotifications) {
                RiderNotificationsSheet(
                    onRefresh: {},
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
            .sheet(isPresented: $showIDVerificationSheet) {
                IDVerificationView().environmentObject(authVM)
            }
            .fullScreenCover(isPresented: $showSearchResults) {
                if let criteria = searchCriteria {
                    RiderSearchResultsView(criteria: criteria)
                }
            }
            .fullScreenCover(isPresented: $showFinding) {
                if case .searching(let requestId) = requestVM.state {
                    FindingDriverView(requestId: requestId, viewModel: requestVM)
                        .environmentObject(authVM)
                }
            }
            .fullScreenCover(isPresented: $showMatchedRide) {
                if let status = matchedTripStatus,
                   let originCoord = requestVM.originCoordinate,
                   let destCoord   = requestVM.destinationCoordinate {
                    MatchedRideView(
                        tripRequest: status,
                        originCoordinate: originCoord,
                        destinationCoordinate: destCoord,
                        originLabel: requestVM.origin,
                        destinationLabel: requestVM.destination
                    )
                    .environmentObject(authVM)
                    .onDisappear {
                        // Reset the request VM so the home screen returns to idle
                        requestVM.reset()
                        resetDirection()
                    }
                }
            }
            .onChange(of: requestVM.state) { newState in
                switch newState {
                case .searching:
                    showFinding = true
                case .matched(let status):
                    showFinding = false
                    matchedTripStatus = status
                    // Small delay so FindingDriverView dismisses cleanly before presenting MatchedRideView
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showMatchedRide = true
                    }
                case .failed:
                    showFinding = false
                default:
                    break
                }
            }
            .onChange(of: locationManager.currentLocation) { newLocation in
                guard !hasInitiallyCentered, let coord = newLocation?.coordinate else { return }
                hasInitiallyCentered = true
                centerMap(on: coord)
            }
            .onReceive(notificationBadgeTimer) { _ in
                Task { await refreshNotificationBadge() }
            }
            .onAppear {
                locationManager.requestPermission()
                locationManager.startLocationUpdates()
                if !hasInitiallyCentered, let coord = locationManager.currentLocation?.coordinate {
                    hasInitiallyCentered = true
                    centerMap(on: coord)
                }
                Task {
                    await refreshNotificationBadge()
                    prefillOriginFromLocation()
                }
            }
        }
    }

    // MARK: - Floating Header

    private var floatingHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("LessGo")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.82))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            )

            Spacer()

            Button(action: { showNotifications = true }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .overlay(alignment: .topTrailing) {
                    if unreadNotificationCount > 0 {
                        Circle()
                            .fill(Color.brandRed)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                            .offset(x: -3, y: 3)
                    }
                }
            }
            .buttonStyle(.plain)

            Button(action: { showAccountMenu = true }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Request Sheet
    //
    // BUG 2 FIX: Sheet has a defined height (currentSheetHeight) that responds to:
    //   1. directionChoice state (auto-expand when direction selected)
    //   2. DragGesture on the handle bar (user-controlled expansion)
    // Content lives inside a ScrollView so autocomplete results are always reachable (BUG 1 FIX).

    private var requestSheet: some View {
        VStack(spacing: 0) {
            // ── Drag handle — gesture is attached here, not inside the ScrollView ──
            dragHandle

            // ── Scrollable content area ──
            // BUG 1 FIX: All sheet content is inside a ScrollView. When autocomplete
            // results push content taller than the current sheet height, the user can
            // scroll to see every suggestion without the view being clipped.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if directionChoice == .none {
                        directionChoiceContent
                    } else {
                        directionInputContent
                    }
                }
            }
        }
        .frame(height: currentSheetHeight)
        .background(Color.cardBackground)
        .cornerRadius(28, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentSheetHeight)
    }

    // MARK: - Drag Handle
    //
    // BUG 2 FIX: DragGesture is wired here. Dragging up (negative translation.height)
    // expands the sheet. Dragging down collapses it. A 60pt threshold prevents accidental
    // toggles. liveDragDelta gives live feedback during the gesture.

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.gray.opacity(0.35))
            .frame(width: 40, height: 4)
            // Enlarge the tap/drag target so it is easy to grab
            .padding(.vertical, 16)
            .padding(.horizontal, 80)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .onChanged { value in
                        liveDragDelta = value.translation.height
                    }
                    .onEnded { value in
                        let dy = value.translation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            if dy < -60 {
                                // Dragged up → expand
                                sheetExpanded = true
                            } else if dy > 60 {
                                // Dragged down → collapse; reset direction if needed
                                sheetExpanded = false
                                if directionChoice != .none {
                                    resetDirection()
                                }
                            }
                            liveDragDelta = 0
                        }
                    }
            )
    }

    // MARK: - Direction Choice Content (initial, collapsed state)

    private var directionChoiceContent: some View {
        VStack(spacing: 0) {
            // Greeting
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Where to,")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("\(authVM.currentUser?.name.components(separatedBy: " ").first ?? "there")?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.brand)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Two large direction buttons
            VStack(spacing: 14) {
                directionButton(
                    label: "To SJSU",
                    subtitle: "Heading to campus",
                    icon: "building.columns.fill",
                    iconColor: .brand
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        directionChoice = .toSJSU
                        requestVM.destination = sjsuName
                        requestVM.destinationCoordinate = AppConstants.sjsuCoordinate
                        editableQuery = requestVM.origin
                        autocompleteResults = []
                        sheetExpanded = true   // auto-expand on direction selection
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editableFieldFocused = true
                    }
                }

                directionButton(
                    label: "From SJSU",
                    subtitle: "Leaving campus",
                    icon: "arrow.turn.up.right",
                    iconColor: .brandGreen
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        directionChoice = .fromSJSU
                        requestVM.origin = sjsuName
                        requestVM.originCoordinate = AppConstants.sjsuCoordinate
                        editableQuery = requestVM.destination
                        autocompleteResults = []
                        sheetExpanded = true   // auto-expand on direction selection
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editableFieldFocused = true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private func directionButton(
        label: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Direction Input Content (after direction selected, expanded state)

    private var directionInputContent: some View {
        VStack(spacing: 0) {
            // Header: direction label + X reset
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: directionChoice == .toSJSU ? "building.columns.fill" : "arrow.turn.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brand)
                    Text(directionChoice == .toSJSU ? "To SJSU" : "From SJSU")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brand)
                }
                Spacer()
                Button(action: resetDirection) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // From / To input card
            VStack(spacing: 0) {
                if directionChoice == .toSJSU {
                    editableFieldRow(placeholder: "Enter pickup location", dotColor: .brandGold)
                    Divider().padding(.leading, 40)
                    lockedFieldRow(text: sjsuName, icon: "mappin.circle.fill", iconColor: .brand)
                } else {
                    lockedFieldRow(text: sjsuName, dot: true)
                    Divider().padding(.leading, 40)
                    editableFieldRow(placeholder: "Enter drop-off location", dotColor: .brandGreen, isDestination: true)
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Autocomplete results or spinner
            // BUG 1 FIX: results are rendered in a VStack directly inside the parent ScrollView,
            // so ALL results are visible and the user can scroll to reach them. There is no inner
            // clipping or fixed-height constraint truncating the list to one row.
            if !autocompleteResults.isEmpty {
                autocompleteDropdown
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            } else if isAutocompleting {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Searching…")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .padding(.bottom, 4)
            }

            // Departure time row
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)

                if useLeaveNow {
                    Button(action: { withAnimation { useLeaveNow = false } }) {
                        HStack(spacing: 6) {
                            Text("Leave now")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    DatePicker(
                        "",
                        selection: $requestVM.departureTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()

                    Button(action: {
                        withAnimation { useLeaveNow = true }
                        requestVM.departureTime = Date().addingTimeInterval(300)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // Error banner
            if case .failed(let msg) = requestVM.state {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(.brandRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Request Ride button
            Button(action: {
                if useLeaveNow { requestVM.departureTime = Date().addingTimeInterval(300) }
                editableFieldFocused = false

                // Create search criteria and navigate to search results
                let direction: SearchCriteria.TripDirection
                let location: String
                let coordinate: CLLocationCoordinate2D

                switch directionChoice {
                case .toSJSU:
                    direction = .toSJSU
                    location = requestVM.origin
                    coordinate = requestVM.originCoordinate ?? AppConstants.sjsuCoordinate
                case .fromSJSU:
                    direction = .fromSJSU
                    location = requestVM.destination
                    coordinate = requestVM.destinationCoordinate ?? AppConstants.sjsuCoordinate
                case .none:
                    return
                }

                searchCriteria = SearchCriteria(
                    direction: direction,
                    location: location,
                    coordinate: coordinate,
                    departureTime: requestVM.departureTime
                )
                showSearchResults = true
            }) {
                HStack(spacing: 10) {
                    if case .submitting = requestVM.state {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isSubmitting ? "Searching..." : "Search Rides")
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSubmit ? Color.brand : Color.brand.opacity(0.4))
                .cornerRadius(16)
            }
            .disabled(!canSubmit)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Field Rows

    private func editableFieldRow(
        placeholder: String,
        dotColor: Color,
        isDestination: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
            TextField(placeholder, text: $editableQuery)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)
                .focused($editableFieldFocused)
                .autocorrectionDisabled()
                .onChange(of: editableQuery) { value in
                    scheduleSearch(value)
                }
            if !editableQuery.isEmpty {
                Button(action: {
                    editableQuery = ""
                    autocompleteResults = []
                    searchDebounceTask?.cancel()
                    isAutocompleting = false
                    if isDestination {
                        requestVM.destination = ""
                        requestVM.destinationCoordinate = nil
                    } else {
                        requestVM.origin = ""
                        requestVM.originCoordinate = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func lockedFieldRow(
        text: String,
        dot: Bool = false,
        icon: String? = nil,
        iconColor: Color = .brand
    ) -> some View {
        HStack(spacing: 14) {
            if dot {
                Circle()
                    .fill(Color.brandGold)
                    .frame(width: 10, height: 10)
            } else if let icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14))
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Autocomplete Dropdown
    //
    // BUG 1 FIX: this view renders ALL results in a plain VStack. There is no inner
    // ScrollView or height cap — the parent ScrollView (in requestSheet) handles
    // scrollability. Every result from the search is visible; none are clipped.

    private var autocompleteDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(autocompleteResults.enumerated()), id: \.element.id) { idx, place in
                Button(action: { selectPlace(place) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.textSecondary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "mappin")
                                .foregroundColor(.textSecondary)
                                .font(.system(size: 13))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            if !place.subtitle.isEmpty {
                                Text(place.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if idx < autocompleteResults.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !requestVM.destination.isEmpty &&
        requestVM.destinationCoordinate != nil &&
        !requestVM.origin.isEmpty &&
        requestVM.originCoordinate != nil &&
        requestVM.state != .submitting
    }

    private var isSubmitting: Bool {
        switch requestVM.state {
        case .submitting, .searching: return true
        default: return false
        }
    }

    private func resetDirection() {
        searchDebounceTask?.cancel()
        editableQuery = ""
        autocompleteResults = []
        isAutocompleting = false
        directionChoice = .none
        sheetExpanded = false
        requestVM.origin = ""
        requestVM.originCoordinate = nil
        requestVM.destination = ""
        requestVM.destinationCoordinate = nil
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        }
    }

    private func selectPlace(_ place: DestinationPlace) {
        editableFieldFocused = false
        searchDebounceTask?.cancel()
        autocompleteResults = []
        isAutocompleting = false
        editableQuery = place.name

        switch directionChoice {
        case .toSJSU:
            requestVM.origin = place.name
            requestVM.originCoordinate = place.coordinate
        case .fromSJSU:
            requestVM.destination = place.name
            requestVM.destinationCoordinate = place.coordinate
        case .none:
            break
        }
    }

    private func scheduleSearch(_ query: String) {
        searchDebounceTask?.cancel()
        guard query.count >= 2 else {
            autocompleteResults = []
            isAutocompleting = false
            return
        }
        isAutocompleting = true
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    @MainActor
    private func performSearch(_ query: String) async {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        // Bias toward San Jose / Bay Area, ~50km radius centered on SJSU
        req.region = MKCoordinateRegion(
            center: AppConstants.sjsuCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.9, longitudeDelta: 0.9)
        )
        do {
            let response = try await MKLocalSearch(request: req).start()
            autocompleteResults = response.mapItems.prefix(6).map { item in
                DestinationPlace(
                    name: item.name ?? item.placemark.title ?? "Unknown",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
        } catch {
            autocompleteResults = []
        }
        isAutocompleting = false
    }

    private func prefillOriginFromLocation() {
        guard let loc = locationManager.currentLocation else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            if let pm = placemarks?.first {
                let addr = [pm.name, pm.locality].compactMap { $0 }.joined(separator: ", ")
                Task { @MainActor in
                    requestVM.origin = addr
                    requestVM.originCoordinate = loc.coordinate
                }
            }
        }
    }

    private func refreshNotificationBadge() async {
        guard let userId = authVM.currentUser?.id else { return }
        do {
            let response = try await NotificationService.shared.listNotifications(userId: userId, limit: 1)
            unreadNotificationCount = response.unreadCount
        } catch {}
    }
}

// MARK: - Destination Place Model

private struct DestinationPlace: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Rider Notifications Sheet

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
                                    if item.isUnread { Task { await markRead(item) } }
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
                        .background(Color.sheetBackground)
                        .cornerRadius(12)

                    Button(action: { onRefresh(); dismiss() }) {
                        Text("Refresh Rides")
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

    private func notificationRow(_ item: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(iconColor(for: item).opacity(0.10)).frame(width: 34, height: 34)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(iconColor(for: item))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary)
                Text(item.message).font(.system(size: 12)).foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.createdAt.timeAgo).font(.system(size: 11, weight: .medium)).foregroundColor(.textTertiary)
            }
            Spacer()
            if item.isUnread {
                Circle().fill(Color.brandRed).frame(width: 7, height: 7).padding(.top, 6)
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
        isLoading = true; errorMessage = nil; defer { isLoading = false }
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
                    id: notifications[idx].id, userId: notifications[idx].userId,
                    type: notifications[idx].type, title: notifications[idx].title,
                    message: notifications[idx].message, data: notifications[idx].data,
                    createdAt: notifications[idx].createdAt, readAt: Date()
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
