import SwiftUI

struct MinimalTopBar: View {
    let entitlement: ProEntitlement
    let onUpgrade: () -> Void
    let onCalendar: () -> Void
    let onProfile: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            topBar(compact: false)
            topBar(compact: true)
        }
    }

    private func topBar(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            MealRecapWordmark(compact: compact)
            .layoutPriority(1)

            Spacer(minLength: compact ? 6 : 10)

            Button(action: onUpgrade) {
                if compact && !entitlement.isPro {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MRColor.accentDeep)
                        .frame(width: 34, height: 30)
                } else {
                    Text(entitlement.isPro ? "PRO" : "Upgrade")
                        .font(.mrMicro)
                        .tracking(0.8)
                        .foregroundStyle(entitlement.isPro ? .white : MRColor.accentDeep)
                        .padding(.horizontal, compact ? 9 : 11)
                        .frame(height: compact ? 30 : 32)
                }
            }
            .glassCapsule(
                tint: entitlement.isPro ? MRColor.accentDeep.opacity(0.35) : MRColor.accentSoft.opacity(0.42),
                strokeOpacity: 0.62,
                shadowOpacity: 0.05
            )
            .contentShape(Capsule())
            .buttonStyle(PressablePolish())
            .accessibilityLabel(entitlement.isPro ? "Pro active" : "Upgrade to Pro")

            GlassCircleButton(systemName: "calendar", size: compact ? 40 : 44, action: onCalendar)
            GlassCircleButton(systemName: "person.crop.circle", size: compact ? 40 : 44, action: onProfile)
        }
        .frame(maxWidth: .infinity)
    }
}


struct CleanDayHero: View {
    let date: Date
    let day: MealDay?
    let meals: [MealEntry]
    let messages: [DayMessage]
    let usage: SmartActionUsage
    let entitlement: ProEntitlement
    let proteinTarget: Int?
    let onUpgrade: () -> Void
    let onConnectHealth: () -> Void

    private var caloriesIn: Int { day?.caloriesIn ?? meals.reduce(0) { $0 + $1.calories } }
    private var goal: Int { max(day?.goalCalories ?? 2200, 1) }
    private var caloriesOut: Int { day?.totalCaloriesOut ?? 0 }
    private var remaining: Int { max(goal - caloriesIn, 0) }
    private var progress: Double { min(Double(caloriesIn) / Double(goal), 1.15) }
    private var macroTotals: MacroSummary {
        meals.reduce(.empty) { total, meal in
            MacroSummary(protein: total.protein + meal.macros.protein, carbs: total.carbs + meal.macros.carbs, fat: total.fat + meal.macros.fat)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                        .font(.mrMicro)
                        .tracking(3.5)
                        .foregroundStyle(MRColor.tertiaryText)
                    Text(dayTitle)
                        .font(.system(size: 35, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                AnimatedNumberText(
                    value: Int((Double(caloriesIn) / Double(goal) * 100).rounded()),
                    format: { "\($0)%" },
                    font: .mrSmall.weight(.bold),
                    color: MRColor.secondaryText
                )
                .padding(.horizontal, 11)
                .frame(height: 32)
                .glassCapsule(strokeOpacity: 0.44, shadowOpacity: 0.03, interactive: false)
            }

            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    AnimatedNumberText(value: caloriesIn, font: .system(size: 54, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("of \(goal.formatted()) cal")
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let proteinTarget, proteinTarget > 0 {
                    GoalLens(
                        calorieProgress: min(Double(caloriesIn) / Double(goal), 1),
                        proteinProgress: min(macroTotals.protein / Double(proteinTarget), 1)
                    )
                    .accessibilityLabel("Calories \(Int(progress * 100)) percent, protein \(Int((macroTotals.protein / Double(proteinTarget) * 100).rounded())) percent")
                }
            }

            CapsuleMeter(progress: progress, isOver: caloriesIn > goal)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HeroMacro(value: Int(macroTotals.protein.rounded()), label: "protein")
                HeroMacro(value: Int(macroTotals.carbs.rounded()), label: "carbs")
                HeroMacro(value: Int(macroTotals.fat.rounded()), label: "fat")
            }

            MetricGrid(
                caloriesIn: caloriesIn,
                caloriesOut: caloriesOut,
                remaining: remaining,
                net: day?.netCalories ?? caloriesIn,
                onConnectHealth: onConnectHealth
            )

            SmartActionsCard(entitlement: entitlement, actionsLeft: smartActionsLeft, onUpgrade: onUpgrade)
        }
    }

    private var smartActionsLeft: Int {
        if usage.isInOnboardingWindow { return max(0, 12 - usage.onboardingUsed) }
        return max(0, 6 - usage.weeklyUsed)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}

private struct CapsuleMeter: View {
    let progress: Double
    let isOver: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MRColor.cardDeep.opacity(0.42)).frame(height: 7)
                Capsule()
                    .fill(isOver ? MRColor.danger : MRColor.accentDeep)
                    .frame(width: max(14, geo.size.width * min(progress, 1.0)), height: 7)
                    .animation(.spring(response: 0.55, dampingFraction: 0.86), value: progress)
                if isOver {
                    Capsule().fill(MRColor.danger).frame(width: 24, height: 7).offset(x: max(0, geo.size.width - 24))
                }
            }
        }
        .frame(height: 7)
    }
}

private struct GoalLens: View {
    let calorieProgress: Double
    let proteinProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(MRColor.cardDeep.opacity(0.34), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.02, calorieProgress))
                .stroke(MRColor.accentDeep, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .stroke(MRColor.cardDeep.opacity(0.24), lineWidth: 4)
                .frame(width: 38, height: 38)
            Circle()
                .trim(from: 0, to: max(0.02, proteinProgress))
                .stroke(MRColor.gold.opacity(0.92), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                Text("P")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundStyle(MRColor.secondaryText)
        }
        .frame(width: 54, height: 54)
        .padding(5)
        .glassCircle(tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.34, shadowOpacity: 0.03, interactive: false)
    }
}

private struct HeroMacro: View {
    let value: Int
    let label: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: label == "fat" ? 7 : 5) {
            AnimatedNumberText(value: value, font: .system(size: 15, weight: .bold, design: .rounded))
            Text(label.uppercased())
                .font(.mrMicro)
                .tracking(1.2)
                .foregroundStyle(MRColor.tertiaryText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.76)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricGrid: View {
    let caloriesIn: Int
    let caloriesOut: Int
    let remaining: Int
    let net: Int
    let onConnectHealth: () -> Void

    private let compactColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                cards(minWidth: 68)
            }
            LazyVGrid(columns: compactColumns, spacing: 8) {
                cards(minWidth: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cards(minWidth: CGFloat) -> some View {
        SmallStat(value: caloriesIn, label: "in", icon: "fork.knife")
            .frame(minWidth: minWidth, maxWidth: .infinity)
        SmallStat(value: caloriesOut, label: caloriesOut == 0 ? "Health" : "out", icon: caloriesOut == 0 ? "heart.text.square.fill" : "flame", action: caloriesOut == 0 ? onConnectHealth : nil)
            .frame(minWidth: minWidth, maxWidth: .infinity)
        SmallStat(value: remaining, label: "left", icon: "target")
            .frame(minWidth: minWidth, maxWidth: .infinity)
        SmallStat(value: net, label: "net", icon: "equal.circle")
            .frame(minWidth: minWidth, maxWidth: .infinity)
    }
}

private struct SmallStat: View {
    let value: Int
    let label: String
    var icon: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MRColor.accentDeep)
                AnimatedNumberText(value: value, font: .system(size: 21, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(action == nil ? MRColor.tertiaryText : MRColor.accentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(.white.opacity(action == nil ? 0.30 : 0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.50), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .disabled(action == nil)
        .accessibilityLabel("\(label), \(value)")
    }
}

private struct SmartActionsCard: View {
    let entitlement: ProEntitlement
    let actionsLeft: Int
    let onUpgrade: () -> Void

    var body: some View {
        Button(action: entitlement.isPro ? {} : onUpgrade) {
            ViewThatFits(in: .horizontal) {
                content(short: false)
                content(short: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .glassRounded(cornerRadius: 22, tint: MRColor.accentSoft.opacity(0.18), strokeOpacity: 0.52, shadowOpacity: 0.04)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .disabled(entitlement.isPro)
        .accessibilityLabel(entitlement.isPro ? "Unlimited smart logging" : "\(actionsLeft) smart actions left, upgrade")
    }

    private func content(short: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entitlement.isPro ? "sparkles" : "sparkle.magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MRColor.accentDeep)
                .frame(width: 34, height: 34)
                .background(MRColor.accentSoft.opacity(0.55))
                .clipShape(Circle())
            Text(entitlement.isPro ? "Unlimited smart logging" : (short ? "\(actionsLeft) smart actions left" : "Smart Actions: \(actionsLeft) left"))
                .font(.mrSmall.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            Spacer(minLength: 8)
            if !entitlement.isPro {
                Text("Upgrade")
                    .font(.mrSmall.weight(.bold))
                    .foregroundStyle(MRColor.accentDeep)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, short ? 10 : 12)
                    .padding(.vertical, 7)
                    .glassCapsule(tint: MRColor.accentSoft.opacity(0.34), strokeOpacity: 0.45, shadowOpacity: 0.02)
            }
        }
    }
}

struct CleanMealFeed: View {
    let meals: [MealEntry]
    let messages: [DayMessage]
    let day: MealDay?
    let namespace: Namespace.ID
    let onSelectMeal: (MealEntry) -> Void
    let onGenerateMissingImages: (() -> Void)?

    private var missingImageCount: Int {
        meals.filter { ($0.photoPath ?? "").isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Meals")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 12)
                    Text("\(meals.count) logged")
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meals")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                    Text("\(meals.count) logged")
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                }
            }

            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groupedSections) { section in
                    SmartMealHeader(section: section)
                        .padding(.top, section.id == groupedSections.first?.id ? 0 : 18)
                        .padding(.bottom, -2)

                    ForEach(section.meals) { meal in
                        MinimalMealRow(meal: meal, day: day, namespace: namespace, prompt: prompt(for: meal)) {
                            onSelectMeal(meal)
                        }
                        .matchedTransitionSource(id: meal.id, in: namespace)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                    }
                }
            }
        }
    }

    private var groupedSections: [MealTimeSection] {
        let groups = Dictionary(grouping: meals) { meal in
            MealTimeSection.Kind(date: meal.createdAt, type: meal.mealType)
        }
        return groups.map { kind, meals in
            MealTimeSection(kind: kind, meals: meals.sorted { $0.createdAt < $1.createdAt })
        }
        .sorted { $0.kind.sortOrder < $1.kind.sortOrder }
    }

    private func prompt(for meal: MealEntry) -> String? {
        if let prompt = meal.originPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty { return prompt }
        let userMessages = messages.filter { $0.role == "user" }
        let candidates = userMessages
            .map { ($0, abs($0.createdAt.timeIntervalSince(meal.createdAt))) }
            .filter { $0.1 < 900 }
            .sorted { $0.1 < $1.1 }
        return candidates.first?.0.content
    }
}

struct MealTimeSection: Identifiable, Equatable {
    enum Kind: String, Hashable {
        case early
        case morning
        case midday
        case afternoon
        case evening
        case late

        init(date: Date, type: MealType) {
            let hour = Calendar.current.component(.hour, from: date)
            if type == .breakfast || (5..<11).contains(hour) { self = .morning }
            else if type == .lunch || (11..<15).contains(hour) { self = .midday }
            else if (15..<18).contains(hour) { self = .afternoon }
            else if type == .dinner || (18..<22).contains(hour) { self = .evening }
            else if hour >= 22 || hour < 2 { self = .late }
            else { self = .early }
        }

        var title: String {
            switch self {
            case .early: "Early"
            case .morning: "Morning"
            case .midday: "Midday"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            case .late: "Late"
            }
        }

        var range: String {
            switch self {
            case .early: "2–5 AM"
            case .morning: "5–11 AM"
            case .midday: "11–3 PM"
            case .afternoon: "3–6 PM"
            case .evening: "6–10 PM"
            case .late: "10 PM+"
            }
        }

        var sortOrder: Int {
            switch self {
            case .early: 0
            case .morning: 1
            case .midday: 2
            case .afternoon: 3
            case .evening: 4
            case .late: 5
            }
        }
    }

    var id: String { kind.rawValue }
    let kind: Kind
    let meals: [MealEntry]
    var calories: Int { meals.reduce(0) { $0 + $1.calories } }
}

private struct SmartMealHeader: View {
    let section: MealTimeSection
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.kind.title.uppercased())
                    .font(.mrMicro)
                    .tracking(3.4)
                    .foregroundStyle(MRColor.accent)
                Text(section.kind.range)
                    .font(.mrMicro)
                    .tracking(1.8)
                    .foregroundStyle(MRColor.tertiaryText)
                Spacer(minLength: 8)
                Text("\(section.calories) cal")
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(section.kind.title.uppercased())
                        .font(.mrMicro)
                        .tracking(3.0)
                        .foregroundStyle(MRColor.accent)
                    Text(section.kind.range)
                        .font(.mrMicro)
                        .tracking(1.4)
                        .foregroundStyle(MRColor.tertiaryText)
                }
                Text("\(section.calories) cal")
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
            }
        }
    }
}

struct CleanEmptyPrompt: View {
    var onSelectPrompt: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MRColor.accentSoft.opacity(0.58))
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(MRColor.accentDeep)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("No meals today")
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                    Text("Log your first meal")
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.accentDeep)
                }
            }
            Text("Write it the way you’d text a friend. MealRecap will turn it into meals, calories, macros, and photos.")
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(4)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(starterPrompts, id: \.self) { prompt in
                    ExamplePrompt(text: prompt, onSelect: onSelectPrompt)
                }
            }
        }
        .padding(.top, 8)
        .padding(18)
        .background(.white.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.45), lineWidth: 1))
    }

    private var starterPrompts: [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        if (5..<11).contains(hour) {
            return [
                "Coffee with eggs and toast",
                "Greek yogurt, berries, and granola",
                "Cappuccino and an almond croissant"
            ]
        }
        if (11..<16).contains(hour) {
            return [
                "Chicken rice bowl with avocado",
                "Turkey sandwich, chips, and iced tea",
                "Two McDoubles and a Coke"
            ]
        }
        if (17..<22).contains(hour) {
            return [
                "Salmon, rice, and roasted vegetables",
                "Steak with potatoes and a side salad",
                "Pasta with chicken and a glass of wine"
            ]
        }
        return [
            "Today I had eggs, chicken rice, and ice cream",
            "Protein shake and a banana",
            "Late snack: cereal with milk"
        ]
    }
}

private struct ExamplePrompt: View {
    let text: String
    let onSelect: ((String) -> Void)?

    var body: some View {
        Button {
            onSelect?(text)
        } label: {
            Text(text)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassRounded(cornerRadius: 18, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.30, shadowOpacity: 0.015)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityLabel("Use suggestion \(text)")
    }
}

// Compatibility wrappers for older view names still referenced by other files.
typealias MinimalMealsSection = CleanMealFeed
typealias MinimalThreadSection = EmptyView
typealias EmptyMealState = CleanEmptyPrompt
