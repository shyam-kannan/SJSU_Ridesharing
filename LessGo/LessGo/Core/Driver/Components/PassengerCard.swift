import SwiftUI

struct PassengerCard: View {
    let passenger: BookingWithRider

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Avatar, Name, Rating
            HStack(spacing: 12) {
                // Circular avatar with SJSU Blue border
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if let pictureUrl = passenger.riderPicture, !pictureUrl.isEmpty {
                        // TODO: AsyncImage for profile picture
                        Text(passenger.riderName.prefix(1).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                    } else {
                        Text(passenger.riderName.prefix(1).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(DesignSystem.Colors.sjsuBlue, lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(passenger.riderName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    StarRatingView(rating: passenger.riderRating, size: 12)
                }

                Spacer()

                // Seats badge with SJSU Gold
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                    Text("\(passenger.seatsBooked)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DesignSystem.Colors.sjsuGold)
                .cornerRadius(8)
            }

            // Pickup Location Badge (if shared)
            if let pickup = passenger.pickupLocation {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                        .font(.system(size: 14))

                    if let address = pickup.address {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Lat: \(pickup.lat, specifier: "%.4f"), Lng: \(pickup.lng, specifier: "%.4f")")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.sjsuBlue.opacity(0.08))
                .cornerRadius(10)
            }

            // Action Buttons
            HStack(spacing: 10) {
                // Call Button
                if let phone = passenger.riderPhone, !phone.isEmpty {
                    Button(action: {
                        if let url = URL(string: "tel://\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12))
                            Text("Call")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                // Navigate Button (if location shared)
                if let pickup = passenger.pickupLocation {
                    Button(action: {
                        let urlString = "maps://?daddr=\(pickup.lat),\(pickup.lng)"
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.system(size: 12))
                            Text("Navigate")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.sjsuBlue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
