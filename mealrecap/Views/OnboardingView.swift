import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppModel

    @State private var name = ""
    @State private var goal = "2200"
    @State private var goalMode = "maintain"
    @State private var proteinTarget = ""
    @State private var step = 0
    @State private var isRequestingHealth = false
    @State private var isFinishing = false

    var body: some View {
        ZStack {
            MRColor.backgroundTop.ignoresSafeArea()
            AmbientBokehView().opacity(0.55)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 22)

                    VStack(spacing: 10) {
                        Text("MEAL\nRECAP")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .tracking(7)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(MRColor.text)

                        Text("Set a goal once. MealRecap will keep daily calories, macros, and Health balance organized from there.")
                            .font(.mrBody)
                            .foregroundStyle(MRColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 16)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        if step == 0 {
                            OnboardingField(title: "Your name", placeholder: "Tinashe", text: $name)
                            GoalModePicker(selection: $goalMode)
                        } else if step == 1 {
                            OnboardingField(title: "Daily calorie goal", placeholder: "2200", text: $goal, keyboard: .numberPad)
                            OnboardingField(title: "Protein target optional", placeholder: "140", text: $proteinTarget, keyboard: .numberPad)
                            Text("You can continue manually even if Health access is unavailable or declined.")
                                .font(.mrSmall)
                                .foregroundStyle(MRColor.secondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Connect Health")
                                    .font(.mrHeadline)
                                    .foregroundStyle(MRColor.text)
                                Text("Optional. MealRecap can read active and resting calories to show your daily balance. You can skip this now and connect later from the dashboard Health stat.")
                                    .font(.mrBody)
                                    .foregroundStyle(MRColor.secondaryText)
                                    .lineSpacing(4)
                                Button {
                                    Task { await requestHealth() }
                                } label: {
                                    Label(isRequestingHealth ? "Opening Health..." : "Allow Health access", systemImage: "heart.text.square.fill")
                                        .font(.mrBody.weight(.bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(OnboardingPrimaryButtonStyle())
                                .disabled(isRequestingHealth || isFinishing)
                            }
                        }
                    }
                    .padding(22)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 1))
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Back") { withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) { step -= 1 } }
                                .buttonStyle(OnboardingSecondaryButtonStyle())
                        }

                        Button(primaryTitle) { advance() }
                            .buttonStyle(OnboardingPrimaryButtonStyle())
                            .disabled(isPrimaryDisabled)
                    }
                    .padding(.horizontal, 24)

                    Button("Continue with manual goal") { finish() }
                        .font(.mrSmall.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                        .padding(.bottom, 28)
                        .disabled(isFinishing)
                }
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: "Continue"
        case 1: "Continue"
        default: "Start logging"
        }
    }

    private var isPrimaryDisabled: Bool {
        isFinishing || isRequestingHealth || (step == 1 && resolvedGoal == nil)
    }

    private var resolvedGoal: Int? {
        let value = Int(goal.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let value, (900...6000).contains(value) else { return nil }
        return value
    }

    private func advance() {
        if step < 2 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { step += 1 }
        } else {
            finish()
        }
    }

    private func requestHealth() async {
        guard !isRequestingHealth else { return }
        isRequestingHealth = true
        await app.requestHealthAccess()
        isRequestingHealth = false
        finish()
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let calorieGoal = resolvedGoal ?? 2200
        let protein = Int(proteinTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        Task {
            await app.completeOnboarding(
                displayName: cleaned.isEmpty ? nil : cleaned,
                goalCalories: calorieGoal,
                goalMode: goalMode,
                proteinTarget: protein
            )
            await MainActor.run { isFinishing = false }
        }
    }
}

private struct GoalModePicker: View {
    @Binding var selection: String
    private let options = [("lose", "Lose"), ("maintain", "Maintain"), ("gain", "Gain")]

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
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(.white.opacity(0.52))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(MRColor.accentDeep.opacity(configuration.isPressed ? 0.86 : 1))
            .clipShape(Capsule())
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
            .frame(height: 54)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
