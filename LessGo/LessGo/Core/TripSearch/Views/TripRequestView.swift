import SwiftUI
import MapKit
import Combine

// MARK: - TripRequestView
// Rider origin/destination/time input screen.
// Shown when the rider taps "Request a Ride" in RiderHomeView.

struct TripRequestView: View {
    @StateObject private var viewModel = TripRequestViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showFinding = false
    @State private var matchedStatus: TripRequestStatus?

    var body: some View {
        NavigationView {
            ZStack {
                Color.canvasGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    formContent
                }
            }
            .navigationTitle("Request a Ride")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.brand)
                }
            }
            .fullScreenCover(isPresented: $showFinding) {
                if case .searching(let requestId) = viewModel.state {
                    FindingDriverView(requestId: requestId, viewModel: viewModel)
                        .environmentObject(authVM)
                }
            }
            .onChange(of: viewModel.state) { newState in
                switch newState {
                case .searching:
                    showFinding = true
                case .matched(let status):
                    matchedStatus = status
                    showFinding = false
                    dismiss()
                case .failed:
                    showFinding = false
                default:
                    break
                }
            }
        }
        .onAppear {
            // Pre-fill origin from current location
            if let loc = locationManager.currentLocation {
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
                    if let pm = placemarks?.first {
                        let addr = [pm.name, pm.locality].compactMap { $0 }.joined(separator: ", ")
                        Task { @MainActor in
                            viewModel.origin = addr
                            viewModel.originCoordinate = loc.coordinate
                        }
                    }
                }
            }
        }
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Origin / Destination card
                VStack(spacing: 0) {
                    locationRow(
                        icon: "circle.fill",
                        iconColor: .brandGold,
                        placeholder: "Pickup location",
                        text: $viewModel.origin
                    )
                    Divider().padding(.leading, 52)
                    locationRow(
                        icon: "mappin.circle.fill",
                        iconColor: .brandGreen,
                        placeholder: "Where to?",
                        text: $viewModel.destination,
                        onCommit: { viewModel.geocodeDestination(viewModel.destination) }
                    )
                }
                .background(Color.cardBackground)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.top, 20)

                // Departure time picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Departure time")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, AppConstants.pagePadding)

                    DatePicker(
                        "",
                        selection: $viewModel.departureTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, AppConstants.pagePadding)
                }

                // Error message
                if case .failed(let msg) = viewModel.state {
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundColor(.brandRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppConstants.pagePadding)
                }

                Spacer().frame(height: 12)

                // Submit button
                Button(action: { viewModel.submit() }) {
                    HStack(spacing: 10) {
                        if case .submitting = viewModel.state {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "car.fill")
                        }
                        Text(viewModel.state == .idle || viewModel.state.isFailed
                             ? "Find my driver"
                             : "Searching…")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canSubmit ? Color.brand : Color.brand.opacity(0.4))
                    .cornerRadius(16)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, AppConstants.pagePadding)
                .padding(.bottom, 32)
            }
        }
    }

    private func locationRow(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        onCommit: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 20))
                .frame(width: 32)

            TextField(placeholder, text: text, onCommit: { onCommit?() })
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var canSubmit: Bool {
        !viewModel.origin.isEmpty &&
        !viewModel.destination.isEmpty &&
        !(viewModel.state == .submitting)
    }
}

private extension TripRequestState {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

