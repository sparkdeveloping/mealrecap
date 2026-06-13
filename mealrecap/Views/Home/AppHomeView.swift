import SwiftUI

struct AppHomeView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            AmbientBackground()

            DayPagerView()
                .environmentObject(app)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .sheet(isPresented: $app.shouldShowPaywall) {
            PaywallView(reason: app.paywallReason)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
}
