import SwiftUI

struct ProfileSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    let meals: [MealEntry]
    let day: MealDay?
    let usage: SmartActionUsage
    let entitlement: ProEntitlement
    let onUpgrade: () -> Void
    let onGenerateImages: () -> Void

    @State private var legalDocument: LegalDocument?
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var cumulativeStats: CumulativeStats = .empty
    private let metricColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var caloriesIn: Int { day?.caloriesIn ?? meals.reduce(0) { $0 + $1.calories } }
    private var missingImageCount: Int { meals.filter { ($0.photoPath ?? "").isEmpty }.count }
    private var macroTotals: MacroSummary {
        meals.reduce(.empty) { total, meal in
            MacroSummary(protein: total.protein + meal.macros.protein, carbs: total.carbs + meal.macros.carbs, fat: total.fat + meal.macros.fat)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Capsule()
                    .fill(MRColor.line)
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Profile")
                            .font(.mrTitle)
                            .foregroundStyle(MRColor.text)
                        Text(displayEmail)
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer()
                    Text(entitlement.isPro ? "PRO" : "FREE")
                        .font(.mrMicro)
                        .tracking(1.2)
                        .foregroundStyle(entitlement.isPro ? .white : MRColor.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassCapsule(tint: entitlement.isPro ? MRColor.accent.opacity(0.55) : MRColor.cardDeep.opacity(0.24), strokeOpacity: 0.46, shadowOpacity: 0.02)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("All-time")
                            .font(.mrHeadline)
                            .foregroundStyle(MRColor.text)
                        Spacer()
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MRColor.accentDeep)
                            .frame(width: 34, height: 34)
                            .background(MRColor.accentSoft.opacity(0.5))
                            .clipShape(Circle())
                    }
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                        ProfileMetric(title: "Days", value: "\(cumulativeStats.loggedDays)")
                        ProfileMetric(title: "Meals", value: "\(cumulativeStats.totalMeals)")
                        ProfileMetric(title: "Calories", value: cumulativeStats.totalCalories.formatted())
                        ProfileMetric(title: "Avg/day", value: cumulativeStats.averageCalories.formatted())
                        ProfileMetric(title: "Avg protein", value: "\(cumulativeStats.averageProtein)g")
                        ProfileMetric(title: "Photos", value: "\(cumulativeStats.generatedPhotos)")
                    }
                    if !cumulativeStats.topCategories.isEmpty {
                        Text(cumulativeStats.topCategories.joined(separator: " · "))
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(18)
                .premiumCard(cornerRadius: 28, shadowOpacity: 0.05)

                VStack(spacing: 10) {
                    ProfileAction(icon: "crown.fill", title: entitlement.isPro ? "Manage Pro" : "Upgrade to Pro", tint: MRColor.gold) {
                        onUpgrade()
                    }
                    .glassRounded(cornerRadius: 24, tint: MRColor.gold.opacity(0.08), strokeOpacity: 0.50, shadowOpacity: 0.04)

                    ProfileAction(icon: "arrow.clockwise", title: "Restore purchases") {
                        Task { await app.purchases.restore() }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Account & app")
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)

                    ProfileAction(icon: "lock.shield", title: "Privacy Policy") { legalDocument = .privacy }
                    ProfileAction(icon: "doc.text", title: "Terms of Use") { legalDocument = .terms }
                    ProfileAction(icon: "heart.text.square", title: "Health & Nutrition Disclaimer") { legalDocument = .health }
                    ProfileAction(icon: "trash", title: "Delete account", tint: MRColor.danger) { showDeleteConfirmation = true }
                    ProfileAction(icon: "rectangle.portrait.and.arrow.right", title: "Sign out", tint: MRColor.danger) {
                        app.signOut()
                        dismiss()
                    }
                }
            }
            .padding(24)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 0, for: .scrollContent)
        .background(
            AmbientBackground()
        )
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
                .presentationDetents([.large])
                .presentationCornerRadius(34)
        }
        .confirmationDialog("Delete local account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete account and data", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local MealRecap account from this device and deletes this user’s MealRecap data from Firestore for the current local user id.")
        }
        .task { await loadStats() }
        .overlay {
            if isDeleting {
                ZStack {
                    Rectangle().fill(.black.opacity(0.08)).ignoresSafeArea()
                    ProgressView("Deleting…")
                        .font(.mrSmall)
                        .padding(18)
                        .glassRounded(cornerRadius: 22, strokeOpacity: 0.48, shadowOpacity: 0.06)
                }
            }
        }
    }

    private var displayEmail: String {
        guard let email = app.session?.email?.trimmingCharacters(in: .whitespacesAndNewlines), email.isEmpty == false else {
            return "Signed in"
        }
        let lower = email.lowercased()
        if lower.contains("test") || lower.contains("example") || lower.contains("demo") || lower.hasPrefix("local") {
            return "Signed in"
        }
        return email
    }

    private func loadStats() async {
        guard let uid = app.session?.uid else { return }
        do {
            let stats = try await app.store.fetchCumulativeStats(uid: uid)
            await MainActor.run { cumulativeStats = stats }
        } catch {
            // Keep profile usable even if analytics are still loading.
        }
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                if let uid = app.session?.uid {
                    try await app.store.deleteUser(uid: uid)
                }
                try app.auth.deleteCurrentAccount()
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    app.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct ProfileMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(1.7)
                .foregroundStyle(MRColor.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileAction: View {
    let icon: String
    let title: String
    var tint: Color = MRColor.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .glassCircle(tint: tint.opacity(0.08), strokeOpacity: 0.28, shadowOpacity: 0.02)
                Text(title)
                    .font(.mrBody.weight(.medium))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MRColor.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .glassRounded(cornerRadius: 22, tint: tint.opacity(0.05), strokeOpacity: 0.34, shadowOpacity: 0.03)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(title)
    }
}

enum LegalDocument: String, Identifiable {
    case privacy
    case terms
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        case .health: "Health & Nutrition Disclaimer"
        }
    }

    var bodyText: String {
        switch self {
        case .privacy:
            return """
            MealRecap Privacy Policy

            MealRecap helps you log meals, estimate nutrition, and view daily food history. The app may store local account details on your device and MealRecap meal data in Firebase, including meal text, generated nutrition estimates, uploaded meal photos, generated meal images, daily totals, Smart Action usage, and purchase entitlement status.

            MealRecap may send meal text or meal images to backend services to estimate nutrition and generate meal imagery. Do not enter sensitive information you do not want processed for meal analysis. MealRecap does not sell personal data.

            Health data is used only to calculate calories out and daily balance when you choose to grant Health access. You can revoke Health access in iOS Settings at any time.

            You can delete your local account and MealRecap data from the Profile screen. This development build uses local-only account auth; before App Store release, replace this text with your final hosted privacy policy URL and jurisdiction-specific legal language.
            """
        case .terms:
            return """
            MealRecap Terms of Use

            MealRecap provides food logging, calorie estimates, meal photo analysis, generated meal imagery, and nutrition organization tools. You are responsible for reviewing and correcting estimates before relying on them.

            MealRecap Pro subscriptions unlock additional usage and features. Purchases are processed by Apple through StoreKit and are subject to Apple’s subscription terms.

            MealRecap is provided as-is. Do not use the app for emergency, medical, or clinical nutrition decisions. You agree not to misuse the backend, upload unlawful content, or attempt to access another user’s data.

            Before App Store release, replace this in-app text with your final hosted Terms of Use and Apple standard EULA link if you choose to use Apple’s default license.
            """
        case .health:
            return """
            Health & Nutrition Disclaimer

            MealRecap is not medical advice. Calorie, macro, portion, and image-based estimates are approximate and may be wrong. Photo analysis cannot truly weigh food from an image; it estimates portions based on visible context.

            Consult a qualified health professional before making major diet, weight-loss, medical, or exercise changes. If you have a medical condition, eating disorder history, pregnancy-related nutrition needs, or prescribed dietary requirements, do not rely on MealRecap as your primary source of guidance.
            """
        }
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(document.title)
                        .font(.mrTitle)
                        .foregroundStyle(MRColor.text)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MRColor.text)
                            .frame(width: 38, height: 38)
                            .glassCircle(strokeOpacity: 0.62, shadowOpacity: 0.04)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text(document.bodyText)
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }
            .padding(24)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 0, for: .scrollContent)
        .background(AmbientBackground())
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}
