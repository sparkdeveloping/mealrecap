import SwiftUI

struct AppHomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showCalendar = false
    @State private var showVoice = false
    @State private var showPhoto = false
    @State private var showRecap = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MRColor.background.ignoresSafeArea()

            DayPagerView()
                .environmentObject(app)

            FloatingDock(
                onCalendar: { showCalendar = true },
                onPhoto: { showPhoto = true },
                onVoice: { showVoice = true },
                onRecap: { showRecap = true }
            )
            .padding(.trailing, 18)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCalendar) {
            CalendarSheet(selectedDate: $app.selectedDate) { date in
                Task { await app.loadDate(date) }
                showCalendar = false
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
        }
        .sheet(isPresented: $showVoice) {
            VoiceLogSheet()
                .presentationDetents([.medium])
                .presentationCornerRadius(36)
        }
        .sheet(isPresented: $showPhoto) {
            PhotoLogSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(36)
        }
        .sheet(isPresented: $showRecap) {
            DayRecapSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(36)
        }
        .sheet(isPresented: $app.shouldShowPaywall) {
            PaywallView(reason: app.paywallReason)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
        }
    }
}
