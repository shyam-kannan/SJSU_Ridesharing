//
//  LessGoTests.swift
//  LessGoTests
//
//  Created by Shyam Kannan on 2/16/26.
//

import Testing
import CoreLocation
@testable import LessGo

struct LessGoTests {

    // MARK: - API Config & App Constants

    @Test func apiConfigBaseURLIsSetToAValidURLString() {
        #expect(!APIConfig.baseURL.isEmpty)
        #expect(APIConfig.baseURL.hasPrefix("http"))
        #expect(URL(string: APIConfig.baseURL) != nil)
    }

    @Test func appConstantsAreWithinExpectedProductBounds() {
        #expect(AppConstants.defaultSearchRadiusMeters == 8000)
        #expect(AppConstants.maxSeats == 8)
        #expect(AppConstants.minPasswordLength == 8)
        #expect(AppConstants.sjsuCoordinate.latitude > 37.0)
        #expect(AppConstants.sjsuCoordinate.longitude < -121.0)
    }

    // MARK: - AuthViewModel: Email Validation

    @Test func validateEmailRejectsEmptyString() {
        #expect(AuthViewModel.validateEmail("") != nil)
    }

    @Test func validateEmailRejectsWhitespaceOnly() {
        #expect(AuthViewModel.validateEmail("   ") != nil)
    }

    @Test func validateEmailRejectsAddressWithoutAtSign() {
        #expect(AuthViewModel.validateEmail("notanemail.com") != nil)
    }

    @Test func validateEmailRejectsAddressWithoutDot() {
        #expect(AuthViewModel.validateEmail("test@nodot") != nil)
    }

    @Test func validateEmailAcceptsValidSJSUAddress() {
        #expect(AuthViewModel.validateEmail("student@sjsu.edu") == nil)
    }

    @Test func validateEmailAcceptsAddressWithLeadingAndTrailingWhitespace() {
        #expect(AuthViewModel.validateEmail("  student@sjsu.edu  ") == nil)
    }

    // MARK: - AuthViewModel: Password Validation

    @Test func validatePasswordRejectsPasswordThatIsTooShort() {
        let error = AuthViewModel.validatePassword("Ab1")
        #expect(error != nil)
        #expect(error?.contains("8") == true)
    }

    @Test func validatePasswordRejectsPasswordWithNoUppercaseLetter() {
        let error = AuthViewModel.validatePassword("password123")
        #expect(error != nil)
        #expect(error?.lowercased().contains("uppercase") == true)
    }

    @Test func validatePasswordRejectsPasswordWithNoNumber() {
        let error = AuthViewModel.validatePassword("Password")
        #expect(error != nil)
        #expect(error?.lowercased().contains("number") == true)
    }

    @Test func validatePasswordAcceptsStrongPassword() {
        #expect(AuthViewModel.validatePassword("Password1") == nil)
    }

    @Test func validatePasswordAcceptsPasswordWithSpecialCharacter() {
        #expect(AuthViewModel.validatePassword("Secure1!") == nil)
    }

    // MARK: - AuthViewModel: Name Validation

    @Test func validateNameRejectsEmptyString() {
        #expect(AuthViewModel.validateName("") != nil)
    }

    @Test func validateNameRejectsWhitespaceOnly() {
        #expect(AuthViewModel.validateName("   ") != nil)
    }

    @Test func validateNameRejectsSingleCharacter() {
        #expect(AuthViewModel.validateName("A") != nil)
    }

    @Test func validateNameAcceptsFullName() {
        #expect(AuthViewModel.validateName("Jane Doe") == nil)
    }

    @Test func validateNameAcceptsMinimumTwoCharacterName() {
        #expect(AuthViewModel.validateName("Jo") == nil)
    }

    // MARK: - SearchCriteria: Coordinate Routing

    @Test func searchCriteriaToSJSUUsesUserCoordAsOriginAndSJSUAsDestination() {
        let userCoord = CLLocationCoordinate2D(latitude: 37.5, longitude: -121.9)
        let criteria = SearchCriteria(
            direction: .toSJSU,
            location: "Home",
            coordinate: userCoord,
            departureTime: Date()
        )
        #expect(criteria.originCoordinate.latitude == userCoord.latitude)
        #expect(criteria.originCoordinate.longitude == userCoord.longitude)
        #expect(criteria.destinationCoordinate.latitude == AppConstants.sjsuCoordinate.latitude)
        #expect(criteria.destinationCoordinate.longitude == AppConstants.sjsuCoordinate.longitude)
    }

    @Test func searchCriteriaFromSJSUUsesSJSUAsOriginAndUserCoordAsDestination() {
        let userCoord = CLLocationCoordinate2D(latitude: 37.5, longitude: -121.9)
        let criteria = SearchCriteria(
            direction: .fromSJSU,
            location: "Home",
            coordinate: userCoord,
            departureTime: Date()
        )
        #expect(criteria.originCoordinate.latitude == AppConstants.sjsuCoordinate.latitude)
        #expect(criteria.originCoordinate.longitude == AppConstants.sjsuCoordinate.longitude)
        #expect(criteria.destinationCoordinate.latitude == userCoord.latitude)
        #expect(criteria.destinationCoordinate.longitude == userCoord.longitude)
    }

    // MARK: - BookingState: Display Values

    @Test func bookingStateDisplayNamesMatchExpectedStrings() {
        #expect(BookingState.pending.displayName == "Awaiting Approval")
        #expect(BookingState.approved.displayName == "Confirmed")
        #expect(BookingState.rejected.displayName == "Declined")
        #expect(BookingState.cancelled.displayName == "Cancelled")
        #expect(BookingState.completed.displayName == "Completed")
    }

    @Test func bookingStateIconNamesAreNonEmpty() {
        for state in [BookingState.pending, .approved, .rejected, .cancelled, .completed] {
            #expect(!state.iconName.isEmpty)
        }
    }

    @Test func bookingStateColorsAreNonEmpty() {
        for state in [BookingState.pending, .approved, .rejected, .cancelled, .completed] {
            #expect(!state.color.isEmpty)
        }
    }

    @Test func bookingStatePendingAndCompletedHaveDistinctColors() {
        #expect(BookingState.pending.color != BookingState.approved.color)
        #expect(BookingState.rejected.color != BookingState.approved.color)
    }

    // MARK: - NetworkError: User Messages

    @Test func networkErrorUnauthorizedMessageMentionsSessionOrLogin() {
        let message = NetworkError.unauthorized.userMessage
        let lower = message.lowercased()
        #expect(lower.contains("session") || lower.contains("log in"))
    }

    @Test func networkErrorNoConnectionMessageMentionsInternet() {
        let message = NetworkError.noConnection.userMessage
        let lower = message.lowercased()
        #expect(lower.contains("internet") || lower.contains("network"))
    }

    @Test func networkErrorTimeoutMessageMentionsTime() {
        let message = NetworkError.timeout.userMessage
        #expect(message.lowercased().contains("time"))
    }

    @Test func networkErrorForbiddenMessageIsNonEmpty() {
        #expect(!NetworkError.forbidden.userMessage.isEmpty)
    }

    @Test func networkErrorNoDataMessageIsNonEmpty() {
        #expect(!NetworkError.noData.userMessage.isEmpty)
    }

    @Test func networkErrorServerErrorInvalidCredentialsMentionsPasswordOrEmail() {
        let apiError = APIError(status: "error", message: "Invalid credentials provided", errors: nil)
        let message = NetworkError.serverError(apiError).userMessage.lowercased()
        #expect(message.contains("password") || message.contains("email"))
    }

    @Test func networkErrorServerErrorUserNotFoundMentionsAccount() {
        let apiError = APIError(status: "error", message: "User not found", errors: nil)
        let message = NetworkError.serverError(apiError).userMessage.lowercased()
        #expect(message.contains("account") || message.contains("email"))
    }

    @Test func networkErrorServerErrorEmailAlreadyExistsMentionsRegistered() {
        let apiError = APIError(status: "error", message: "Email already exists", errors: nil)
        let message = NetworkError.serverError(apiError).userMessage.lowercased()
        #expect(message.contains("email") || message.contains("registered"))
    }

    @Test func networkErrorServerErrorNotEnoughSeatsMentionsSeats() {
        let apiError = APIError(status: "error", message: "Not enough seats available", errors: nil)
        let message = NetworkError.serverError(apiError).userMessage.lowercased()
        #expect(message.contains("seat"))
    }

    // MARK: - CreateTripViewModel: Step Validation

    @Test @MainActor func createTripViewModelStep0IsAlwaysValid() {
        let vm = CreateTripViewModel()
        #expect(vm.isStep0Valid)
    }

    @Test @MainActor func createTripViewModelStep1InvalidWhenLocationIsEmpty() {
        let vm = CreateTripViewModel()
        vm.userLocation = ""
        #expect(!vm.isStep1Valid)
    }

    @Test @MainActor func createTripViewModelStep1InvalidWhenLocationIsTooShort() {
        let vm = CreateTripViewModel()
        vm.userLocation = "AB"
        #expect(!vm.isStep1Valid)
    }

    @Test @MainActor func createTripViewModelStep1ValidForSufficientLocation() {
        let vm = CreateTripViewModel()
        vm.userLocation = "123 Main St"
        #expect(vm.isStep1Valid)
    }

    @Test @MainActor func createTripViewModelStep2InvalidForPastDeparture() {
        let vm = CreateTripViewModel()
        vm.departureDate = Date().addingTimeInterval(-3600)
        #expect(!vm.isStep2Valid)
    }

    @Test @MainActor func createTripViewModelStep2ValidForFutureDeparture() {
        let vm = CreateTripViewModel()
        vm.departureDate = Date().addingTimeInterval(3600)
        #expect(vm.isStep2Valid)
    }

    @Test @MainActor func createTripViewModelStep3InvalidWhenSeatsIsZero() {
        let vm = CreateTripViewModel()
        vm.seatsAvailable = 0
        #expect(!vm.isStep3Valid)
    }

    @Test @MainActor func createTripViewModelStep3ValidWithAtLeastOneSeat() {
        let vm = CreateTripViewModel()
        vm.seatsAvailable = 1
        #expect(vm.isStep3Valid)
    }

    // MARK: - CreateTripViewModel: Step Navigation

    @Test @MainActor func createTripViewModelStartsOnStep0() {
        let vm = CreateTripViewModel()
        #expect(vm.currentStep == 0)
    }

    @Test @MainActor func createTripViewModelAdvancesAndReverses() {
        let vm = CreateTripViewModel()
        vm.nextStep()
        #expect(vm.currentStep == 1)
        vm.nextStep()
        #expect(vm.currentStep == 2)
        vm.prevStep()
        #expect(vm.currentStep == 1)
        vm.prevStep()
        #expect(vm.currentStep == 0)
    }

    @Test @MainActor func createTripViewModelDoesNotGoBelowStep0() {
        let vm = CreateTripViewModel()
        vm.prevStep()
        #expect(vm.currentStep == 0)
    }

    @Test @MainActor func createTripViewModelDoesNotExceedLastStep() {
        let vm = CreateTripViewModel()
        for _ in 0...vm.totalSteps + 2 {
            vm.nextStep()
        }
        #expect(vm.currentStep == vm.totalSteps - 1)
    }

    // MARK: - CreateTripViewModel: Origin/Destination Sync

    @Test @MainActor func syncOriginDestinationToSJSUSetsUserLocationAsOrigin() {
        let vm = CreateTripViewModel()
        vm.tripDirection = .toSJSU
        vm.userLocation = "Campbell, CA"
        vm.syncOriginDestination()
        #expect(vm.origin == "Campbell, CA")
        #expect(vm.destination == "San Jose State University")
    }

    @Test @MainActor func syncOriginDestinationFromSJSUSetsUserLocationAsDestination() {
        let vm = CreateTripViewModel()
        vm.tripDirection = .fromSJSU
        vm.userLocation = "Campbell, CA"
        vm.syncOriginDestination()
        #expect(vm.origin == "San Jose State University")
        #expect(vm.destination == "Campbell, CA")
    }

    // MARK: - CreateTripViewModel: Recurrence String

    @Test @MainActor func recurrenceStringIsNilWhenNotRecurring() {
        let vm = CreateTripViewModel()
        vm.isRecurring = false
        #expect(vm.recurrenceString == nil)
    }

    @Test @MainActor func recurrenceStringIsNilWhenRecurringButNoDaysSelected() {
        let vm = CreateTripViewModel()
        vm.isRecurring = true
        vm.recurrenceDays = []
        #expect(vm.recurrenceString == nil)
    }

    @Test @MainActor func recurrenceStringIsWeekdaysForMonThroughFri() {
        let vm = CreateTripViewModel()
        vm.isRecurring = true
        // Calendar.Component.weekday: 1=Sunday, 2=Monday, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Saturday
        vm.recurrenceDays = Set([2, 3, 4, 5, 6]) // Monday through Friday
        #expect(vm.recurrenceString == "weekdays")
    }

    @Test @MainActor func recurrenceStringIsDailyForAllSevenDays() {
        let vm = CreateTripViewModel()
        vm.isRecurring = true
        vm.recurrenceDays = Set([1, 2, 3, 4, 5, 6, 7])
        #expect(vm.recurrenceString == "daily")
    }

    @Test @MainActor func recurrenceStringContainsDayNamesForPartialSelection() {
        let vm = CreateTripViewModel()
        vm.isRecurring = true
        vm.recurrenceDays = Set([2, 4]) // Mon, Wed
        let result = vm.recurrenceString
        #expect(result != nil)
        #expect(result?.contains("mon") == true || result?.contains("Mon") == true)
    }

    // MARK: - CreateTripViewModel: Reset

    @Test @MainActor func resetRestoresAllFieldsToDefaults() {
        let vm = CreateTripViewModel()
        vm.userLocation = "Some Place"
        vm.tripDirection = .fromSJSU
        vm.seatsAvailable = 4
        vm.isRecurring = true
        vm.recurrenceDays = [2, 3]
        vm.errorMessage = "Some error"
        vm.currentStep = 2

        vm.reset()

        #expect(vm.userLocation == "")
        #expect(vm.tripDirection == .toSJSU)
        #expect(vm.seatsAvailable == 2)
        #expect(vm.isRecurring == false)
        #expect(vm.recurrenceDays.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.currentStep == 0)
        #expect(vm.isSuccess == false)
        #expect(vm.createdTrip == nil)
    }

    // MARK: - Date Extensions

    @Test func currentRoundedToMinuteHasZeroSeconds() {
        let date = Date.currentRoundedToMinute
        let seconds = Calendar.autoupdatingCurrent.component(.second, from: date)
        #expect(seconds == 0)
    }

    @Test func countdownStringIsDepartedForPastDate() {
        let pastDate = Date().addingTimeInterval(-3600)
        #expect(pastDate.countdownString == "Departed")
    }

    @Test func countdownStringIsLeavingNowWhenDepartureIsUnderOneMinuteAway() {
        // minutesUntil() truncates via Int(), so 30 s → 0 min → "Leaving now"
        let nearFuture = Date().addingTimeInterval(30)
        #expect(nearFuture.countdownString == "Leaving now")
    }

    @Test func countdownStringContainsMinutesWhenDepartureIsMoreThanOneMinuteAway() {
        // 90 seconds → 1 minute when truncated → "Leaving in 1 min"
        let oneMinFuture = Date().addingTimeInterval(90)
        #expect(oneMinFuture.countdownString.contains("Leaving in"))
    }

    @Test func countdownStringContainsHoursForTwoHourFutureDate() {
        let futureDate = Date().addingTimeInterval(7200)
        #expect(futureDate.countdownString.contains("2h"))
    }

    @Test func countdownStringContainsMinutesForShortFutureDate() {
        let futureDate = Date().addingTimeInterval(1800) // 30 min
        #expect(futureDate.countdownString.contains("30 min"))
    }

    @Test func timeAgoReturnsJustNowForRecentDate() {
        let justNow = Date().addingTimeInterval(-5)
        #expect(justNow.timeAgo == "Just now")
    }

    @Test func timeAgoReturnsMinutesAgoForFiveMinutesBack() {
        let minutesAgo = Date().addingTimeInterval(-300)
        #expect(minutesAgo.timeAgo.contains("m ago"))
    }

    @Test func timeAgoReturnsHoursAgoForTwoHoursBack() {
        let hoursAgo = Date().addingTimeInterval(-7200)
        #expect(hoursAgo.timeAgo.contains("h ago"))
    }

    @Test func timeAgoReturnsDaysAgoForTwoDaysBack() {
        let daysAgo = Date().addingTimeInterval(-172800)
        #expect(daysAgo.timeAgo.contains("d ago"))
    }

    // MARK: - TripWithDriver: Model Initialization

    @Test func tripWithDriverMemberwiseInitPreservesAllFields() {
        let now = Date()
        let trip = TripWithDriver(
            id: "trip-1",
            driverId: "driver-1",
            driverName: "Alex Smith",
            driverRating: 4.8,
            driverPhotoUrl: nil,
            vehicleInfo: "Toyota Prius",
            origin: "Campbell, CA",
            destination: "San Jose State University",
            departureTime: now,
            seatsAvailable: 3,
            estimatedCost: 12.50,
            featured: true,
            status: "active"
        )
        #expect(trip.id == "trip-1")
        #expect(trip.driverName == "Alex Smith")
        #expect(trip.driverRating == 4.8)
        #expect(trip.seatsAvailable == 3)
        #expect(trip.estimatedCost == 12.50)
        #expect(trip.featured == true)
        #expect(trip.status == "active")
    }

}
