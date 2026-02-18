import SwiftUI

struct FAQView: View {
    @State private var expandedId: String? = nil

    private let faqs: [(id: String, question: String, answer: String)] = [
        (
            id: "verify",
            question: "How do I verify my SJSU ID?",
            answer: "Go to your Profile tab and tap \"Verify Now\" on the verification card. Take a clear photo of your SJSU Student ID card. In debug builds, you can use the test ID for instant approval. Once submitted, your status is updated within seconds (in test mode) or by our team (in production)."
        ),
        (
            id: "pricing",
            question: "How does pricing work?",
            answer: "LessGo uses distance-based pricing calculated by our cost service. The price is calculated from origin to SJSU (or vice versa) and split among the booked seats. You'll see the exact price before confirming your booking — no surprises."
        ),
        (
            id: "cancel",
            question: "What if my driver cancels?",
            answer: "If a driver cancels a trip, all confirmed bookings are automatically cancelled and full refunds are issued to the payment method used. Refunds typically process within 3–5 business days. You'll receive a cancellation email with refund details."
        ),
        (
            id: "driver",
            question: "How do I become a driver?",
            answer: "On the Profile tab, tap \"Become Driver\" or \"Vehicle Setup\" in Quick Actions. Enter your vehicle information (year, make, model, color, license plate) and the number of available seats. You must be SJSU-verified first. Once saved, you can create trips from the Home tab."
        ),
        (
            id: "payment",
            question: "Is my payment information secure?",
            answer: "Yes. LessGo uses Stripe for all payment processing — your full card number is never stored on our servers. Stripe is PCI DSS Level 1 certified, the highest level of payment security certification. We only store payment intent IDs."
        ),
        (
            id: "safety",
            question: "How do I report a safety concern?",
            answer: "For emergencies, call SJSU Campus Police at 408-924-2222 or 911. For non-emergency concerns, use the \"Report an Issue\" option in Help & Support, or email safety@lessgo.app. All safety reports are reviewed by our team within 24 hours."
        ),
        (
            id: "refund",
            question: "How do refunds work?",
            answer: "Refunds are issued automatically when you cancel a confirmed booking. The amount is returned to your original payment method within 3–5 business days. You'll receive a cancellation email confirming the refund amount."
        ),
        (
            id: "ride-match",
            question: "How do I find rides near me?",
            answer: "On the Home tab, use the search bar to enter your pickup location. Toggle between \"To SJSU\" and \"From SJSU\" using the direction buttons. Matching trips appear on the map and in the list below. Tap any trip card to view full details and book."
        ),
    ]

    var body: some View {
        List {
            ForEach(faqs, id: \.id) { faq in
                FAQRow(faq: faq, isExpanded: expandedId == faq.id) {
                    withAnimation(.spring(response: 0.3)) {
                        expandedId = expandedId == faq.id ? nil : faq.id
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQRow: View {
    let faq: (id: String, question: String, answer: String)
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    Text(faq.question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                .padding(.vertical, 4)
            }

            if isExpanded {
                Text(faq.answer)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }
}
