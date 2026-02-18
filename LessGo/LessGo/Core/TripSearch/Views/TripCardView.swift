import SwiftUI

// MARK: - Main Trip Card (List View)

struct TripCardView: View {
    let trip: Trip
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: Driver + Price ──
            HStack(alignment: .top, spacing: 12) {
                // Driver Avatar
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(trip.driver?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brand)
                }

                // Driver Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.driver?.name ?? "Driver")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 4) {
                        StarRatingView(rating: trip.driver?.rating ?? 0, size: 11)
                        Text(String(format: "%.1f", trip.driver?.rating ?? 0))
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    if let vehicle = trip.driver?.vehicleInfo {
                        Text(vehicle)
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Departure time badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.departureTime.tripTimeString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(trip.departureTime.countdownString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.brandGreen)
                }
            }

            // ── Route Row ──
            HStack(alignment: .center, spacing: 0) {
                // Dot line
                VStack(spacing: 0) {
                    Circle().fill(Color.brand).frame(width: 8, height: 8)
                    Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1.5, height: 28)
                    Image(systemName: "mappin.circle.fill").font(.system(size: 12)).foregroundColor(.brandRed)
                }
                .frame(width: 24)
                .padding(.leading, 12)

                // Labels
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.origin)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text(trip.destination)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
                .padding(.leading, 12)

                Spacer()
            }
            .padding(.top, 14)

            // ── Footer: Seats + Date ──
            HStack(spacing: 10) {
                // Seat chips
                HStack(spacing: 5) {
                    ForEach(0..<min(trip.seatsAvailable, 4), id: \.self) { _ in
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.brandGreen)
                    }
                    if trip.seatsAvailable > 4 {
                        Text("+\(trip.seatsAvailable - 4)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.brandGreen)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(10)

                Text("\(trip.seatsAvailable) seat\(trip.seatsAvailable == 1 ? "" : "s") left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                Spacer()

                // Date
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 11))
                    Text(trip.departureTime.tripDateString)
                        .font(.system(size: 12))
                }
                .foregroundColor(.textTertiary)
            }
            .padding(.top, 14)

            // Recurrence badge
            if let recurrence = trip.recurrence, !recurrence.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "repeat").font(.system(size: 11))
                    Text("Repeats \(recurrence)").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.brand)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppConstants.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppConstants.cardRadius)
        .shadow(color: .black.opacity(isPressed ? 0.04 : 0.08), radius: isPressed ? 4 : 12, x: 0, y: isPressed ? 2 : 4)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 100, maximumDistance: 50,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
    }
}

// MARK: - Compact Trip Card (For Driver View)

struct CompactTripCard: View {
    let trip: Trip
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(trip.status == .active ? Color.brandGreen : Color.gray.opacity(0.4))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trip.destination)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(trip.departureTime.tripTimeString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.brand)
                }

                HStack {
                    Image(systemName: "mappin").font(.system(size: 11)).foregroundColor(.textTertiary)
                    Text("From: \(trip.origin)").font(.system(size: 13)).foregroundColor(.textSecondary).lineLimit(1)
                    Spacer()
                    Text(trip.departureTime.tripDateString).font(.system(size: 12)).foregroundColor(.textTertiary)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill").font(.system(size: 11))
                        Text("\(trip.seatsAvailable) seats").font(.system(size: 12))
                    }
                    .foregroundColor(.textSecondary)

                    if let recurrence = trip.recurrence {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat").font(.system(size: 11))
                            Text(recurrence).font(.system(size: 12))
                        }
                        .foregroundColor(.brand)
                    }

                    Spacer()

                    if let cancel = onCancel {
                        Button(action: cancel) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.brandRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.brandRed.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(AppConstants.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppConstants.cardRadius)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
