import SwiftUI
import UIKit
import UserNotifications
import Combine

@main
struct LessGoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue

    init() {
        let persistedAppearance = AppAppearance(rawValue: appAppearanceRawValue) ?? .system
        configureAppearance(for: persistedAppearance)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(locationManager)
                .preferredColorScheme(appAppearance.colorScheme)
                .onAppear {
                    appDelegate.authVM = authVM
                    applyGlobalAppearance()
                }
                .onChange(of: appAppearanceRawValue) { _ in
                    applyGlobalAppearance()
                }
        }
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }

    private func applyGlobalAppearance() {
        applyWindowInterfaceStyle()
        configureAppearance(for: appAppearance)
    }

    private func applyWindowInterfaceStyle() {
        let style = appAppearance.uiUserInterfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    private func configureAppearance(for appearance: AppAppearance) {
        // SJSU Blue for navigation bar titles
        let sjsuBlue = UIColor(red: 0/255, green: 85/255, blue: 162/255, alpha: 1) // #0055A2

        let navBackground: UIColor
        let navTitleColor: UIColor
        let tabBackground: UIColor
        let tabUnselectedColor: UIColor

        switch appearance {
        case .light:
            navBackground = .white
            navTitleColor = sjsuBlue
            tabBackground = .white
            tabUnselectedColor = UIColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1)
        case .dark:
            navBackground = UIColor(red: 24/255, green: 26/255, blue: 31/255, alpha: 1)
            navTitleColor = .white
            tabBackground = UIColor(red: 24/255, green: 26/255, blue: 31/255, alpha: 1)
            tabUnselectedColor = UIColor(red: 0.64, green: 0.67, blue: 0.73, alpha: 1)
        case .system:
            navBackground = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 24/255, green: 26/255, blue: 31/255, alpha: 1)
                    : .white
            }
            navTitleColor = UIColor { trait in
                trait.userInterfaceStyle == .dark ? .white : sjsuBlue
            }
            tabBackground = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 24/255, green: 26/255, blue: 31/255, alpha: 1)
                    : .white
            }
            tabUnselectedColor = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.64, green: 0.67, blue: 0.73, alpha: 1)
                    : UIColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1)
            }
        }

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBackground
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: navTitleColor
        ]
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: navTitleColor
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // SJSU Blue for selected tab items
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = tabBackground
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = sjsuBlue
        UITabBar.appearance().unselectedItemTintColor = tabUnselectedColor

        // Also update already-mounted bars so theme changes are visible immediately.
        applyAppearanceToVisibleControllers(
            navAppearance: navAppearance,
            tabAppearance: tabAppearance,
            tintColor: sjsuBlue,
            tabUnselectedColor: tabUnselectedColor
        )
    }

    private func applyAppearanceToVisibleControllers(
        navAppearance: UINavigationBarAppearance,
        tabAppearance: UITabBarAppearance,
        tintColor: UIColor,
        tabUnselectedColor: UIColor
    ) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                applyAppearance(
                    to: window.rootViewController,
                    navAppearance: navAppearance,
                    tabAppearance: tabAppearance,
                    tintColor: tintColor,
                    tabUnselectedColor: tabUnselectedColor
                )
            }
        }
    }

    private func applyAppearance(
        to controller: UIViewController?,
        navAppearance: UINavigationBarAppearance,
        tabAppearance: UITabBarAppearance,
        tintColor: UIColor,
        tabUnselectedColor: UIColor
    ) {
        guard let controller else { return }

        if let navController = controller as? UINavigationController {
            navController.navigationBar.standardAppearance = navAppearance
            navController.navigationBar.compactAppearance = navAppearance
            navController.navigationBar.scrollEdgeAppearance = navAppearance
            navController.navigationBar.tintColor = tintColor
        }

        if let tabController = controller as? UITabBarController {
            tabController.tabBar.standardAppearance = tabAppearance
            tabController.tabBar.scrollEdgeAppearance = tabAppearance
            tabController.tabBar.tintColor = tintColor
            tabController.tabBar.unselectedItemTintColor = tabUnselectedColor
        }

        controller.children.forEach {
            applyAppearance(
                to: $0,
                navAppearance: navAppearance,
                tabAppearance: tabAppearance,
                tintColor: tintColor,
                tabUnselectedColor: tabUnselectedColor
            )
        }

        if let presented = controller.presentedViewController {
            applyAppearance(
                to: presented,
                navAppearance: navAppearance,
                tabAppearance: tabAppearance,
                tintColor: tintColor,
                tabUnselectedColor: tabUnselectedColor
            )
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var authVM: AuthViewModel?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error { print("[Push] Authorization error: \(error.localizedDescription)"); return }
            if granted {
                DispatchQueue.main.async {
                    #if targetEnvironment(simulator)
                    print("[Push] Simulator detected - skipping APNs device-token registration")
                    #else
                    UIApplication.shared.registerForRemoteNotifications()
                    #endif
                }
            }
            print("[Push] Permission \(granted ? "granted" : "denied")")
        }

        return true
    }

    // MARK: - Device Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(tokenString)")

        guard let userId = KeychainManager.shared.getUserId() else { return }
        Task { try? await UserService.shared.registerDeviceToken(userId: userId, token: tokenString) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let message = error.localizedDescription.lowercased()
        if message.contains("aps-environment") {
            print("[Push] Registration failed: missing APNs entitlement (enable Push Notifications capability for this app ID/profile)")
            return
        }
        print("[Push] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] Notification tapped: \(userInfo)")
        completionHandler()
    }
}
