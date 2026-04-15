import SwiftUI
import Combine

// MARK: - IncomingRideRequestView
// Uber-style driver request card shown when the matching pipeline selects this driver.
// Displays rider info, fare estimate, and a 15-second countdown timer.
// Driver can Accept or Decline; Decline triggers the retry queue.

struct IncomingRideRequestView: View {
    let payload: IncomingMatchPayload
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var secondsLeft: Int
    @State private var timerActive = true
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Dev-only: auto-accept fires after 3 s so simulations proceed without manual taps.
    #if DEBUG
    @State private var devAutoAcceptSecondsLeft = 3
    private let devAutoAcceptTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    #endif

    init(payload: IncomingMatchPayload, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.payload = payload
        self.onAccept = onAccept
        self.onDecline = onDecline
        _secondsLeft = State(initialValue: payload.expiresInSeconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.textSecondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.brand.opacity(0.15), lineWidth: 6)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(
                        from: 0,
                        to: CGFloat(secondsLeft) / CGFloat(payload.expiresInSeconds)
                    )
                    .stroke(
                        secondsLeft > 5 ? Color.brand : Color.brandRed,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: secondsLeft)

                Text("\(secondsLeft)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(secondsLeft > 5 ? .textPrimary : .brandRed)
            }
            .padding(.bottom, 16)

            Text("New Ride Request")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 4)

            Text("Respond within \(payload.expiresInSeconds) seconds")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .padding(.bottom, 8)

            #if DEBUG
            Text("⚡ Auto-accepting in \(devAutoAcceptSecondsLeft)s…")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.brandOrange)
                .padding(.bottom, 16)
            #else
            Spacer().frame(height: 24)
            #endif

            // Rider info card
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.brand.opacity(0.12)).frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.brand)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(payload.riderName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.brandGold)
                        Text(String(format: "%.1f", payload.riderRating))
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(14)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Route info
            VStack(spacing: 0) {
                routeRow(icon: "circle.fill", iconColor: .brandGold, label: payload.origin)
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.2))
                    .frame(width: 1, height: 18)
                    .padding(.leading, 24 + 16 + 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                routeRow(icon: "mappin.circle.fill", iconColor: .brandGreen, label: payload.destination)
            }
            .background(Color.cardBackground)
            .cornerRadius(14)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            // Accept / Decline buttons
            HStack(spacing: 12) {
                Button(action: {
                    timerActive = false
                    onDecline()
                }) {
                    Text("Decline")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.brandRed.opacity(0.1))
                        .cornerRadius(14)
                }

                Button(action: {
                    timerActive = false
                    onAccept()
                }) {
                    Text("Accept")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.brand)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -4)
        .onReceive(countdownTimer) { _ in
            guard timerActive else { return }
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                timerActive = false
                onDecline()   // auto-decline on expiry
            }
        }
        #if DEBUG
        .onReceive(devAutoAcceptTimer) { _ in
            guard timerActive else { return }
            if devAutoAcceptSecondsLeft > 1 {
                devAutoAcceptSecondsLeft -= 1
            } else {
                timerActive = false
                onAccept()   // dev auto-accept
            }
        }
        #endif
    }

    private func routeRow(icon: String, iconColor: Color, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 18))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

