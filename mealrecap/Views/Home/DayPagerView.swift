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
                    .task(id: date) {
                        if Calendar.current.isDate(date, inSameDayAs: app.selectedDate) {
                            await app.loadDate(date)
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: app.selectedDate) { _, newValue in
            Task { await app.loadDate(newValue) }
        }
    }
}
