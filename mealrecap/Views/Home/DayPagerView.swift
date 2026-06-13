import SwiftUI

struct DayPagerView: View {
    @EnvironmentObject private var app: AppModel

    private var days: [Date] {
        (-30...30).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))
        }
    }

    var body: some View {
        TabView(selection: $app.selectedDate) {
            ForEach(days, id: \.self) { date in
                DayView(date: date)
                    .tag(date)
                    .transition(.asymmetric(insertion: .scale(scale: 0.985).combined(with: .opacity), removal: .scale(scale: 1.015).combined(with: .opacity)))
                    .task(id: date) {
                        if Calendar.current.isDate(date, inSameDayAs: app.selectedDate) {
                            await app.loadDate(date)
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .animation(.interpolatingSpring(stiffness: 220, damping: 25), value: app.selectedDate)
        .onChange(of: app.selectedDate) { _, newValue in
            Task { await app.loadDate(newValue) }
        }
    }
}
