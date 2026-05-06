import SwiftUI

struct ReportUserView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let reportedUserId: String
    let reportedUserName: String
    let tripId: String?

    @State private var selectedCategory: ReportCategory = .safety_concern
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    enum ReportCategory: String, CaseIterable, Identifiable {
        case safety_concern = "Safety Concern"
        case inappropriate_behavior = "Inappropriate Behavior"
        case cleanliness = "Cleanliness Issue"
        case harassment = "Harassment"
        case discrimination = "Discrimination"
        case route_issue = "Route Issue"
        case payment_dispute = "Payment Dispute"
        case no_show = "No Show"
        case other = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .safety_concern: return "exclamationmark.shield.fill"
            case .inappropriate_behavior: return "person.fill.xmark"
            case .cleanliness: return "sparkles"
            case .harassment: return "hand.raised.fill"
            case .discrimination: return "person.2.slash"
            case .route_issue: return "map.fill"
            case .payment_dispute: return "dollarsign.circle.fill"
            case .no_show: return "clock.badge.xmark"
            case .other: return "ellipsis.circle.fill"
            }
        }

        var apiValue: String {
            rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.brandRed.opacity(0.12)).frame(width: 44, height: 44)
                            Image(systemName: "person.fill").foregroundColor(.brandRed)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reporting").font(.system(size: 11, weight: .semibold)).foregroundColor(.textTertiary)
                            Text(reportedUserName).font(.system(size: 15, weight: .bold)).foregroundColor(.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CATEGORY").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ReportCategory.allCases) { category in
                                Button(action: { withAnimation { selectedCategory = category } }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: category.icon).font(.system(size: 18))
                                        Text(category.rawValue).font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
                                    }
                                    .foregroundColor(selectedCategory == category ? .white : .textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedCategory == category ? Color.brandRed : Color.cardBackground)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary)

                        TextEditor(text: $description)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                    }

                    if selectedCategory == .safety_concern || selectedCategory == .harassment {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.brandRed)
                            Text("For emergencies, call **911** or SJSU Police: **408-924-2222**")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(12)
                        .background(Color.brandRed.opacity(0.08))
                        .cornerRadius(12)
                    }

                    PrimaryButton(title: "Submit Report", isLoading: isSubmitting, color: .red) {
                        Task { await submitReport() }
                    }
                    .disabled(description.isEmpty || isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Thank you. Our safety team will review within 24 hours.")
            }
        }
    }

    private func submitReport() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            struct CreateReportRequest: Codable {
                let reportedUserId: String
                let tripId: String?
                let category: String
                let description: String

                enum CodingKeys: String, CodingKey {
                    case reportedUserId = "reported_user_id"
                    case tripId = "trip_id"
                    case category, description
                }
            }

            let request = CreateReportRequest(
                reportedUserId: reportedUserId,
                tripId: tripId,
                category: selectedCategory.apiValue,
                description: description
            )

            let _: EmptyResponse = try await NetworkManager.shared.request(
                endpoint: "/reports",
                method: .post,
                body: request,
                requiresAuth: true
            )

            showSuccess = true
        } catch {
            errorMessage = "Failed to submit report"
        }
    }
}

#Preview {
    ReportUserView(
        reportedUserId: "user-1",
        reportedUserName: "Marcus Chen",
        tripId: "trip-1"
    )
    .environmentObject(AuthViewModel())
}
