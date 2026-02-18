import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = ProfileViewModel()
    @State private var showEdit = false
    @State private var showDriverSetup = false
    @State private var showIDVerification = false
    @State private var showLogoutConfirm = false
    @State private var showTripHistory = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Profile Header ──
                    profileHeader

                    // ── Verification Status ──
                    verificationCard

                    // ── Stats Row ──
                    statsRow

                    // ── Quick Actions ──
                    quickActions

                    // ── Settings Section ──
                    settingsSection

                    // ── Danger Zone ──
                    dangerZone

                    Spacer().frame(height: 100)
                }
                .padding(.top, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let id = authVM.currentUser?.id {
                    await vm.loadProfile(userId: id)
                }
            }
            .sheet(isPresented: $showEdit) {
                EditProfileView(vm: vm, userId: authVM.currentUser?.id ?? "")
                    .onDisappear { Task { await authVM.refreshUser() } }
            }
            .sheet(isPresented: $showDriverSetup) {
                DriverSetupView(vm: vm, userId: authVM.currentUser?.id ?? "")
                    .onDisappear { Task { await authVM.refreshUser() } }
            }
            .sheet(isPresented: $showIDVerification) {
                IDVerificationView().environmentObject(authVM)
            }
            .sheet(isPresented: $showTripHistory) {
                TripHistoryView()
            }
            .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { Task { await authVM.logout() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .successMessage(message: vm.successMessage)
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandGradient)
                    .frame(width: 90, height: 90)
                Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.brand.opacity(0.3), radius: 14, x: 0, y: 7)

            VStack(spacing: 6) {
                Text(authVM.currentUser?.name ?? "")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text(authVM.currentUser?.email ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)

                // Role badge
                if let role = authVM.currentUser?.role {
                    Text(role.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(role == .driver ? .brandOrange : .brand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background((role == .driver ? Color.brandOrange : Color.brand).opacity(0.12))
                        .cornerRadius(10)
                }
            }

            Button(action: { showEdit = true }) {
                Text("Edit Profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Verification Card
    private var verificationCard: some View {
        let status = authVM.currentUser?.sjsuIdStatus ?? .pending
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor(status).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon(status))
                    .font(.system(size: 20))
                    .foregroundColor(statusColor(status))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("SJSU Verification")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(statusMessage(status))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if status == .pending {
                Button(action: { showIDVerification = true }) {
                    Text("Verify Now")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.brand)
                        .cornerRadius(12)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Stats
    private var statsRow: some View {
        HStack(spacing: 12) {
            ProfileStat(value: String(format: "%.1f", authVM.currentUser?.rating ?? 0),
                        label: "Rating", icon: "star.fill", color: .brandOrange)
            ProfileStat(value: "\(vm.stats?.totalTripsCompleted ?? 0)",
                        label: "Trips", icon: "car.fill", color: .brand)
            ProfileStat(value: "\(vm.ratings.count)",
                        label: "Reviews", icon: "bubble.fill", color: .brandGreen)
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Quick Actions")

            HStack(spacing: 12) {
                QuickActionCard(icon: "clock.arrow.circlepath", label: "Trip History", color: .brand) {
                    showTripHistory = true
                }
                QuickActionCard(icon: "star.fill", label: "My Ratings", color: .brandOrange) {}

                if !authVM.isDriver {
                    QuickActionCard(icon: "car.badge.plus", label: "Become Driver", color: .brandGreen) {
                        showDriverSetup = true
                    }
                } else {
                    QuickActionCard(icon: "car.fill", label: "Vehicle Setup", color: .brandGreen) {
                        showDriverSetup = true
                    }
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Settings")
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsRow(icon: "bell.fill", title: "Notifications", color: .brandOrange) {}
                Divider().padding(.leading, 52)
                SettingsRow(icon: "lock.fill", title: "Privacy & Security", color: .brand) {}
                Divider().padding(.leading, 52)
                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .brandGreen) {}
                Divider().padding(.leading, 52)
                SettingsRow(icon: "info.circle.fill", title: "About LessGo", color: .textTertiary) {}
            }
            .background(Color.cardBackground)
            .cornerRadius(AppConstants.cardRadius)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Danger Zone
    private var dangerZone: some View {
        Button(action: { showLogoutConfirm = true }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.brandRed)
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brandRed)
                Spacer()
            }
            .padding(AppConstants.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppConstants.cardRadius)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Helper Functions
    private func statusColor(_ s: SJSUIDStatus) -> Color {
        switch s { case .verified: return .brandGreen; case .rejected: return .brandRed; default: return .brandOrange }
    }
    private func statusIcon(_ s: SJSUIDStatus) -> String {
        switch s { case .verified: return "checkmark.seal.fill"; case .rejected: return "xmark.seal.fill"; default: return "clock.badge.questionmark.fill" }
    }
    private func statusMessage(_ s: SJSUIDStatus) -> String {
        switch s { case .verified: return "You're verified as an SJSU student"; case .rejected: return "Verification failed. Please retry"; default: return "Upload your SJSU ID to unlock booking" }
    }
}

// MARK: - Profile Stat
private struct ProfileStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.textPrimary)
            Text(label).font(.system(size: 11)).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.cardBackground).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Quick Action Card
private struct QuickActionCard: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                }
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color.cardBackground).cornerRadius(14)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Settings Row
private struct SettingsRow: View {
    let icon: String; let title: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                }
                Text(title).font(.system(size: 16)).foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LabeledTextField(label: "Full Name", placeholder: "Your name", text: $vm.editName, icon: "person")
                    LabeledTextField(label: "Email", placeholder: "your@sjsu.edu", text: $vm.editEmail,
                                     icon: "envelope", keyboardType: .emailAddress)
                    if let err = vm.errorMessage { ToastBanner(message: err, type: .error) }
                    if let msg = vm.successMessage { ToastBanner(message: msg, type: .success) }
                    PrimaryButton(title: "Save Changes", isLoading: vm.isSaving, color: .blue) {
                        Task { await vm.saveProfile(userId: userId); dismiss() }
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Driver Setup View
struct DriverSetupView: View {
    @ObservedObject var vm: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LabeledTextField(label: "Vehicle Info",
                                     placeholder: "e.g. 2022 Honda Civic - White - 7ABC123",
                                     text: $vm.vehicleInfo, icon: "car")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SEATS AVAILABLE").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)
                        HStack {
                            Button(action: { if vm.seatsAvailable > 1 { vm.seatsAvailable -= 1 } }) {
                                Image(systemName: "minus.circle.fill").font(.system(size: 28))
                                    .foregroundColor(vm.seatsAvailable > 1 ? .brand : .gray.opacity(0.3))
                            }
                            Spacer()
                            Text("\(vm.seatsAvailable)").font(.system(size: 36, weight: .bold))
                            Spacer()
                            Button(action: { if vm.seatsAvailable < 8 { vm.seatsAvailable += 1 } }) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.brand)
                            }
                        }.cardStyle()
                    }
                    if let err = vm.errorMessage { ToastBanner(message: err, type: .error) }
                    PrimaryButton(title: "Save Driver Profile", isLoading: vm.isSaving) {
                        Task { await vm.setupDriver(userId: userId); if vm.successMessage != nil { dismiss() } }
                    }
                }
                .padding()
            }
            .navigationTitle("Driver Setup").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Trip History View
struct TripHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = BookingViewModel()

    var body: some View {
        NavigationView {
            Group {
                if vm.isLoading { LoadingRow() }
                else if vm.bookings.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "No history", message: "Your completed trips will appear here")
                } else {
                    List(vm.bookings) { booking in
                        if let trip = booking.trip {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(trip.origin) → \(trip.destination)")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(trip.departureTime.tripDateTimeString)
                                    .font(.system(size: 12)).foregroundColor(.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Trip History").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } } }
            .task { await vm.loadBookings() }
        }
    }
}

// MARK: - Success Message Modifier
extension View {
    func successMessage(message: String?) -> some View {
        self.overlay(alignment: .top) {
            if let msg = message {
                ToastBanner(message: msg, type: .success)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: message)
    }
}
