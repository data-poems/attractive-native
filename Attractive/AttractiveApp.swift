import SwiftUI

@main
struct AttractiveApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = AttractiveSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .task {
                    if scenePhase == .active {
                        settings.recordActiveSession()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        settings.recordActiveSession()
                    }
                }
        }
    }
}
