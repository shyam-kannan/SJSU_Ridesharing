import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab: Tab = .home
    @State private var showIDVerification = false

    enum Tab { case home, bookings, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
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
        HStack(spacing: 0) {
            ForEach(items, id: \.label) { item in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = item.tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == item.tab ? item.selectedIcon : item.icon)
                            .font(.system(size: 22))
                            .foregroundColor(selectedTab == item.tab ? .brand : .textTertiary)
                            .scaleEffect(selectedTab == item.tab ? 1.1 : 1.0)
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedTab == item.tab ? .brand : .textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedTab)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(
            Color.cardBackground
                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: -4)
        )
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

