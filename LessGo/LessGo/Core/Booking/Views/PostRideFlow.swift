import SwiftUI

// MARK: - Post Ride Flow (Rider)
// Three-step sheet presented after a trip completes from the rider's perspective.
// Sequences: Summary → Payment → Rating → Done.
// Both payment and rating can be individually skipped.

struct PostRideFlow: View {
    let bookingId: String
    let driverName: String
    let driverRating: Double
    let fareAmount: Double
    var origin: String = ""
    var destination: String = ""
    var onComplete: (() -> Void)? = nil

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Step { case summary, payment, rating, done }
    @State private var step: Step = .summary

    // Payment
    @State private var isProcessingPayment = false
    @State private var capturedPayment: Payment?
    @State private var paymentError: String?

    // Rating
    @State private var selectedStars = 5
    @State private var comment = ""
    @State private var isSubmittingRating = false
    @State private var submittedRating: Rating?
    @State private var ratingError: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Group {
                    switch step {
                    case .summary: summaryStep
                    case .payment: paymentStep
                    case .rating:  ratingStep
                    case .done:    doneStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .animation(.easeInOut(duration: 0.28), value: step)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .done {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") { skipStep() }
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Summary Step

    private var summaryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                completionBadge

                if !origin.isEmpty || !destination.isEmpty {
                    routeCard
                }

                driverFareCard

                VStack(spacing: 12) {
                    PrimaryButton(
                        title: String(format: "Pay  $%.2f", fareAmount),
                        icon: "creditcard.fill",
                        isLoading: isProcessingPayment,
                        isEnabled: !isProcessingPayment
                    ) {
                        Task { await processPayment() }
                    }

                    if let err = paymentError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.brandRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Button("Skip payment, rate driver") {
                        withAnimation { step = .rating }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .navigationTitle("Trip Complete")
    }

    // MARK: - Payment Step

    private var paymentStep: some View {
        VStack(spacing: 32) {
            Spacer()

            if let payment = capturedPayment {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.brandGreen)

                    VStack(spacing: 6) {
                        Text("Payment Captured")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text(String(format: "$%.2f paid", payment.amount))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.brandGreen)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brand))
                        .scaleEffect(1.6)
                    Text("Processing Payment…")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
            }

            Spacer()

            if capturedPayment != nil {
                PrimaryButton(
                    title: "Rate Your Driver",
                    icon: "star.fill",
                    color: .green
                ) {
                    withAnimation { step = .rating }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Payment")
    }

    // MARK: - Rating Step

    private var ratingStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Driver avatar + heading
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 72, height: 72)
                        Text(driverFirstName.prefix(1).uppercased())
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text("How was \(driverFirstName)?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 4) {
                        StarRatingView(rating: driverRating, size: 13)
                        Text(String(format: "%.1f avg", driverRating))
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.top, 8)

                // Tap-to-set star picker
                starPicker

                Text(ratingLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandOrange)

                commentField

                if let submitted = submittedRating {
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brandGreen)
                            Text("You gave \(driverFirstName) \(submitted.score) star\(submitted.score == 1 ? "" : "s")")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        PrimaryButton(title: "Finish", icon: "house.fill", color: .green) {
                            withAnimation { step = .done }
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        PrimaryButton(
                            title: "Submit Rating",
                            icon: "star.fill",
                            isLoading: isSubmittingRating,
                            isEnabled: !isSubmittingRating
                        ) {
                            Task { await submitRating() }
                        }

                        if let err = ratingError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.brandRed)
                                .multilineTextAlignment(.center)
                        }

                        Button("Skip rating") {
                            withAnimation { step = .done }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .padding(.vertical, 4)
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Rate Driver")
    }

    // MARK: - Done Step

    private var doneStep: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.brandGold)
                    .padding(.bottom, 4)

                VStack(spacing: 8) {
                    Text("All Done!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Thanks for riding with LessGo.\nSee you next time!")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            PrimaryButton(title: "Back to Home", icon: "house.fill") {
                onComplete?()
                dismiss()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Reusable Sub-views

    private var completionBadge: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.brandGreen)
            Text("You've arrived!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            Text("Time to settle up.")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 16)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(Color.brand).frame(width: 8, height: 8)
                Text(origin)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(width: 1, height: 16)
                .padding(.leading, 3)
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.brandGreen)
                    .frame(width: 8)
                Text(destination)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var driverFareCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 48, height: 48)
                Text(driverFirstName.prefix(1).uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(driverFirstName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.brandGold)
                    Text(String(format: "%.1f", driverRating))
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", fareAmount))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("your fare")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var starPicker: some View {
        HStack(spacing: 14) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        selectedStars = star
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: star <= selectedStars ? "star.fill" : "star")
                        .font(.system(size: 38))
                        .foregroundColor(star <= selectedStars ? .brandOrange : DesignSystem.Colors.border)
                        .scaleEffect(star == selectedStars ? 1.2 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedStars)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a comment (optional)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
            TextEditor(text: $comment)
                .frame(height: 80)
                .padding(10)
                .background(DesignSystem.Colors.fieldBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                )
                .font(.system(size: 14))
        }
    }

    private var ratingLabel: String {
        switch selectedStars {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        default: return "Excellent!"
        }
    }

    private var driverFirstName: String {
        driverName.components(separatedBy: " ").first ?? driverName
    }

    // MARK: - Async Actions

    private func processPayment() async {
        isProcessingPayment = true
        paymentError = nil
        withAnimation { step = .payment }
        do {
            let intent = try await PaymentService.shared.createPaymentIntent(
                bookingId: bookingId,
                amount: fareAmount
            )
            let captured = try await PaymentService.shared.capturePayment(id: intent.id)
            await MainActor.run {
                capturedPayment = captured
                isProcessingPayment = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                isProcessingPayment = false
                paymentError = "Payment failed: \(error.localizedDescription)"
                withAnimation { step = .summary }
            }
        }
    }

    private func submitRating() async {
        isSubmittingRating = true
        ratingError = nil
        do {
            let rating = try await BookingService.shared.rateBooking(
                id: bookingId,
                score: selectedStars,
                comment: comment.isEmpty ? nil : comment
            )
            await MainActor.run {
                submittedRating = rating
                isSubmittingRating = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run { withAnimation { step = .done } }
        } catch {
            await MainActor.run {
                isSubmittingRating = false
                ratingError = error.localizedDescription
            }
        }
    }

    private func skipStep() {
        withAnimation {
            switch step {
            case .summary: step = .rating
            case .payment: step = .rating
            case .rating:  step = .done
            case .done: break
            }
        }
    }
}

// MARK: - Previews

#Preview("Summary — with route") {
    PostRideFlow(
        bookingId: "booking-preview",
        driverName: "Marcus Chen",
        driverRating: 4.8,
        fareAmount: 8.50,
        origin: "SJSU Engineering Building",
        destination: "Diridon Station"
    )
    .environmentObject(AuthViewModel())
}

#Preview("Rating step") {
    let flow = PostRideFlow(
        bookingId: "booking-preview",
        driverName: "Priya Patel",
        driverRating: 4.6,
        fareAmount: 7.25
    )
    // Show rating step via a wrapper
    return NavigationView {
        flow
    }
    .environmentObject(AuthViewModel())
}
