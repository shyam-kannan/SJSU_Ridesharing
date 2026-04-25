import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab: Tab = .home
    @State private var showIDVerification = false

    enum Tab { case home, bookings, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                Color.canvasGradient.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        Color.brand.opacity(0.08),
                        .clear,
                        Color.brandTeal.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            // ── Content ──
            TabView(selection: $selectedTab) {
                Group {
                    if authVM.isDriver {
                        DriverHomeView()
                    } else {
                        RiderHomeView()
                    }
                }
                .tag(Tab.home)

                BookingListView()
                    .tag(Tab.bookings)

                ProfileView()
                    .tag(Tab.profile)
            }
            // hide the default tab bar so we can use our custom one
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .background(Color.clear)

            // ── Custom Tab Bar ──
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        // ── ID Verification prompt after registration ──
        .sheet(isPresented: $authVM.showIDVerification) {
            IDVerificationView()
                .environmentObject(authVM)
        }
        // ── Unverified / Rejected banner — drivers only.
        // Riders handle this banner inside RiderHomeView.searchHeader so it
        // appears in-flow (above greeting) rather than as a floating overlay.
        .overlay(alignment: .top) {
            if authVM.isDriver, let user = authVM.currentUser, user.sjsuIdStatus != .verified {
                VerifyBannerView(status: user.sjsuIdStatus) {
                    authVM.showIDVerification = true
                }
                .padding(.top, VerifyBannerView.windowTopInset)
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: authVM.currentUser?.id) { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedTab = .home
            }
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selectedTab: HomeView.Tab

    private struct TabItem {
        let tab: HomeView.Tab
        let icon: String
        let selectedIcon: String
        let label: String
    }

    private let items: [TabItem] = [
        TabItem(tab: .home,     icon: "house",              selectedIcon: "house.fill",            label: "Home"),
        TabItem(tab: .bookings, icon: "list.bullet.clipboard", selectedIcon: "list.bullet.clipboard.fill", label: "Trips"),
        TabItem(tab: .profile,  icon: "person",             selectedIcon: "person.fill",            label: "Profile")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(items, id: \.label) { item in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = item.tab
                        }
                    }) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(selectedTab == item.tab ? DesignSystem.Colors.accentLime.opacity(0.18) : Color.clear)
                                    .frame(width: 30, height: 30)
                                Image(systemName: selectedTab == item.tab ? item.selectedIcon : item.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(selectedTab == item.tab ? DesignSystem.Colors.onAccentLime : .white.opacity(0.65))
                            }

                            if selectedTab == item.tab {
                                Text(item.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.Colors.onAccentLime)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTab == item.tab
                                    ? AnyShapeStyle(DesignSystem.Colors.selectedTabBackground)
                                    : AnyShapeStyle(Color.clear)
                                )
                        )
                        .contentShape(Rectangle())
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedTab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignSystem.Colors.tabBarSurface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.onDark.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 22, x: 0, y: 10)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
