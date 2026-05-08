import SwiftUI
import UIKit
import MapKit
import Combine

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateTripViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.accentLime.opacity(0.10))
                        .frame(width: 280)
                        .offset(x: 140, y: 560)
                        .ignoresSafeArea()
                    Circle()
                        .fill(DesignSystem.Colors.textPrimary.opacity(0.03))
                        .frame(width: 340)
                        .offset(x: -140, y: 40)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stepTitle)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Text("Step \(vm.currentStep + 1) of \(vm.totalSteps)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                            Text(progressPercentText)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.onAccentLime)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DesignSystem.Colors.accentLime)
                                .cornerRadius(999)
                        }

                        StepIndicator(currentStep: vm.currentStep, totalSteps: vm.totalSteps)
                    }
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

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
                                .padding(8)
                                .background(Color.cardBackground)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.currentStep < vm.totalSteps - 1 {
                        Button(action: vm.nextStep) {
                            Label("Next", systemImage: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(vm.canProceed ? DesignSystem.Colors.sjsuBlue : .gray)
                        }
                        .disabled(!vm.canProceed)
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: vm.isSuccess)
        }
    }

    private var progressPercentText: String {
        let progress = Double(vm.currentStep + 1) / Double(max(vm.totalSteps, 1))
        return "\(Int(progress * 100))%"
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
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.sjsuBlue : DesignSystem.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? DesignSystem.Colors.sjsuBlue.opacity(0.25)
                    : DesignSystem.Shadow.card.color,
                radius: isSelected ? 16 : DesignSystem.Shadow.card.radius,
                x: 0,
                y: isSelected ? 8 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 1: Location

private struct Step1LocationView: View {
    @ObservedObject var vm: CreateTripViewModel
    @StateObject private var locationSearch = CreateTripLocationSearch()

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
                .glassMorphism(cornerRadius: 16)

                if !locationSearch.suggestions.isEmpty && !vm.userLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 0) {
                        ForEach(locationSearch.suggestions.prefix(6), id: \.self) { suggestion in
                            Button(action: {
                                vm.userLocation = locationSearch.displayText(for: suggestion)
                                locationSearch.clear()
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.brand)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                            .lineLimit(1)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if suggestion != locationSearch.suggestions.prefix(6).last {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DesignSystem.Colors.border.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                }

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
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(DesignSystem.Colors.sjsuBlue.opacity(0.1))
                                    .cornerRadius(20)
                                    .shadow(color: DesignSystem.Colors.sjsuBlue.opacity(0.12), radius: 6, x: 0, y: 3)
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
                        Text("SJSU")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.sjsuBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .elevatedCard(cornerRadius: 14)
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
        .onChange(of: vm.userLocation) { query in
            locationSearch.update(query: query)
        }
        .onChange(of: vm.tripDirection) { _ in
            locationSearch.clear()
        }
    }
}

@MainActor
private final class CreateTripLocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
    }

    func displayText(for completion: MKLocalSearchCompletion) -> String {
        completion.subtitle.isEmpty ? completion.title : "\(completion.title), \(completion.subtitle)"
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = Array(completer.results.prefix(8))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        print("CreateTrip autocomplete error: \(error)")
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
                    HStack {
                        Text("DEPARTURE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.textTertiary)
                            .kerning(0.5)
                        Spacer()
                        Button(action: {
                            vm.departureDate = Date.currentRoundedToMinute
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Now")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.brand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.brand.opacity(0.1))
                            .cornerRadius(999)
                        }
                        .buttonStyle(.plain)
                    }

                    DatePicker("", selection: $vm.departureDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(.brand)
                }
                .padding(16)
                .elevatedCard(cornerRadius: 20)

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
                                        .cornerRadius(12)
                                        .shadow(
                                            color: selected ? Color.brand.opacity(0.25) : .clear,
                                            radius: selected ? 8 : 0,
                                            x: 0, y: 3
                                        )
                                }
                            }
                        }
                        .animation(.spring(response: 0.25), value: vm.recurrenceDays)

                        // End date picker
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("END DATE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.textTertiary)
                                    .kerning(0.5)
                                Spacer()
                                Button(action: {
                                    vm.recurrenceEndDate = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Text("Clear")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.brand)
                                }
                                .buttonStyle(.plain)
                            }

                            DatePicker("Repeat until", selection: Binding(
                                get: { vm.recurrenceEndDate ?? vm.departureDate },
                                set: { vm.recurrenceEndDate = $0 }
                            ), in: vm.departureDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(.brand)
                        }
                        .padding(14)
                        .background(Color.sheetBackground)
                        .cornerRadius(12)
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
                                    .font(.system(size: 36))
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
                                    .font(.system(size: 36))
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
                .padding(16)
                .elevatedCard(cornerRadius: 24)

                // Error
                if let err = vm.errorMessage {
                    ToastBanner(message: err, type: .error)
                }

                PrimaryButton(title: "Create Trip", icon: "car.fill",
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
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(
                            i <= currentStep
                                ? (i < currentStep
                                    ? LinearGradient(colors: [DesignSystem.Colors.sjsuGold, DesignSystem.Colors.sjsuGold.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [DesignSystem.Colors.sjsuBlue, DesignSystem.Colors.sjsuTeal], startPoint: .leading, endPoint: .trailing)
                                  )
                                : LinearGradient(colors: [Color.gray.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(
                            minWidth: 0,
                            maxWidth: i == currentStep ? .infinity : 34,
                            minHeight: i == currentStep ? 7 : 5,
                            maxHeight: i == currentStep ? 7 : 5
                        )

                    // Step number or checkmark dot
                    ZStack {
                        Circle()
                            .fill(i <= currentStep ? Color.brand : Color.gray.opacity(0.2))
                            .frame(width: 16, height: 16)
                            .opacity(i == currentStep ? 1 : 0.7)

                        if i < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(i <= currentStep ? .white : .textTertiary)
                        }
                    }
                    .opacity(i == currentStep ? 1 : 0.6)
                }
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
    @State private var glowPulse: CGFloat = 0.6

    var body: some View {
        ZStack {
            Color.canvasGradient.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    // Gold pulsing sparkle ring behind checkmark
                    Circle()
                        .fill(DesignSystem.Colors.sjsuGold.opacity(0.18))
                        .frame(width: 150, height: 150)
                        .scaleEffect(glowPulse)
                        .opacity(2.0 - Double(glowPulse))

                    Circle()
                        .fill(DesignSystem.Colors.sjsuGold.opacity(0.10))
                        .frame(width: 130, height: 130)

                    Circle().fill(Color.brandGreen.opacity(0.2)).frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56)).foregroundColor(.brandGreen)
                }
                .scaleEffect(scale).opacity(opacity)

                VStack(spacing: 10) {
                    Text("Trip Created!")
                        .font(DesignSystem.Typography.title1)
                        .foregroundColor(.textPrimary)
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
            withAnimation(DesignSystem.Animation.successExpand) {
                scale = 1; opacity = 1
            }
            withAnimation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            ) {
                glowPulse = 1.15
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
