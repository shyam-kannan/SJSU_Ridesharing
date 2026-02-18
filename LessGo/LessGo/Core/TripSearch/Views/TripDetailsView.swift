import SwiftUI
import UIKit
import MapKit

struct TripDetailsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookingVM = BookingViewModel()

    let trip: Trip

    @State private var region: MKCoordinateRegion
    @State private var seatsSelected = 1
    @State private var showBookingSheet = false
    @State private var showLoginPrompt = false
    @State private var showVerificationSheet = false

    init(trip: Trip) {
        self.trip = trip
        let center = trip.originPoint?.clLocationCoordinate2D ?? AppConstants.sjsuCoordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero Map ──
                heroMap
                    .frame(height: 220)
                    .clipped()

                VStack(spacing: 0) {
                    // ── Route Card ──
                    routeCard
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, -28) // overlap with map

                    // ── Driver Card ──
                    driverCard
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, AppConstants.itemSpacing)

                    // ── Trip Info Grid ──
                    infoGrid
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, AppConstants.itemSpacing)

                    // ── Seats Selector ──
                    seatsSelector
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.top, AppConstants.itemSpacing)

                    Spacer().frame(height: 120)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) { bookButton }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .sheet(isPresented: $showBookingSheet) {
            BookingConfirmationView(trip: trip, seats: seatsSelected)
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
            Map(coordinateRegion: $region,
                annotationItems: mapAnnotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(item.isDestination ? Color.brandRed : Color.brand)
                                .frame(width: 36, height: 36)
                            Image(systemName: item.isDestination ? "mappin" : "car.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Triangle()
                            .fill(item.isDestination ? Color.brandRed : Color.brand)
                            .frame(width: 12, height: 8)
                    }
                }
            }

            // Gradient overlay at bottom
            LinearGradient(
                colors: [.clear, Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Route Card

    private var routeCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                // Timeline dots
                VStack(spacing: 0) {
                    Circle().fill(Color.brand).frame(width: 12, height: 12)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2, height: 40)
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
        .padding(AppConstants.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppConstants.cardRadius)
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle().fill(Color.brand.opacity(0.12)).frame(width: 56, height: 56)
                Text(trip.driver?.name.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.brand)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.driver?.name ?? "Driver")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary)

                HStack(spacing: 6) {
                    StarRatingView(rating: trip.driver?.rating ?? 0, size: 13)
                    Text(String(format: "%.1f", trip.driver?.rating ?? 0))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.textSecondary)
                }

                if let vehicle = trip.driver?.vehicleInfo {
                    HStack(spacing: 5) {
                        Image(systemName: "car.fill").font(.system(size: 11)).foregroundColor(.textTertiary)
                        Text(vehicle).font(.system(size: 12)).foregroundColor(.textTertiary).lineLimit(1)
                    }
                }
            }

            Spacer()

            // Verified badge
            if trip.driver?.sjsuIdStatus == .verified {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22)).foregroundColor(.brandGreen)
                    Text("Verified").font(.system(size: 10, weight: .semibold)).foregroundColor(.brandGreen)
                }
            }
        }
        .cardStyle()
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
        .cardStyle()
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
                            .font(.system(size: 28))
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
                            .font(.system(size: 28))
                            .foregroundColor(seatsSelected < trip.seatsAvailable ? .brand : .gray.opacity(0.3))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Book Button

    private var bookButton: some View {
        VStack(spacing: 0) {
            Divider()
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
                    title: "Book This Ride",
                    icon: "checkmark.circle.fill",
                    isEnabled: authVM.currentUser?.sjsuIdStatus == .verified && trip.status == .active
                ) {
                    guard authVM.isAuthenticated else { showLoginPrompt = true; return }
                    showBookingSheet = true
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
        }
    }

    // MARK: - Helpers

    private var mapAnnotations: [MapPin] {
        var pins: [MapPin] = []
        if let origin = trip.originPoint {
            pins.append(MapPin(id: "origin", coordinate: origin.clLocationCoordinate2D, isDestination: false))
        }
        if let dest = trip.destinationPoint {
            pins.append(MapPin(id: "dest", coordinate: dest.clLocationCoordinate2D, isDestination: true))
        }
        return pins
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

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Map Pin Model

struct MapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isDestination: Bool
}
