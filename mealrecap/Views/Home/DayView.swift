import SwiftUI

struct DayView: View {
    @EnvironmentObject private var app: AppModel
    let date: Date
    @State private var message = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DayHeader(date: date, day: app.activeDay, usage: app.usage, entitlement: app.entitlement)

                    if app.meals.isEmpty {
                        EmptyMealState()
                    } else {
                        MealsSection(meals: app.meals)
                    }

                    ConversationSection(messages: app.messages)
                        .padding(.bottom, 90)
                }
                .padding(.horizontal, MRSpace.page)
                .padding(.top, 16)
            }
            .safeAreaInset(edge: .bottom) {
                ChatComposer(text: $message) {
                    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    message = ""
                    Task { await app.logText(trimmed) }
                }
                .padding(.horizontal, MRSpace.page)
                .padding(.bottom, 4)
                .background(MRColor.background.opacity(0.96))
            }
        }
        .task {
            if Calendar.current.isDate(date, inSameDayAs: Date()) {
                await app.refreshHealth()
            }
        }
    }
}

struct DayHeader: View {
    let date: Date
    let day: MealDay?
    let usage: SmartActionUsage
    let entitlement: ProEntitlement

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.mrTitle)
                        .foregroundStyle(MRColor.text)
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                }
                Spacer()
                Text(entitlement.isPro ? "PRO" : "FREE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(entitlement.isPro ? .white : MRColor.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(entitlement.isPro ? MRColor.accent : MRColor.cardDeep)
                    .clipShape(Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(day?.caloriesIn ?? 0)")
                    .font(.mrHero)
                    .foregroundStyle(MRColor.text)
                Text("kcal in")
                    .font(.mrHeadline)
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                StatPill(title: "Out", value: "\(day?.totalCaloriesOut ?? 0)")
                StatPill(title: "Net", value: "\(day?.netCalories ?? 0)")
                StatPill(title: "Goal", value: "\(day?.goalCalories ?? 2200)")
            }

            if !entitlement.isPro {
                Text("Smart Actions: \(remainingText)")
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
            }
        }
        .padding(22)
        .premiumCard()
    }

    private var title: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var remainingText: String {
        if usage.isInOnboardingWindow {
            return "\(max(0, 12 - usage.onboardingUsed)) left in your intro week"
        }
        return "\(max(0, 6 - usage.weeklyUsed)) left this week"
    }
}

struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(MRColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(MRColor.background.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
