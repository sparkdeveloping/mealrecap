import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLaunchSplash = true

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

            if showLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(100)
            }
        }
        .task {
            let delay: UInt64 = reduceMotion ? 450_000_000 : 1_150_000_000
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.34)) {
                    showLaunchSplash = false
                }
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

private struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var glow = false

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(MRColor.accentSoft.opacity(0.30))
                        .frame(width: 154, height: 154)
                        .blur(radius: 34)
                        .scaleEffect(glow ? 1.08 : 0.92)

                    MealRecapLogoMark(size: 104)
                        .scaleEffect(appeared ? 1 : 0.86)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (appeared ? 0 : -5)))
                }

                MealRecapWordmark()
                    .scaleEffect(1.08)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("MealRecap")
        .onAppear {
            if reduceMotion {
                appeared = true
                glow = true
            } else {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }
}
