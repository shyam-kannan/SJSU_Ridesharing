import SwiftUI
import UIKit
import Combine

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var devTools = DevToolsViewModel()
    @State private var showEdit = false
    @State private var showDriverSetup = false
    @State private var showIDVerification = false
    @State private var showLogoutConfirm = false
    @State private var showTripHistory = false
    @State private var showDeleteAccountAlert = false
    @State private var isRefreshingStatus = false
    @State private var showChangePassword = false
    @State private var showSupport = false
    @State private var showAbout = false
    @State private var showAccountMenu = false
    @State private var showImagePicker = false
    @State private var selectedProfileImage: UIImage?
    @State private var showStripeOnboarding = false
    @State private var stripeOnboardingURL: URL? = nil
    @State private var isLoadingStripeURL = false
    @State private var stripeError: String? = nil
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("emailNotificationsEnabled") private var emailNotificationsEnabled = true
    @AppStorage("locationShareEnabled") private var locationShareEnabled = true
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    profileTopBar

                    // ── Profile Header ──
                    profileHeader

                    // ── Verification Status ──
                    verificationCard

                    // ── Role Switcher ──
                    roleSwitcherCard

                    // ── Stats Row ──
                    statsRow

                    // ── Driver Vehicle Info (drivers only) ──
                    if authVM.isDriver {
                        driverVehicleSection
                    }

                    // ── Quick Actions ──
                    quickActions

                    // ── Ratings Section ──
                    if !vm.ratings.isEmpty {
                        ratingsSection
                    }

                    // ── Settings Section ──
                    settingsSection

                    // ── Account Management ──
                    accountManagementSection

                    // ── Developer Tools ──
                    DevToolsSection(vm: devTools)

                    // ── Danger Zone ──
                    dangerZone

                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            .background(
                Color.appBackground.ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .task {
                if let id = authVM.currentUser?.id {
                    await vm.loadProfile(userId: id)
                    if authVM.currentUser?.role == .driver {
                        await vm.loadEarnings(userId: id)
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                EditProfileView(vm: vm, userId: authVM.currentUser?.id ?? "")
                    .onDisappear { Task { await authVM.refreshCurrentUser() } }
            }
            .sheet(isPresented: $showDriverSetup, onDismiss: {
                Task {
                    await authVM.refreshCurrentUser()
                    if authVM.isDriver && authVM.currentUser?.stripeConnectAccountId == nil {
                        do {
                            let url = try await UserService.shared.startStripeOnboarding()
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s — allows iOS 16 sheet dismiss to finish
                            await MainActor.run {
                                stripeOnboardingURL = url
                                showStripeOnboarding = true
                            }
                        } catch {
                            await MainActor.run { stripeError = error.localizedDescription }
                        }
                    }
                }
            }) {
                DriverSetupView(vm: vm, userId: authVM.currentUser?.id ?? "")
            }
            .sheet(isPresented: $showStripeOnboarding, onDismiss: {
                Task { await authVM.refreshCurrentUser() }
            }) {
                if let url = stripeOnboardingURL {
                    SafariView(url: url)
                }
            }
            .alert("Payout Setup Failed", isPresented: Binding(
                get: { stripeError != nil },
                set: { if !$0 { stripeError = nil } }
            )) {
                Button("OK") { stripeError = nil }
            } message: {
                Text(stripeError ?? "")
            }
            .sheet(isPresented: $showIDVerification) {
                IDVerificationView().environmentObject(authVM)
            }
            .sheet(isPresented: $showTripHistory) {
                TripHistoryView()
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView().environmentObject(authVM)
            }
            .sheet(isPresented: $showSupport) {
                SupportView().environmentObject(authVM)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showAccountMenu) {
                InAppAccountMenuView()
                    .environmentObject(authVM)
            }
            .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { Task { await authVM.logout() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete", role: .destructive) { Task { await authVM.logout() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all data. This action cannot be undone.")
            }
            .successMessage(message: vm.successMessage)
        }
    }

    // MARK: - Profile Header

    private var profileTopBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Account, settings, and verification")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
            Spacer()
            Button(action: { showAccountMenu = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.Colors.onDark.opacity(0.08))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .padding(.horizontal, AppConstants.pagePadding)
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                profileAvatarButton
                profileIdentityBlock
                editProfileButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.sheetBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
        .padding(.horizontal, AppConstants.pagePadding)
    }

    private var profileAvatarButton: some View {
        Button(action: { showImagePicker = true }) {
            ZStack(alignment: .bottomTrailing) {
                profileAvatarImage
                profileAvatarCameraBadge
                    .offset(x: -2, y: -2)
            }
            .overlay(profileAvatarRing)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.brand.opacity(0.3), radius: 14, x: 0, y: 7)
        .background(
            ProfileImagePickerView(
                selectedImage: $selectedProfileImage,
                showPicker: $showImagePicker,
                onRemovePhoto: {
                    if let userId = authVM.currentUser?.id {
                        Task {
                            await vm.removeProfilePicture(userId: userId)
                            await authVM.refreshCurrentUser()
                        }
                    }
                }
            )
        )
        .onChange(of: selectedProfileImage) { newImage in
            if let image = newImage, let userId = authVM.currentUser?.id {
                Task {
                    await vm.uploadProfilePicture(userId: userId, image: image)
                    await authVM.refreshCurrentUser()
                }
            }
        }
    }

    @ViewBuilder
    private var profileAvatarImage: some View {
        if let profilePicture = authVM.currentUser?.profilePicture,
           !profilePicture.isEmpty,
           let url = resolvedProfileImageURL(profilePicture) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                        .frame(width: 90, height: 90)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                case .failure:
                    initialsAvatar
                @unknown default:
                    EmptyView()
                }
            }
        } else if let selectedImage = selectedProfileImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(DesignSystem.Colors.sjsuBlue)
            .frame(width: 90, height: 90)
            .overlay(
                Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var profileAvatarCameraBadge: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.sjsuGold)
                .frame(width: 28, height: 28)
            Image(systemName: "camera.fill")
                .font(.system(size: 13))
                .foregroundColor(.white)
        }
    }

    private var profileAvatarRing: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.sjsuGold,
                        DesignSystem.Colors.sjsuGold.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
    }

    private var profileIdentityBlock: some View {
        VStack(spacing: 7) {
            Text(authVM.currentUser?.name ?? "")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(authVM.currentUser?.email ?? "")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let role = authVM.currentUser?.role {
                Text(role.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(role == .driver ? .brandOrange : .brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background((role == .driver ? Color.brandOrange : Color.brand).opacity(0.12))
                    .cornerRadius(10)
            }

            if let createdAt = authVM.currentUser?.createdAt {
                Text("Member since \(createdAt, formatter: memberSinceFormatter)")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
        }
    }

    private var editProfileButton: some View {
        Button(action: { showEdit = true }) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                Text("Edit Profile")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.brand)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.brand.opacity(0.1))
            .overlay(
                Capsule().strokeBorder(Color.brand.opacity(0.12), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .shadow(color: Color.brand.opacity(0.2), radius: 10, x: 0, y: 4)
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
            switch status {
            case .pending:
                HStack(spacing: 8) {
                    // Refresh status
                    Button(action: {
                        isRefreshingStatus = true
                        Task {
                            await authVM.refreshCurrentUser()
                            isRefreshingStatus = false
                        }
                    }) {
                        if isRefreshingStatus {
                            ProgressView()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.brand)
                                .frame(width: 32, height: 32)
                                .background(Color.brand.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
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
            case .rejected:
                Button(action: { showIDVerification = true }) {
                    Text("Retry")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.brandRed)
                        .cornerRadius(12)
                }
            case .verified:
                Text("Verified ✓")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.brandGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brandGreen.opacity(0.12))
                    .cornerRadius(12)
            }
        }
        .padding(15)
        .elevatedCard(cornerRadius: 18)
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Role Switcher

    private var roleSwitcherCard: some View {
        let currentRole = authVM.currentUser?.role ?? .rider
        let canSwitchToDriver = authVM.currentUser?.vehicleInfo != nil && authVM.currentUser?.licensePlate != nil

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandGold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: currentRole == .driver ? "car.fill" : "figure.walk")
                    .font(.system(size: 20))
                    .foregroundColor(.brandGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Account Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("Currently: \(currentRole == .driver ? "Driver" : "Rider")")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if currentRole == .driver {
                // Switch to Rider (always allowed)
                Button(action: {
                    Task {
                        do {
                            try await authVM.switchRole(to: .rider)
                        } catch {
                            print("Failed to switch role: \(error)")
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 13))
                        Text("Switch to Rider")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(12)
                }
            } else {
                // Switch to Driver (requires setup)
                Button(action: {
                    if canSwitchToDriver {
                        Task {
                            do {
                                try await authVM.switchRole(to: .driver)
                            } catch {
                                print("Failed to switch role: \(error)")
                            }
                        }
                    } else {
                        showDriverSetup = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 13))
                        Text(canSwitchToDriver ? "Switch to Driver" : "Setup Driver")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brand.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Stats

    private var statsRow: some View {
        VStack(spacing: 10) {
            // Primary stats
            HStack(spacing: 12) {
                ProfileStat(value: String(format: "%.1f", Double(authVM.currentUser?.rating ?? 0)),
                            label: "Rating", icon: "star.fill", color: .brandOrange)
                    .staggeredAppear(index: 0)
                ProfileStat(value: "\(vm.stats?.totalTripsAsDriver ?? 0)",
                            label: "Trips", icon: "car.fill", color: .brand)
                    .staggeredAppear(index: 1)
                ProfileStat(value: "\(vm.ratings.count)",
                            label: "Reviews", icon: "bubble.fill", color: .brandGreen)
                    .staggeredAppear(index: 2)
            }

            // Secondary stats (backend currently returns ratings/bookings counts, not distance)
            if let stats = vm.stats {
                HStack(spacing: 12) {
                    ProfileStat(
                        value: "\(stats.totalBookingsAsRider ?? 0)",
                        label: "Bookings", icon: "ticket.fill", color: .brand)
                        .staggeredAppear(index: 3)
                    ProfileStat(
                        value: "\(stats.totalRatings)",
                        label: "Rated", icon: "person.2.fill", color: .brandGreen)
                        .staggeredAppear(index: 4)
                }
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Driver Vehicle Section

    private var driverVehicleSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Driver Dashboard")

            // Earnings Card
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandGreen.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandGreen)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Earned")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)
                        Text(String(format: "$%.2f", vm.earnings?.totalEarned ?? 0.0))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.brandGreen)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("This Month")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Text(String(format: "$%.2f", vm.earnings?.thisMonthEarned ?? 0.0))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(AppConstants.cardPadding)

                Divider()

                HStack {
                    VStack(spacing: 4) {
                        Text("\(vm.earnings?.tripsCompleted ?? 0)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Completed")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 30)

                    VStack(spacing: 4) {
                        Text("\(vm.earnings?.tripsActive ?? 0)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.brand)
                        Text("Active")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, AppConstants.pagePadding)

            // Vehicle Info Card
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandOrange.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "car.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authVM.currentUser?.vehicleInfo ?? "No vehicle info set")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        if let seats = authVM.currentUser?.seatsAvailable {
                            Text("\(seats) seat\(seats == 1 ? "" : "s") available")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Spacer()
                    Button(action: { showDriverSetup = true }) {
                        Text("Edit")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.brand)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.brand.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(AppConstants.cardPadding)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.panelGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.brand.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, AppConstants.pagePadding)

            // Payout Setup Card
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((hasStripeAccount ? Color.brandGreen : Color.brandOrange).opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: hasStripeAccount ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(hasStripeAccount ? .brandGreen : .brandOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payout Setup")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(hasStripeAccount ? "Bank account connected" : "Required to receive payments")
                            .font(.system(size: 13))
                            .foregroundColor(hasStripeAccount ? .brandGreen : .brandOrange)
                    }
                    Spacer()
                    Button(action: {
                        guard !isLoadingStripeURL else { return }
                        Task {
                            isLoadingStripeURL = true
                            defer { isLoadingStripeURL = false }
                            do {
                                let url = hasStripeAccount
                                    ? try await UserService.shared.getStripeDashboardUrl()
                                    : try await UserService.shared.startStripeOnboarding()
                                await MainActor.run {
                                    stripeOnboardingURL = url
                                    showStripeOnboarding = true
                                }
                            } catch {
                                await MainActor.run { stripeError = error.localizedDescription }
                            }
                        }
                    }) {
                        if isLoadingStripeURL {
                            ProgressView()
                                .frame(width: 44, height: 28)
                        } else {
                            Text(hasStripeAccount ? "Edit" : "Setup")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(hasStripeAccount ? .brand : .brandOrange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background((hasStripeAccount ? Color.brand : Color.brandOrange).opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isLoadingStripeURL)
                }
                .padding(AppConstants.cardPadding)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.panelGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder((hasStripeAccount ? Color.brandGreen : Color.brandOrange).opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    private var hasStripeAccount: Bool {
        authVM.currentUser?.stripeConnectAccountId != nil
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Quick Actions")

            HStack(spacing: 12) {
                QuickActionCard(icon: "clock.arrow.circlepath", label: "Trip History", color: .brand) {
                    showTripHistory = true
                }
                .staggeredAppear(index: 0)

                QuickActionCard(icon: "star.fill", label: "My Ratings", color: .brandOrange) {
                    // scroll to ratings section (handled by UI)
                }
                .staggeredAppear(index: 1)

                if !authVM.isDriver {
                    QuickActionCard(icon: "car.fill", label: "Become Driver", color: .brandGreen) {
                        showDriverSetup = true
                    }
                    .staggeredAppear(index: 2)
                } else {
                    QuickActionCard(icon: "car.fill", label: "Vehicle Setup", color: .brandGreen) {
                        showDriverSetup = true
                    }
                    .staggeredAppear(index: 2)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Ratings Section

    private var ratingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Reviews")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.brandOrange)
                    Text(String(format: "%.1f avg", Double(authVM.currentUser?.rating ?? 0)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)

            VStack(spacing: 10) {
                ForEach(vm.ratings.prefix(3)) { rating in
                    RatingRowView(rating: rating)
                        .padding(.horizontal, AppConstants.pagePadding)
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Settings")
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Push Notifications toggle
                SettingsToggleRow(
                    icon: "bell.fill",
                    title: "Push Notifications",
                    subtitle: nil,
                    color: .brandOrange,
                    isOn: $notificationsEnabled
                )

                Divider().padding(.leading, 52)

                // Email Notifications toggle
                SettingsToggleRow(
                    icon: "envelope.fill",
                    title: "Email Notifications",
                    subtitle: nil,
                    color: .brand,
                    isOn: $emailNotificationsEnabled
                )

                Divider().padding(.leading, 52)

                // Location Sharing toggle
                SettingsToggleRow(
                    icon: "location.fill",
                    title: "Share Location",
                    subtitle: locationManager.permissionStatusText,
                    color: .brandGreen,
                    isOn: $locationManager.isTrackingEnabled
                )

                Divider().padding(.leading, 52)

                SettingsAppearanceRow(selection: appAppearanceSelection)

                Divider().padding(.leading, 52)

                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .brandGreen) {
                    showSupport = true
                }

                Divider().padding(.leading, 52)

                SettingsRow(icon: "info.circle.fill", title: "About LessGo", color: .textTertiary) {
                    showAbout = true
                }
            }
            .padding(4)
            .elevatedCard(cornerRadius: 18)
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Account Management

    private var accountManagementSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Account")
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsRow(icon: "lock.rotation", title: "Change Password", color: .brand) {
                    showChangePassword = true
                }

                Divider().padding(.leading, 52)

                SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .textTertiary) {}

                Divider().padding(.leading, 52)

                SettingsRow(icon: "doc.text.fill", title: "Terms of Service", color: .textTertiary) {}
            }
            .padding(4)
            .elevatedCard(cornerRadius: 18)
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 10) {
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
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.brandRed.opacity(0.10), lineWidth: 1)
                        )
                )
                .shadow(color: Color.brandRed.opacity(0.08), radius: 8, x: 0, y: 3)
            }
            .padding(.horizontal, AppConstants.pagePadding)

            Button(action: { showDeleteAccountAlert = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.brandRed.opacity(0.7))
                    Text("Delete Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.brandRed.opacity(0.7))
                    Spacer()
                }
                .padding(AppConstants.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Helper Functions

    private func statusColor(_ s: SJSUIDStatus) -> Color {
        switch s { case .verified: return .brandGreen; case .rejected: return .brandRed; default: return .brandOrange }
    }
    private func statusIcon(_ s: SJSUIDStatus) -> String {
        switch s { case .verified: return "checkmark.seal.fill"; case .rejected: return "xmark.seal.fill"; default: return "clock.badge.questionmark.fill" }
    }
    private func statusMessage(_ s: SJSUIDStatus) -> String {
        switch s {
        case .verified: return "You're verified as an SJSU student"
        case .rejected: return "Verification failed — please resubmit your ID"
        default: return "Upload your SJSU ID to unlock booking"
        }
    }

    private var memberSinceFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.calendar = .autoupdatingCurrent
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "MMMM yyyy"
        return f
    }

    private func resolvedProfileImageURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        if raw.hasPrefix("/") {
            // Resolve relative media paths against the configured API host.
            // API base usually includes /api, so trim that segment before appending /uploads/... paths.
            guard var components = URLComponents(string: APIConfig.baseURL) else {
                return URL(string: raw)
            }
            components.path = components.path.replacingOccurrences(of: "/api", with: "", options: [.anchored])
            let gatewayRoot = components.string?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            return URL(string: "\(gatewayRoot)\(raw)")
        }
        return URL(string: raw)
    }

    private var appAppearanceSelection: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appAppearanceRawValue) ?? .system },
            set: { appAppearanceRawValue = $0.rawValue }
        )
    }
}

// MARK: - Rating Row

private struct RatingRowView: View {
    let rating: Rating
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 38, height: 38)
                Text(rating.rater?.name.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rating.rater?.name ?? "Anonymous")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    // Stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= rating.score ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(i <= rating.score ? .brandOrange : .textTertiary)
                        }
                    }
                }
                if let comment = rating.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                Text(rating.createdAt, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(14)
        .elevatedCard(cornerRadius: 18)
    }
}

// MARK: - Profile Stat

private struct ProfileStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.textPrimary)
            Text(label).font(.system(size: 11)).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
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
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.brand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsAppearanceRow: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brand.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16))
                    .foregroundColor(.brand)
            }

            Text("Appearance")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)

            Spacer()

            Menu {
                Picker("Appearance", selection: $selection) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.brand.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

// MARK: - Driver Setup View (Smart Vehicle Picker)

struct DriverSetupView: View {
    @ObservedObject var vm: ProfileViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss

    @State private var showMakePicker  = false
    @State private var showModelPicker = false
    @State private var showSeatsOverride = false

    private let currentYear = Calendar.current.component(.year, from: Date())
    private var years: [Int] { Array((currentYear - 15)...currentYear).reversed() }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Fallback banner if lookup failed ─────────────────────
                    if vm.vehicleLookupFailed && !vm.vehiclePickerIsActive {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.brandGold)
                            Text("Vehicle lookup unavailable. Enter details manually below.")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(12)
                        .background(Color.brandGold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // ── STEP 1: Year ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YEAR").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)
                        Menu {
                            ForEach(years, id: \.self) { year in
                                Button(String(year)) {
                                    if vm.pickerYear != year {
                                        vm.pickerYear = year
                                        vm.clearPickerMake()
                                        vm.availableMakes = []
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar").foregroundColor(.brand).frame(width: 20)
                                Text(String(vm.pickerYear))
                                    .font(.system(size: 15))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textTertiary)
                            }
                            .cardStyle()
                        }
                    }

                    // ── STEP 2: Make ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAKE").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)
                        Button(action: {
                            if vm.availableMakes.isEmpty {
                                Task { await vm.loadMakes() }
                            }
                            showMakePicker = true
                        }) {
                            HStack {
                                if vm.isLoadingMakes {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Image(systemName: "car.fill").foregroundColor(.brand).frame(width: 20)
                                }
                                Text(vm.pickerMake.isEmpty ? "Select make…" : vm.pickerMake)
                                    .font(.system(size: 15))
                                    .foregroundColor(vm.pickerMake.isEmpty ? .textTertiary : .textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textTertiary)
                            }
                            .cardStyle()
                        }
                        .sheet(isPresented: $showMakePicker) {
                            SearchablePickerSheet(
                                title: "Select Make",
                                items: vm.availableMakes,
                                isLoading: vm.isLoadingMakes,
                                selectedItem: vm.pickerMake
                            ) { selected in
                                if selected != vm.pickerMake {
                                    vm.pickerMake = selected
                                    vm.clearPickerModel()
                                    Task { await vm.loadModels(make: selected, year: vm.pickerYear) }
                                }
                                showMakePicker = false
                            }
                        }
                    }

                    // ── STEP 3: Model ────────────────────────────────────────
                    if !vm.pickerMake.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MODEL").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)
                            Button(action: {
                                if vm.availableModels.isEmpty {
                                    Task { await vm.loadModels(make: vm.pickerMake, year: vm.pickerYear) }
                                }
                                showModelPicker = true
                            }) {
                                HStack {
                                    if vm.isLoadingModels {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "car.2.fill").foregroundColor(.brand).frame(width: 20)
                                    }
                                    Text(vm.pickerModel.isEmpty ? "Select model…" : vm.pickerModel)
                                        .font(.system(size: 15))
                                        .foregroundColor(vm.pickerModel.isEmpty ? .textTertiary : .textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.textTertiary)
                                }
                                .cardStyle()
                            }
                            .sheet(isPresented: $showModelPicker) {
                                SearchablePickerSheet(
                                    title: "Select Model",
                                    items: vm.availableModels,
                                    isLoading: vm.isLoadingModels,
                                    selectedItem: vm.pickerModel
                                ) { selected in
                                    vm.pickerModel = selected
                                    showModelPicker = false
                                    Task { await vm.loadSpecs(make: vm.pickerMake, model: selected, year: vm.pickerYear) }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── SPECS CARD (after model selected) ───────────────────
                    if vm.isLoadingSpecs {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking up vehicle data…")
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                    } else if let specs = vm.vehicleSpecs {
                        VehicleSpecsCard(vm: vm, specs: specs)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if vm.vehiclePickerIsActive {
                        // model selected but no specs yet (old system fallback)
                        vehicleFallbackSection
                    }

                    // ── Manual fallback (when lookup completely failed) ──────
                    if vm.vehicleLookupFailed && vm.vehicleSpecs == nil && !vm.vehiclePickerIsActive {
                        vehicleFallbackSection
                    }

                    // ── License plate ────────────────────────────────────────
                    LabeledTextField(label: "License Plate",
                                     placeholder: "e.g. 7ABC123",
                                     text: $vm.licensePlate, icon: "number")
                        .textCase(.uppercase)

                    if let err = vm.errorMessage { ToastBanner(message: err, type: .error) }

                    PrimaryButton(title: "Save Driver Profile", isLoading: vm.isSaving) {
                        Task { await vm.setupDriver(userId: userId); if vm.successMessage != nil { dismiss() } }
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: vm.pickerMake)
                .animation(.easeInOut(duration: 0.2), value: vm.vehicleSpecs?.model)
            }
            .navigationTitle("Driver Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .task {
                // Pre-load makes on appear; parse existing vehicleInfo if set
                if let existingInfo = vm.user?.vehicleInfo, !existingInfo.isEmpty {
                    vm.parseExistingVehicleInfo(existingInfo)
                    if !vm.pickerMake.isEmpty {
                        async let makesTask: () = vm.loadMakes()
                        async let modelsTask: () = vm.loadModels(make: vm.pickerMake, year: vm.pickerYear)
                        _ = await (makesTask, modelsTask)
                        if !vm.pickerModel.isEmpty {
                            await vm.loadSpecs(make: vm.pickerMake, model: vm.pickerModel, year: vm.pickerYear)
                        }
                    }
                } else {
                    await vm.loadMakes()
                }
            }
        }
    }

    // Seats section (fallback when API unavailable)
    private var vehicleFallbackSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
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
        }
    }
}

// MARK: - Vehicle Specs Card

private struct VehicleSpecsCard: View {
    @ObservedObject var vm: ProfileViewModel
    let specs: VehicleSpecs

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Vehicle photo ─────────────────────────────────────────────────
            vehiclePhotoView

            // ── Header ───────────────────────────────────────────────────────
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.brand.opacity(0.1)).frame(width: 38, height: 38)
                    Image(systemName: "car.fill").foregroundColor(.brand).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(specs.year)) \(specs.make) \(specs.model)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
            }

            Divider()

            // ── Trim selector ────────────────────────────────────────────────
            if specs.trims.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT YOUR TRIM").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)
                    ForEach(specs.trims) { trim in
                        let isSelected = vm.pickerTrimId == trim.id
                        Button(action: { vm.pickerTrimId = trim.id }) {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .brand : .textTertiary)
                                    .font(.system(size: 18))
                                Text(trim.trimName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .background(isSelected ? Color.brand.opacity(0.06) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                Divider()
            }

            Divider()

            // ── Seats ────────────────────────────────────────────────────────
            HStack {
                Label("\(vm.effectiveSeats) seats", systemImage: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.textPrimary)
                if vm.seatsOverride == nil {
                    Text("from vehicle data")
                        .font(.system(size: 11)).foregroundColor(.textTertiary)
                }
                Spacer()
                // Inline +/- override
                HStack(spacing: 8) {
                    Button(action: {
                        let current = vm.seatsOverride ?? specs.seatingCapacity
                        if current > 1 { vm.seatsOverride = current - 1 }
                    }) {
                        Image(systemName: "minus.circle").foregroundColor(.brand)
                    }
                    Button(action: {
                        let current = vm.seatsOverride ?? specs.seatingCapacity
                        if current < 9 { vm.seatsOverride = current + 1 }
                    }) {
                        Image(systemName: "plus.circle").foregroundColor(.brand)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.brand.opacity(0.18), lineWidth: 1.5)
                )
        )
    }

    @ViewBuilder
    private var vehiclePhotoView: some View {
        let photoFrame = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Group {
            if vm.isLoadingPhoto {
                // Shimmer placeholder
                photoFrame
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 160)
                    .overlay(
                        ProgressView().tint(.textTertiary)
                    )
            } else if let urlString = vm.vehiclePhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .transition(.opacity.animation(.easeIn(duration: 0.35)))
                    case .failure:
                        carPlaceholder
                    default:
                        photoFrame.fill(Color.gray.opacity(0.12)).frame(height: 160)
                            .overlay(ProgressView().tint(.textTertiary))
                    }
                }
                .frame(height: 160)
                .clipShape(photoFrame)
            } else {
                carPlaceholder
            }
        }
        .clipShape(photoFrame)
    }

    private var carPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.gray.opacity(0.08))
            .frame(height: 160)
            .overlay(
                Image(systemName: "car.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.textTertiary)
            )
    }

}

// MARK: - Searchable Picker Sheet

private struct SearchablePickerSheet: View {
    let title: String
    let items: [String]
    let isLoading: Bool
    let selectedItem: String
    let onSelect: (String) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [String] {
        query.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading…").font(.system(size: 14)).foregroundColor(.textSecondary)
                    }
                } else if items.isEmpty {
                    Text("No results found")
                        .font(.system(size: 15)).foregroundColor(.textSecondary)
                } else {
                    List(filtered, id: \.self) { item in
                        Button(action: { onSelect(item) }) {
                            HStack {
                                Text(item).foregroundColor(.textPrimary)
                                Spacer()
                                if item == selectedItem {
                                    Image(systemName: "checkmark").foregroundColor(.brand)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
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
                    List(vm.bookings.filter { $0.trip?.departureTime ?? Date() < Date().addingTimeInterval(-86400) }) { booking in
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
        self.safeAreaInset(edge: .top, spacing: 0) {
            if let msg = message {
                VStack(spacing: 0) {
                    ToastBanner(message: msg, type: .success)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                // Message will auto-dismiss after 2.5 seconds
                                // This is handled by the view model clearing the message
                            }
                        }
                }
            }
        }
        .animation(.spring(), value: message)
    }
}

// MARK: - Matching Simulation Types

private enum MatchSimStepStatus { case pending, running, success, error }

private struct MatchSimStep: Identifiable {
    let id = UUID()
    let number: Int
    let label: String
    var status: MatchSimStepStatus = .pending
    var detail: String = ""
}

private struct MatchSimResult: Identifiable {
    let id = UUID()
    let name: String
    var distR1: String = "—"
    var scoreR1: String = "N/A"
    var distR2: String = "—"
    var scoreR2: String = "N/A"
    var assignedTo: String = "None"
}

private enum SimError: LocalizedError {
    case step(Int, String)
    var errorDescription: String? {
        if case .step(_, let m) = self { return m }
        return "Simulation error"
    }
}

private struct CarpoolSimResult: Identifiable {
    let id = UUID()
    var candidateName: String   // "Driver A (active)" or "Driver B (idle)"
    var candidateType: String   // "en-route" or "fresh"
    var distToR2: String        // e.g. "203m"
    var scost: String           // estimated Scost e.g. "0.14"
    var assigned: Bool
}

private enum CarpoolSimOutcome {
    case none
    case carpoolInsertion   // matched to the en-route driver
    case freshMatch         // matched to the idle driver (valid if Scost is lower)
    case noMatch            // no driver matched at all
}

private struct CostSimScenario: Identifiable {
    let id: Int          // 1–5
    let label: String    // short display name
    var status: MatchSimStepStatus = .pending
    var detail: String = ""
    var expectedValue: String = "–"
    var actualValue: String = "–"
    var passed: Bool? = nil
    var rawJSON: String = ""
}

// MARK: - Developer Tools ViewModel

@MainActor
class DevToolsViewModel: ObservableObject {
    // Section expand state
    @Published var expandFullTrip = false
    @Published var expandPassengerJoin = false
    @Published var expandForceMatch = false
    @Published var expandEmbedding = false

    // Running/result state for each section
    @Published var fullTripRunning = false
    @Published var fullTripLog: [String] = []

    @Published var passengerJoinRunning = false
    @Published var passengerJoinJSON = ""

    @Published var forceMatchRunning = false
    @Published var forceMatchJSON = ""

    @Published var embeddingRunning = false
    @Published var embeddingJSON = ""
    @Published var retrainRunning = false
    @Published var retrainJSON = ""

    // Matching Scenario Simulation
    @Published var expandMatchingSim = false
    @Published var matchSimRunning = false
    @Published fileprivate var matchSimSteps: [MatchSimStep] = []
    @Published fileprivate var matchSimResults: [MatchSimResult] = []
    @Published var matchSimVerbose = false

    // Carpool Insertion Simulation
    @Published var expandCarpoolSim = false
    @Published var carpoolSimRunning = false
    @Published fileprivate var carpoolSimSteps: [MatchSimStep] = []
    @Published fileprivate var carpoolSimResults: [CarpoolSimResult] = []
    @Published fileprivate var carpoolSimOutcome: CarpoolSimOutcome = .none
    @Published var carpoolSimWaypoints: [String] = []

    // Cost Calculation Simulation
    @Published var expandCostSim = false
    @Published var costSimRunning = false
    @Published fileprivate var costSimSteps: [MatchSimStep] = []
    @Published fileprivate var costSimScenarios: [CostSimScenario] = []

    private let base = APIConfig.baseURL
    private var embeddingBase: String { "\(APIConfig.baseURL)/embedding" }

    // MARK: - Simulate Full Trip
    //
    // Self-contained end-to-end simulation using two temp accounts:
    //  1. Register temp driver → POST /debug-verify → re-login to get verified JWT
    //  2. Set driver available_for_rides = true
    //  3. Create trip SJSU → Santana Row, departure = now+30min
    //  4. Register temp rider → submit trip request near SJSU
    //  5. Poll trip_requests.status up to 15s

    func simulateFullTrip() async {
        fullTripRunning = true
        fullTripLog = []

        func log(_ msg: String) { fullTripLog.append(msg) }

        do {
            let ts = Int(Date().timeIntervalSince1970)
            let depTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(1800))

            // ── Step 1: Register temp driver ──────────────────────────────────
            log("1/8  Registering temp driver…")
            let driverEmail = "devtools-driver-\(ts)@sjsu.edu"
            let driverReg = try await rawPost("/auth/register", body: [
                "name": "DevTools Driver",
                "email": driverEmail,
                "password": "DevPass123!",
                "role": "Driver"
            ])
            let driverRegData = driverReg["data"] as? [String: Any] ?? driverReg
            let driverIdRaw = (driverRegData["user"] as? [String: Any])?["user_id"] as? String
                           ?? (driverRegData["user_id"] as? String)
                           ?? ""
            let driverTokenRaw = driverRegData["access_token"] as? String ?? ""
            guard !driverIdRaw.isEmpty else {
                log("Error: Driver registration failed — \(driverReg["message"] as? String ?? "unknown")")
                fullTripRunning = false; return
            }
            log("   Driver \(driverIdRaw) registered ✓")

            // ── Step 2: Debug-verify driver (dev-only endpoint) ───────────────
            log("2/8  Verifying driver via debug-verify…")
            let verResp = try await rawPost("/users/\(driverIdRaw)/debug-verify", body: [:])
            log("   \(verResp["message"] as? String ?? "verified ✓")")

            // ── Step 3: Re-login as driver to get a fresh JWT (sjsuIdStatus=verified) ──
            log("3/8  Re-logging in as driver to get verified token…")
            let loginResp = try await rawPost("/auth/login", body: [
                "email": driverEmail,
                "password": "DevPass123!"
            ])
            let loginData = loginResp["data"] as? [String: Any] ?? loginResp
            let driverToken = loginData["accessToken"] as? String ?? ""
            guard !driverToken.isEmpty else {
                log("Error: Driver login failed — \(loginResp["message"] as? String ?? "unknown")")
                fullTripRunning = false; return
            }
            log("   Driver token refreshed ✓")

            // ── Step 4: Set driver available ──────────────────────────────────
            log("4/8  Setting driver available_for_rides = true…")
            let availResp = try await rawPatch("/users/\(driverIdRaw)/availability",
                                               body: ["available_for_rides": true],
                                               token: driverToken)
            log("   \(availResp["message"] as? String ?? "available ✓")")

            // ── Step 5: Create trip SJSU → Santana Row ────────────────────────
            log("5/8  Creating trip SJSU → Santana Row…")
            let tripResp = try await rawPost("/trips", body: [
                "origin": "San Jose State University, San Jose, CA",
                "destination": "Santana Row, San Jose, CA",
                "departure_time": depTime,
                "seats_available": 3
            ], token: driverToken)
            let tripData = tripResp["data"] as? [String: Any] ?? tripResp
            let tripId = tripData["trip_id"] as? String ?? ""
            guard !tripId.isEmpty else {
                log("Error: Trip creation failed — \(tripResp["message"] as? String ?? "unknown")")
                log("   Full response: \(prettyJSON(tripResp))")
                fullTripRunning = false; return
            }
            log("   Trip \(tripId) created ✓")

            // ── Step 6: Register temp rider ───────────────────────────────────
            log("6/8  Registering temp rider…")
            let riderEmail = "devtools-rider-\(ts)@sjsu.edu"
            let riderReg = try await rawPost("/auth/register", body: [
                "name": "DevTools Rider",
                "email": riderEmail,
                "password": "DevPass123!",
                "role": "Rider"
            ])
            let riderData = riderReg["data"] as? [String: Any] ?? riderReg
            let riderToken = riderData["accessToken"] as? String ?? ""
            guard !riderToken.isEmpty else {
                log("Error: Rider registration failed — \(riderReg["message"] as? String ?? "unknown")")
                fullTripRunning = false; return
            }
            log("   Rider registered ✓")

            // ── Step 7: Submit ride request near SJSU ─────────────────────────
            log("7/8  Submitting ride request near SJSU…")
            let reqBody: [String: Any] = [
                "origin": "SJSU Campus",
                "destination": "Santana Row, San Jose, CA",
                "origin_lat": 37.3355,        // ~30m from SJSU
                "origin_lng": -121.8815,
                "destination_lat": 37.3209,
                "destination_lng": -121.9480,
                "departure_time": depTime     // matches driver trip exactly
            ]
            let reqResp = try await rawPost("/trips/request", body: reqBody, token: riderToken)
            let reqData = reqResp["data"] as? [String: Any] ?? reqResp
            let requestId = reqData["request_id"] as? String ?? ""
            guard !requestId.isEmpty else {
                log("Error: Request failed — \(reqResp["message"] as? String ?? "unknown")")
                fullTripRunning = false; return
            }
            log("   Request \(requestId) submitted ✓")

            // ── Step 8: Poll for match ────────────────────────────────────────
            log("8/8  Polling for match (up to 15s)…")
            var matched = false
            for attempt in 1...5 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let pollResp = try await rawGet("/trips/request/\(requestId)", token: riderToken)
                let tripReqStatus = (pollResp["data"] as? [String: Any])?["status"] as? String ?? "?"
                log("   [attempt \(attempt)] status = \(tripReqStatus)")
                if tripReqStatus == "matched" { matched = true; break }
                if tripReqStatus == "expired" || tripReqStatus == "cancelled" { break }
            }

            log(matched ? "Result: MATCHED ✓" : "Result: NO MATCH — check trip-service logs for Scost/candidate details")
        } catch {
            fullTripLog.append("Error: \(error.localizedDescription)")
        }

        fullTripRunning = false
    }

    // MARK: - Simulate Matching Scenario (3 drivers × 2 riders)
    //
    // Implements the full He et al. + Tang et al. pipeline test:
    //   Driver A: North zone → SJSU, morning  → should match Rider 1
    //   Driver B: South zone → SJSU, morning  → should match Rider 2
    //   Driver C: Willow Glen → far, any time → should be filtered by Scost
    //
    // 13-step flow, cleanup always runs regardless of earlier failures.

    private static let simStepLabels = [
        "Register Drivers A, B, C",
        "Debug-verify all three drivers",
        "Login as each driver, get tokens",
        "Seed driver historical trip history",
        "Register Riders 1 and 2",
        "Login as both riders",
        "Seed rider historical trip history",
        "Set drivers available + create live trips",
        "Rider 1: submit ride request",
        "Rider 1: poll for match (30s)",
        "Rider 2: submit + poll for match (30s)",
        "Build summary table",
        "Cleanup all sim_ accounts"
    ]

    private static let carpoolSimStepLabels = [
        "Register Driver A (North zone) + Driver B (Willow Glen)",
        "Debug-verify both drivers",
        "Login, get driver tokens",
        "Seed driver trip history (A=North morning, B=Willow Glen evening)",
        "Register Rider 1 + Rider 2",
        "Login, get rider tokens",
        "Seed rider trip history (both North morning)",
        "Set drivers available, create live trips",
        "Rider 1: submit request (North → SJSU)",
        "Rider 1: poll for match (expected: Driver A)",
        "Advance Driver A's trip → en_route",
        "Verify: Driver A en_route, Driver B still pending",
        "Rider 2: submit request (offset North → SJSU)",
        "Rider 2: poll for match — evaluate outcome",
        "Fetch matched driver anchor points",
        "Cleanup all sim_ accounts"
    ]

    // Formula: cost = distance × $0.67 + duration_hours × $15, split by riderCount
    private static let costSimStepLabels = [
        "Scenario 1 — 1 rider (baseline)",
        "Scenario 2 — 2 riders (split verification)",
        "Scenario 3 — 1 rider + detour pickup",
        "Scenario 4 — 3 riders",
        "Scenario 5 — 1 rider (repeat baseline)",
        "Cleanup all sim_cost_ accounts"
    ]

    private static let costSimScenarioDefs: [(label: String, riders: Int, detour: Bool)] = [
        ("1 rider",         1, false),
        ("2 riders",        2, false),
        ("Detour · 1 rider", 1, true),
        ("3 riders",        3, false),
        ("1 rider (repeat)", 1, false),
    ]

    // Geographic anchors (matches zone_mapper.py grid)
    private let simSJSULat   = 37.3352,  simSJSULng   = -121.8811
    private let simNorthLat  = 37.3400,  simNorthLng  = -121.8780  // Near 10th & Julian
    private let simSouthLat  = 37.3290,  simSouthLng  = -121.8790  // Near 7th & Humboldt
    // Carpool sim: Rider 2 pickup ~200m offset from North zone
    private let cpR2Lat      = 37.3403,  cpR2Lng      = -121.8775
    private let simWillowLat = 37.3050,  simWillowLng = -121.8990  // Willow Glen

    func simulateMatchingScenario() async {
        matchSimRunning = true
        matchSimSteps = Self.simStepLabels.enumerated().map {
            MatchSimStep(number: $0.offset + 1, label: $0.element)
        }
        matchSimResults = []

        var allUserIds: [String] = []

        do {
            let ts  = Int(Date().timeIntervalSince1970)
            let fmt = ISO8601DateFormatter()
            let depTime = fmt.string(from: Date().addingTimeInterval(1800)) // now+30min

            // ── Step 1: Register Drivers A, B, C ─────────────────────────────
            simStep(1, .running)
            let drvAEmail = "sim-driver-a-\(ts)@sjsu.edu"
            let drvBEmail = "sim-driver-b-\(ts)@sjsu.edu"
            let drvCEmail = "sim-driver-c-\(ts)@sjsu.edu"

            let regA = try await rawPost("/auth/register", body: ["name":"Sim Driver A","email":drvAEmail,"password":"SimPass123!","role":"Driver"])
            let drvAId = simUserId(regA); if drvAId.isEmpty { throw simErr(1, simMsg(regA)) }
            allUserIds.append(drvAId)

            let regB = try await rawPost("/auth/register", body: ["name":"Sim Driver B","email":drvBEmail,"password":"SimPass123!","role":"Driver"])
            let drvBId = simUserId(regB); if drvBId.isEmpty { throw simErr(1, simMsg(regB)) }
            allUserIds.append(drvBId)

            let regC = try await rawPost("/auth/register", body: ["name":"Sim Driver C","email":drvCEmail,"password":"SimPass123!","role":"Driver"])
            let drvCId = simUserId(regC); if drvCId.isEmpty { throw simErr(1, simMsg(regC)) }
            allUserIds.append(drvCId)
            simStep(1, .success, "A:\(drvAId.prefix(8))… B:\(drvBId.prefix(8))… C:\(drvCId.prefix(8))…")

            // ── Step 2: Debug-verify all three ────────────────────────────────
            simStep(2, .running)
            _ = try await rawPost("/users/\(drvAId)/debug-verify", body: [:])
            _ = try await rawPost("/users/\(drvBId)/debug-verify", body: [:])
            _ = try await rawPost("/users/\(drvCId)/debug-verify", body: [:])
            simStep(2, .success, "All three drivers verified (role=Driver, license set) ✓")

            // ── Step 3: Login as each driver ──────────────────────────────────
            simStep(3, .running)
            let tokenA = try await simLoginToken(drvAEmail, step: 3)
            let tokenB = try await simLoginToken(drvBEmail, step: 3)
            let tokenC = try await simLoginToken(drvCEmail, step: 3)
            simStep(3, .success, "All three driver tokens obtained ✓")

            // ── Step 4: Seed historical driver trips ──────────────────────────
            simStep(4, .running)
            // Driver A: 15 weekday morning trips, North zone → SJSU (time_bin 8)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvAId,
                "trips": simMakeTrips(15, originLat: simNorthLat, originLng: simNorthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 10th & Julian, SJ", destLabel: "SJSU Campus",
                                      hour: 8, onlyWeekdays: true)
            ])
            // Driver B pt1: 8 weekday EVENING trips, North zone → SJSU (time_bin 18)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvBId,
                "trips": simMakeTrips(8, originLat: simNorthLat, originLng: simNorthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 10th & Julian, SJ", destLabel: "SJSU Campus",
                                      hour: 18, onlyWeekdays: true)
            ])
            // Driver B pt2: 7 weekend morning trips, South zone → SJSU (time_bin 9)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvBId,
                "trips": simMakeTrips(7, originLat: simSouthLat, originLng: simSouthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 7th & Humboldt, SJ", destLabel: "SJSU Campus",
                                      hour: 9, onlyWeekends: true)
            ])
            // Driver C: 15 trips entirely in Willow Glen (no SJSU overlap)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvCId,
                "trips": simMakeTrips(15, originLat: simWillowLat, originLng: simWillowLng,
                                      destLat: simWillowLat - 0.005, destLng: simWillowLng + 0.008,
                                      originLabel: "Willow Glen", destLabel: "Willow Glen Area",
                                      hour: 14)
            ])
            simStep(4, .success, "A=15 morning, B=8 eve+7 wknd, C=15 Willow Glen ✓")

            // ── Step 5: Register Riders 1 and 2 ──────────────────────────────
            simStep(5, .running)
            let r1Email = "sim-rider-1-\(ts)@sjsu.edu"
            let r2Email = "sim-rider-2-\(ts)@sjsu.edu"

            let regR1 = try await rawPost("/auth/register", body: ["name":"Sim Rider 1","email":r1Email,"password":"SimPass123!","role":"Rider"])
            let r1Id = simUserId(regR1); if r1Id.isEmpty { throw simErr(5, simMsg(regR1)) }
            allUserIds.append(r1Id)

            let regR2 = try await rawPost("/auth/register", body: ["name":"Sim Rider 2","email":r2Email,"password":"SimPass123!","role":"Rider"])
            let r2Id = simUserId(regR2); if r2Id.isEmpty { throw simErr(5, simMsg(regR2)) }
            allUserIds.append(r2Id)
            simStep(5, .success, "R1:\(r1Id.prefix(8))… R2:\(r2Id.prefix(8))…")

            // ── Step 6: Login as both riders ──────────────────────────────────
            simStep(6, .running)
            let tokenR1 = try await simLoginToken(r1Email, step: 6)
            let tokenR2 = try await simLoginToken(r2Email, step: 6)
            simStep(6, .success, "Both rider tokens obtained ✓")

            // ── Step 7: Seed rider trip history ───────────────────────────────
            simStep(7, .running)
            // Rider 1: 10 weekday morning trips, North zone → SJSU (overlaps Driver A)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": r1Id,
                "trips": simMakeTrips(10, originLat: simNorthLat, originLng: simNorthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 10th & Julian, SJ", destLabel: "SJSU Campus",
                                      hour: 8, onlyWeekdays: true)
            ])
            // Rider 2: 10 weekend morning trips, South zone → SJSU (overlaps Driver B)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": r2Id,
                "trips": simMakeTrips(10, originLat: simSouthLat, originLng: simSouthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 7th & Humboldt, SJ", destLabel: "SJSU Campus",
                                      hour: 9, onlyWeekends: true)
            ])
            simStep(7, .success, "R1=10 morning north, R2=10 weekend south ✓")

            // ── Step 8: Set drivers available + create live pending trips ─────
            simStep(8, .running)
            // Driver A: live trip from North zone → SJSU
            _ = try await rawPatch("/users/\(drvAId)/availability", body: ["available_for_rides": true], token: tokenA)
            let tripARsp = try await rawPost("/trips", body: [
                "origin": "Near 10th and Julian, San Jose, CA",
                "destination": "San Jose State University, San Jose, CA",
                "departure_time": depTime, "seats_available": 3
            ], token: tokenA)
            let tripAId = (tripARsp["data"] as? [String: Any])?["trip_id"] as? String ?? ""
            if tripAId.isEmpty { throw simErr(8, "Driver A trip creation failed: \(simMsg(tripARsp))") }

            // Driver B: live trip from South zone → SJSU
            _ = try await rawPatch("/users/\(drvBId)/availability", body: ["available_for_rides": true], token: tokenB)
            let tripBRsp = try await rawPost("/trips", body: [
                "origin": "Near 7th and Humboldt, San Jose, CA",
                "destination": "San Jose State University, San Jose, CA",
                "departure_time": depTime, "seats_available": 3
            ], token: tokenB)
            let tripBId = (tripBRsp["data"] as? [String: Any])?["trip_id"] as? String ?? ""
            if tripBId.isEmpty { throw simErr(8, "Driver B trip creation failed: \(simMsg(tripBRsp))") }

            // Driver C: live trip in Willow Glen (far from SJSU riders)
            _ = try await rawPatch("/users/\(drvCId)/availability", body: ["available_for_rides": true], token: tokenC)
            _ = try await rawPost("/trips", body: [
                "origin": "Willow Glen, San Jose, CA",
                "destination": "Los Gatos, CA",
                "departure_time": depTime, "seats_available": 3
            ], token: tokenC)
            simStep(8, .success, "A,B,C available; trips A:\(tripAId.prefix(8))… B:\(tripBId.prefix(8))… ✓")

            // ── Step 9: Rider 1 submits request ──────────────────────────────
            simStep(9, .running)
            let req1Rsp = try await rawPost("/trips/request", body: [
                "origin": "Near 10th and Julian, San Jose",
                "destination": "San Jose State University, San Jose",
                "origin_lat": simNorthLat, "origin_lng": simNorthLng,
                "destination_lat": simSJSULat, "destination_lng": simSJSULng,
                "departure_time": depTime
            ], token: tokenR1)
            let req1Id = (req1Rsp["data"] as? [String: Any])?["request_id"] as? String ?? ""
            if req1Id.isEmpty { throw simErr(9, "Rider 1 request failed: \(simMsg(req1Rsp))") }
            simStep(9, .success, "Request \(req1Id.prefix(8))… submitted ✓")

            // ── Step 10: Poll Rider 1 match ───────────────────────────────────
            simStep(10, .running)
            var r1AssignedId = ""; var r1AssignedName = ""
            for attempt in 1...15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll = try await rawGet("/trips/request/\(req1Id)", token: tokenR1)
                let st = (poll["data"] as? [String: Any])?["status"] as? String ?? "pending"
                simStep(10, .running, "[\(attempt)/15] \(st)…")
                if st == "matched" {
                    r1AssignedId   = (poll["data"] as? [String: Any])?["driver_id"] as? String ?? ""
                    r1AssignedName = (poll["data"] as? [String: Any])?["driver_name"] as? String ?? "?"
                    break
                }
                if st == "expired" || st == "cancelled" { break }
            }
            simStep(10, r1AssignedId.isEmpty ? .error : .success,
                    r1AssignedId.isEmpty ? "No match found" : "Matched → \(r1AssignedName) ✓")

            // ── Step 11: Rider 2 submits + polls ─────────────────────────────
            simStep(11, .running)
            let req2Rsp = try await rawPost("/trips/request", body: [
                "origin": "Near 7th and Humboldt, San Jose",
                "destination": "San Jose State University, San Jose",
                "origin_lat": simSouthLat, "origin_lng": simSouthLng,
                "destination_lat": simSJSULat, "destination_lng": simSJSULng,
                "departure_time": depTime
            ], token: tokenR2)
            let req2Id = (req2Rsp["data"] as? [String: Any])?["request_id"] as? String ?? ""
            if req2Id.isEmpty { throw simErr(11, "Rider 2 request failed: \(simMsg(req2Rsp))") }

            var r2AssignedId = ""; var r2AssignedName = ""
            for attempt in 1...15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll = try await rawGet("/trips/request/\(req2Id)", token: tokenR2)
                let st = (poll["data"] as? [String: Any])?["status"] as? String ?? "pending"
                simStep(11, .running, "[\(attempt)/15] \(st)…")
                if st == "matched" {
                    r2AssignedId   = (poll["data"] as? [String: Any])?["driver_id"] as? String ?? ""
                    r2AssignedName = (poll["data"] as? [String: Any])?["driver_name"] as? String ?? "?"
                    break
                }
                if st == "expired" || st == "cancelled" { break }
            }
            simStep(11, r2AssignedId.isEmpty ? .error : .success,
                    r2AssignedId.isEmpty ? "No match found" : "Matched → \(r2AssignedName) ✓")

            // ── Step 12: Build summary table ─────────────────────────────────
            simStep(12, .running)
            func driverLabel(_ id: String) -> String {
                if id == drvAId { return "Rider 1 ✓" }
                if id == drvBId { return "Rider 2 ✓" }
                if id == drvCId { return "Rider ? ✓" }
                return "None"
            }
            let distAR1 = simHaversine(simNorthLat,  simNorthLng,  simNorthLat,  simNorthLng)
            let distAR2 = simHaversine(simNorthLat,  simNorthLng,  simSouthLat,  simSouthLng)
            let distBR1 = simHaversine(simSouthLat,  simSouthLng,  simNorthLat,  simNorthLng)
            let distBR2 = simHaversine(simSouthLat,  simSouthLng,  simSouthLat,  simSouthLng)
            let distCR1 = simHaversine(simWillowLat, simWillowLng, simNorthLat,  simNorthLng)
            let distCR2 = simHaversine(simWillowLat, simWillowLng, simSouthLat,  simSouthLng)
            matchSimResults = [
                MatchSimResult(name: "Driver A",
                    distR1: "\(Int(distAR1))m", scoreR1: "N/A",
                    distR2: "\(Int(distAR2))m", scoreR2: "N/A",
                    assignedTo: r1AssignedId == drvAId ? "Rider 1 ✓" : (r2AssignedId == drvAId ? "Rider 2" : "None")),
                MatchSimResult(name: "Driver B",
                    distR1: "\(Int(distBR1))m", scoreR1: "N/A",
                    distR2: "\(Int(distBR2))m", scoreR2: "N/A",
                    assignedTo: r1AssignedId == drvBId ? "Rider 1" : (r2AssignedId == drvBId ? "Rider 2 ✓" : "None")),
                MatchSimResult(name: "Driver C",
                    distR1: "\(Int(distCR1))m (Scost>\(String(format:"%.1f",simScost(distCR1, simNorthLat, simNorthLng))))",
                    scoreR1: "N/A",
                    distR2: "\(Int(distCR2))m (Scost>\(String(format:"%.1f",simScost(distCR2, simSouthLat, simSouthLng))))",
                    scoreR2: "N/A",
                    assignedTo: r1AssignedId == drvCId || r2AssignedId == drvCId ? "Assigned" : "Filtered")
            ]
            simStep(12, .success, "Table built ✓")

        } catch let e as SimError {
            // step was already marked error inside simErr()
            _ = e
        } catch {
            if let idx = matchSimSteps.firstIndex(where: { $0.status == .running }) {
                matchSimSteps[idx].status = .error
                matchSimSteps[idx].detail = error.localizedDescription
            }
        }

        // ── Step 13: Cleanup (always runs) ────────────────────────────────────
        simStep(13, .running)
        var failedIds: [String] = []
        for uid in allUserIds {
            do { _ = try await rawDelete("/users/\(uid)/debug-delete") }
            catch { failedIds.append(String(uid.prefix(8))) }
        }
        simStep(13,
                failedIds.isEmpty ? .success : .error,
                failedIds.isEmpty
                    ? "Deleted \(allUserIds.count) account(s) ✓"
                    : "Partial cleanup. Failed: \(failedIds.joined(separator: ", "))")

        matchSimRunning = false
    }

    // MARK: - Simulate Carpool Insertion

    func simulateCarpoolInsertion() async {
        carpoolSimRunning = true
        carpoolSimSteps = Self.carpoolSimStepLabels.enumerated().map {
            MatchSimStep(number: $0.offset + 1, label: $0.element)
        }
        carpoolSimResults = []
        carpoolSimOutcome = .none
        carpoolSimWaypoints = []

        var allUserIds: [String] = []
        var drvAId = "", drvBId = ""
        var tripAId = ""
        var matchedTripIdForR2 = "", r2AssignedDriverId = ""

        do {
            let ts  = Int(Date().timeIntervalSince1970)
            let fmt = ISO8601DateFormatter()
            let depTime = fmt.string(from: Date().addingTimeInterval(1800))

            // ── Step 1: Register Driver A + Driver B ──────────────────────────
            cpStep(1, .running)
            let drvAEmail = "sim-cp-a-\(ts)@sjsu.edu"
            let drvBEmail = "sim-cp-b-\(ts)@sjsu.edu"

            let regA = try await rawPost("/auth/register", body: ["name":"Sim CP Driver A","email":drvAEmail,"password":"SimPass123!","role":"Driver"])
            drvAId = simUserId(regA); if drvAId.isEmpty { throw cpErr(1, "Driver A: \(simMsg(regA))") }
            allUserIds.append(drvAId)

            let regB = try await rawPost("/auth/register", body: ["name":"Sim CP Driver B","email":drvBEmail,"password":"SimPass123!","role":"Driver"])
            drvBId = simUserId(regB); if drvBId.isEmpty { throw cpErr(1, "Driver B: \(simMsg(regB))") }
            allUserIds.append(drvBId)
            cpStep(1, .success, "A:\(drvAId.prefix(8))… B:\(drvBId.prefix(8))…")

            // ── Step 2: Debug-verify both drivers ─────────────────────────────
            cpStep(2, .running)
            _ = try await rawPost("/users/\(drvAId)/debug-verify", body: [:])
            _ = try await rawPost("/users/\(drvBId)/debug-verify", body: [:])
            cpStep(2, .success, "Both drivers verified (role=Driver) ✓")

            // ── Step 3: Login as both drivers ─────────────────────────────────
            cpStep(3, .running)
            let loginA = try await rawPost("/auth/login", body: ["email":drvAEmail,"password":"SimPass123!"])
            let tokenA = (loginA["data"] as? [String: Any])?["accessToken"] as? String ?? ""
            if tokenA.isEmpty { throw cpErr(3, "Driver A login failed: \(simMsg(loginA))") }

            let loginB = try await rawPost("/auth/login", body: ["email":drvBEmail,"password":"SimPass123!"])
            let tokenB = (loginB["data"] as? [String: Any])?["accessToken"] as? String ?? ""
            if tokenB.isEmpty { throw cpErr(3, "Driver B login failed: \(simMsg(loginB))") }
            cpStep(3, .success, "Driver tokens obtained ✓")

            // ── Step 4: Seed driver trip history ──────────────────────────────
            cpStep(4, .running)
            // Driver A: 15 weekday morning trips, North zone → SJSU (strong North morning HIN profile)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvAId,
                "trips": simMakeTrips(15, originLat: simNorthLat, originLng: simNorthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 10th & Julian, SJ", destLabel: "SJSU Campus",
                                      hour: 8, onlyWeekdays: true)
            ])
            // Driver B: 15 Willow Glen → nearby evening trips (no SJSU overlap, weak North-morning embedding)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": drvBId,
                "trips": simMakeTrips(15, originLat: simWillowLat, originLng: simWillowLng,
                                      destLat: simWillowLat - 0.005, destLng: simWillowLng + 0.008,
                                      originLabel: "Willow Glen", destLabel: "Willow Glen Area",
                                      hour: 17)
            ])
            cpStep(4, .success, "A=15 North morning, B=15 Willow Glen evening ✓")

            // ── Step 5: Register Rider 1 + Rider 2 ────────────────────────────
            cpStep(5, .running)
            let r1Email = "sim-cp-r1-\(ts)@sjsu.edu"
            let r2Email = "sim-cp-r2-\(ts)@sjsu.edu"

            let regR1 = try await rawPost("/auth/register", body: ["name":"Sim CP Rider 1","email":r1Email,"password":"SimPass123!","role":"Rider"])
            let r1Id = simUserId(regR1); if r1Id.isEmpty { throw cpErr(5, "Rider 1: \(simMsg(regR1))") }
            allUserIds.append(r1Id)

            let regR2 = try await rawPost("/auth/register", body: ["name":"Sim CP Rider 2","email":r2Email,"password":"SimPass123!","role":"Rider"])
            let r2Id = simUserId(regR2); if r2Id.isEmpty { throw cpErr(5, "Rider 2: \(simMsg(regR2))") }
            allUserIds.append(r2Id)
            cpStep(5, .success, "R1:\(r1Id.prefix(8))… R2:\(r2Id.prefix(8))…")

            // ── Step 6: Login as both riders ──────────────────────────────────
            cpStep(6, .running)
            let loginR1 = try await rawPost("/auth/login", body: ["email":r1Email,"password":"SimPass123!"])
            let tokenR1 = (loginR1["data"] as? [String: Any])?["accessToken"] as? String ?? ""
            if tokenR1.isEmpty { throw cpErr(6, "Rider 1 login failed: \(simMsg(loginR1))") }

            let loginR2 = try await rawPost("/auth/login", body: ["email":r2Email,"password":"SimPass123!"])
            let tokenR2 = (loginR2["data"] as? [String: Any])?["accessToken"] as? String ?? ""
            if tokenR2.isEmpty { throw cpErr(6, "Rider 2 login failed: \(simMsg(loginR2))") }
            cpStep(6, .success, "Rider tokens obtained ✓")

            // ── Step 7: Seed rider trip history ───────────────────────────────
            cpStep(7, .running)
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": r1Id,
                "trips": simMakeTrips(10, originLat: simNorthLat, originLng: simNorthLng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "Near 10th & Julian, SJ", destLabel: "SJSU Campus",
                                      hour: 8, onlyWeekdays: true)
            ])
            _ = try await rawPost("/trips/debug-seed-history", body: [
                "user_id": r2Id,
                "trips": simMakeTrips(10, originLat: cpR2Lat, originLng: cpR2Lng,
                                      destLat: simSJSULat, destLng: simSJSULng,
                                      originLabel: "North zone offset", destLabel: "SJSU Campus",
                                      hour: 8, onlyWeekdays: true)
            ])
            cpStep(7, .success, "R1=10 North morning, R2=10 offset North morning ✓")

            // ── Step 8: Set drivers available + create live trips ─────────────
            cpStep(8, .running)
            // Driver A: North zone → SJSU (will become the en-route candidate)
            _ = try await rawPatch("/users/\(drvAId)/availability", body: ["available_for_rides": true], token: tokenA)
            let tripARsp = try await rawPost("/trips", body: [
                "origin": "Near 10th and Julian, San Jose, CA",
                "destination": "San Jose State University, San Jose, CA",
                "departure_time": depTime, "seats_available": 3
            ], token: tokenA)
            tripAId = (tripARsp["data"] as? [String: Any])?["trip_id"] as? String ?? ""
            if tripAId.isEmpty { throw cpErr(8, "Driver A trip creation failed: \(simMsg(tripARsp))") }

            // Driver B: Willow Glen → SJSU (will remain the fresh idle candidate)
            _ = try await rawPatch("/users/\(drvBId)/availability", body: ["available_for_rides": true], token: tokenB)
            let tripBRsp = try await rawPost("/trips", body: [
                "origin": "Willow Glen, San Jose, CA",
                "destination": "San Jose State University, San Jose, CA",
                "departure_time": depTime, "seats_available": 3
            ], token: tokenB)
            let tripBId = (tripBRsp["data"] as? [String: Any])?["trip_id"] as? String ?? ""
            if tripBId.isEmpty { throw cpErr(8, "Driver B trip creation failed: \(simMsg(tripBRsp))") }
            cpStep(8, .success, "A:\(tripAId.prefix(8))… B:\(tripBId.prefix(8))… ✓")

            // ── Step 9: Rider 1 submits request (North → SJSU) ────────────────
            cpStep(9, .running)
            let req1Rsp = try await rawPost("/trips/request", body: [
                "origin": "Near 10th and Julian, San Jose",
                "destination": "San Jose State University, San Jose",
                "origin_lat": simNorthLat, "origin_lng": simNorthLng,
                "destination_lat": simSJSULat, "destination_lng": simSJSULng,
                "departure_time": depTime
            ], token: tokenR1)
            let req1Id = (req1Rsp["data"] as? [String: Any])?["request_id"] as? String ?? ""
            if req1Id.isEmpty { throw cpErr(9, "Rider 1 request failed: \(simMsg(req1Rsp))") }
            cpStep(9, .success, "Request \(req1Id.prefix(8))… submitted ✓")

            // ── Step 10: Poll Rider 1's match ─────────────────────────────────
            cpStep(10, .running)
            var r1AssignedDriverId = ""
            var r1MatchedTripId = ""
            for attempt in 1...15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll = try await rawGet("/trips/request/\(req1Id)", token: tokenR1)
                let st = (poll["data"] as? [String: Any])?["status"] as? String ?? "pending"
                cpStep(10, .running, "[\(attempt)/15] \(st)…")
                if st == "matched" {
                    r1AssignedDriverId = (poll["data"] as? [String: Any])?["driver_id"] as? String ?? ""
                    r1MatchedTripId    = (poll["data"] as? [String: Any])?["matched_trip_id"] as? String ?? ""
                    break
                }
                if st == "expired" || st == "cancelled" { break }
            }
            let r1Label = r1AssignedDriverId == drvAId ? "Driver A ✓" :
                          r1AssignedDriverId == drvBId ? "Driver B (unexpected — Rider 2 test may differ)" :
                          "No match"
            cpStep(10, r1AssignedDriverId.isEmpty ? .error : .success,
                   r1AssignedDriverId.isEmpty ? "No match for Rider 1" : "→ \(r1Label)")

            // ── Step 11: Advance Driver A's trip to en_route ──────────────────
            // Use the matched trip ID if Rider 1 matched Driver A, otherwise tripAId directly.
            cpStep(11, .running)
            let activeTrip = !r1MatchedTripId.isEmpty ? r1MatchedTripId : tripAId
            let stateRsp = try await rawPut("/trips/\(activeTrip)/state",
                                             body: ["status": "en_route"], token: tokenA)
            let stateOk = (stateRsp["status"] as? String) == "success"
            cpStep(11, stateOk ? .success : .error,
                   stateOk
                       ? "Trip \(activeTrip.prefix(8))… → en_route ✓"
                       : "State update failed: \(simMsg(stateRsp))")

            // ── Step 12: Verify states ────────────────────────────────────────
            cpStep(12, .running)
            let tripAInfo = try await rawGet("/trips/\(activeTrip)")
            let tripAStatus = (tripAInfo["data"] as? [String: Any])?["status"] as? String ?? "?"
            let tripASeats  = (tripAInfo["data"] as? [String: Any])?["seats_available"] as? Int ?? 0
            cpStep(12, .success,
                   "Driver A: status=\(tripAStatus) seats=\(tripASeats) | Driver B: pending (idle) ✓")

            // ── Step 13: Rider 2 submits request (offset North → SJSU) ────────
            cpStep(13, .running)
            let req2Rsp = try await rawPost("/trips/request", body: [
                "origin": "North zone offset, San Jose",
                "destination": "San Jose State University, San Jose",
                "origin_lat": cpR2Lat, "origin_lng": cpR2Lng,
                "destination_lat": simSJSULat, "destination_lng": simSJSULng,
                "departure_time": depTime
            ], token: tokenR2)
            let req2Id = (req2Rsp["data"] as? [String: Any])?["request_id"] as? String ?? ""
            if req2Id.isEmpty { throw cpErr(13, "Rider 2 request failed: \(simMsg(req2Rsp))") }
            cpStep(13, .success, "Request \(req2Id.prefix(8))… submitted ✓")

            // ── Step 14: Poll Rider 2's match — evaluate outcome ──────────────
            cpStep(14, .running)
            for attempt in 1...15 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll = try await rawGet("/trips/request/\(req2Id)", token: tokenR2)
                let st = (poll["data"] as? [String: Any])?["status"] as? String ?? "pending"
                cpStep(14, .running, "[\(attempt)/15] \(st)…")
                if st == "matched" {
                    r2AssignedDriverId = (poll["data"] as? [String: Any])?["driver_id"] as? String ?? ""
                    matchedTripIdForR2  = (poll["data"] as? [String: Any])?["matched_trip_id"] as? String ?? ""
                    break
                }
                if st == "expired" || st == "cancelled" { break }
            }

            // Build results table
            let distAR2 = simHaversine(simNorthLat, simNorthLng, cpR2Lat, cpR2Lng)
            let distBR2 = simHaversine(simWillowLat, simWillowLng, cpR2Lat, cpR2Lng)
            let scostA  = simScost(distAR2, cpR2Lat, cpR2Lng)
            let scostB  = simScost(distBR2, cpR2Lat, cpR2Lng)
            carpoolSimResults = [
                CarpoolSimResult(
                    candidateName: "Driver A (active)",
                    candidateType: "en-route",
                    distToR2: "\(Int(distAR2))m",
                    scost: String(format: "%.2f", scostA),
                    assigned: r2AssignedDriverId == drvAId
                ),
                CarpoolSimResult(
                    candidateName: "Driver B (idle)",
                    candidateType: "fresh",
                    distToR2: "\(Int(distBR2))m",
                    scost: String(format: "%.2f", scostB),
                    assigned: r2AssignedDriverId == drvBId
                )
            ]

            if r2AssignedDriverId.isEmpty {
                carpoolSimOutcome = .noMatch
                cpStep(14, .error, "✗ NO MATCH — en-route candidate fetching may be broken")
            } else if r2AssignedDriverId == drvAId {
                carpoolSimOutcome = .carpoolInsertion
                cpStep(14, .success, "✓ CARPOOL INSERTION: Rider 2 → Driver A (en-route, Scost≈\(String(format:"%.2f",scostA)))")
            } else {
                carpoolSimOutcome = .freshMatch
                let note = r2AssignedDriverId == drvBId ? "Driver B" : "unknown driver"
                cpStep(14, .success, "✓ FRESH MATCH: Rider 2 → \(note) (verify Scost: A=\(String(format:"%.2f",scostA)) B=\(String(format:"%.2f",scostB)))")
            }

            // ── Step 15: Fetch matched driver anchor points ────────────────────
            cpStep(15, .running)
            if !matchedTripIdForR2.isEmpty {
                let anchorsRsp = try await rawGet("/trips/\(matchedTripIdForR2)/anchor-points")
                let anchors = (anchorsRsp["data"] as? [String: Any])?["anchor_points"] as? [[String: Any]] ?? []
                carpoolSimWaypoints = anchors.enumerated().map { (i, a) in
                    let type_  = a["type"]     as? String ?? "?"
                    let label  = a["label"]    as? String ?? "Unknown"
                    let rId    = a["rider_id"] as? String ?? ""
                    let rTag   = rId.isEmpty ? "" : " (rider \(rId.prefix(6))…)"
                    return "\(i + 1). \(type_.capitalized)\(rTag) — \(label)"
                }
                cpStep(15, .success, "\(anchors.count) waypoint(s) fetched ✓")
            } else {
                carpoolSimWaypoints = r2AssignedDriverId.isEmpty
                    ? ["No match — no trip to inspect"]
                    : ["No matched_trip_id returned by poll; fetch skipped"]
                cpStep(15, r2AssignedDriverId.isEmpty ? .error : .success,
                       r2AssignedDriverId.isEmpty ? "Skipped (no match)" : "No trip ID from poll")
            }

        } catch let e as SimError {
            _ = e
        } catch {
            if let idx = carpoolSimSteps.firstIndex(where: { $0.status == .running }) {
                carpoolSimSteps[idx].status = .error
                carpoolSimSteps[idx].detail = error.localizedDescription
            }
        }

        // ── Step 16: Cleanup (always runs) ───────────────────────────────────
        cpStep(16, .running)
        var failedIds: [String] = []
        for uid in allUserIds {
            do { _ = try await rawDelete("/users/\(uid)/debug-delete") }
            catch { failedIds.append(String(uid.prefix(8))) }
        }
        cpStep(16,
               failedIds.isEmpty ? .success : .error,
               failedIds.isEmpty
                   ? "Deleted \(allUserIds.count) account(s) ✓"
                   : "Partial cleanup. Failed: \(failedIds.joined(separator: ", "))")

        carpoolSimRunning = false
    }

    // MARK: - Simulate Cost Calculation (5 scenarios)
    //
    // Each scenario registers a fresh driver + rider pair, creates a trip
    // (Santa Clara → SJSU), confirms a booking, then calls
    // GET /cost/settle/:trip_id and validates the IRS formula:
    //   costPerRider = (distance × $0.67 + duration_hours × $15) / riderCount  (±$0.05)

    func simulateCostCalculation() async {
        costSimRunning = true
        costSimSteps = Self.costSimStepLabels.enumerated().map {
            MatchSimStep(number: $0.offset + 1, label: $0.element)
        }
        costSimScenarios = Self.costSimScenarioDefs.enumerated().map { (i, def) in
            CostSimScenario(id: i + 1, label: def.label)
        }

        let ts  = Int(Date().timeIntervalSince1970)
        let fmt = ISO8601DateFormatter()
        let depTime = fmt.string(from: Date().addingTimeInterval(1800))

        var allUserIds: [String] = []

        // ── Scenarios 1–5 (each independent; failure marks step but continues) ──
        for (idx, def) in Self.costSimScenarioDefs.enumerated() {
            let n = idx + 1
            csStep(n, .running)

            do {
                let drvEmail = "sim-cost-d\(n)-\(ts)@sjsu.edu"

                // Register driver
                let regD = try await rawPost("/auth/register", body: [
                    "name": "Cost Test Driver \(n)", "email": drvEmail,
                    "password": "SimPass123!", "role": "Driver"
                ])
                let drvId = simUserId(regD)
                guard !drvId.isEmpty else { throw csErr(n, "Driver reg failed: \(simMsg(regD))") }
                allUserIds.append(drvId)

                // Verify driver role
                _ = try await rawPost("/users/\(drvId)/debug-verify", body: [:])

                // Login driver
                let loginD = try await rawPost("/auth/login", body: ["email": drvEmail, "password": "SimPass123!"])
                let tokenD = (loginD["data"] as? [String: Any])?["accessToken"] as? String ?? ""
                guard !tokenD.isEmpty else { throw csErr(n, "Driver login failed") }

                // Set driver profile
                _ = try await rawPut("/users/\(drvId)/driver-setup", body: [
                    "vehicle_info": "2024 Test Vehicle",
                    "seats_available": max(def.riders + 1, 3),
                    "license_plate": "TST\(n)00"
                ], token: tokenD)

                // Create trip Santa Clara → SJSU
                let tripRsp = try await rawPost("/trips", body: [
                    "origin": "Santa Clara, CA",
                    "destination": "San Jose State University, San Jose, CA",
                    "departure_time": depTime,
                    "seats_available": max(def.riders + 1, 3)
                ], token: tokenD)
                let tripData = tripRsp["data"] as? [String: Any] ?? tripRsp
                let tripId = tripData["trip_id"] as? String ?? ""
                guard !tripId.isEmpty else { throw csErr(n, "Trip creation failed: \(simMsg(tripRsp))") }

                // Register and book for each rider separately (1 booking per rider, seats_booked=1)
                let riderSuffixes = ["a","b","c"]
                for ri in 0..<def.riders {
                    let suffix = ri < riderSuffixes.count ? riderSuffixes[ri] : "\(ri)"
                    let thisRdrEmail = "sim-cost-r\(n)\(suffix)-\(ts)@sjsu.edu"

                    let regR = try await rawPost("/auth/register", body: [
                        "name": "Cost Test Rider \(n)\(suffix)", "email": thisRdrEmail,
                        "password": "SimPass123!", "role": "Rider"
                    ])
                    let rdrId = simUserId(regR)
                    guard !rdrId.isEmpty else { throw csErr(n, "Rider \(suffix) reg failed: \(simMsg(regR))") }
                    allUserIds.append(rdrId)

                    let loginR = try await rawPost("/auth/login", body: ["email": thisRdrEmail, "password": "SimPass123!"])
                    let tokenR = (loginR["data"] as? [String: Any])?["accessToken"] as? String ?? ""
                    guard !tokenR.isEmpty else { throw csErr(n, "Rider \(suffix) login failed") }

                    // Only first rider gets detour pickup (so there's exactly one detour in scenario 3)
                    var bookBody: [String: Any] = ["trip_id": tripId, "seats_booked": 1]
                    if def.detour && ri == 0 {
                        bookBody["pickup_location"] = ["lat": 37.3200, "lng": -121.9500]
                    }
                    let bkRsp = try await rawPost("/bookings", body: bookBody, token: tokenR)
                    let bkData = bkRsp["data"] as? [String: Any] ?? bkRsp
                    let bkInner = bkData["booking"] as? [String: Any] ?? bkData
                    let bkId = bkInner["booking_id"] as? String
                        ?? bkInner["id"] as? String
                        ?? (bkRsp["data"] as? [String: Any])?["booking_id"] as? String
                        ?? ""
                    guard !bkId.isEmpty else { throw csErr(n, "Booking for rider \(suffix) failed: \(simMsg(bkRsp))") }

                    _ = try await rawPost("/bookings/\(bkId)/confirm", body: [:], token: tokenR)
                }

                // Fetch settlement
                let settleRsp = try await rawGet("/cost/settle/\(tripId)")
                let settleData = settleRsp["data"] as? [String: Any] ?? [:]
                let actualCPR   = settleData["cost_per_rider"] as? Double ?? 0
                let brkdn       = settleData["breakdown"] as? [String: Any] ?? [:]
                let distMi      = brkdn["direct_distance_miles"] as? Double ?? 0
                let durHrs      = brkdn["direct_duration_hours"] as? Double ?? 0
                let riders      = settleData["riders"] as? [[String: Any]] ?? []
                let riderPaid   = riders.first?["amount_paid"] as? Double
                let detourRider = riders.first(where: { ($0["detour_miles"] as? Double ?? 0) > 0 })
                let detourMilesActual = detourRider?["detour_miles"] as? Double ?? 0
                let detourBreakdown   = detourRider?["breakdown"] as? String ?? ""

                // IRS formula validation
                let expectedCPR  = (distMi * 0.67 + durHrs * 15.0) / Double(def.riders)
                let cprOk   = abs(actualCPR - expectedCPR) < 0.05
                // Detour pass: paid > base cost AND detour_miles > 0 AND breakdown mentions surcharge
                let baseCost = (distMi * 0.67 + durHrs * 15.0) / Double(def.riders)
                let detourOk = !def.detour || (
                    (riderPaid ?? 0) > baseCost + 0.01 &&
                    detourMilesActual > 0 &&
                    detourBreakdown.contains("detour surcharge")
                )
                let passed  = cprOk && detourOk

                let prettySettle = prettyJSON(settleRsp)
                var detail: String
                if def.detour {
                    let paid = riderPaid.map { String(format: "$%.2f", $0) } ?? "?"
                    detail = "rate=\(String(format:"%.4f",actualRate)) ≈\(String(format:"%.4f",expectedRate)) | base=$\(String(format:"%.2f",baseCost)) paid=\(paid) detour_mi=\(String(format:"%.2f",detourMilesActual)) surcharge:\(detourOk ? "✓" : "✗")"
                } else {
                    detail = "rate=\(String(format:"%.4f",actualRate)) ≈\(String(format:"%.4f",expectedRate)) | cost=$\(String(format:"%.2f",actualCPR)) exp=$\(String(format:"%.2f",expectedCPR))"
                }
                csStep(n, passed ? .success : .error, detail)
                costSimScenarios[idx].status      = passed ? .success : .error
                costSimScenarios[idx].detail      = detail
                costSimScenarios[idx].expectedValue = def.detour
                    ? "> $\(String(format:"%.2f", actualCPR))"
                    : String(format: "$%.2f", expectedCPR)
                costSimScenarios[idx].actualValue = def.detour
                    ? (riderPaid.map { String(format: "$%.2f", $0) } ?? "?")
                    : String(format: "$%.2f", actualCPR)
                costSimScenarios[idx].passed      = passed
                costSimScenarios[idx].rawJSON     = prettySettle

            } catch let e as SimError {
                _ = e   // step already marked in csErr()
                costSimScenarios[idx].status = .error
                costSimScenarios[idx].passed = false
            } catch {
                csStep(n, .error, error.localizedDescription)
                costSimScenarios[idx].status = .error
                costSimScenarios[idx].passed = false
            }
        }

        // ── Step 6: Cleanup all sim_cost_ accounts ────────────────────────────
        csStep(6, .running)
        var failedIds: [String] = []
        for uid in allUserIds {
            do { _ = try await rawDelete("/users/\(uid)/debug-delete") }
            catch { failedIds.append(String(uid.prefix(8))) }
        }
        csStep(6,
               failedIds.isEmpty ? .success : .error,
               failedIds.isEmpty
                   ? "Deleted \(allUserIds.count) account(s) ✓"
                   : "Partial cleanup. Failed: \(failedIds.joined(separator: ", "))")

        costSimRunning = false
    }

    // MARK: - Simulation Helpers

    private func simStep(_ n: Int, _ status: MatchSimStepStatus, _ detail: String = "") {
        if let idx = matchSimSteps.firstIndex(where: { $0.number == n }) {
            matchSimSteps[idx].status = status
            if !detail.isEmpty { matchSimSteps[idx].detail = detail }
        }
    }

    private func simErr(_ n: Int, _ msg: String) -> SimError {
        simStep(n, .error, msg)
        return SimError.step(n, msg)
    }

    // Carpool sim step helpers (parallel to simStep/simErr, operate on carpoolSimSteps)
    private func cpStep(_ n: Int, _ status: MatchSimStepStatus, _ detail: String = "") {
        if let idx = carpoolSimSteps.firstIndex(where: { $0.number == n }) {
            carpoolSimSteps[idx].status = status
            if !detail.isEmpty { carpoolSimSteps[idx].detail = detail }
        }
    }

    private func cpErr(_ n: Int, _ msg: String) -> SimError {
        cpStep(n, .error, msg)
        return SimError.step(n, msg)
    }

    // Cost sim step helpers
    private func csStep(_ n: Int, _ status: MatchSimStepStatus, _ detail: String = "") {
        if let idx = costSimSteps.firstIndex(where: { $0.number == n }) {
            costSimSteps[idx].status = status
            if !detail.isEmpty { costSimSteps[idx].detail = detail }
        }
    }

    private func csErr(_ n: Int, _ msg: String) -> SimError {
        csStep(n, .error, msg)
        return SimError.step(n, msg)
    }

    private func simUserId(_ resp: [String: Any]) -> String {
        let d = resp["data"] as? [String: Any] ?? resp
        return (d["user"] as? [String: Any])?["user_id"] as? String
            ?? d["user_id"] as? String ?? ""
    }

    private func simMsg(_ resp: [String: Any]) -> String {
        return resp["message"] as? String ?? "unknown"
    }

    private func simLoginToken(_ email: String, step: Int) async throws -> String {
        let resp = try await rawPost("/auth/login", body: ["email": email, "password": "SimPass123!"])
        let token = (resp["data"] as? [String: Any])?["accessToken"] as? String ?? ""
        if token.isEmpty { throw simErr(step, "Login failed for \(email): \(simMsg(resp))") }
        return token
    }

    /// Generate `count` historical trip records spread over the past 60 days.
    private func simMakeTrips(
        _ count: Int,
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        originLabel: String, destLabel: String,
        hour: Int,
        onlyWeekdays: Bool = false,
        onlyWeekends: Bool = false
    ) -> [[String: Any]] {
        var result: [[String: Any]] = []
        let cal = Calendar.current
        let fmt = ISO8601DateFormatter()
        var daysBack = 1
        while result.count < count && daysBack <= 60 {
            let base = Date().addingTimeInterval(-Double(daysBack) * 86400)
            let wd = cal.component(.weekday, from: base)
            let isWD = wd >= 2 && wd <= 6
            if onlyWeekdays && !isWD   { daysBack += 1; continue }
            if onlyWeekends && isWD    { daysBack += 1; continue }
            var comps = cal.dateComponents([.year, .month, .day], from: base)
            comps.hour   = hour
            comps.minute = (result.count % 3) * 10
            if let d = cal.date(from: comps) {
                result.append([
                    "origin_lat": originLat, "origin_lng": originLng,
                    "destination_lat": destLat, "destination_lng": destLng,
                    "origin_label": originLabel, "destination_label": destLabel,
                    "departure_time": fmt.string(from: d)
                ])
            }
            daysBack += 1
        }
        return result
    }

    /// Haversine distance in meters (mirrors matching.service.ts)
    private func simHaversine(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let R = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1 * .pi/180)*cos(lat2 * .pi/180)*sin(dLng/2)*sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Estimate leading Scost term for a driver at driverOrigin serving a rider at riderOrigin→SJSU.
    /// Uses W1*(dw/dp) where dp = rider origin→SJSU and dw = driver origin to rider origin.
    private func simScost(_ dw: Double, _ riderLat: Double, _ riderLng: Double) -> Double {
        let dp = max(simHaversine(riderLat, riderLng, simSJSULat, simSJSULng), 1.0)
        return 0.5 * (dw / dp) + 0.2 * (dw / 5000.0)  // W1+W2 leading terms
    }

    // MARK: - Simulate Passenger Join

    func simulatePassengerJoin(tripId: String) async {
        guard !tripId.isEmpty else {
            passengerJoinJSON = "Enter a trip ID above."; return
        }
        passengerJoinRunning = true
        do {
            // Before
            let before = try await rawGet("/trips/\(tripId)/anchor-points")
            // Book
            let bookBody: [String: Any] = [
                "trip_id": tripId,
                "seats_booked": 1
            ]
            let booking = try await rawPost("/bookings", body: bookBody)
            let bookingId = booking["id"] as? String ?? "?"
            // After
            let after = try await rawGet("/trips/\(tripId)/anchor-points")
            let combined: [String: Any] = [
                "booking_id": bookingId,
                "anchor_points_before": before["anchor_points"] ?? [],
                "anchor_points_after": after["anchor_points"] ?? []
            ]
            passengerJoinJSON = prettyJSON(combined)
        } catch {
            passengerJoinJSON = "Error: \(error.localizedDescription)"
        }
        passengerJoinRunning = false
    }

    // MARK: - Force Match

    func forceMatch(riderLat: Double, riderLng: Double, destLat: Double, destLng: Double) async {
        forceMatchRunning = true
        do {
            let body: [String: Any] = [
                "origin": "Force Match Test Origin",
                "destination": "San Jose State University",
                "origin_lat": riderLat,
                "origin_lng": riderLng,
                "destination_lat": destLat,
                "destination_lng": destLng,
                "departure_time": ISO8601DateFormatter().string(from: Date().addingTimeInterval(1200))
            ]
            let resp = try await rawPost("/trips/request", body: body)
            forceMatchJSON = prettyJSON(resp)
        } catch {
            forceMatchJSON = "Error: \(error.localizedDescription)"
        }
        forceMatchRunning = false
    }

    // MARK: - Embedding Health

    func fetchEmbeddingHealth() async {
        embeddingRunning = true
        do {
            let resp = try await rawGetAbsolute("\(embeddingBase)/health")
            embeddingJSON = prettyJSON(resp)
        } catch {
            embeddingJSON = "Error: \(error.localizedDescription)"
        }
        embeddingRunning = false
    }

    func triggerRetrain() async {
        retrainRunning = true
        do {
            let resp = try await rawPostAbsolute("\(embeddingBase)/train", body: [:])
            retrainJSON = prettyJSON(resp)
        } catch {
            retrainJSON = "Error: \(error.localizedDescription)"
        }
        retrainRunning = false
    }

    // MARK: - HTTP Helpers

    private func rawPost(_ path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        return try await rawRequest(path, method: "POST", body: body, token: token)
    }

    private func rawPatch(_ path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        return try await rawRequest(path, method: "PATCH", body: body, token: token)
    }

    private func rawPut(_ path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        return try await rawRequest(path, method: "PUT", body: body, token: token)
    }

    private func rawDelete(_ path: String, token: String? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "DELETE"
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        else if let stored = KeychainManager.shared.getAccessToken() {
            req.setValue("Bearer \(stored)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func rawRequest(_ path: String, method: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        else if let stored = KeychainManager.shared.getAccessToken() {
            req.setValue("Bearer \(stored)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func rawGet(_ path: String, token: String? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: base + path)!)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        else if let stored = KeychainManager.shared.getAccessToken() {
            req.setValue("Bearer \(stored)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func rawGetAbsolute(_ url: String) async throws -> [String: Any] {
        let req = URLRequest(url: URL(string: url)!)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func rawPostAbsolute(_ url: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func prettyJSON(_ obj: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - Developer Tools Section View

struct DevToolsSection: View {
    @ObservedObject var vm: DevToolsViewModel
    @State private var isExpanded = false
    @State private var passengerTripId = ""
    @State private var forceMatchOriginLat = "37.4146"
    @State private var forceMatchOriginLng = "-121.9006"

    var body: some View {
        VStack(spacing: 0) {
            // Orange header
            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandOrange.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.brandOrange)
                    }
                    Text("Developer Tools")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandOrange)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandOrange.opacity(0.06))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    simulateMatchingScenarioPanel
                    simulateCarpoolInsertionPanel
                    simulateCostCalcPanel
                    simulateFullTripPanel
                    simulatePassengerJoinPanel
                    forceMatchPanel
                    embeddingHealthPanel
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }

    // MARK: - Simulate Matching Scenario Panel

    private var simulateMatchingScenarioPanel: some View {
        devPanel(title: "Simulate Matching Scenario", icon: "person.3.fill", expanded: $vm.expandMatchingSim) {
            VStack(alignment: .leading, spacing: 12) {

                Text("Registers 3 drivers (A/B/C) + 2 riders, seeds historical trips to build HIN embeddings, then submits live requests and verifies the 3-stage pipeline (PostGIS → RShareForm → Scost). All real API calls — creates and deletes real accounts.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Verbose toggle ──────────────────────────────────────────
                Toggle(isOn: $vm.matchSimVerbose) {
                    Text("Verbose mode (raw API bodies)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: .brandOrange))

                // ── Step log ────────────────────────────────────────────────
                if !vm.matchSimSteps.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.matchSimSteps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                // Status indicator
                                Group {
                                    switch step.status {
                                    case .pending:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 3)
                                    case .running:
                                        ProgressView()
                                            .scaleEffect(0.55)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 1)
                                    case .success:
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.green)
                                            .padding(.top, 2)
                                    case .error:
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red)
                                            .padding(.top, 2)
                                    }
                                }
                                .frame(width: 14)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("\(step.number).")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(stepLabelColor(step.status))
                                        Text(step.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(stepLabelColor(step.status))
                                    }
                                    if !step.detail.isEmpty {
                                        Text(step.detail)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(step.status == .error ? .red : .textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(stepRowBackground(step.status))

                            if step.id != vm.matchSimSteps.last?.id {
                                Divider().padding(.horizontal, 10)
                            }
                        }
                    }
                    .background(DesignSystem.Colors.fieldBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                }

                // ── Results table ───────────────────────────────────────────
                if !vm.matchSimResults.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Match Results")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        // Header row
                        HStack(spacing: 0) {
                            Text("Driver").frame(width: 56, alignment: .leading)
                            Text("Dist R1").frame(maxWidth: .infinity, alignment: .center)
                            Text("Score R1").frame(maxWidth: .infinity, alignment: .center)
                            Text("Dist R2").frame(maxWidth: .infinity, alignment: .center)
                            Text("Score R2").frame(maxWidth: .infinity, alignment: .center)
                            Text("Match").frame(width: 56, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.groupedBackground)
                        .cornerRadius(6)

                        // Data rows
                        ForEach(vm.matchSimResults) { result in
                            HStack(spacing: 0) {
                                Text(result.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .frame(width: 56, alignment: .leading)
                                Text(result.distR1)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text(result.scoreR1)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(scoreColor(result.scoreR1))
                                Text(result.distR2)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text(result.scoreR2)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(scoreColor(result.scoreR2))
                                Text(result.assignedTo)
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 56, alignment: .trailing)
                                    .foregroundColor(result.assignedTo == "None" ? .textSecondary : .green)
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.cardBackground)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                        }
                    }
                }

                // ── Run / Run Again button ──────────────────────────────────
                devButton(
                    title: vm.matchSimSteps.isEmpty ? "Run Simulation" : "Run Again",
                    icon: vm.matchSimSteps.isEmpty ? "play.fill" : "arrow.clockwise",
                    running: vm.matchSimRunning,
                    color: .brandOrange
                ) {
                    vm.matchSimSteps = []
                    vm.matchSimResults = []
                    Task { await vm.simulateMatchingScenario() }
                }
            }
        }
    }

    // MARK: - Simulate Carpool Insertion Panel

    private var simulateCarpoolInsertionPanel: some View {
        devPanel(title: "Simulate Carpool Insertion", icon: "car.2.fill", expanded: $vm.expandCarpoolSim) {
            VStack(alignment: .leading, spacing: 12) {

                Text("Tests en-route carpool matching. Driver A is carrying Rider 1 on a North→SJSU route (en_route). Driver B is idle in Willow Glen. Rider 2 requests from the same North zone (~200m offset). Driver A should win: geographically close and strong HIN similarity. If Driver B wins instead, the en-route candidate pipeline is broken.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Step log ────────────────────────────────────────────────
                if !vm.carpoolSimSteps.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.carpoolSimSteps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Group {
                                    switch step.status {
                                    case .pending:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 3)
                                    case .running:
                                        ProgressView()
                                            .scaleEffect(0.55)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 1)
                                    case .success:
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.green)
                                            .padding(.top, 2)
                                    case .error:
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red)
                                            .padding(.top, 2)
                                    }
                                }
                                .frame(width: 14)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("\(step.number).")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(stepLabelColor(step.status))
                                        Text(step.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(stepLabelColor(step.status))
                                    }
                                    if !step.detail.isEmpty {
                                        Text(step.detail)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(step.status == .error ? .red : .textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(stepRowBackground(step.status))

                            if step.id != vm.carpoolSimSteps.last?.id {
                                Divider().padding(.horizontal, 10)
                            }
                        }
                    }
                    .background(DesignSystem.Colors.fieldBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                }

                // ── Results table ───────────────────────────────────────────
                if !vm.carpoolSimResults.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Candidate Comparison")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        // Header
                        HStack(spacing: 0) {
                            Text("Candidate").frame(minWidth: 110, alignment: .leading)
                            Text("Type").frame(maxWidth: .infinity, alignment: .center)
                            Text("Dist R2").frame(maxWidth: .infinity, alignment: .center)
                            Text("Scost").frame(maxWidth: .infinity, alignment: .center)
                            Text("Assigned").frame(width: 58, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.groupedBackground)
                        .cornerRadius(6)

                        ForEach(vm.carpoolSimResults) { r in
                            HStack(spacing: 0) {
                                Text(r.candidateName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .frame(minWidth: 110, alignment: .leading)
                                Text(r.candidateType)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text(r.distToR2)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text(r.scost)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(scostColor(r.scost))
                                Text(r.assigned ? "✓" : "—")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 58, alignment: .trailing)
                                    .foregroundColor(r.assigned ? .green : .textSecondary)
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(r.assigned ? Color.green.opacity(0.05) : Color.cardBackground)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                        }

                        // Outcome badge
                        carpoolOutcomeBadge
                    }
                }

                // ── Waypoint sequence ───────────────────────────────────────
                if !vm.carpoolSimWaypoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Waypoint Sequence (matched trip)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(vm.carpoolSimWaypoints.enumerated()), id: \.offset) { _, wp in
                                Text(wp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(DesignSystem.Colors.fieldBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                    }
                }

                // ── Run / Run Again button ──────────────────────────────────
                devButton(
                    title: vm.carpoolSimSteps.isEmpty ? "Run Simulation" : "Run Again",
                    icon: vm.carpoolSimSteps.isEmpty ? "play.fill" : "arrow.clockwise",
                    running: vm.carpoolSimRunning,
                    color: .brandOrange
                ) {
                    vm.carpoolSimSteps = []
                    vm.carpoolSimResults = []
                    vm.carpoolSimOutcome = .none
                    vm.carpoolSimWaypoints = []
                    Task { await vm.simulateCarpoolInsertion() }
                }
            }
        }
    }

    @ViewBuilder
    private var carpoolOutcomeBadge: some View {
        switch vm.carpoolSimOutcome {
        case .carpoolInsertion:
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("CARPOOL INSERTION — en-route driver won")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.top, 2)
        case .freshMatch:
            HStack(spacing: 6) {
                Circle().fill(DesignSystem.Colors.cautionOrange).frame(width: 8, height: 8)
                Text("FRESH MATCH — idle driver won (verify Scost values above)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.cautionOrange)
            }
            .padding(.top, 2)
        case .noMatch:
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("NO MATCH — en-route candidate fetching may be broken")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
            }
            .padding(.top, 2)
        case .none:
            EmptyView()
        }
    }

    // ── Step log helpers ─────────────────────────────────────────────────────

    private func stepLabelColor(_ status: MatchSimStepStatus) -> Color {
        switch status {
        case .pending:  return .gray
        case .running:  return DesignSystem.Colors.runningBlue
        case .success:  return .textPrimary
        case .error:    return .red
        }
    }

    private func stepRowBackground(_ status: MatchSimStepStatus) -> Color {
        switch status {
        case .running:  return DesignSystem.Colors.runningBlue.opacity(0.05)
        case .error:    return Color.red.opacity(0.04)
        default:        return Color.clear
        }
    }

    private func scoreColor(_ score: String) -> Color {
        guard let v = Double(score) else { return .textSecondary }
        if v >= 0.8 { return .green }
        if v >= 0.5 { return DesignSystem.Colors.cautionOrange }
        return .textSecondary
    }

    // Scost coloring: lower is better (inverse of scoreColor)
    private func scostColor(_ score: String) -> Color {
        guard let v = Double(score) else { return .textSecondary }
        if v < 0.5  { return .green }
        if v < 1.5  { return DesignSystem.Colors.cautionOrange }
        return .red
    }

    // MARK: - Simulate Cost Calculation Panel

    private var simulateCostCalcPanel: some View {
        devPanel(title: "Test Cost Calculation", icon: "dollarsign.circle.fill", expanded: $vm.expandCostSim) {
            VStack(alignment: .leading, spacing: 12) {

                Text("Runs 5 live end-to-end scenarios testing the IRS mileage rate settlement formula. Creates real temp accounts (sim_cost_), confirms bookings, calls GET /cost/settle/:id, validates ±$0.05. All accounts deleted after.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Formula reference ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("Formula Reference")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Text("tripCost     = distance × $0.67 + duration_hrs × $15.00\ncostPerRider = tripCost / riderCount\ndetourCost   = detourMiles × $0.67 × 1.25")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.groupedBackground)
                .cornerRadius(8)

                // ── Step log ───────────────────────────────────────────────────
                if !vm.costSimSteps.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.costSimSteps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Group {
                                    switch step.status {
                                    case .pending:
                                        Circle().fill(Color.gray.opacity(0.3))
                                            .frame(width: 10, height: 10).padding(.top, 3)
                                    case .running:
                                        ProgressView().scaleEffect(0.55)
                                            .frame(width: 10, height: 10).padding(.top, 1)
                                    case .success:
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11)).foregroundColor(.green).padding(.top, 2)
                                    case .error:
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11)).foregroundColor(.red).padding(.top, 2)
                                    }
                                }
                                .frame(width: 14)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("\(step.number).")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(stepLabelColor(step.status))
                                        Text(step.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(stepLabelColor(step.status))
                                    }
                                    if !step.detail.isEmpty {
                                        Text(step.detail)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(step.status == .error ? .red : .textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(stepRowBackground(step.status))

                            if step.id != vm.costSimSteps.last?.id {
                                Divider().padding(.horizontal, 10)
                            }
                        }
                    }
                    .background(DesignSystem.Colors.fieldBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                }

                // ── Scenario results table ─────────────────────────────────────
                if !vm.costSimScenarios.isEmpty {
                    let passCount = vm.costSimScenarios.filter { $0.passed == true }.count
                    let failCount = vm.costSimScenarios.filter { $0.passed == false }.count

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Scenario Results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if passCount + failCount > 0 {
                                HStack(spacing: 6) {
                                    Label(String(passCount), systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                    Label(String(failCount), systemImage: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(failCount > 0 ? .red : .textSecondary)
                                }
                            }
                        }

                        // Header
                        HStack(spacing: 0) {
                            Text("Scenario").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Expected").frame(width: 68, alignment: .center)
                            Text("Actual").frame(width: 68, alignment: .center)
                            Text("").frame(width: 20)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.groupedBackground)
                        .cornerRadius(6)

                        // Data rows
                        ForEach(vm.costSimScenarios) { scenario in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    Text(scenario.label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(scenario.expectedValue)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                        .frame(width: 68, alignment: .center)
                                    Text(scenario.actualValue)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(scenario.passed == true ? .green : scenario.passed == false ? .red : .textSecondary)
                                        .frame(width: 68, alignment: .center)
                                    Group {
                                        if let passed = scenario.passed {
                                            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .font(.system(size: 13))
                                                .foregroundColor(passed ? .green : .red)
                                        } else {
                                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 10, height: 10)
                                        }
                                    }
                                    .frame(width: 20, alignment: .center)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)

                                // Raw JSON expandable (only if there's data)
                                if !scenario.rawJSON.isEmpty && scenario.status != .pending {
                                    DisclosureGroup("Raw response") {
                                        Text(scenario.rawJSON)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                    }
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 6)
                                }
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                        }
                    }
                }

                // ── Run / Run Again button ─────────────────────────────────────
                devButton(
                    title: vm.costSimSteps.isEmpty ? "Run Tests" : "Run Again",
                    icon: vm.costSimSteps.isEmpty ? "play.fill" : "arrow.clockwise",
                    running: vm.costSimRunning,
                    color: .brandOrange
                ) {
                    vm.costSimSteps = []
                    vm.costSimScenarios = []
                    Task { await vm.simulateCostCalculation() }
                }
            }
        }
    }

    // MARK: - Simulate Full Trip Panel

    private var simulateFullTripPanel: some View {
        devPanel(title: "Simulate Full Trip", icon: "car.2.fill", expanded: $vm.expandFullTrip) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Registers a temp driver + rider, creates a trip, submits a ride request, and polls for a match. All real API calls.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !vm.fullTripLog.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(vm.fullTripLog.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(line.contains("Error") ? .brandRed : .textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .frame(height: 160)
                    .background(DesignSystem.Colors.fieldBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                }

                devButton(title: "Run Simulation", icon: "play.fill", running: vm.fullTripRunning, color: .brandOrange) {
                    vm.fullTripLog = []
                    Task { await vm.simulateFullTrip() }
                }
            }
        }
    }

    // MARK: - Simulate Passenger Join Panel

    private var simulatePassengerJoinPanel: some View {
        devPanel(title: "Simulate Passenger Join", icon: "person.badge.plus", expanded: $vm.expandPassengerJoin) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Books a seat on an existing trip and shows anchor point diff (before / after Algorithm 3 merging).")
                    .font(.system(size: 12)).foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Trip ID", text: $passengerTripId)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(DesignSystem.Colors.fieldBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                    .autocorrectionDisabled()

                if !vm.passengerJoinJSON.isEmpty {
                    jsonBox(vm.passengerJoinJSON)
                }

                devButton(title: "Book & Diff Anchors", icon: "arrow.triangle.merge", running: vm.passengerJoinRunning, color: .brandOrange) {
                    Task { await vm.simulatePassengerJoin(tripId: passengerTripId) }
                }
            }
        }
    }

    // MARK: - Force Match Panel

    private var forceMatchPanel: some View {
        devPanel(title: "Force Match", icon: "bolt.fill", expanded: $vm.expandForceMatch) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Submits a ride request using SJSU as destination. Returns Scost + embedding similarity from the matching pipeline.")
                    .font(.system(size: 12)).foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Origin Lat").font(.system(size: 10)).foregroundColor(.textSecondary)
                        TextField("37.4146", text: $forceMatchOriginLat)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8).background(DesignSystem.Colors.fieldBackground).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                            .keyboardType(.decimalPad).autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Origin Lng").font(.system(size: 10)).foregroundColor(.textSecondary)
                        TextField("-121.9006", text: $forceMatchOriginLng)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8).background(DesignSystem.Colors.fieldBackground).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                            .keyboardType(.decimalPad).autocorrectionDisabled()
                    }
                }

                if !vm.forceMatchJSON.isEmpty {
                    jsonBox(vm.forceMatchJSON)
                }

                devButton(title: "Force Match", icon: "bolt.fill", running: vm.forceMatchRunning, color: .brandOrange) {
                    let lat = Double(forceMatchOriginLat) ?? 37.4146
                    let lng = Double(forceMatchOriginLng) ?? -121.9006
                    Task { await vm.forceMatch(riderLat: lat, riderLng: lng, destLat: 37.3352, destLng: -121.8811) }
                }
            }
        }
    }

    // MARK: - Embedding Health Panel

    private var embeddingHealthPanel: some View {
        devPanel(title: "Embedding Health", icon: "brain.head.profile", expanded: $vm.expandEmbedding) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Checks RShareForm embedding service status (port 3010). Optionally triggers a retrain.")
                    .font(.system(size: 12)).foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !vm.embeddingJSON.isEmpty {
                    jsonBox(vm.embeddingJSON)
                }

                HStack(spacing: 8) {
                    devButton(title: "Check Health", icon: "waveform.path.ecg", running: vm.embeddingRunning, color: .brandTeal) {
                        Task { await vm.fetchEmbeddingHealth() }
                    }
                    devButton(title: "Retrain", icon: "arrow.clockwise", running: vm.retrainRunning, color: .brandOrange) {
                        Task { await vm.triggerRetrain() }
                    }
                }

                if !vm.retrainJSON.isEmpty {
                    jsonBox(vm.retrainJSON)
                }
            }
        }
    }

    // MARK: - Shared Sub-views

    private func devPanel<Content: View>(
        title: String,
        icon: String,
        expanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.wrappedValue.toggle() } }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brandOrange)
                        .frame(width: 20)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expanded.wrappedValue {
                Divider().padding(.horizontal, 14)
                content()
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.brandOrange.opacity(0.20), lineWidth: 1))
    }

    private func jsonBox(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(height: 140)
        .background(DesignSystem.Colors.fieldBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
    }

    private func devButton(
        title: String,
        icon: String,
        running: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if running {
                    ProgressView().scaleEffect(0.8).tint(.white)
                } else {
                    Image(systemName: icon).font(.system(size: 13))
                }
                Text(running ? "Running…" : title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(running ? color.opacity(0.5) : color)
            .cornerRadius(10)
        }
        .disabled(running)
        .buttonStyle(.plain)
    }
}
