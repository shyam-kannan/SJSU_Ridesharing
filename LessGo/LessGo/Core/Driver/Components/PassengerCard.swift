import SwiftUI

struct PassengerCard: View {
    let passenger: BookingWithRider
    private var hasActions: Bool { (passenger.riderPhone?.isEmpty == false) || passenger.pickupLocation != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Circular avatar with SJSU Blue border
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                        .frame(width: 56, height: 56)

                    if let pictureUrl = passenger.riderPicture, !pictureUrl.isEmpty {
                        // TODO: AsyncImage for profile picture
                        Text(passenger.riderName.prefix(1).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                    } else {
                        Text(passenger.riderName.prefix(1).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(DesignSystem.Colors.sjsuBlue, lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(passenger.riderName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

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
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(DesignSystem.Colors.sjsuGold)
                .clipShape(Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "F8FAFC"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )

            // Pickup Location Badge (if shared)
            if let pickup = passenger.pickupLocation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                        .font(.system(size: 14))
                        .padding(.top, 1)

                    if let address = pickup.address {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Lat: \(pickup.lat, specifier: "%.4f"), Lng: \(pickup.lng, specifier: "%.4f")")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.sjsuBlue.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Action Buttons
            if hasActions {
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
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.sjsuBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
