import SwiftUI

struct InAppAccountMenuView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    currentAccountCard

                    if !otherSavedProfiles.isEmpty {
                        savedAccountsSection
                    }

                    actionsSection
                }
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                        presentationMode.wrappedValue.dismiss()
                    }
                        .foregroundColor(.brand)
                }
            }
            .onAppear {
                authVM.refreshSavedLoginProfiles()
            }
        }
    }

    private var currentUserId: String? { authVM.currentUser?.id }

    private var otherSavedProfiles: [SavedLoginProfile] {
        authVM.savedLoginProfiles.filter { $0.userId != currentUserId }
    }

    private var currentAccountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Account")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Text(authVM.currentUser?.name.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.brand)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(authVM.currentUser?.name ?? "Signed In")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(authVM.currentUser?.email ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let role = authVM.currentUser?.role {
                    Text(role.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(999)
                }
            }
        }
        .padding(AppConstants.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppConstants.cardRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var savedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Switch Account")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)

            ForEach(otherSavedProfiles) { profile in
                HStack(spacing: 10) {
                    Button(action: {
                        dismiss()
                        presentationMode.wrappedValue.dismiss()
                        Task { await authVM.loginWithSavedProfile(profile) }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.brand.opacity(0.1)).frame(width: 40, height: 40)
                                Text(profile.name.prefix(1).uppercased())
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.brand)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text(profile.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.brand)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { authVM.removeSavedLoginProfile(profile) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.cardBackground)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if let current = authVM.currentUser,
               authVM.savedLoginProfiles.contains(where: { $0.userId == current.id }) {
                Button(action: {
                    authVM.removeSavedLoginProfile(
                        SavedLoginProfile(
                            id: current.id,
                            userId: current.id,
                            name: current.name,
                            email: current.email,
                            role: current.role,
                            createdAt: Date(),
                            lastUsedAt: Date()
                        )
                    )
                    dismiss()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.minus")
                        Text("Remove This Saved Account")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.textPrimary)
                    .padding(AppConstants.cardPadding)
                    .background(Color.cardBackground)
                    .cornerRadius(AppConstants.cardRadius)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                Task {
                    await authVM.logout()
                    dismiss()
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(.brandRed)
                .padding(AppConstants.cardPadding)
                .background(Color.cardBackground)
                .cornerRadius(AppConstants.cardRadius)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}
