import SwiftUI

struct CalendarSheet: View {
    @EnvironmentObject private var app: AppModel
    @Binding var selectedDate: Date
    let onSelect: (Date) -> Void

    @State private var visibleMonth: Date
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    init(selectedDate: Binding<Date>, onSelect: @escaping (Date) -> Void) {
        _selectedDate = selectedDate
        self.onSelect = onSelect
        _visibleMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
    }

    private var displayedDates: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: visibleMonth) ?? 1..<31
        let weekdayOffset = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        let leading = (weekdayOffset + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        return Array(repeating: nil, count: leading) + days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(MRColor.line)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar")
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                }
                Spacer()
                HStack(spacing: 8) {
                    monthButton("chevron.left") { moveMonth(-1) }
                    monthButton("chevron.right") { moveMonth(1) }
                }
            }

            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.prefix(1).uppercased())
                        .font(.mrMicro)
                        .tracking(1.2)
                        .foregroundStyle(MRColor.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(displayedDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarRingDay(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            progress: completion(for: date)
                        ) {
                            selectedDate = date
                            onSelect(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: visibleMonth)

            HStack(spacing: 10) {
                RingLegend(progress: 0, title: "No data")
                RingLegend(progress: 0.55, title: "Partial")
                RingLegend(progress: 1, title: "Goal met")
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(
            AmbientBackground()
        )
        .onAppear { visibleMonth = selectedDate }
    }

    private func monthButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MRColor.text)
                .frame(width: 38, height: 38)
                .glassCircle(strokeOpacity: 0.54, shadowOpacity: 0.04)
                .contentShape(Circle())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(systemName == "chevron.left" ? "Previous month" : "Next month")
    }

    private func moveMonth(_ delta: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) ?? visibleMonth
    }

    private func completion(for date: Date) -> Double {
        guard calendar.isDate(date, inSameDayAs: app.selectedDate) else { return 0 }
        let goal = max(app.activeDay?.goalCalories ?? 2200, 1)
        let calories = app.activeDay?.caloriesIn ?? app.meals.reduce(0) { $0 + $1.calories }
        return min(Double(calories) / Double(goal), 1)
    }
}

private struct CalendarRingDay: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let progress: Double
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(MRColor.cardDeep.opacity(0.42), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(progress > 0 ? MRColor.accentDeep : MRColor.cardDeep.opacity(0.42), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: progress)
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : MRColor.text)
                    .contentTransition(.numericText())
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .glassCircle(
                tint: isSelected ? MRColor.accentDeep.opacity(0.55) : (isToday ? MRColor.accentSoft.opacity(0.28) : nil),
                strokeOpacity: isToday || isSelected ? 0.48 : 0.18,
                shadowOpacity: isSelected ? 0.04 : 0.0
            )
            .contentShape(Circle())
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityValue(progress > 0 ? "\(Int((progress * 100).rounded())) percent of calorie goal" : "No logged calories")
        }
        .buttonStyle(PressablePolish())
    }
}

private struct RingLegend: View {
    let progress: Double
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(MRColor.cardDeep.opacity(0.38), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(progress > 0 ? MRColor.accentDeep.opacity(0.8) : MRColor.cardDeep.opacity(0.38), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
