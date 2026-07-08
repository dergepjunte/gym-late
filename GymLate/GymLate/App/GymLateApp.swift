import SwiftUI

@main
struct GymLateApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
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
