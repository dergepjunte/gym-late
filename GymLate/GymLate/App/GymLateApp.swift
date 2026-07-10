import SwiftUI
import UIKit

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
                userId: profile.userId, recoveryCode: profile.recoveryCode)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.activeGroup != nil && appState.userProfile != nil {
                AppRootView()
            } else {
                LandingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.activeGroup?.id)
    }
}
