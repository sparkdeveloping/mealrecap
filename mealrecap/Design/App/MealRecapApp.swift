import SwiftUI
import FirebaseCore

@main
struct MealRecapApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .preferredColorScheme(.light)
                .task {
                    await appModel.start()
                }
        }
    }
}
