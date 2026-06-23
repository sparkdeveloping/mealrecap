import SwiftUI
import StoreKit
import SafariServices

struct PaywallView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    @State private var safariURL: SafariURL?
    @State private var statusMessage: String?

    private let privacyURL = URL(string: "https://mealrecap.app/privacy")!
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)

                    header
                    featureCard
                    productSection
                    subscriptionNote
                    restoreAndDismissActions
                    legalLinks
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
                .padding(.vertical, max(0, proxy.safeAreaInsets.top - 8))
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 0, for: .scrollContent)
            .background(AmbientBackground())
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .task {
            if app.purchases.products.isEmpty, app.purchases.productLoadState != .loading {
                await app.purchases.loadProducts()
            }
        }
        .sheet(item: $safariURL) { item in
            SafariSheet(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MealRecap Pro", systemImage: "crown.fill")
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.gold)
            Text(reason.title)
                .font(.mrTitle)
                .foregroundStyle(MRColor.text)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
            Text(reason.subtitle)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaywallFeature(text: "Unlimited chat, voice, photo, and day recaps")
            PaywallFeature(text: "Review meals before saving with portions and nutrition details")
            PaywallFeature(text: "Weekly calorie and protein insights")
            PaywallFeature(text: "Faster logging with usual meals and cleaner history")
        }
        .padding(18)
        .premiumCard(cornerRadius: 28, shadowOpacity: 0.04)
    }

    @ViewBuilder
    private var productSection: some View {
        VStack(spacing: 10) {
            switch app.purchases.productLoadState {
            case .idle, .loading:
                LoadingPlansCard()
            case .loaded:
                ForEach(app.purchases.products, id: \.id) { product in
                    productButton(product)
                }
            case .unavailable, .failed:
                unavailableCard
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            } else if let purchaseError = app.purchases.purchaseError {
                Text(purchaseError)
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriptions are unavailable right now. Please try again.")
                .font(.mrBody.weight(.semibold))
                .foregroundStyle(MRColor.text)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { unavailableButtons }
                VStack(spacing: 10) { unavailableButtons }
            }
        }
        .padding(18)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.46, shadowOpacity: 0.03)
    }

    @ViewBuilder
    private var unavailableButtons: some View {
        compactAction("Try again", tint: MRColor.accentDeep) {
            Task { await app.purchases.loadProducts() }
        }
        compactAction("Restore purchases", tint: MRColor.text) {
            Task { await restore() }
        }
        compactAction("Not now", tint: MRColor.secondaryText) {
            dismiss()
        }
    }

    private func productButton(_ product: Product) -> some View {
        let isPurchasing = app.purchases.purchasingProductID == product.id
        return Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(planTitle(for: product))
                            .font(.mrHeadline)
                            .foregroundStyle(MRColor.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        if isYearly(product) {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.0)
                                .foregroundStyle(MRColor.accentDeep)
                                .padding(.horizontal, 7)
                                .frame(height: 22)
                                .glassCapsule(tint: MRColor.accentSoft.opacity(0.20), strokeOpacity: 0.34, shadowOpacity: 0.01)
                        }
                    }
                    Text(planSubtitle(for: product))
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(3)
                }
                Spacer(minLength: 10)
                if isPurchasing {
                    ProgressView()
                        .tint(MRColor.accentDeep)
                } else {
                    Text(product.displayPrice)
                        .font(.mrHeadline)
                        .foregroundStyle(MRColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(18)
            .glassRounded(cornerRadius: 22, tint: isYearly(product) ? MRColor.accentSoft.opacity(0.34) : MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.68, shadowOpacity: 0.04)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .disabled(app.purchases.purchasingProductID != nil)
        .accessibilityLabel("\(planTitle(for: product)), \(product.displayPrice)")
    }

    private var subscriptionNote: some View {
        Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.")
            .font(.mrSmall)
            .foregroundStyle(MRColor.secondaryText)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private var restoreAndDismissActions: some View {
        HStack(spacing: 16) {
            Button {
                Task { await restore() }
            } label: {
                HStack(spacing: 8) {
                    if app.purchases.restoreState == .restoring {
                        ProgressView().tint(MRColor.secondaryText)
                    }
                    Text("Restore purchases")
                }
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(app.purchases.restoreState == .restoring)

            Button("Not now") { dismiss() }
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .font(.mrSmall.weight(.semibold))
        .foregroundStyle(MRColor.secondaryText)
        .frame(maxWidth: .infinity)
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Button("Privacy Policy") { safariURL = SafariURL(url: privacyURL) }
                .contentShape(Rectangle())
            Button("Terms of Use") { safariURL = SafariURL(url: termsURL) }
                .contentShape(Rectangle())
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(MRColor.tertiaryText)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.bottom, 10)
    }

    private func compactAction(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .glassCapsule(tint: tint.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
    }

    private func purchase(_ product: Product) async {
        statusMessage = nil
        let ok = await app.purchases.purchase(product)
        if ok {
            await app.activateProEntitlement()
            statusMessage = "MealRecap Pro is active."
            try? await Task.sleep(nanoseconds: 650_000_000)
            dismiss()
        }
    }

    private func restore() async {
        statusMessage = nil
        let state = await app.restorePurchases()
        switch state {
        case .restored:
            statusMessage = "MealRecap Pro is active."
            try? await Task.sleep(nanoseconds: 650_000_000)
            dismiss()
        case .noActiveSubscription:
            statusMessage = "No active subscription was found for this Apple Account."
        case .failed:
            statusMessage = "Couldn’t restore purchases. Try again."
        case .idle, .restoring:
            break
        }
    }

    private func isYearly(_ product: Product) -> Bool {
        product.id == StoreKitService.ProductID.yearly
    }

    private func planTitle(for product: Product) -> String {
        if product.id == StoreKitService.ProductID.weekly { return "Weekly" }
        if product.id == StoreKitService.ProductID.monthly { return "Monthly" }
        if product.id == StoreKitService.ProductID.yearly { return "Yearly" }
        return product.displayName
    }

    private func planSubtitle(for product: Product) -> String {
        let period = product.subscription?.subscriptionPeriod
        let length = period.map { subscriptionLength($0) } ?? planTitle(for: product)
        return "\(length) subscription. Unlocks unlimited smart logging, Snap, Say, and Day recap."
    }

    private func subscriptionLength(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 7 ? "Weekly" : "\(period.value)-day"
        case .week: return period.value == 1 ? "Weekly" : "\(period.value)-week"
        case .month: return period.value == 1 ? "Monthly" : "\(period.value)-month"
        case .year: return period.value == 1 ? "Yearly" : "\(period.value)-year"
        @unknown default: return "Subscription"
        }
    }
}

private struct SafariURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct LoadingPlansCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(MRColor.accentDeep)
            VStack(alignment: .leading, spacing: 4) {
                Text("Loading subscriptions")
                    .font(.mrHeadline)
                    .foregroundStyle(MRColor.text)
                Text("This should only take a moment.")
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer(minLength: 0)
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

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
