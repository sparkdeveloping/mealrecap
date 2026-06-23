import SwiftUI

struct ReviewMealView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let pending: PendingMealReview
    var onAdded: (() -> Void)? = nil
    var onTryAgain: (() -> Void)? = nil

    @State private var portion = 1.0
    @State private var isAdding = false

    private var scaled: MealAnalysisResult { pending.result.scaled(by: portion) }
    private var displayItems: [FoodItem] {
        let filtered = scaled.items.filter { $0.hasDisplayableIngredientName }
        if filtered.isEmpty, scaled.items.count == 1, scaled.items.first?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "food item" {
            return scaled.items
        }
        return filtered
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Review meal")
                            .font(.mrTitle)
                            .foregroundStyle(MRColor.text)
                        Text(pending.source.subtitle)
                            .font(.mrBody)
                            .foregroundStyle(MRColor.secondaryText)
                    }

                    mealSummary
                    portionSelector
                    if !displayItems.isEmpty { ingredientsCard }
                    if let details = scaled.nutritionDetails, details.hasAdvancedNutrients {
                        ReviewNutritionDetailsCard(details: details)
                    }
                    actions
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
                .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
            }
            .background(AmbientBackground())
        }
        .interactiveDismissDisabled(isAdding)
    }

    private var mealSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(scaled.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(MRColor.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                Text(summarySubtitle)
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(2)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(scaled.totalCalories)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(MRColor.text)
                Text("cal")
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(MRColor.secondaryText)
                Spacer(minLength: 0)
            }

            HStack(spacing: 9) {
                MacroChip(label: "P", value: scaled.macros.protein)
                MacroChip(label: "C", value: scaled.macros.carbs)
                MacroChip(label: "F", value: scaled.macros.fat)
            }
        }
        .padding(18)
        .glassRounded(cornerRadius: 28, tint: MRColor.backgroundTop.opacity(0.09), strokeOpacity: 0.56, shadowOpacity: 0.06)
    }

    private var portionSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How much did you eat?")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            HStack(spacing: 8) {
                portionButton("1/4", 0.25)
                portionButton("1/2", 0.5)
                portionButton("3/4", 0.75)
                portionButton("All", 1)
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            ForEach(displayItems) { item in
                ReviewIngredientRow(item: item)
                if item.id != displayItems.last?.id { Divider().background(MRColor.line.opacity(0.35)) }
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await addMeal() }
            } label: {
                HStack {
                    if isAdding { ProgressView().tint(.white) }
                    Text(isAdding ? "Adding..." : "Add to today")
                }
                .font(.mrBody.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .glassCapsule(tint: MRColor.accentDeep.opacity(isAdding ? 0.30 : 0.62), strokeOpacity: 0.42, shadowOpacity: 0.08)
                .contentShape(Capsule())
            }
            .buttonStyle(PressablePolish())
            .disabled(isAdding)

            HStack(spacing: 10) {
                secondaryAction("Edit") { dismiss() }
                secondaryAction("Try again") { onTryAgain?(); dismiss() }
                secondaryAction("Cancel") { dismiss() }
            }
        }
    }

    private var summarySubtitle: String {
        if let category = scaled.foodCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            return "\(category) · \(scaled.mealType.title)"
        }
        return scaled.mealType.title
    }

    private func portionButton(_ title: String, _ value: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) { portion = value }
        } label: {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(portion == value ? .white : MRColor.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(portion == value ? MRColor.accentDeep : MRColor.card.opacity(0.46))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.48), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
    }

    private func secondaryAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .glassCapsule(tint: MRColor.backgroundTop.opacity(0.06), strokeOpacity: 0.30, shadowOpacity: 0.01)
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .disabled(isAdding)
    }

    private func addMeal() async {
        isAdding = true
        let didAdd = await app.addReviewedMeal(pending, portionFactor: portion)
        await MainActor.run {
            isAdding = false
            if didAdd {
                onAdded?()
                dismiss()
            }
        }
    }
}

struct ReviewDayView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let pending: PendingDayReview
    var onAdded: (() -> Void)? = nil

    @State private var selections: [String: Bool] = [:]
    @State private var portions: [String: Double] = [:]
    @State private var isAdding = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Review day")
                            .font(.mrTitle)
                            .foregroundStyle(MRColor.text)
                        Text("Choose the meals to add and adjust portions before saving.")
                            .font(.mrBody)
                            .foregroundStyle(MRColor.secondaryText)
                    }

                    ForEach(pending.meals) { meal in
                        dayMealCard(meal)
                    }

                    Button {
                        Task { await addSelected() }
                    } label: {
                        HStack {
                            if isAdding { ProgressView().tint(.white) }
                            Text(isAdding ? "Adding..." : "Add selected meals")
                        }
                        .font(.mrBody.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .glassCapsule(tint: MRColor.accentDeep.opacity(isAdding ? 0.30 : 0.62), strokeOpacity: 0.42, shadowOpacity: 0.08)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressablePolish())
                    .disabled(isAdding || selectedCount == 0)

                    Button("Cancel") { dismiss() }
                        .font(.mrSmall.weight(.bold))
                        .foregroundStyle(MRColor.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .contentShape(Rectangle())
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
                .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
            }
            .background(AmbientBackground())
        }
        .interactiveDismissDisabled(isAdding)
        .onAppear {
            for meal in pending.meals {
                selections[meal.id] = selections[meal.id, default: true]
                portions[meal.id] = portions[meal.id, default: 1]
            }
        }
    }

    private var selectedCount: Int {
        pending.meals.filter { selections[$0.id, default: true] }.count
    }

    private func dayMealCard(_ meal: PendingMealReview) -> some View {
        let factor = portions[meal.id, default: 1]
        let scaled = meal.result.scaled(by: factor)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    selections[meal.id] = !selections[meal.id, default: true]
                } label: {
                    Image(systemName: selections[meal.id, default: true] ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selections[meal.id, default: true] ? MRColor.accentDeep : MRColor.tertiaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    Text(scaled.title)
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                        .lineLimit(2)
                    Text("\(scaled.mealType.title) · \(scaled.totalCalories) cal")
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                    HStack(spacing: 8) {
                        MacroChip(label: "P", value: scaled.macros.protein)
                        MacroChip(label: "C", value: scaled.macros.carbs)
                        MacroChip(label: "F", value: scaled.macros.fat)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                dayPortionButton("1/4", 0.25, meal.id)
                dayPortionButton("1/2", 0.5, meal.id)
                dayPortionButton("3/4", 0.75, meal.id)
                dayPortionButton("All", 1, meal.id)
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.42, shadowOpacity: 0.03)
    }

    private func dayPortionButton(_ title: String, _ value: Double, _ id: String) -> some View {
        Button {
            portions[id] = value
        } label: {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(portions[id, default: 1] == value ? .white : MRColor.text)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(portions[id, default: 1] == value ? MRColor.accentDeep : MRColor.card.opacity(0.46))
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
    }

    private func addSelected() async {
        isAdding = true
        let didAdd = await app.addReviewedDay(pending, selections: selections, portions: portions)
        await MainActor.run {
            isAdding = false
            if didAdd {
                onAdded?()
                dismiss()
            }
        }
    }
}

private struct ReviewIngredientRow: View {
    let item: FoodItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.mrBody.weight(.semibold))
                    .foregroundStyle(MRColor.text)
                    .lineLimit(2)
                if let serving = item.servingDescription, !serving.isEmpty {
                    Text(serving)
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(2)
                }
                if let macroText = item.macroSummaryText {
                    Text(macroText)
                        .font(.mrMicro)
                        .tracking(1.1)
                        .foregroundStyle(MRColor.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(item.calories) cal")
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 62, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

private struct ReviewNutritionDetailsCard: View {
    let details: NutritionDetails
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More nutrition")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(NutritionDisplay.rows(for: details), id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(row.1)
                            .font(.mrSmall.weight(.bold))
                            .foregroundStyle(MRColor.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 38)
                    .background(.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }
}
