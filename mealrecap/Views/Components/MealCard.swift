import SwiftUI

struct MinimalMealRow: View {
    @EnvironmentObject private var app: AppModel
    let meal: MealEntry
    let day: MealDay?
    let namespace: Namespace.ID
    var prompt: String? = nil
    let onTap: () -> Void

    private var percentOfDay: Int {
        let total = max(day?.caloriesIn ?? meal.calories, 1)
        return Int((Double(meal.calories) / Double(total) * 100).rounded())
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if let prompt, !prompt.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MRColor.accentDeep)
                            .padding(.top, 2)
                        Text(prompt)
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(MRColor.accentSoft.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(alignment: .center, spacing: 12) {
                    MealVisual(meal: meal, size: 60, cornerRadius: 22) {
                        Task { await app.generateImage(for: meal) }
                    }
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(label.uppercased())
                                .font(.mrMicro)
                                .tracking(2.1)
                                .foregroundStyle(MRColor.accent)
                                .lineLimit(1)
                            Text(meal.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.mrMicro)
                                .tracking(1.5)
                                .foregroundStyle(MRColor.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .lineLimit(1)

                        Text(meal.title)
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                            .foregroundStyle(MRColor.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)

                        Text(subtitle)
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    VStack(alignment: .trailing, spacing: 4) {
                        AnimatedNumberText(value: meal.calories, font: .system(size: 30, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("cal")
                            .font(.mrMicro)
                            .tracking(1.5)
                            .foregroundStyle(MRColor.tertiaryText)
                        Text("\(percentOfDay)% day")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(width: 72, alignment: .trailing)
                    .layoutPriority(2)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    MacroChip(label: "P", value: meal.macros.protein)
                    MacroChip(label: "C", value: meal.macros.carbs)
                    MacroChip(label: "F", value: meal.macros.fat)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MRColor.tertiaryText)
                }
            }
            .padding(14)
            .background(.white.opacity(0.34))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.52), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressablePolish())
        .contextMenu {
            Button("Refresh photo") { Task { await app.generateImage(for: meal) } }
            Button("Delete", role: .destructive) { Task { await app.deleteMeal(meal) } }
        }
    }

    private var label: String {
        if let foodCategory = meal.foodCategory, !foodCategory.isEmpty { return foodCategory }
        return meal.mealType.title
    }

    private var subtitle: String {
        if let first = meal.items.first?.servingDescription, !first.isEmpty { return first }
        if let first = meal.items.first?.name { return first }
        return "\(Int(meal.confidence * 100))% confidence"
    }
}

struct MacroChip: View {
    let label: String
    let value: Double

    var body: some View {
        Text("\(label) \(Int(value.rounded()))g")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(MRColor.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.white.opacity(0.40))
            .clipShape(Capsule())
    }
}

struct MealCard: View {
    let meal: MealEntry
    let day: MealDay?
    @Namespace private var fallbackNamespace

    var body: some View {
        MinimalMealRow(meal: meal, day: day, namespace: fallbackNamespace) {}
    }
}

struct MealDetailFullScreen: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let meal: MealEntry
    let day: MealDay?
    let namespace: Namespace.ID

    @State private var title: String
    @State private var mealType: MealType
    @State private var foodCategory: String
    @State private var note: String
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    init(meal: MealEntry, day: MealDay?, namespace: Namespace.ID) {
        self.meal = meal
        self.day = day
        self.namespace = namespace
        _title = State(initialValue: meal.title)
        _mealType = State(initialValue: meal.mealType)
        _foodCategory = State(initialValue: meal.foodCategory ?? meal.mealType.title)
        _note = State(initialValue: meal.assistantNote ?? "")
    }

    private var hasChanges: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) != meal.title ||
        mealType != meal.mealType ||
        foodCategory.trimmingCharacters(in: .whitespacesAndNewlines) != (meal.foodCategory ?? meal.mealType.title) ||
        note.trimmingCharacters(in: .whitespacesAndNewlines) != (meal.assistantNote ?? "")
    }

    private var percentOfDay: Int {
        let total = max(day?.caloriesIn ?? meal.calories, 1)
        return Int((Double(meal.calories) / Double(total) * 100).rounded())
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = proxy.size.width
            let viewportHeight = proxy.size.height
            let horizontalPadding: CGFloat = 22
            let contentWidth = max(0, viewportWidth - horizontalPadding * 2)

            ZStack(alignment: .top) {
                AmbientBackground()
                    .frame(width: viewportWidth, height: viewportHeight)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection
                            .padding(.top, proxy.safeAreaInsets.top + 58)

                        macroSection

                        detailsSection

                        itemsSection

                        actionSection

                        Color.clear.frame(height: max(24, proxy.safeAreaInsets.bottom + 20))
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .frame(width: viewportWidth, alignment: .center)
                }
                .frame(width: viewportWidth)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollContent)

                topControls
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, proxy.safeAreaInsets.top + 10)
                    .frame(width: viewportWidth)
            }
            .frame(width: viewportWidth, height: viewportHeight)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTransition(.zoom(sourceID: meal.id, in: namespace))
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("Remove this meal?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove meal", role: .destructive) {
                Task { await app.deleteMeal(meal) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the meal from today and recalculates your totals.")
        }
    }

    private var heroSection: some View {
        VStack(alignment: .center, spacing: 13) {
            MealVisual(meal: meal, size: 164, cornerRadius: 38) {
                Task { await app.generateImage(for: meal) }
            }
            .matchedTransitionSource(id: meal.id, in: namespace)
            .padding(.bottom, 4)

            TextField("Meal title", text: $title, axis: .vertical)
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(1...3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.mrBody.weight(.medium))
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AnimatedNumberText(value: meal.calories, font: .system(size: 44, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("cal")
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(MRColor.secondaryText)
            }

            Text("\(percentOfDay)% of the day · \(meal.createdAt.formatted(date: .omitted, time: .shortened))")
                .font(.mrMicro)
                .tracking(1.6)
                .foregroundStyle(MRColor.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private var macroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Nutrition")
            VStack(spacing: 13) {
                MacroLine(title: "Protein", value: meal.macros.protein, max: 120)
                MacroLine(title: "Carbs", value: meal.macros.carbs, max: 320)
                MacroLine(title: "Fat", value: meal.macros.fat, max: 120)
            }
        }
        .padding(18)
        .background(.white.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.54), lineWidth: 1))
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Details")

            MealTypeChips(selection: $mealType)

            VStack(alignment: .leading, spacing: 7) {
                Text("LABEL")
                    .font(.mrMicro)
                    .tracking(2.0)
                    .foregroundStyle(MRColor.tertiaryText)
                TextField("Category", text: $foodCategory)
                    .font(.mrBody)
                    .foregroundStyle(MRColor.text)
                    .padding(14)
                    .glassRounded(cornerRadius: 18, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.36, shadowOpacity: 0.02)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NOTE")
                    .font(.mrMicro)
                    .tracking(2.0)
                    .foregroundStyle(MRColor.tertiaryText)
                TextEditor(text: $note)
                    .font(.mrBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86)
                    .padding(10)
                    .glassRounded(cornerRadius: 18, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.34, shadowOpacity: 0.02)
            }
        }
        .padding(18)
        .background(.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.50), lineWidth: 1))
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Items")
            ForEach(meal.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.mrBody.weight(.semibold))
                            .foregroundStyle(MRColor.text)
                            .lineLimit(2)
                        if let serving = item.servingDescription {
                            Text(serving)
                                .font(.mrSmall)
                                .foregroundStyle(MRColor.secondaryText)
                                .lineLimit(2)
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
                .padding(.vertical, 7)
                if item.id != meal.items.last?.id {
                    Divider().background(MRColor.line.opacity(0.35))
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.48), lineWidth: 1))
    }

    private var actionSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                detailAction("New photo", systemImage: "sparkles") {
                    Task { await app.generateImage(for: meal) }
                }
                detailAction("Remove", systemImage: "trash", tint: MRColor.danger) {
                    showDeleteConfirmation = true
                }
            }
            VStack(spacing: 10) {
                detailAction("New photo", systemImage: "sparkles") {
                    Task { await app.generateImage(for: meal) }
                }
                detailAction("Remove", systemImage: "trash", tint: MRColor.danger) {
                    showDeleteConfirmation = true
                }
            }
        }
    }

    private var topControls: some View {
        HStack {
            closeButton
            Spacer()
            if hasChanges {
                Button {
                    save()
                } label: {
                    Label(isSaving ? "Saving" : "Save", systemImage: isSaving ? "checkmark.circle" : "checkmark")
                        .font(.mrSmall.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 72, minHeight: 44)
                        .glassCapsule(tint: MRColor.accentDeep.opacity(0.58), strokeOpacity: 0.44, shadowOpacity: 0.08)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressablePolish())
                .disabled(isSaving)
                .accessibilityLabel(isSaving ? "Saving changes" : "Save changes")
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MRColor.text)
                .frame(width: 46, height: 46)
                .glassCircle(strokeOpacity: 0.74, shadowOpacity: 0.10)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close meal detail")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.mrHeadline)
            .foregroundStyle(MRColor.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailAction(_ title: String, systemImage: String, tint: Color = MRColor.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .glassCapsule(tint: tint.opacity(0.08), strokeOpacity: 0.42, shadowOpacity: 0.04)
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(title)
    }

    private var subtitle: String {
        if let category = meal.foodCategory, !category.isEmpty { return category }
        if let first = meal.items.first?.servingDescription, !first.isEmpty { return first }
        return meal.mealType.title
    }

    private func save() {
        guard !isSaving, hasChanges else { return }
        isSaving = true
        Task {
            await app.updateMeal(meal, title: title, mealType: mealType, foodCategory: foodCategory, assistantNote: note)
            await MainActor.run { isSaving = false; dismiss() }
        }
    }
}

private struct MacroLine: View {
    let title: String
    let value: Double
    let max: Double

    var body: some View {
        HStack(spacing: 14) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2)
                .foregroundStyle(MRColor.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 78, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MRColor.cardDeep.opacity(0.35)).frame(height: 6)
                    Capsule().fill(MRColor.secondaryText.opacity(0.72)).frame(width: geo.size.width * min(value / max, 1), height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: value)
                }
            }
            .frame(height: 6)
            Text("\(Int(value.rounded()))g")
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

private struct MealTypeChips: View {
    @Binding var selection: MealType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { selection = type }
                    } label: {
                        Text(type.title)
                            .font(.mrSmall.weight(.bold))
                            .lineLimit(1)
                            .foregroundStyle(selection == type ? .white : MRColor.text)
                            .padding(.horizontal, 15)
                            .frame(minHeight: 40)
                            .glassCapsule(
                                tint: selection == type ? MRColor.accentDeep.opacity(0.55) : MRColor.backgroundTop.opacity(0.08),
                                strokeOpacity: selection == type ? 0.42 : 0.34,
                                shadowOpacity: selection == type ? 0.06 : 0.025
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressablePolish())
                    .accessibilityLabel(type.title)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
        .scrollClipDisabled()
    }
}
