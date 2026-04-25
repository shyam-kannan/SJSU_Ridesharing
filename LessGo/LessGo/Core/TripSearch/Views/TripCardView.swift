import SwiftUI
import UIKit

// MARK: - Main Trip Card (List View)

struct TripCardView: View {
    let trip: Trip
    var index: Int = 0

    private var driverName: String { "Driver details after booking" }
    private var driverRating: Double { trip.driver?.rating ?? 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            fareColumn

            VStack(alignment: .leading, spacing: 6) {
                driverHeader
                routeSummary
                footerRow
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .staggeredAppear(index: index)
    }

    private var fareColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("$8.50")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.brandGreen)
            Text("per seat")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(width: 84, alignment: .leading)
    }

    private var driverHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.brand.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brand)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(driverName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    StarRatingView(rating: driverRating, size: 8)
                    Text(String(format: "%.1f", Double(driverRating)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(trip.departureTime.tripTimeString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                Text(trip.departureTime.tripDateString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 96, alignment: .trailing)
        }
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 6, height: 6)
                Text(trip.origin)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.brandRed)
                Text(trip.destination)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Text(trip.departureTime.countdownString)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.brandGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("•")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.textTertiary)

            Text("\(trip.seatsAvailable) seats")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: 5) {
                Text("View")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.brandGreen)
            .clipShape(Capsule())
            .frame(minWidth: 76)
        }
        .frame(minHeight: 28)
    }

    private func pill(icon: String, text: String, color: Color, background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background)
        .cornerRadius(999)
    }
}

// MARK: - Compact Trip Card (For Driver View)

struct CompactTripCard: View {
    let trip: Trip
    var onCancel: (() -> Void)? = nil

    @State private var passengers: [BookingWithRider] = []
    @State private var isLoadingPassengers = false

    private var totalSeatsBooked: Int {
        passengers.reduce(0) { $0 + $1.seatsBooked }
    }

    private var passengerNames: String {
        if passengers.isEmpty {
            return "No passengers yet"
        } else if passengers.count <= 2 {
            return passengers.map { $0.riderName }.joined(separator: ", ")
        } else {
            let first2 = passengers.prefix(2).map { $0.riderName }.joined(separator: ", ")
            return "\(first2), +\(passengers.count - 2) more"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(trip.status == .pending ? Color.brandGreen : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(trip.status.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(trip.status == .pending ? .brandGreen : .textSecondary)
                }
                Spacer()
                compactPill(icon: "clock", text: trip.departureTime.tripTimeString)
                compactPill(icon: "calendar", text: trip.departureTime.tripDateString)
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
                        .font(.system(size: 12))
                        .foregroundColor(.brandRed)
                    Text(trip.destination)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(DesignSystem.Colors.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
            )
            .cornerRadius(12)

            // Passenger count badge with SJSU Blue background
            if !passengers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("\(totalSeatsBooked)/\(trip.seatsAvailable) seats filled")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.sjsuBlue)
                .cornerRadius(8)
            }

            // Passenger avatars in overlapping circles
            if !passengers.isEmpty {
                HStack(spacing: -8) {
                    ForEach(passengers.prefix(3)) { passenger in
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.cardBackground, lineWidth: 2)
                                )

                            Text(passenger.riderName.prefix(1).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.sjsuBlue)
                        }
                    }

                    if passengers.count > 3 {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.sjsuGold)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.cardBackground, lineWidth: 2)
                                )

                            Text("+\(passengers.count - 3)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Text(passengerNames)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .padding(.leading, 12)
                }
            }

            HStack(spacing: 12) {
                if let recurrence = trip.recurrence {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat").font(.system(size: 11))
                        Text(recurrence).font(.system(size: 12))
                    }
                    .foregroundColor(.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brand.opacity(0.08))
                    .cornerRadius(8)
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
        .padding(14)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .task(id: trip.id) { await loadPassengers(force: true) }
        .onAppear { Task { await loadPassengers(force: true) } }
        .onChange(of: trip.seatsAvailable) { _ in
            Task { await loadPassengers(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadPassengers(force: true) }
        }
    }

    private func compactPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.fieldBackground)
        .cornerRadius(999)
    }

    private func loadPassengers(force: Bool = false) async {
        if !force { guard !isLoadingPassengers else { return } }
        if isLoadingPassengers { return }
        isLoadingPassengers = true

        do {
            passengers = try await TripService.shared.getTripPassengers(tripId: trip.id)
        } catch {
            // Silently fail - card will show no passengers
            print("Failed to load passengers for trip \(trip.id): \(error)")
        }

        isLoadingPassengers = false
    }
}
