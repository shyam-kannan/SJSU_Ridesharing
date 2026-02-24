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
    @State private var showDeleteAccountAlert = false
    @State private var isRefreshingStatus = false
    @State private var showChangePassword = false
    @State private var showSupport = false
    @State private var showAbout = false
    @State private var showAccountMenu = false
    @State private var showImagePicker = false
    @State private var selectedProfileImage: UIImage?
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("emailNotificationsEnabled") private var emailNotificationsEnabled = true
    @AppStorage("locationShareEnabled") private var locationShareEnabled = true
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

                    // ── Danger Zone ──
                    dangerZone

                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            .background(
                Color(hex: "F4F6F2").ignoresSafeArea()
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
            .sheet(isPresented: $showDriverSetup) {
                DriverSetupView(vm: vm, userId: authVM.currentUser?.id ?? "")
                    .onDisappear { Task { await authVM.refreshCurrentUser() } }
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
                        .fill(Color.white.opacity(0.08))
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
                    .fill(Color(hex: "F8FAFC"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
                ProfileStat(value: String(format: "%.1f", authVM.currentUser?.rating ?? 0),
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
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
        }
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
                    QuickActionCard(icon: "car.badge.plus", label: "Become Driver", color: .brandGreen) {
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
                    Text(String(format: "%.1f avg", authVM.currentUser?.rating ?? 0))
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
                        .fill(Color.white)
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
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
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
            // User service serves uploads directly; backend currently returns a relative path.
            return URL(string: "http://127.0.0.1:3002\(raw)")
        }
        return URL(string: raw)
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
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
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
                                     placeholder: "e.g. 2022 Honda Civic - White",
                                     text: $vm.vehicleInfo, icon: "car")

                    LabeledTextField(label: "License Plate",
                                     placeholder: "e.g. 7ABC123",
                                     text: $vm.licensePlate, icon: "number")
                        .textCase(.uppercase)

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
        self.safeAreaInset(edge: .top, spacing: 0) {
            if let msg = message {
                VStack(spacing: 0) {
                    ToastBanner(message: msg, type: .success)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(), value: message)
    }
}
