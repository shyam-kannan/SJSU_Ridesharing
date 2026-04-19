import SwiftUI
import MapKit
import Combine

// MARK: - FindingDriverView
// Full-screen "Searching" state shown after rider submits a request.
//
// Layout:
//   Top 60%  — MapKit map with pickup pin, destination pin, and a dashed route polyline.
//              An animated pulsing ring overlays the pickup pin to signal active search.
//   Bottom 40% — Sheet with "Finding your driver…" headline, dot animation,
//              origin→destination route summary, and a "Cancel" button.
//
// Polls TripRequestViewModel.state until .matched or .failed.

struct FindingDriverView: View {
    let requestId: String
    @ObservedObject var viewModel: TripRequestViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Dot animation
    @State private var dotCount = 0
    private let dotTimer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    // Pulse animation
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── Map (top 60%) ─────────────────────────────────────────────
                mapSection
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.62)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                // ── Bottom sheet ──────────────────────────────────────────────
                searchingSheet
                    .frame(maxWidth: .infinity)
            }
            .background(Color(hex: "F5F5F5"))
            .ignoresSafeArea(edges: .top)
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 4
        }
        .onChange(of: viewModel.state) { newState in
            if case .failed = newState {
                // Auto-dismiss after 2 s on failure so user can retry
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    dismiss()
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Map Section

    private var mapSection: some View {
        ZStack {
            AnchorRouteMapView(
                origin: viewModel.originCoordinate,
                destination: viewModel.destinationCoordinate,
                driver: nil,
                anchorPoints: [],
                showsUserLocation: false
            )

            // Pulsing ring centered on the pickup area (top-center of map frame)
            GeometryReader { geo in
                pulsingRing
                    .frame(width: 80, height: 80)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height * 0.48
                    )
            }
        }
    }

    // MARK: - Pulsing Ring

    private var pulsingRing: some View {
        ZStack {
            Circle()
                .stroke(Color.brand.opacity(pulseOpacity * 0.4), lineWidth: 3)
                .scaleEffect(pulseScale * 1.45)
            Circle()
                .stroke(Color.brand.opacity(pulseOpacity * 0.65), lineWidth: 3)
                .scaleEffect(pulseScale * 1.20)
            Circle()
                .fill(Color.brand.opacity(0.22))
                .scaleEffect(pulseScale * 0.95)
            Circle()
                .fill(Color.brand)
                .frame(width: 14, height: 14)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.18
                pulseOpacity = 1.0
            }
        }
    }

    // MARK: - Searching Bottom Sheet

    private var searchingSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 20)

            // Headline
            Text("Finding your driver\(String(repeating: ".", count: dotCount))")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .animation(nil, value: dotCount)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Text("Matching you with the best driver nearby")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 20)

            // Error state
            if case .failed(let msg) = viewModel.state {
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundColor(.brandRed)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            // Route summary card
            routeSummaryCard
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            // Cancel button
            Button(action: {
                viewModel.reset()
                dismiss()
            }) {
                Text("Cancel request")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color.white)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
    }

    // MARK: - Route Summary

    private var routeSummaryCard: some View {
        HStack(spacing: 14) {
            // Dot-line-dot indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.brandGold)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.25))
                    .frame(width: 2, height: 28)
                Circle()
                    .fill(Color.brand)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.origin.isEmpty ? "Pickup location" : viewModel.origin)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(viewModel.destination.isEmpty ? "Destination" : viewModel.destination)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "F8FAFC"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
