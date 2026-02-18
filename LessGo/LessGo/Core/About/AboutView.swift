import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // ── App Info ──
                    VStack(spacing: 12) {
                        // App icon placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.brandGradient)
                                .frame(width: 88, height: 88)
                            Text("🚗")
                                .font(.system(size: 42))
                        }
                        .shadow(color: Color.brand.opacity(0.3), radius: 12, x: 0, y: 6)

                        Text("LessGo")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    // ── Mission ──
                    AboutCard(title: "Our Mission") {
                        Text("LessGo connects SJSU students for **safe, affordable, and sustainable** carpooling. We reduce traffic, cut emissions, and build community — one ride at a time.")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                            .lineSpacing(4)

                        HStack(spacing: 0) {
                            ValuePill(icon: "leaf.fill", label: "Sustainability", color: .brandGreen)
                            ValuePill(icon: "person.2.fill", label: "Community", color: .brand)
                            ValuePill(icon: "shield.fill", label: "Safety", color: .brandOrange)
                        }
                    }

                    // ── Impact Stats ──
                    AboutCard(title: "Our Impact") {
                        HStack(spacing: 12) {
                            ImpactStat(value: "500+", label: "Rides Shared", icon: "car.fill", color: .brand)
                            ImpactStat(value: "2.1T", label: "CO₂ Saved", icon: "leaf.fill", color: .brandGreen)
                            ImpactStat(value: "4.8★", label: "Avg Rating", icon: "star.fill", color: .brandOrange)
                        }
                    }

                    // ── Team ──
                    AboutCard(title: "Built by SJSU Students") {
                        Text("LessGo was built by a team of San José State University students passionate about sustainable transportation and campus community.")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .lineSpacing(4)

                        VStack(spacing: 10) {
                            TeamMemberRow(name: "Shyam Kannan", role: "Full-Stack & iOS Lead")
                            TeamMemberRow(name: "SJSU CS Team", role: "Backend & DevOps")
                        }
                    }

                    // ── Legal ──
                    AboutCard(title: "Legal") {
                        AboutLinkRow(icon: "doc.text.fill", title: "Terms of Service", color: .textTertiary)
                        Divider().padding(.leading, 36)
                        AboutLinkRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .textTertiary)
                        Divider().padding(.leading, 36)
                        AboutLinkRow(icon: "list.bullet.rectangle.fill", title: "Licenses & Attributions", color: .textTertiary)
                    }

                    // ── Share ──
                    Button(action: share) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share LessGo")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, AppConstants.pagePadding)
                    }

                    Text("Made with ♥ at SJSU")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("About LessGo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
        }
    }

    private func share() {
        let text = "Check out LessGo — the SJSU carpooling app! 🚗 Safe, affordable rides for students."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            vc.present(av, animated: true)
        }
    }
}

// MARK: - Subcomponents

private struct AboutCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 18)
        .padding(.horizontal, AppConstants.pagePadding)
    }
}

private struct ValuePill: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

private struct ImpactStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.textPrimary)
            Text(label).font(.system(size: 10)).foregroundColor(.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .cornerRadius(12)
    }
}

private struct TeamMemberRow: View {
    let name: String; let role: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.brand.opacity(0.12)).frame(width: 36, height: 36)
                Text(String(name.prefix(1))).font(.system(size: 15, weight: .semibold)).foregroundColor(.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary)
                Text(role).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
            Spacer()
        }
    }
}

private struct AboutLinkRow: View {
    let icon: String; let title: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(color).frame(width: 20)
            Text(title).font(.system(size: 15)).foregroundColor(.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textTertiary)
        }
        .padding(.vertical, 10)
    }
}
