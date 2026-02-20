import SwiftUI
import UIKit

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateTripViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Step Indicator ──
                    StepIndicator(currentStep: vm.currentStep, totalSteps: vm.totalSteps)
                        .padding(.horizontal, AppConstants.pagePadding)
                        .padding(.vertical, 20)
                        .background(Color.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)

                    // ── Step Content ──
                    TabView(selection: $vm.currentStep) {
                        Step0DirectionView(vm: vm).tag(0)
                        Step1LocationView(vm: vm).tag(1)
                        Step2ScheduleView(vm: vm).tag(2)
                        Step3DetailsView(vm: vm).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.currentStep)
                }

                // ── Success Overlay ──
                if vm.isSuccess {
                    TripCreatedView(trip: vm.createdTrip) { dismiss() }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.currentStep > 0 {
                        Button(action: vm.prevStep) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.brand)
                        }
                    } else {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .padding(8).background(Color.appBackground).clipShape(Circle())
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.currentStep < vm.totalSteps - 1 {
                        Button(action: vm.nextStep) {
                            Text("Next").font(.system(size: 16, weight: .semibold))
                                .foregroundColor(vm.canProceed ? .brand : .gray)
                        }
                        .disabled(!vm.canProceed)
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: vm.isSuccess)
        }
    }

    private var stepTitle: String {
        switch vm.currentStep {
        case 0: return "Trip direction"
        case 1: return "Your location"
        case 2: return "When do you leave?"
        default: return "Trip details"
        }
    }
}

// MARK: - Step 0: Direction

private struct Step0DirectionView: View {
    @ObservedObject var vm: CreateTripViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your direction")
                        .font(DesignSystem.Typography.title1)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Are you driving to campus or leaving campus?")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

                // Direction Cards
                VStack(spacing: 16) {
                    DirectionCard(
                        icon: "building.2.fill",
                        title: "To SJSU",
                        subtitle: "Driving to campus from home or another location",
                        isSelected: vm.tripDirection == .toSJSU
                    ) {
                        withAnimation(DesignSystem.Animation.quick) {
                            vm.tripDirection = .toSJSU
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                    DirectionCard(
                        icon: "house.fill",
                        title: "From SJSU",
                        subtitle: "Leaving campus to go home or another location",
                        isSelected: vm.tripDirection == .fromSJSU
                    ) {
                        withAnimation(DesignSystem.Animation.quick) {
                            vm.tripDirection = .fromSJSU
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

                // Info Box
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                        .font(.system(size: 20))
                    Text("All LessGo trips connect to SJSU. We'll automatically set your \(vm.tripDirection == .toSJSU ? "destination" : "starting point") to campus.")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.sjsuBlue.opacity(0.08))
                .cornerRadius(DesignSystem.CornerRadius.medium)

                PrimaryButton(title: "Continue", icon: "arrow.right", isEnabled: vm.isStep0Valid) {
                    vm.nextStep()
                }
                .padding(.top, DesignSystem.Spacing.lg)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        }
    }
}

// MARK: - Direction Card

private struct DirectionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.sjsuBlue : DesignSystem.Colors.surfaceBackground)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.sjsuBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(subtitle)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.sjsuBlue)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.sjsuBlue : DesignSystem.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? DesignSystem.Colors.sjsuBlue.opacity(0.2) : DesignSystem.Shadow.card.color,
                radius: isSelected ? 12 : DesignSystem.Shadow.card.radius,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 1: Location

private struct Step1LocationView: View {
    @ObservedObject var vm: CreateTripViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.tripDirection == .toSJSU ? "Where are you starting?" : "Where are you headed?")
                        .font(DesignSystem.Typography.title1)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(vm.tripDirection == .toSJSU ? "Enter your pickup location" : "Enter your destination")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)

                // Single Location Field
                LabeledTextField(
                    label: vm.tripDirection == .toSJSU ? "Starting Point" : "Destination",
                    placeholder: vm.tripDirection == .toSJSU ? "e.g. San Francisco, Palo Alto" : "e.g. San Francisco, Palo Alto",
                    text: $vm.userLocation,
                    icon: vm.tripDirection == .toSJSU ? "location.circle.fill" : "mappin.circle.fill"
                )

                // Quick select buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("POPULAR LOCATIONS").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary).kerning(0.5)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["San Francisco", "Palo Alto", "Santa Clara", "Fremont", "Milpitas"], id: \.self) { place in
                                Button(action: { vm.userLocation = place }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.fill").font(.system(size: 11))
                                        Text(place).font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(DesignSystem.Colors.sjsuBlue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }

                // Fixed SJSU Endpoint Display
                VStack(alignment: .leading, spacing: 12) {
                    Text("FIXED ENDPOINT").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary).kerning(0.5)

                    HStack(spacing: 12) {
                        Image(systemName: vm.tripDirection == .toSJSU ? "mappin.circle.fill" : "location.circle.fill")
                            .foregroundColor(DesignSystem.Colors.sjsuGold)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.tripDirection == .toSJSU ? "Destination" : "Starting Point")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                            Text("San Jose State University")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.textTertiary)
                            .font(.system(size: 14))
                    }
                    .padding(14)
                    .background(DesignSystem.Colors.sjsuGold.opacity(0.08))
                    .cornerRadius(12)
                }

                // Route Preview
                if !vm.userLocation.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.brandGreen)
                        Text(vm.tripDirection == .toSJSU ? "\(vm.userLocation) → SJSU" : "SJSU → \(vm.userLocation)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(14)
                    .background(Color.brandGreen.opacity(0.08))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                PrimaryButton(title: "Continue", icon: "arrow.right", isEnabled: vm.isStep1Valid) {
                    vm.nextStep()
                }
                .padding(.top, 8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.userLocation)
    }
}

// MARK: - Step 2: Schedule

private struct Step2ScheduleView: View {
    @ObservedObject var vm: CreateTripViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set departure time")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(.textPrimary)
                    Text("When will you be leaving?")
                        .font(.system(size: 15)).foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)

                // Date + Time Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("DEPARTURE").font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary).kerning(0.5)

                    DatePicker("", selection: $vm.departureDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(.brand)
                }
                .cardStyle()

                // Recurring Toggle
                VStack(spacing: 16) {
                    Toggle(isOn: $vm.isRecurring.animation()) {
                        HStack(spacing: 12) {
                            Image(systemName: "repeat").font(.system(size: 18)).foregroundColor(.brand)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Recurring Trip").font(.system(size: 15, weight: .semibold))
                                Text("Repeat on specific days each week")
                                    .font(.system(size: 13)).foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .tint(.brandGreen)

                    if vm.isRecurring {
                        // Day selector
                        HStack(spacing: 8) {
                            ForEach(Array(zip(vm.dayNames, vm.dayNumbers)), id: \.0) { name, num in
                                let selected = vm.recurrenceDays.contains(num)
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selected { vm.recurrenceDays.remove(num) }
                                    else { vm.recurrenceDays.insert(num) }
                                }) {
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(selected ? Color.brand : Color.appBackground)
                                        .foregroundColor(selected ? .white : .textSecondary)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .animation(.spring(response: 0.25), value: vm.recurrenceDays)
                    }
                }
                .cardStyle()

                PrimaryButton(title: "Continue", icon: "arrow.right", isEnabled: vm.isStep2Valid) {
                    vm.nextStep()
                }
                .padding(.top, 8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }
}

// MARK: - Step 3: Details

private struct Step3DetailsView: View {
    @ObservedObject var vm: CreateTripViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set seats available")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(.textPrimary)
                    Text("How many passengers can you take?")
                        .font(.system(size: 15)).foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)

                // Seats Stepper
                VStack(spacing: 20) {
                    HStack {
                        Text("Seats Available")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.textPrimary)
                        Spacer()
                        HStack(spacing: 20) {
                            Button(action: {
                                if vm.seatsAvailable > 1 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.seatsAvailable -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(vm.seatsAvailable > 1 ? .brand : .gray.opacity(0.3))
                            }
                            Text("\(vm.seatsAvailable)")
                                .font(.system(size: 32, weight: .bold)).foregroundColor(.textPrimary)
                                .frame(width: 44)
                                .contentTransition(.numericText())
                            Button(action: {
                                if vm.seatsAvailable < AppConstants.maxSeats {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.seatsAvailable += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(vm.seatsAvailable < AppConstants.maxSeats ? .brand : .gray.opacity(0.3))
                            }
                        }
                    }

                    // Seat icons
                    HStack(spacing: 8) {
                        ForEach(1...AppConstants.maxSeats, id: \.self) { i in
                            Image(systemName: i <= vm.seatsAvailable ? "person.fill" : "person")
                                .font(.system(size: 20))
                                .foregroundColor(i <= vm.seatsAvailable ? .brandGreen : .gray.opacity(0.25))
                        }
                    }
                    .animation(.spring(response: 0.3), value: vm.seatsAvailable)
                }
                .cardStyle()

                // Review Summary
                VStack(alignment: .leading, spacing: 14) {
                    Text("TRIP SUMMARY")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.textTertiary).kerning(0.5)

                    let fromLocation = vm.tripDirection == .toSJSU ? vm.userLocation : "SJSU"
                    let toLocation = vm.tripDirection == .toSJSU ? "SJSU" : vm.userLocation

                    SummaryRow(icon: "location.circle.fill", label: "From", value: fromLocation, color: DesignSystem.Colors.sjsuBlue)
                    Divider()
                    SummaryRow(icon: "mappin.circle.fill", label: "To", value: toLocation, color: DesignSystem.Colors.sjsuGold)
                    Divider()
                    SummaryRow(icon: "clock.fill", label: "Time",
                               value: vm.departureDate.tripDateTimeString, color: .orange)
                    Divider()
                    SummaryRow(icon: "person.2.fill", label: "Seats",
                               value: "\(vm.seatsAvailable) available", color: .green)
                    if let recurrence = vm.recurrenceString {
                        Divider()
                        SummaryRow(icon: "repeat", label: "Repeat", value: recurrence.capitalized, color: DesignSystem.Colors.sjsuBlue)
                    }
                }
                .cardStyle()

                // Error
                if let err = vm.errorMessage {
                    ToastBanner(message: err, type: .error)
                }

                PrimaryButton(title: "Create Trip", icon: "car.badge.plus",
                              isLoading: vm.isLoading, isEnabled: vm.canProceed) {
                    Task { await vm.createTrip() }
                }
                .padding(.top, 8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
        .animation(.spring(response: 0.3), value: vm.seatsAvailable)
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).foregroundColor(.textTertiary)
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary)
            }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                  .fill(i <= currentStep ? Color.brand : Color.gray.opacity(0.2))
                  .frame(
                    minWidth: 0,
                    maxWidth: i == currentStep ? .infinity : 30,
                    minHeight: 5,
                    maxHeight: 5
                  )
                  .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}

// MARK: - Trip Created Success View

private struct TripCreatedView: View {
    let trip: Trip?
    let onDone: () -> Void
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(Color.brandGreen.opacity(0.1)).frame(width: 130, height: 130)
                    Circle().fill(Color.brandGreen.opacity(0.2)).frame(width: 100, height: 100)
                    Image(systemName: "car.badge.checkmark")
                        .font(.system(size: 56)).foregroundColor(.brandGreen)
                }
                .scaleEffect(scale).opacity(opacity)

                VStack(spacing: 10) {
                    Text("Trip Created!").font(.system(size: 28, weight: .bold)).foregroundColor(.textPrimary)
                    if let trip = trip {
                        Text("Your trip to \(trip.destination) is now live.\nRiders can start booking.")
                            .font(.system(size: 16)).foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                }

                PrimaryButton(title: "Done", icon: "checkmark") { onDone() }
                    .padding(.horizontal, AppConstants.pagePadding)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scale = 1; opacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
