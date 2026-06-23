import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("mealrecap.pendingFirstName.v1") private var firstName = ""

    @State private var path: GoalSetupPath?
    @State private var step = 0
    @State private var goal = "2200"
    @State private var goalMode = "maintain"
    @State private var proteinTarget = "140"
    @State private var age = "29"
    @State private var bodyProfile = "prefer_not"
    @State private var heightFeet = "5"
    @State private var heightInches = "10"
    @State private var weightPounds = "170"
    @State private var activityLevel = "moderate"
    @State private var trainingDays = "3"
    @State private var pace = "balanced"
    @State private var recommendation: GoalRecommendation?
    @State private var recommendationError: String?
    @State private var isCalculating = false
    @State private var isRequestingHealth = false
    @State private var isRequestingNotifications = false
    @State private var isFinishing = false

    var body: some View {
        ZStack {
            AmbientBackground()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer(minLength: proxy.safeAreaInsets.top + 44)

                        header

                        contentCard
                            .padding(.horizontal, 24)

                        footerControls
                            .padding(.horizontal, 24)

                        Spacer(minLength: proxy.safeAreaInsets.bottom + 28)
                    }
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }

    private var header: some View {
        VStack(spacing: 10) {
            MealRecapBrandLockup(compact: false, markSize: 52)
                .scaleEffect(1.04)

            Text(stepTitle)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.80)

            Text(stepSubtitle)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch path {
            case nil:
                setupChoice
            case .manual:
                manualContent
            case .guided:
                guidedContent
            }
        }
        .padding(22)
        .glassRounded(cornerRadius: 30, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.64, shadowOpacity: 0.07)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: step)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: path)
    }

    private var setupChoice: some View {
        VStack(alignment: .leading, spacing: 14) {
            GoalSetupChoiceCard(
                icon: "sparkles",
                title: "Help me choose",
                subtitle: "Answer a few quick questions and get a smart starting point.",
                tint: MRColor.accentDeep
            ) {
                choosePath(.guided)
            }

            GoalSetupChoiceCard(
                icon: "slider.horizontal.3",
                title: "I know my goals",
                subtitle: "Enter your calorie and protein targets manually.",
                tint: MRColor.gold
            ) {
                choosePath(.manual)
            }

            Text("This is general wellness guidance, not medical advice. You can adjust targets anytime.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private var manualContent: some View {
        if step == 1 {
            GoalModePicker(selection: $goalMode)
            GoalNumberCard(title: "Daily calories", value: $goal, unit: "cal", range: 900...6000, step: 50)
            assistButton
        } else if step == 2 {
            GoalNumberCard(title: "Daily protein", value: $proteinTarget, unit: "g", range: 40...300, step: 5)
            Text("This powers the protein ring on Home. Start simple and adjust as you learn your day.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.secondaryText)
            assistButton
        } else {
            optionalConnections
        }
    }

    @ViewBuilder
    private var guidedContent: some View {
        switch step {
        case 1:
            OptionGrid(title: "What are you aiming for?", selection: $goalMode, options: [
                GoalOption(id: "maintain", title: "Maintain", subtitle: "Keep your day steady", icon: "equal.circle"),
                GoalOption(id: "lose_fat", title: "Lose fat", subtitle: "A gentle deficit", icon: "arrow.down.circle"),
                GoalOption(id: "build_muscle", title: "Build muscle", subtitle: "Fuel training", icon: "figure.strengthtraining.traditional"),
                GoalOption(id: "improve_protein", title: "Improve protein", subtitle: "Prioritize protein", icon: "bolt.heart"),
                GoalOption(id: "track", title: "Just track", subtitle: "No strong target", icon: "list.bullet.clipboard")
            ])
        case 2:
            VStack(alignment: .leading, spacing: 14) {
                OnboardingField(title: "Age", placeholder: "Age", text: $age, keyboard: .numberPad)
                BodyProfilePicker(selection: $bodyProfile)
                HStack(spacing: 12) {
                    OnboardingField(title: "Height ft", placeholder: "ft", text: $heightFeet, keyboard: .numberPad)
                    OnboardingField(title: "Height in", placeholder: "in", text: $heightInches, keyboard: .numberPad)
                }
                OnboardingField(title: "Weight", placeholder: "lb", text: $weightPounds, keyboard: .decimalPad)
                Text("MealRecap uses these only to estimate a practical starting target.")
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
            }
        case 3:
            VStack(alignment: .leading, spacing: 16) {
                OptionGrid(title: "Activity", selection: $activityLevel, options: [
                    GoalOption(id: "sedentary", title: "Mostly sitting", subtitle: "Desk-heavy days", icon: "chair"),
                    GoalOption(id: "light", title: "Lightly active", subtitle: "Some walking", icon: "figure.walk"),
                    GoalOption(id: "moderate", title: "Moderately active", subtitle: "Regular movement", icon: "figure.run"),
                    GoalOption(id: "very_active", title: "Very active", subtitle: "Active work or sport", icon: "flame")
                ])
                OptionGrid(title: "Training", selection: $trainingDays, options: [
                    GoalOption(id: "1", title: "0-1 days", subtitle: "Light training", icon: "1.circle"),
                    GoalOption(id: "3", title: "2-3 days", subtitle: "Consistent", icon: "3.circle"),
                    GoalOption(id: "5", title: "4-5 days", subtitle: "Frequent", icon: "5.circle"),
                    GoalOption(id: "6", title: "6+ days", subtitle: "High routine", icon: "6.circle")
                ])
                if showsPace {
                    OptionGrid(title: "Pace", selection: $pace, options: [
                        GoalOption(id: "gentle", title: "Gentle", subtitle: "Easier start", icon: "leaf"),
                        GoalOption(id: "balanced", title: "Balanced", subtitle: "Middle path", icon: "target"),
                        GoalOption(id: "faster", title: "Faster", subtitle: "More assertive", icon: "bolt")
                    ])
                }
            }
        default:
            recommendationContent
        }
    }

    @ViewBuilder
    private var recommendationContent: some View {
        if isCalculating {
            CalculatingGoalsView()
                .frame(maxWidth: .infinity)
        } else if let recommendation {
            RecommendationResultCard(recommendation: recommendation)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MRColor.accentDeep)
                    .frame(width: 48, height: 48)
                    .glassCircle(tint: MRColor.accentSoft.opacity(0.28), strokeOpacity: 0.34, shadowOpacity: 0.02)
                Text("Couldn’t calculate right now.")
                    .font(.mrHeadline)
                    .foregroundStyle(MRColor.text)
                Text(recommendationError ?? "You can try again or enter your targets manually.")
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineSpacing(4)
                HStack(spacing: 10) {
                    Button("Try again") { Task { await calculateRecommendation() } }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                    Button("Enter manually") { startManualFromRecommendation() }
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                }
            }
        }
    }

    private var optionalConnections: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect Apple Health")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            Text("MealRecap can read active energy and related fitness data from Apple Health to help estimate calories out and net calories. This is optional.")
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(4)
            Text("Health data is used only for your MealRecap insights and is not used for advertising.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.tertiaryText)
                .lineSpacing(3)
            Button {
                Task { await requestHealth() }
            } label: {
                Label(isRequestingHealth ? "Opening Apple Health..." : "Connect Apple Health", systemImage: "heart.text.square.fill")
                    .font(.mrBody.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(isRequestingHealth || isFinishing)

            Button("Not now") { finish() }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                .disabled(isFinishing)

            Divider().opacity(0.35)

            Text("Milestone notifications")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            Text("MealRecap can celebrate goal milestones and learn your usual meal times for gentle reminders. This is optional and never blocks the app.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(3)
            Button {
                Task { await requestNotifications() }
            } label: {
                Label(isRequestingNotifications ? "Opening..." : "Enable smart reminders", systemImage: "bell.badge")
                    .font(.mrBody.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
            .disabled(isRequestingNotifications || isFinishing)
        }
    }

    private var assistButton: some View {
        Button {
            choosePath(.guided)
        } label: {
            Label("Help me choose", systemImage: "sparkles")
                .font(.mrBody.weight(.bold))
                .foregroundStyle(MRColor.accentDeep)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(OnboardingSecondaryButtonStyle())
        .contentShape(Capsule())
        .accessibilityLabel("Help me choose goals")
    }

    @ViewBuilder
    private var footerControls: some View {
        if path == nil {
            EmptyView()
        } else if path == .guided && step == 4 {
            VStack(spacing: 10) {
                if recommendation != nil {
                    Button("Use these targets") { useRecommendation() }
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                        .disabled(isFinishing)
                    HStack(spacing: 10) {
                        Button("Adjust manually") { startManualFromRecommendation() }
                            .buttonStyle(OnboardingSecondaryButtonStyle())
                        Button("Recalculate") { Task { await calculateRecommendation() } }
                            .buttonStyle(OnboardingSecondaryButtonStyle())
                            .disabled(isCalculating)
                    }
                }
                Button("Back") { back() }
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
        } else {
            HStack(spacing: 12) {
                Button(step <= 1 ? "Back" : "Back") { back() }
                    .buttonStyle(OnboardingSecondaryButtonStyle())

                Button(primaryTitle) { advance() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .disabled(isPrimaryDisabled)
            }

            if path == .manual && step < 3 {
                Button("Skip setup") { finish() }
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .disabled(isFinishing)
            }
        }
    }

    private var stepTitle: String {
        guard let path else { return "Set your daily targets" }
        if path == .manual {
            switch step {
            case 1: return "Daily calorie goal"
            case 2: return "Daily protein goal"
            default: return "Optional connections"
            }
        }
        switch step {
        case 1: return "Let’s build your day"
        case 2: return "A few basics"
        case 3: return "Your routine"
        default: return recommendation == nil && !isCalculating ? "Almost there" : "Your starting targets"
        }
    }

    private var stepSubtitle: String {
        guard let path else {
            return "MealRecap can suggest a calorie and protein target, or you can enter your own."
        }
        if path == .manual {
            switch step {
            case 1: return "Enter a starting calorie target. You can adjust it anytime."
            case 2: return "Pick a protein target that feels realistic for your day."
            default: return "Health and notifications can make MealRecap smarter. You can skip both."
            }
        }
        switch step {
        case 1: return "Choose the direction that best fits this season. No pressure, no judgement."
        case 2: return "These details help estimate a practical starting point."
        case 3: return "Your movement and training shape the estimate."
        default: return "MealRecap estimates based on your answers. You can adjust anytime."
        }
    }

    private var primaryTitle: String {
        if path == .guided && step == 3 { return "Calculate targets" }
        if path == .manual && step == 3 { return "Start logging" }
        return "Continue"
    }

    private var isPrimaryDisabled: Bool {
        isFinishing || isRequestingHealth || isCalculating || !currentStepIsValid
    }

    private var currentStepIsValid: Bool {
        guard let path else { return true }
        if path == .manual {
            if step == 1 { return resolvedGoal != nil }
            if step == 2 { return resolvedProtein != nil }
            return true
        }
        if step == 2 { return resolvedGuidedProfile != nil }
        return true
    }

    private var showsPace: Bool {
        goalMode == "lose_fat" || goalMode == "build_muscle"
    }

    private var resolvedGoal: Int? {
        let value = Int(goal.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let value, (900...6000).contains(value) else { return nil }
        return value
    }

    private var resolvedProtein: Int? {
        let value = Int(proteinTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let value, (40...300).contains(value) else { return nil }
        return value
    }

    private var resolvedGuidedProfile: GoalRecommendationProfile? {
        guard let ageValue = Int(age.trimmingCharacters(in: .whitespacesAndNewlines)), (13...100).contains(ageValue),
              let feet = Int(heightFeet.trimmingCharacters(in: .whitespacesAndNewlines)),
              let inches = Int(heightInches.trimmingCharacters(in: .whitespacesAndNewlines)),
              let pounds = Double(weightPounds.trimmingCharacters(in: .whitespacesAndNewlines)),
              pounds > 60, pounds < 700 else { return nil }
        let totalInches = max(36, feet * 12 + inches)
        let heightCm = Int((Double(totalInches) * 2.54).rounded())
        let weightKg = (pounds * 0.453592).rounded(toPlaces: 1)
        return GoalRecommendationProfile(
            age: ageValue,
            sex: bodyProfile,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            trainingDaysPerWeek: Int(trainingDays) ?? 3,
            goal: goalMode,
            pace: showsPace ? pace : nil
        )
    }

    private func choosePath(_ newPath: GoalSetupPath) {
        recommendationError = nil
        recommendation = nil
        path = newPath
        step = 1
    }

    private func advance() {
        guard let path else { return }
        if path == .manual {
            if step < 3 {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { step += 1 }
            } else {
                finish()
            }
            return
        }

        if step < 3 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { step += 1 }
        } else {
            step = 4
            Task { await calculateRecommendation() }
        }
    }

    private func back() {
        if step <= 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                path = nil
                step = 0
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) { step -= 1 }
        }
    }

    private func calculateRecommendation() async {
        guard let profile = resolvedGuidedProfile else {
            recommendationError = "Add your height and weight so MealRecap can estimate your target."
            recommendation = nil
            return
        }
        isCalculating = true
        recommendationError = nil
        do {
            let result = try await app.functions.recommendGoals(profile: profile)
            recommendation = result
            goal = "\(result.dailyCalories)"
            proteinTarget = "\(result.dailyProtein)"
        } catch {
            recommendation = nil
            recommendationError = "You can enter goals manually or try again."
        }
        isCalculating = false
    }

    private func useRecommendation() {
        guard let recommendation else { return }
        goal = "\(recommendation.dailyCalories)"
        proteinTarget = "\(recommendation.dailyProtein)"
        finish(goalSetupMode: "guided", recommendationSummary: recommendation.summary)
    }

    private func startManualFromRecommendation() {
        if let recommendation {
            goal = "\(recommendation.dailyCalories)"
            proteinTarget = "\(recommendation.dailyProtein)"
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            path = .manual
            step = 1
        }
    }

    private func requestHealth() async {
        guard !isRequestingHealth else { return }
        isRequestingHealth = true
        await app.requestHealthAccess()
        isRequestingHealth = false
        finish()
    }

    private func requestNotifications() async {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        await app.requestSmartRemindersFromOnboarding()
        isRequestingNotifications = false
    }

    private func finish(goalSetupMode overrideSetupMode: String? = nil, recommendationSummary: String? = nil) {
        guard !isFinishing else { return }
        isFinishing = true
        let calorieGoal = resolvedGoal ?? 2200
        let protein = resolvedProtein ?? Int(proteinTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        let displayName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let setupMode = overrideSetupMode ?? (path == .guided ? "guided" : "manual")
        Task {
            await app.completeOnboarding(
                displayName: displayName.isEmpty ? nil : displayName,
                goalCalories: calorieGoal,
                goalMode: goalMode,
                proteinTarget: protein,
                goalSetupMode: setupMode,
                goalRecommendationSummary: recommendationSummary
            )
            await MainActor.run {
                firstName = ""
                isFinishing = false
            }
        }
    }
}

private enum GoalSetupPath: Equatable {
    case manual
    case guided
}

private struct GoalOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

private struct GoalSetupChoiceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .glassCircle(tint: tint.opacity(0.10), strokeOpacity: 0.34, shadowOpacity: 0.03)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                    Text(subtitle)
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MRColor.tertiaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .glassRounded(cornerRadius: 26, tint: tint.opacity(0.055), strokeOpacity: 0.42, shadowOpacity: 0.04)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(title)
    }
}

private struct OptionGrid: View {
    let title: String
    @Binding var selection: String
    let options: [GoalOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2.4)
                .foregroundStyle(MRColor.tertiaryText)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(options) { option in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                            selection = option.id
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(selection == option.id ? .white : MRColor.accentDeep)
                            Text(option.title)
                                .font(.mrSmall.weight(.bold))
                                .foregroundStyle(selection == option.id ? .white : MRColor.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(option.subtitle)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(selection == option.id ? .white.opacity(0.82) : MRColor.secondaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
                        .background(selection == option.id ? MRColor.accentDeep : .white.opacity(0.40))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.50), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(PressablePolish())
                    .accessibilityLabel(option.title)
                }
            }
        }
    }
}

private struct BodyProfilePicker: View {
    @Binding var selection: String
    private let options = [("male", "Male"), ("female", "Female"), ("prefer_not", "Prefer not")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BODY PROFILE")
                .font(.mrMicro)
                .tracking(2.4)
                .foregroundStyle(MRColor.tertiaryText)
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { id, title in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selection = id }
                    } label: {
                        Text(title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .foregroundStyle(selection == id ? .white : MRColor.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(selection == id ? MRColor.accentDeep : .white.opacity(0.46))
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                }
            }
        }
    }
}

private struct RecommendationResultCard: View {
    let recommendation: GoalRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                TargetOrb(value: recommendation.dailyCalories, unit: "cal", progress: 0.78, color: MRColor.accentDeep)
                TargetOrb(value: recommendation.dailyProtein, unit: "g", progress: 0.64, color: MRColor.gold)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                Text(recommendation.goalLabel)
                    .font(.mrHeadline)
                    .foregroundStyle(MRColor.text)
                Text(recommendation.summary)
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            if let calorieLow = recommendation.calorieRangeLow,
               let calorieHigh = recommendation.calorieRangeHigh,
               let proteinLow = recommendation.proteinRangeLow,
               let proteinHigh = recommendation.proteinRangeHigh {
                Text("\(calorieLow)-\(calorieHigh) cal · \(proteinLow)-\(proteinHigh)g protein range")
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.accentDeep)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .glassCapsule(tint: MRColor.accentSoft.opacity(0.24), strokeOpacity: 0.28, shadowOpacity: 0.01)
            }

            ForEach(recommendation.reasoningBullets.prefix(2), id: \.self) { bullet in
                Label(bullet, systemImage: "checkmark.circle.fill")
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(3)
            }

            Text(recommendation.safetyNote ?? "This is a starting point. For medical conditions or specialized nutrition needs, ask a qualified professional.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.tertiaryText)
                .lineSpacing(3)
                .lineLimit(3)
        }
    }
}

private struct TargetOrb: View {
    let value: Int
    let unit: String
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(MRColor.cardDeep.opacity(0.34), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                AnimatedNumberText(value: value, font: .system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(unit.uppercased())
                    .font(.mrMicro)
                    .tracking(1.6)
                    .foregroundStyle(MRColor.tertiaryText)
            }
            .padding(8)
        }
        .frame(width: 118, height: 118)
        .padding(6)
        .glassCircle(tint: color.opacity(0.06), strokeOpacity: 0.36, shadowOpacity: 0.04)
    }
}

private struct CalculatingGoalsView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(MRColor.accentSoft.opacity(0.75), lineWidth: 8)
                    .frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(MRColor.accentDeep, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MRColor.accentDeep)
            }
            Text("Building your starting targets")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            Text("MealRecap is estimating calories and protein from your answers.")
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.vertical, 18)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct GoalModePicker: View {
    @Binding var selection: String
    private let options = [("lose_fat", "Lose"), ("maintain", "Maintain"), ("build_muscle", "Build")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BASIC GOAL")
                .font(.mrMicro)
                .tracking(2.4)
                .foregroundStyle(MRColor.tertiaryText)
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { value, title in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selection = value
                        }
                    } label: {
                        Text(title)
                            .font(.mrSmall.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(selection == value ? .white : MRColor.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(selection == value ? MRColor.accentDeep : .white.opacity(0.46))
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                }
            }
        }
    }
}

private struct GoalNumberCard: View {
    let title: String
    @Binding var value: String
    let unit: String
    let range: ClosedRange<Int>
    let step: Int

    private var numericValue: Int {
        get {
            let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? range.lowerBound
            return min(max(parsed, range.lowerBound), range.upperBound)
        }
        nonmutating set {
            value = "\(min(max(newValue, range.lowerBound), range.upperBound))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2.4)
                .foregroundStyle(MRColor.tertiaryText)

            HStack(spacing: 14) {
                stepButton(systemName: "minus") {
                    numericValue -= step
                }

                VStack(spacing: 0) {
                    TextField("", text: $value)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                        .contentTransition(.numericText())
                    Text(unit.uppercased())
                        .font(.mrMicro)
                        .tracking(2.0)
                        .foregroundStyle(MRColor.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .glassRounded(cornerRadius: 26, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.36, shadowOpacity: 0.02)

                stepButton(systemName: "plus") {
                    numericValue += step
                }
            }
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MRColor.text)
                .frame(width: 48, height: 48)
                .glassCircle(strokeOpacity: 0.46, shadowOpacity: 0.04)
                .contentShape(Circle())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(systemName == "plus" ? "Increase \(title)" : "Decrease \(title)")
    }
}

private struct OnboardingField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2.4)
                .foregroundStyle(MRColor.tertiaryText)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(.white.opacity(0.52))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mrBody.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(MRColor.accentDeep.opacity(configuration.isPressed ? 0.86 : 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mrBody.weight(.bold))
            .foregroundStyle(MRColor.text)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
