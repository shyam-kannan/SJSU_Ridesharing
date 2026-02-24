import SwiftUI
import UIKit
import CoreLocation

struct TripDetailsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookingVM = BookingViewModel()

    let trip: Trip

    @State private var seatsSelected = 1
    @State private var showBookingSheet = false
    @State private var showLoginPrompt = false
    @State private var showVerificationSheet = false
    @State private var routeInfo: RouteMapInfo?
    @State private var hasCompletedBookingForThisTrip = false

    init(trip: Trip) {
        self.trip = trip
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Color(hex: "F4F6F2").ignoresSafeArea()
                Circle()
                    .fill(Color(hex: "A3E635").opacity(0.10))
                    .frame(width: 260)
                    .offset(x: 150, y: 540)
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 0) {
                    heroMap
                        .frame(height: 310)
                        .clipped()

                    VStack(spacing: 14) {
                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: 44, height: 5)
                            .padding(.top, 10)

                        routeCard
                        driverCard
                        infoGrid
                        seatsSelector

                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, AppConstants.pagePadding)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .offset(y: -36)
                    .padding(.bottom, -36)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) { bookButton }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .sheet(isPresented: $showBookingSheet) {
            BookingConfirmationView(trip: trip, seats: seatsSelected) {
                hasCompletedBookingForThisTrip = true
                dismiss()
            }
                .environmentObject(authVM)
                .environmentObject(bookingVM)
        }
        .alert("Sign In Required", isPresented: $showLoginPrompt) {
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need to be logged in to book a ride.")
        }
        .sheet(isPresented: $showVerificationSheet) {
            IDVerificationView()
                .environmentObject(authVM)
        }
        .errorAlert(message: $bookingVM.errorMessage)
    }

    // MARK: - Hero Map

    private var heroMap: some View {
        ZStack {
            RouteMapView(
                origin: trip.originPoint?.clLocationCoordinate2D,
                destination: trip.destinationPoint?.clLocationCoordinate2D,
                driver: nil,
                showsUserLocation: false,
                onRouteUpdated: { info in
                    routeInfo = info
                }
            )

            LinearGradient(
                colors: [Color.black.opacity(0.62), Color.black.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(
                colors: [.clear, Color(hex: "F4F6F2")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                        Text("Ride Preview")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    Spacer()
                    HStack(spacing: 8) {
                        Label(routeDistanceText, systemImage: "arrow.left.and.right")
                        Label(estimatedDriveTimeText, systemImage: "clock")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Capsule())
                }
                .padding(.top, 58)
                .padding(.horizontal, AppConstants.pagePadding)
                Spacer()
            }
        }
    }

    // MARK: - Route Card

    private var routeCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip Route")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Text("Pickup to dropoff")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                routeMetricChip(icon: "point.topleft.down.curvedto.point.bottomright.up", text: routeDistanceText, color: .brand)
                routeMetricChip(icon: "clock", text: estimatedDriveTimeText, color: Color(hex: "84CC16"))
                Spacer()
            }

            HStack(alignment: .top, spacing: 14) {
                // Timeline dots
                VStack(spacing: 0) {
                    Circle().fill(Color.brand).frame(width: 14, height: 14)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2, height: 42)
                    Image(systemName: "mappin.circle.fill").font(.system(size: 16)).foregroundColor(.brandRed)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pickup").font(.system(size: 11, weight: .semibold)).foregroundColor(.textTertiary).textCase(.uppercase)
                        Text(trip.origin).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dropoff").font(.system(size: 11, weight: .semibold)).foregroundColor(.textTertiary).textCase(.uppercase)
                        Text(trip.destination).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.brand.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private func routeMetricChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(999)
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.sjsuBlue.opacity(0.18), DesignSystem.Colors.sjsuBlue.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.sjsuBlue.opacity(0.5), DesignSystem.Colors.sjsuTeal.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                Text(trip.driver?.name.prefix(1).uppercased() ?? "D")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.brand)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Driver")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)

                HStack(spacing: 6) {
                    StarRatingView(rating: trip.driver?.rating ?? 0, size: 13)
                    Text(String(format: "%.1f", trip.driver?.rating ?? 0))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.78))
                }

                HStack(spacing: 5) {
                    Image(systemName: "car.fill").font(.system(size: 11)).foregroundColor(.white.opacity(0.56))
                    Text("Details revealed after payment").font(.system(size: 12)).foregroundColor(.white.opacity(0.56))
                }
            }

            Spacer()

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "17191E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if trip.driver?.sjsuIdStatus == .verified {
                Label("Verified", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.brandGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.brandGreen.opacity(0.15), Color.brandGreen.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(999)
                    .padding(12)
            }
        }
    }

    // MARK: - Info Grid

    private var infoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            InfoCell(icon: "clock.fill", label: "Departure", value: trip.departureTime.tripTimeString, color: .brand)
            InfoCell(icon: "calendar", label: "Date", value: trip.departureTime.tripDateString, color: .brand)
            InfoCell(icon: "person.2.fill", label: "Seats Left", value: "\(trip.seatsAvailable)", color: .brandGreen)
            if let recurrence = trip.recurrence {
                InfoCell(icon: "repeat", label: "Recurrence", value: recurrence.capitalized, color: .brandOrange)
            } else {
                InfoCell(icon: "1.circle.fill", label: "Trip Type", value: "One-time", color: .textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Seats Selector

    private var seatsSelector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Seats to Book")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack {
                Text("How many seats do you need?")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: {
                        if seatsSelected > 1 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            seatsSelected -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(seatsSelected > 1 ? .brand : .gray.opacity(0.3))
                    }

                    Text("\(seatsSelected)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 32)

                    Button(action: {
                        if seatsSelected < trip.seatsAvailable {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            seatsSelected += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(seatsSelected < trip.seatsAvailable ? .brand : .gray.opacity(0.3))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Book Button

    private var bookButton: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {

                // Verification required banner (tappable)
                if authVM.currentUser?.sjsuIdStatus != .verified {
                    Button(action: {
                        guard authVM.isAuthenticated else { showLoginPrompt = true; return }
                        showVerificationSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .font(.system(size: 14))
                            Text("SJSU ID verification required — ")
                                .font(.system(size: 13))
                            + Text("Verify Now →")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.brandOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.brandOrange.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.brandOrange.opacity(0.4), lineWidth: 1)
                        )
                    }
                }

                PrimaryButton(
                    title: hasCompletedBookingForThisTrip ? "Booked" : "Book This Ride",
                    icon: "checkmark.circle.fill",
                    isEnabled: !hasCompletedBookingForThisTrip &&
                        authVM.currentUser?.sjsuIdStatus == .verified &&
                        trip.status == .pending
                ) {
                    guard authVM.isAuthenticated else { showLoginPrompt = true; return }
                    showBookingSheet = true
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .overlay(alignment: .top) { Divider().opacity(0.3) }

            // HomeView uses a floating custom tab bar overlay, so reserve space
            // when TripDetails is pushed from the rider tab stack.
            Color.clear
                .frame(height: 86)
        }
    }

    // MARK: - Helpers

    private var routeDistanceText: String {
        if let info = routeInfo {
            let miles = info.distanceMeters / 1609.344
            return String(format: "%.1f mi", miles)
        }
        guard let origin = trip.originPoint, let dest = trip.destinationPoint else { return "Distance unavailable" }
        let a = CLLocation(latitude: origin.lat, longitude: origin.lng)
        let b = CLLocation(latitude: dest.lat, longitude: dest.lng)
        let miles = a.distance(from: b) / 1609.344
        return String(format: "%.1f mi", miles)
    }

    private var estimatedDriveTimeText: String {
        let mins: Int
        if let info = routeInfo {
            mins = max(1, Int(info.expectedTravelTime / 60.0))
        } else {
            guard let origin = trip.originPoint, let dest = trip.destinationPoint else { return "ETA unavailable" }
            let a = CLLocation(latitude: origin.lat, longitude: origin.lng)
            let b = CLLocation(latitude: dest.lat, longitude: dest.lng)
            let miles = a.distance(from: b) / 1609.344
            mins = max(5, Int((miles / 28.0) * 60.0))
        }
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) min"
    }

}

// MARK: - Info Cell

struct InfoCell: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .brand

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
