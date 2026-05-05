import SwiftUI

// MARK: - DriverSelectionView
//
// Presented full-screen immediately after `POST /trips/request` returns a ranked
// list of available drivers (CandidateDriver[]).  The rider can:
//   • Tap "Select This Driver" on any card  → calls selectDriver on the VM,
//     transitions to .searching, and the FindingDriverView appears.
//   • Tap "None of these — pool me"         → transitions directly to .searching
//     without sending a driver request (pooled mode).
//   • Tap × (dismiss)                       → resets the VM to .idle.

struct DriverSelectionView: View {
    let requestId: String
    let drivers: [CandidateDriver]
    let origin: String
    let destination: String
    @ObservedObject var viewModel: TripRequestViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDriverId: String? = nil
    @State private var isSelecting = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    routeSummary
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    sectionTitle
                        .padding(.horizontal, 20)

                    ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                        driverCard(driver: driver, rank: index + 1)
                            .padding(.horizontal, 20)
                    }

                    poolOptionButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        // Reset the busy state if the VM reports an error so the rider can retry
        .onChange(of: viewModel.state) { newState in
            if case .failed = newState {
                isSelecting = false
                selectedDriverId = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose a Driver")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("\(drivers.count) match\(drivers.count == 1 ? "" : "es") found")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button(action: {
                viewModel.reset()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .overlay(
            Rectangle()
                .fill(DesignSystem.Colors.border.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Route Summary

    private var routeSummary: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(Color.brandGold).frame(width: 9, height: 9)
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.25))
                    .frame(width: 2, height: 24)
                Circle().fill(Color.brand).frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(origin.isEmpty ? "Your location" : origin)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(destination.isEmpty ? "Destination" : destination)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .background(DesignSystem.Colors.fieldBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Section Title

    private var sectionTitle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Available Drivers")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("Ranked by route compatibility — best match first")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Driver Card

    private func driverCard(driver: CandidateDriver, rank: Int) -> some View {
        let (rankLabel, rankColor): (String, Color) = {
            switch rank {
            case 1: return ("Best Match", Color.brandGold)
            case 2: return ("2nd Best",   Color.textSecondary)
            case 3: return ("3rd Best",   Color.textTertiary)
            default: return ("\(rank)th Best", Color.textTertiary)
            }
        }()

        let walkText = driver.walkingMinutes <= 1
            ? "< 1 min walk"
            : "\(driver.walkingMinutes) min walk"

        let isThisOne  = selectedDriverId == driver.id
        let showSpinner = isThisOne && isSelecting

        return VStack(alignment: .leading, spacing: 12) {
            // Rank badge + departure time
            HStack {
                Text(rankLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(rankColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(rankColor.opacity(0.12))
                    .cornerRadius(20)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    Text(driver.departureTime, style: .time)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }

            // Stats row
            HStack(spacing: 20) {
                Label(walkText, systemImage: "figure.walk")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                Label(
                    "\(driver.seatsAvailable) seat\(driver.seatsAvailable == 1 ? "" : "s")",
                    systemImage: "person.2.fill"
                )
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)

                if driver.routeScore > 0 {
                    Label("Frequent route", systemImage: "star.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.brandGold)
                }
            }

            // Select button
            Button {
                guard !isSelecting else { return }
                selectedDriverId = driver.id
                isSelecting = true
                viewModel.selectDriver(
                    requestId: requestId,
                    tripId: driver.id,
                    driverId: driver.driverId
                )
            } label: {
                HStack(spacing: 8) {
                    if showSpinner {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Sending request…")
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Select This Driver")
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    (isSelecting && !showSpinner)
                        ? Color.brand.opacity(0.35)
                        : Color.brand
                )
                .cornerRadius(13)
            }
            .disabled(isSelecting)
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: showSpinner)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isThisOne ? Color.brand : DesignSystem.Colors.border.opacity(0.7),
                    lineWidth: isThisOne ? 2 : 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isThisOne)
    }

    // MARK: - Pool Option Button

    private var poolOptionButton: some View {
        Button {
            guard !isSelecting else { return }
            viewModel.skipToPool(requestId: requestId)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 14))
                Text("None of these — add me to the pool")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelecting)
    }
}
#Preview {
    let viewModel = TripRequestViewModel()
    let mockDrivers = [
        CandidateDriver(
            id: "trip-1",
            driverId: "driver-1",
            originLat: 37.3352,
            originLng: -121.8811,
            destinationLat: 37.3360,
            destinationLng: -121.8820,
            departureTime: Date().addingTimeInterval(300),
            distanceToRiderM: 150,
            seatsAvailable: 3,
            routeScore: 0.95
        ),
        CandidateDriver(
            id: "trip-2",
            driverId: "driver-2",
            originLat: 37.3352,
            originLng: -121.8811,
            destinationLat: 37.3360,
            destinationLng: -121.8820,
            departureTime: Date().addingTimeInterval(900),
            distanceToRiderM: 400,
            seatsAvailable: 4,
            routeScore: 0.8
        )
    ]
    
    return DriverSelectionView(
        requestId: "test-req",
        drivers: mockDrivers,
        origin: "SJSU",
        destination: "Diridon",
        viewModel: viewModel
    ).environmentObject(AuthViewModel())
}
