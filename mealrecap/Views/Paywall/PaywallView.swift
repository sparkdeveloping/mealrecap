import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Label("MealRecap Pro", systemImage: "crown.fill")
                        .font(.mrSmall.weight(.bold))
                        .foregroundStyle(MRColor.gold)
                    Text(reason.title)
                        .font(.mrTitle)
                        .foregroundStyle(MRColor.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(reason.subtitle)
                        .font(.mrBody)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 12) {
                    PaywallFeature(text: "Remember every meal automatically")
                    PaywallFeature(text: "Stop manually searching food databases")
                    PaywallFeature(text: "See how your eating affects your health")
                    PaywallFeature(text: "Save hours every month with voice, photo, and day recaps")
                }
                .padding(18)
                .premiumCard(cornerRadius: 28, shadowOpacity: 0.04)

                VStack(spacing: 10) {
                    if app.purchases.isLoadingProducts {
                        PlanPlaceholder(title: "Monthly", subtitle: "Flexible Pro access")
                        PlanPlaceholder(title: "Yearly", subtitle: "Best value for building a food memory")
                    } else if app.purchases.products.isEmpty {
                        StoreKitRetryCard(error: app.purchases.purchaseError) {
                            Task { await app.purchases.loadProducts() }
                        }
                    } else {
                        ForEach(app.purchases.products, id: \.id) { product in
                            Button {
                                Task {
                                    let ok = await app.purchases.purchase(product)
                                    if ok {
                                        app.entitlement = ProEntitlement(isPro: true, expiresAt: nil)
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(planTitle(for: product))
                                            .font(.mrHeadline)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.82)
                                        Text(planSubtitle(for: product))
                                            .font(.caption)
                                            .foregroundStyle(MRColor.secondaryText)
                                            .lineLimit(3)
                                    }
                                    Spacer(minLength: 10)
                                    Text(product.displayPrice)
                                        .font(.mrHeadline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .foregroundStyle(MRColor.text)
                                .padding(18)
                                .glassRounded(
                                    cornerRadius: 22,
                                    tint: isYearly(product) ? MRColor.accentSoft.opacity(0.34) : MRColor.backgroundTop.opacity(0.08),
                                    strokeOpacity: 0.68,
                                    shadowOpacity: 0.04
                                )
                                .overlay(alignment: .topTrailing) {
                                    if isYearly(product) {
                                        Text("BEST VALUE")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .tracking(1.0)
                                            .foregroundStyle(MRColor.accentDeep)
                                            .padding(.horizontal, 8)
                                            .frame(height: 22)
                                            .glassCapsule(tint: MRColor.accentSoft.opacity(0.18), strokeOpacity: 0.36, shadowOpacity: 0.01)
                                            .padding(10)
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(PressablePolish())
                            .accessibilityLabel("\(planTitle(for: product)), \(product.displayPrice)")
                        }
                    }
                }

                Text("Subscription terms, trial availability, and cancellation are managed by Apple on the purchase sheet.")
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 16) {
                    Button("Restore purchases") {
                        Task { await app.purchases.restore() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Restore purchases")

                    Button("Not now") { dismiss() }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Not now")
                }
                .font(.mrSmall.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity)

                HStack(spacing: 16) {
                    Text("Privacy")
                    Text("Terms")
                    Text("Health disclaimer")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(MRColor.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
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
        .task { await app.purchases.loadProducts() }
    }

    private func isYearly(_ product: Product) -> Bool {
        product.id.localizedCaseInsensitiveContains("year")
    }

    private func planTitle(for product: Product) -> String {
        if product.id.localizedCaseInsensitiveContains("week") { return "Weekly" }
        if product.id.localizedCaseInsensitiveContains("month") { return "Monthly" }
        if isYearly(product) { return "Yearly" }
        return product.displayName
    }

    private func planSubtitle(for product: Product) -> String {
        if product.id.localizedCaseInsensitiveContains("week") { return "Try Pro weekly" }
        if product.id.localizedCaseInsensitiveContains("month") { return "Flexible Pro access" }
        if isYearly(product) { return "Best value for building a food memory" }
        return product.description
    }
}

private struct PlanPlaceholder: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.mrHeadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
            ProgressView()
                .tint(MRColor.accentDeep)
        }
        .padding(18)
        .glassRounded(cornerRadius: 22, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.42, shadowOpacity: 0.03)
    }
}

private struct StoreKitRetryCard: View {
    let error: String?
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plans are unavailable")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            Text("Check your connection and try again.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.secondaryText)
            Button("Retry", action: retry)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.accentDeep)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .glassCapsule(tint: MRColor.accentSoft.opacity(0.24), strokeOpacity: 0.36, shadowOpacity: 0.02)
                .contentShape(Capsule())
        }
        .padding(18)
        .glassRounded(cornerRadius: 22, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.42, shadowOpacity: 0.03)
    }
}

struct PaywallFeature: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MRColor.accent)
            Text(text)
                .font(.mrBody)
                .foregroundStyle(MRColor.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
