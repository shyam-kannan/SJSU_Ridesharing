//
//  LessGoUITests.swift
//  LessGoUITests
//
//  Created by Shyam Kannan on 2/16/26.
//

import XCTest

final class LessGoUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Welcome Screen

    /// The app name "LessGo" should appear on the splash screen or welcome screen.
    @MainActor
    func testAppNameIsVisibleOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let appName = app.staticTexts["LessGo"]
        XCTAssertTrue(
            appName.waitForExistence(timeout: 5),
            "Expected 'LessGo' to be visible on launch"
        )
    }

    /// After the splash screen fades, the welcome screen shows the "Get Started" CTA.
    @MainActor
    func testWelcomeScreenShowsGetStartedButton() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for the 1.2-second splash to clear and the welcome screen to appear.
        let getStarted = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Get Started'")
        ).firstMatch
        XCTAssertTrue(
            getStarted.waitForExistence(timeout: 5),
            "Expected a 'Get Started' button on the welcome screen"
        )
    }

    /// The welcome screen provides a login path for returning users.
    @MainActor
    func testWelcomeScreenShowsLoginButton() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(
            loginButton.waitForExistence(timeout: 5),
            "Expected a login button on the welcome screen"
        )
    }

    /// The welcome screen shows the SJSU platform badge.
    @MainActor
    func testWelcomeScreenShowsSJSUBranding() throws {
        let app = XCUIApplication()
        app.launch()

        let sjsuText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'SJSU'")
        ).firstMatch
        XCTAssertTrue(
            sjsuText.waitForExistence(timeout: 5),
            "Expected SJSU branding to appear on the welcome screen"
        )
    }

    // MARK: - Login Navigation

    /// Tapping the login button presents the login sheet with an email field.
    @MainActor
    func testTappingLoginButtonPresentsLoginSheet() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        // The login sheet should show the email text field with its placeholder.
        let emailField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'sjsu.edu'")
        ).firstMatch
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 3),
            "Expected an email text field after tapping the login button"
        )
    }

    /// The login sheet contains a password field.
    @MainActor
    func testLoginSheetHasPasswordField() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(
            passwordField.waitForExistence(timeout: 3),
            "Expected a secure password field on the login sheet"
        )
    }

    /// The login sheet shows a "Log In" action element.
    @MainActor
    func testLoginSheetShowsLogInAction() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let logInLabel = app.staticTexts.matching(
            NSPredicate(format: "label == 'Log In'")
        ).firstMatch
        XCTAssertTrue(
            logInLabel.waitForExistence(timeout: 3),
            "Expected 'Log In' text to be visible on the login sheet"
        )
    }

    /// The login sheet offers a "Sign Up for Free" link for new users.
    @MainActor
    func testLoginSheetHasSignUpLink() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let signUpLink = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sign Up'")
        ).firstMatch
        XCTAssertTrue(
            signUpLink.waitForExistence(timeout: 3),
            "Expected a 'Sign Up' link on the login sheet"
        )
    }

    /// The "Welcome Back" heading should appear on the login sheet.
    @MainActor
    func testLoginSheetShowsWelcomeBackHeading() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let heading = app.staticTexts["Welcome Back"]
        XCTAssertTrue(
            heading.waitForExistence(timeout: 3),
            "Expected 'Welcome Back' heading on the login sheet"
        )
    }

    // MARK: - Sign Up Navigation

    /// Tapping "Get Started" opens the sign-up sheet.
    @MainActor
    func testTappingGetStartedPresentsSignUpSheet() throws {
        let app = XCUIApplication()
        app.launch()

        let getStarted = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Get Started'")
        ).firstMatch
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        // The sign-up sheet header reads "Create account".
        let heading = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Create account'")
        ).firstMatch
        XCTAssertTrue(
            heading.waitForExistence(timeout: 3),
            "Expected 'Create account' heading on the sign-up sheet"
        )
    }

    /// The sign-up sheet shows a name field.
    @MainActor
    func testSignUpSheetHasNameField() throws {
        let app = XCUIApplication()
        app.launch()

        let getStarted = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Get Started'")
        ).firstMatch
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let nameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'Jane Doe'")
        ).firstMatch
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 3),
            "Expected a name text field on the sign-up sheet"
        )
    }

    /// The sign-up sheet shows "Rider" and "Driver" role options — central to SJSU
    /// verification gating, since role determines post-signup verification prompts.
    @MainActor
    func testSignUpSheetShowsRiderAndDriverRoleOptions() throws {
        let app = XCUIApplication()
        app.launch()

        let getStarted = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Get Started'")
        ).firstMatch
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let riderButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Rider'")
        ).firstMatch
        XCTAssertTrue(
            riderButton.waitForExistence(timeout: 3),
            "Expected a 'Rider' role button on the sign-up sheet"
        )

        let driverButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Driver'")
        ).firstMatch
        XCTAssertTrue(
            driverButton.waitForExistence(timeout: 3),
            "Expected a 'Driver' role button on the sign-up sheet"
        )
    }

    /// The sign-up sheet has a "Create Account" submit button.
    @MainActor
    func testSignUpSheetShowsCreateAccountAction() throws {
        let app = XCUIApplication()
        app.launch()

        let getStarted = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Get Started'")
        ).firstMatch
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let createLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Create Account'")
        ).firstMatch
        XCTAssertTrue(
            createLabel.waitForExistence(timeout: 3),
            "Expected 'Create Account' text on the sign-up sheet"
        )
    }

    // MARK: - SJSU Verification Gating

    /// The welcome screen badge explicitly mentions "Verified SJSU Students Only",
    /// confirming that SJSU verification is surfaced before the user signs up.
    @MainActor
    func testWelcomeScreenAdvisesVerifiedSJSUStudentsOnly() throws {
        let app = XCUIApplication()
        app.launch()

        let verifiedText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Verified SJSU Students'")
        ).firstMatch
        XCTAssertTrue(
            verifiedText.waitForExistence(timeout: 5),
            "Expected 'Verified SJSU Students Only' text on the welcome screen"
        )
    }

    /// The login sheet shows the "Verified SJSU" trust chip, reinforcing the
    /// gating requirement for all authenticated users.
    @MainActor
    func testLoginSheetShowsVerifiedSJSUTrustChip() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'already have an account'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        loginButton.tap()

        let chip = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Verified SJSU'")
        ).firstMatch
        XCTAssertTrue(
            chip.waitForExistence(timeout: 3),
            "Expected a 'Verified SJSU' trust chip on the login sheet"
        )
    }
}
