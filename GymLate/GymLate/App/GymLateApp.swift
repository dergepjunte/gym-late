import SwiftUI
import UIKit
import GoogleSignIn

@main
struct GymLateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let profile = AppState.shared.userProfile,
              let group = AppState.shared.activeGroup else { return }
        Task { @MainActor in
            NotificationManager.shared.registerAPNsToken(
                deviceToken, groupId: group.id,
                userId: profile.userId, recoveryCode: profile.recoveryCode,
                accountToken: AppState.shared.account?.accountToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    // GoogleSignIn resumes its flow (Safari/Google-app redirect) through
    // this URL callback — required for GIDSignIn.sharedInstance.signIn to
    // ever complete.
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.isBootLoading {
                LaunchLoadingView().transition(.opacity)
            } else if appState.activeGroup != nil && appState.userProfile != nil {
                AppRootView().transition(.opacity)
            } else {
                LandingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.isBootLoading)
        .animation(.easeInOut(duration: 0.3), value: appState.activeGroup?.id)
    }
}
