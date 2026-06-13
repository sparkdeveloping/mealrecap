import SwiftUI

struct MealCard: View {
    let meal: MealEntry
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(meal.mealType.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MRColor.accent)
                    Text(meal.title)
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(meal.calories)")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(MRColor.text)
            }

            VStack(spacing: 8) {
                ForEach(meal.items) { item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.mrBody)
                            .foregroundStyle(MRColor.text)
                            .lineLimit(1)
                        Spacer()
                        if let grams = item.estimatedGrams {
                            Text("\(Int(grams))g")
                                .font(.mrSmall)
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Text("\(item.calories)")
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.text)
                    }
                }
            }

            HStack(spacing: 10) {
                MacroBadge(label: "P", value: meal.macros.protein)
                MacroBadge(label: "C", value: meal.macros.carbs)
                MacroBadge(label: "F", value: meal.macros.fat)
                Spacer()
                Text("\(Int(meal.confidence * 100))% confidence")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MRColor.secondaryText)
            }
        }
        .padding(18)
        .premiumCard()
        .contextMenu {
            Button(role: .destructive) {
                Task { await app.deleteMeal(meal) }
            } label: {
                Label("Delete meal", systemImage: "trash")
            }
        }
    }
}

struct MacroBadge: View {
    let label: String
    let value: Double

    var body: some View {
        Text("\(label) \(Int(value))g")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MRColor.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(MRColor.background.opacity(0.8))
            .clipShape(Capsule())
    }
}
