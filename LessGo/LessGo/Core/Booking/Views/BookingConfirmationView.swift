import SwiftUI
import UIKit

struct BookingConfirmationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var bookingVM: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let seats: Int

    @State private var step: Step = .review
    @State private var showSuccess = false
    @State private var showVerificationAlert = false
    @State private var showIDVerificationSheet = false

    enum Step { case review, paying }

    var estimatedPrice: Double { Double(seats) * 8.50 }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if showSuccess {
                    BookingSuccessView(trip: trip) { dismiss() }
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                removal: .opacity))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // ── Summary Header ──
                            VStack(spacing: 6) {
                                Text("Confirm Booking")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                Text("Review your trip details")
                                    .font(.system(size: 15))
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 28)

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
                            .background(Color.cardBackground)
                            .cornerRadius(AppConstants.cardRadius)
                            .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
                            .padding(.horizontal, AppConstants.pagePadding)

                            // ── Price Breakdown ──
                            VStack(spacing: 12) {
                                Text("Price Breakdown")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                PriceRow(label: "Per seat", value: "$8.50")
                                PriceRow(label: "Seats", value: "× \(seats)")
                                Divider()
                                PriceRow(label: "Total", value: String(format: "$%.2f", estimatedPrice), isBold: true)
                            }
                            .cardStyle()
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
                                title: "Confirm & Pay \(String(format: "$%.2f", estimatedPrice))",
                                icon: "lock.fill",
                                isLoading: bookingVM.isCreating || bookingVM.isLoading
                            ) { confirmBooking() }
                            .padding(.horizontal, AppConstants.pagePadding)
                            .padding(.vertical, 16)
                            .background(Color.cardBackground)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary).padding(8).background(Color.appBackground).clipShape(Circle())
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
        // Client-side verification guard — catches unverified users before the network call
        guard authVM.currentUser?.sjsuIdStatus == .verified else {
            showVerificationAlert = true
            return
        }

        Task {
            let success = await bookingVM.createBooking(tripId: trip.id, seats: seats)
            if success, let bookingId = bookingVM.currentBooking?.id {
                let paid = await bookingVM.confirmAndPay(bookingId: bookingId, amount: estimatedPrice)
                if paid { withAnimation { showSuccess = true } }
            } else if let errMsg = bookingVM.errorMessage,
                      errMsg.lowercased().contains("verif") {
                // Backend also rejects unverified bookings — surface the verification flow
                bookingVM.errorMessage = nil
                showVerificationAlert = true
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
    let onDone: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated checkmark
            ZStack {
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
                    .font(.system(size: 28, weight: .bold))
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
            .background(Color.brand.opacity(0.08))
            .cornerRadius(14)

            Spacer()

            PrimaryButton(title: "Done", icon: "checkmark") { onDone() }
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1; opacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Booking List View

struct BookingListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = BookingViewModel()
    @State private var showAsDriver = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segment
                if authVM.isDriver {
                    Picker("View", selection: $showAsDriver) {
                        Text("As Rider").tag(false)
                        Text("As Driver").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.cardBackground)
                }

                if vm.isLoading {
                    SkeletonTripList().padding(.top, 12)
                    Spacer()
                } else if vm.bookings.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.plus",
                        title: "No bookings yet",
                        message: showAsDriver ? "Your passengers will appear here" : "Find a ride and get going!",
                        actionTitle: showAsDriver ? nil : "Find Rides"
                    ) {}
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppConstants.itemSpacing) {
                            ForEach(vm.bookings) { booking in
                                BookingRow(booking: booking, vm: vm)
                                    .padding(.horizontal, AppConstants.pagePadding)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .refreshable { await vm.loadBookings(asDriver: showAsDriver) }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(showAsDriver ? "Passengers" : "My Trips")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.loadBookings(asDriver: showAsDriver) }
            .onChange(of: showAsDriver) { newVal in
                Task { await vm.loadBookings(asDriver: newVal) }
            }
        }
    }
}

// MARK: - Booking Row

private struct BookingRow: View {
    let booking: Booking
    @ObservedObject var vm: BookingViewModel

    var statusColor: Color {
        switch booking.status {
        case .pending:   return .brandOrange
        case .confirmed: return .brandGreen
        case .cancelled: return .brandRed
        case .completed: return .textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(booking.status.rawValue.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                Spacer()
                Text(booking.createdAt.timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }

            if let trip = booking.trip {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.brand).font(.system(size: 16))
                    Text("\(trip.origin) → \(trip.destination)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 12))
                        Text(trip.departureTime.tripDateTimeString).font(.system(size: 13))
                    }
                    .foregroundColor(.textSecondary)
                    Spacer()
                    if let amount = booking.quote?.maxPrice {
                        Text(String(format: "$%.2f", amount))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.brandGreen)
                    }
                }
            }

            // Cancel button for pending bookings
            if booking.status == .pending {
                Button(action: { Task { await vm.cancelBooking(id: booking.id) } }) {
                    Text("Cancel Booking")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.brandRed.opacity(0.08))
                        .cornerRadius(10)
                }
            }
        }
        .cardStyle()
    }
}
