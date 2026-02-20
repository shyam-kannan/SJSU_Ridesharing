import SwiftUI

struct RecentActivityCard: View {
    let passenger: BookingWithRider
    let trip: Trip

    private var isNew: Bool {
        // Check if booking was created within last 24 hours
        let hoursSinceCreation = Date().timeIntervalSince(passenger.createdAt) / 3600
        return hoursSinceCreation < 24
    }

    private var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(passenger.createdAt)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rider avatar
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                    .frame(width: 42, height: 42)

                Text(passenger.riderName.prefix(1).uppercased())
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.sjsuBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Rider name with NEW badge
                HStack(spacing: 8) {
                    Text(passenger.riderName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    if isNew {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.sjsuGold)
                            .cornerRadius(4)
                    }
                }

                // Trip summary
                Text("Booked your trip to \(trip.destination)")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                // Time ago
                Text(timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            // Seats count
            VStack(spacing: 2) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.sjsuGold)

                Text("\(passenger.seatsBooked)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
