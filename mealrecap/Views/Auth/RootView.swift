import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            MRColor.background.ignoresSafeArea()
            if app.isBooting {
                ProgressView()
                    .tint(MRColor.accent)
            } else if app.session == nil {
                AuthView()
            } else if !app.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(app)
            } else {
                AppHomeView()
            }
        }
        .alert("MealRecap", isPresented: Binding(get: { app.errorMessage != nil }, set: { _ in app.errorMessage = nil })) {
            Button("OK", role: .cancel) { app.errorMessage = nil }
            Button("Sign Out", role: .destructive) {
                app.errorMessage = nil
                app.signOut()
            }
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}
