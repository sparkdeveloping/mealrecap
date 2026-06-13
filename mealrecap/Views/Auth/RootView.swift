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
            } else {
                AppHomeView()
            }
        }
        .alert("MealRecap", isPresented: Binding(get: { app.errorMessage != nil }, set: { _ in app.errorMessage = nil })) {
            Button("OK", role: .cancel) { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}
