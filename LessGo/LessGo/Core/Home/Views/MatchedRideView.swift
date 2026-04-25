import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

// MARK: - Active Ride Phase State Machine
// idle → matched → driverEnRoute → driverArrived → inTrip → completed | cancelled
//
// `matched`      – driver assigned, pending acceptance (or dev auto-committed)
// `driverEnRoute`– driver headed to rider's pickup pin
// `driverArrived`– driver within 100 m of pickup
// `inTrip`       – rider is in the car, headed to destination
// `completed`    – trip finished
// `cancelled`    – either party cancelled

enum ActiveRidePhase: String, Equatable {
    case matched
    case driverEnRoute
    case driverArrived
    case inTrip
    case completed
    case cancelled
}

// MARK: - MatchedRideView

struct MatchedRideView: View {
    let tripRequest: TripRequestStatus
    let originCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let originLabel: String
    let destinationLabel: String

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var locationService = LocationTrackingService.shared
    @ObservedObject private var locationManager = LocationManager.shared

    // ── Phase ──────────────────────────────────────────────────────────────────
    @State private var phase: ActiveRidePhase = .matched

    // ── Map ────────────────────────────────────────────────────────────────────
    @State private var mapRegion: MKCoordinateRegion

    // ── Driver profile (loaded once) ───────────────────────────────────────────
    @State private var driverProfile: User? = nil

    // ── Chat ───────────────────────────────────────────────────────────────────
    @State private var showChat = false
    @State private var chatUnreadBadge = 0
    private let chatPollTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    // ── Misc sheet/alert ───────────────────────────────────────────────────────
    @State private var showSafety = false
    @State private var showCancelConfirm = false
    @State private var isCancelling = false
    @State private var errorMessage: String?

    // ── Entry animations ───────────────────────────────────────────────────────
    @State private var sheetAppeared = false
    @State private var driverCardAppeared = false

    // ── ETA ────────────────────────────────────────────────────────────────────
    @State private var etaMinutes: Int? = nil
    private let etaTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // ── Smooth driver coordinate (interpolated between GPS updates) ────────────
    @State private var smoothDriverCoord: CLLocationCoordinate2D? = nil
    @State private var smoothingTask: Task<Void, Never>? = nil

    // ── Convenience ────────────────────────────────────────────────────────────
    var matchedTripId: String  { tripRequest.matchedTripId ?? "" }
    var driverName: String     { tripRequest.driverName ?? "Your Driver" }
    var driverFirstName: String { driverName.components(separatedBy: " ").first ?? driverName }
    var driverRating: Double   { tripRequest.driverRating ?? 5.0 }
    var vehicleInfo: String    { tripRequest.driverVehicleInfo ?? "Vehicle" }
    var licensePlate: String   { driverProfile?.licensePlate ?? "" }

    // MARK: - Init

    init(
        tripRequest: TripRequestStatus,
        originCoordinate: CLLocationCoordinate2D,
        destinationCoordinate: CLLocationCoordinate2D,
        originLabel: String,
        destinationLabel: String
    ) {
        self.tripRequest = tripRequest
        self.originCoordinate = originCoordinate
        self.destinationCoordinate = destinationCoordinate
        self.originLabel = originLabel
        self.destinationLabel = destinationLabel

        let centerLat = (originCoordinate.latitude + destinationCoordinate.latitude) / 2
        let centerLng = (originCoordinate.longitude + destinationCoordinate.longitude) / 2
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
        ))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── Map (top ~55%) ────────────────────────────────────────────
                AnchorRouteMapView(
                    origin: originCoordinate,
                    destination: destinationCoordinate,
                    driver: smoothDriverCoord,
                    anchorPoints: [],
                    showsUserLocation: true
                )
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height * 0.58)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .topTrailing) {
                    etaBadge
                        .padding(.top, 56)
                        .padding(.trailing, 14)
                }

                // ── Bottom sheet ──────────────────────────────────────────────
                bottomSheet
                    .offset(y: sheetAppeared ? 0 : geo.size.height * 0.55)
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: sheetAppeared)
            }
            .background(Color.appBackground)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .task {
            // Haptic feedback on match
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Start driver location polling
            if !matchedTripId.isEmpty {
                LocationTrackingService.shared.startPollingDriverLocation(tripId: matchedTripId)
            }

            // Slide up sheet
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                sheetAppeared = true
            }
            // Fade in driver card
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeIn(duration: 0.3)) { driverCardAppeared = true }

            // Load driver profile for license plate
            await loadDriverProfile()

            // Compute initial ETA
            computeETA()
        }
        .onDisappear {
            LocationTrackingService.shared.stopPollingDriverLocation()
        }
        .onReceive(etaTimer) { _ in
            computeETA()
        }
        .onReceive(chatPollTimer) { _ in
            Task { await refreshChatUnread() }
        }
        .onChange(of: locationService.driverLocation?.latitude) { _ in
            checkDriverArrival()
            interpolateDriverCoordinate()
        }
        .onChange(of: locationService.driverLocation?.longitude) { _ in
            checkDriverArrival()
            interpolateDriverCoordinate()
        }
        .sheet(isPresented: $showChat, onDismiss: {
            Task { await refreshChatUnread() }
        }) {
            ChatView(
                tripId: matchedTripId,
                otherPartyName: driverName,
                isDriver: false,
                includesTabBarClearance: false
            )
            .environmentObject(authVM)
        }
        .sheet(isPresented: $showSafety) {
            safetySheet
        }
        .confirmationDialog(
            "Cancel your ride?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Confirm cancel", role: .destructive) {
                Task { await cancelRide() }
            }
            Button("Keep ride", role: .cancel) {}
        } message: {
            Text("You may be charged a cancellation fee.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - ETA Badge

    private var etaBadge: some View {
        Group {
            if let eta = etaMinutes {
                VStack(spacing: 2) {
                    Text("\(eta)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Text("min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
            }
        }
    }

    // MARK: - Bottom Sheet

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            // Row 1 — Pickup instruction
            pickupInstructionRow
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            // Row 2 — Driver card
            driverCard
                .opacity(driverCardAppeared ? 1 : 0)
                .scaleEffect(driverCardAppeared ? 1 : 0.96, anchor: .top)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            // Row 3 — Action bar
            actionBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            // Row 4 — Cancel
            Button(action: { showCancelConfirm = true }) {
                Text("Cancel ride")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .disabled(isCancelling)

            Spacer(minLength: 0)
                .frame(height: 20)
        }
        .background(Color.cardBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
    }

    // MARK: - Pickup Instruction Row

    private var pickupInstructionRow: some View {
        HStack(spacing: 14) {
            // Walk time icon
            VStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.brand)
                Text(walkTime)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.brand)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Meet at your pickup spot")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(pickupStreet)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 52, height: 52)
                Text(driverFirstName.prefix(1).uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(driverFirstName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.textPrimary)

                if !licensePlate.isEmpty {
                    Text(licensePlate.uppercased())
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.darkBrandSurface)
                        .cornerRadius(8)
                }

                Text(vehicleInfo)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Rating
            VStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.brandGold)
                Text(String(format: "%.1f", Double(driverRating)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: "message.fill",
                label: "Message",
                badge: chatUnreadBadge > 0 ? "\(chatUnreadBadge)" : nil
            ) {
                chatUnreadBadge = 0
                showChat = true
            }

            Spacer()

            actionButton(icon: "phone.fill", label: "Call") {
                // Call button — opens phone dialer.
                // Driver phone is not stored in the current data model;
                // this opens the tel: scheme with a prompt if unavailable.
                if let url = URL(string: "tel://") {
                    UIApplication.shared.open(url)
                }
            }

            Spacer()

            actionButton(icon: "shield.fill", label: "Safety") {
                showSafety = true
            }
        }
        .padding(.horizontal, 20)
    }

    private func actionButton(
        icon: String,
        label: String,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.fieldBackground)
                            .frame(width: 56, height: 56)
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.brandRed)
                            .cornerRadius(8)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Safety Sheet (stub)

    private var safetySheet: some View {
        NavigationView {
            List {
                Section {
                    Label("Share trip status", systemImage: "square.and.arrow.up")
                    Label("Emergency services", systemImage: "phone.fill.badge.plus")
                        .foregroundColor(.brandRed)
                }
            }
            .navigationTitle("Safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showSafety = false }
                }
            }
        }
    }

    // MARK: - Computed helpers

    private var pickupStreet: String {
        // Extract first line of the origin label as the street name
        let parts = originLabel.components(separatedBy: ",")
        return parts.first?.trimmingCharacters(in: .whitespaces) ?? originLabel
    }

    private var walkTime: String {
        guard let currentLoc = locationManager.currentLocation else { return "—" }
        let dist = haversineMeters(currentLoc.coordinate, originCoordinate)
        let walkSeconds = dist / (5000.0 / 3600.0) // 5 km/h walking
        let mins = max(1, Int(walkSeconds / 60))
        return "\(mins) min"
    }

    // MARK: - Async helpers

    private func checkDriverArrival() {
        guard let loc = locationService.driverLocation, phase == .driverEnRoute else { return }
        let driverCoord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        let dist = haversineMeters(driverCoord, originCoordinate)
        if dist < 100 {
            withAnimation { phase = .driverArrived }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // Interpolates smoothDriverCoord from its current position to the new GPS fix
    // over 12 steps × 0.25s = 3s, matching the polling interval.
    // Each step triggers an updateUIView on AnchorRouteMapView which moves the car pin.
    private func interpolateDriverCoordinate() {
        guard let newLoc = locationService.driverLocation else { return }
        let target = CLLocationCoordinate2D(latitude: newLoc.latitude, longitude: newLoc.longitude)
        let start = smoothDriverCoord ?? target
        smoothingTask?.cancel()
        let steps = 12
        smoothingTask = Task {
            for i in 1...steps {
                guard !Task.isCancelled else { return }
                let t = Double(i) / Double(steps)
                let interp = CLLocationCoordinate2D(
                    latitude:  start.latitude  + (target.latitude  - start.latitude)  * t,
                    longitude: start.longitude + (target.longitude - start.longitude) * t
                )
                await MainActor.run { smoothDriverCoord = interp }
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 s
            }
        }
    }

    private func loadDriverProfile() async {
        guard let driverId = tripRequest.driverId, !driverId.isEmpty else { return }
        do {
            let user: User = try await NetworkManager.shared.request(
                endpoint: "/users/\(driverId)",
                method: .get,
                requiresAuth: false
            )
            await MainActor.run { driverProfile = user }
        } catch {
            // Non-fatal — license plate just stays hidden
            print("[MatchedRideView] Failed to load driver profile: \(error)")
        }
    }

    private func computeETA() {
        guard let coord = smoothDriverCoord ?? (locationService.driverLocation.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }) else {
            etaMinutes = 5
            return
        }
        let distMeters = haversineMeters(coord, originCoordinate)
        // 30 km/h average urban speed
        let travelSeconds = distMeters / (30_000.0 / 3600.0)
        etaMinutes = max(1, Int(travelSeconds / 60))
    }

    private func refreshChatUnread() async {
        guard !matchedTripId.isEmpty else { return }
        // Count messages where sender is NOT the current user and createdAt > last seen
        // Simple proxy: fetch messages and count ones not from current rider
        // This is a polling-based unread count — lightweight for the action bar badge
        guard let myId = authVM.currentUser?.id else { return }
        do {
            let messages = try await ChatService.shared.getMessages(tripId: matchedTripId)
            let unread = messages.filter { $0.senderId != myId }.count
            // We only show badge if chat is not open, but reset when opened
            if !showChat {
                await MainActor.run { chatUnreadBadge = unread }
            }
        } catch { }
    }

    private func cancelRide() async {
        isCancelling = true
        // For a matched request with no booking yet, cancel the trip_request
        // by marking status=cancelled via the backend (if endpoint exists),
        // or simply dismiss and reset state
        // Using the trip cancel endpoint on the matched trip
        if !matchedTripId.isEmpty {
            _ = try? await TripService.shared.cancelTrip(id: matchedTripId)
        }
        isCancelling = false
        await MainActor.run { dismiss() }
    }
}

// MARK: - Haversine helper

private func haversineMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let R = 6_371_000.0
    let φ1 = a.latitude * .pi / 180
    let φ2 = b.latitude * .pi / 180
    let Δφ = (b.latitude - a.latitude) * .pi / 180
    let Δλ = (b.longitude - a.longitude) * .pi / 180
    let s = sin(Δφ/2)*sin(Δφ/2) + cos(φ1)*cos(φ2)*sin(Δλ/2)*sin(Δλ/2)
    return R * 2 * atan2(sqrt(s), sqrt(1-s))
}
