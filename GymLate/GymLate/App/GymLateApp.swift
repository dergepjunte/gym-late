import SwiftUI
import UIKit
import GoogleSignIn

@main
struct GymLateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    init() {
        // v0.3 "Iron": navigation titles in condensed black caps, like gym-wall signage.
        let big = UIFont.systemFont(ofSize: 34, weight: .black, width: .compressed)
        let small = UIFont.systemFont(ofSize: 19, weight: .heavy, width: .condensed)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [.font: big, .foregroundColor: UIColor.white]
        nav.titleTextAttributes = [.font: small, .foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        // Segmented pickers: yellow slab for the selected segment, black stencil text.
        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(K.accent)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.black,
                                    .font: UIFont.systemFont(ofSize: 14, weight: .heavy, width: .condensed)], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.75),
                                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold, width: .condensed)], for: .normal)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                // v0.3 "Iron": the gym is dark — one tuned look instead of a light/dark pair.
                .preferredColorScheme(.dark)
                .tint(K.accent)
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
            } else if appState.showLaunchPicker {
                // Netflix-style "Wer trainiert?" grid (website: #screen-profile-picker) —
                // shown on every cold start with ≥1 saved group instead of silently
                // re-entering the last-active one.
                ProfilePickerView().transition(Self.screenTransition)
            } else if appState.activeGroup != nil && appState.userProfile != nil {
                AppRootView().transition(Self.screenTransition)
            } else {
                LandingView().transition(Self.screenTransition)
            }
        }
        // Fester Boden hinter allen Szenen: beim Heranwachsen/Zurueckweichen (scale) blitzt
        // sonst das schwarze Fenster als Balken oben/unten durch.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GymBackground())
        .animation(.easeInOut(duration: 0.4), value: appState.isBootLoading)
        .animation(.smooth(duration: 0.55), value: appState.showLaunchPicker)
        .animation(.smooth(duration: 0.55), value: appState.activeGroup?.id)
    }

    /// Grosse Szenenwechsel (Profilwahl ↔ App ↔ Start): die neue Szene waechst sanft heran,
    /// die alte ueberstrahlt leicht und verschwindet.
    private static let screenTransition = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.93)),
        removal: .opacity.combined(with: .scale(scale: 1.07)))
}
