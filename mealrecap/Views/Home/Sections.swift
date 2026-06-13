import SwiftUI

struct MealsSection: View {
    let meals: [MealEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meals")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            ForEach(meals) { meal in
                MealCard(meal: meal)
            }
        }
    }
}

struct ConversationSection: View {
    let messages: [DayMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !messages.isEmpty {
                Text("Thread")
                    .font(.mrHeadline)
                    .foregroundStyle(MRColor.text)
            }
            ForEach(messages) { message in
                MessageBubble(message: message)
            }
        }
    }
}

struct EmptyMealState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start with anything.")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            Text("Type a meal, hold the mic, snap your plate, or recap your whole day. MealRecap will organize it into clean calories.")
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .premiumCard()
    }
}
