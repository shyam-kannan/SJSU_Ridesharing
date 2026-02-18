import SwiftUI
import MessageUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFAQ = false
    @State private var showReportIssue = false
    @State private var showSafetyTips = false
    @State private var showMailComposer = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Get Help ──
                    SupportSection(title: "Get Help") {
                        SupportRow(icon: "questionmark.circle.fill", title: "FAQ", subtitle: "Common questions answered", color: .brand) {
                            showFAQ = true
                        }
                        Divider().padding(.leading, 52)
                        SupportRow(icon: "envelope.fill", title: "Contact Support", subtitle: "support@lessgo.app", color: .brand) {
                            if MFMailComposeViewController.canSendMail() {
                                showMailComposer = true
                            } else {
                                // Fallback: open mail URL
                                if let url = URL(string: "mailto:support@lessgo.app") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        Divider().padding(.leading, 52)
                        SupportRow(icon: "exclamationmark.bubble.fill", title: "Report an Issue", subtitle: "Bug, payment, or safety concern", color: .brandOrange) {
                            showReportIssue = true
                        }
                    }

                    // ── Safety ──
                    SupportSection(title: "Safety") {
                        SupportRow(icon: "phone.fill", title: "SJSU Campus Police", subtitle: "408-924-2222 — tap to call", color: .brandRed) {
                            if let url = URL(string: "tel://4089242222") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Divider().padding(.leading, 52)
                        SupportRow(icon: "shield.checkered", title: "Safety Tips", subtitle: "Stay safe while carpooling", color: .brandGreen) {
                            showSafetyTips = true
                        }
                    }

                    // ── Info ──
                    SupportSection(title: "Info") {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.textTertiary.opacity(0.12)).frame(width: 32, height: 32)
                                Image(systemName: "envelope.open.fill").font(.system(size: 16)).foregroundColor(.textTertiary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email us at")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textPrimary)
                                Text("support@lessgo.app")
                                    .font(.system(size: 13))
                                    .foregroundColor(.brand)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.top, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
            .navigationDestination(isPresented: $showFAQ) { FAQView() }
            .navigationDestination(isPresented: $showReportIssue) { ReportIssueView() }
            .navigationDestination(isPresented: $showSafetyTips) { SafetyTipsView() }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(recipient: "support@lessgo.app", subject: "LessGo Support Request", result: $mailResult)
            }
        }
    }
}

// MARK: - Safety Tips

struct SafetyTipsView: View {
    private let tips: [(icon: String, title: String, detail: String)] = [
        ("person.2.fill", "Verify Your Ride", "Always confirm your driver's name, vehicle, and license plate in the app before getting in."),
        ("location.fill", "Share Your Location", "Let a trusted friend or family member know your route and expected arrival time."),
        ("star.fill", "Check Ratings", "Only ride with drivers who have good ratings and verified SJSU status."),
        ("exclamationmark.triangle.fill", "Trust Your Instincts", "If something feels wrong, exit the vehicle in a safe, public location."),
        ("phone.fill", "Keep Emergency Numbers Ready", "Save SJSU Campus Police (408-924-2222) and 911 in your contacts."),
        ("lock.shield.fill", "Never Share Login Credentials", "LessGo staff will never ask for your password or tokens."),
    ]

    var body: some View {
        List(tips, id: \.title) { tip in
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.brandGreen.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: tip.icon).font(.system(size: 18)).foregroundColor(.brandGreen)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                    Text(tip.detail).font(.system(size: 13)).foregroundColor(.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("Safety Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents

struct SupportSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                content
            }
            .background(Color.cardBackground)
            .cornerRadius(AppConstants.cardRadius)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }
}

struct SupportRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }
}

// MARK: - Mail Composer Wrapper

struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Binding var result: Result<MFMailComposeResult, Error>?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        init(_ parent: MailComposerView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.result = error.map { .failure($0) } ?? .success(result)
            parent.dismiss()
        }
    }
}
