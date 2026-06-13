import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text(reason.title)
                    .font(.mrTitle)
                    .foregroundStyle(MRColor.text)
                Text(reason.subtitle)
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
            }

            VStack(alignment: .leading, spacing: 12) {
                PaywallFeature(text: "Unlimited chat, voice, photo, and day recap logging")
                PaywallFeature(text: "Saved usual meals and smarter corrections")
                PaywallFeature(text: "Weekly calorie balance and advanced HealthKit insights")
                PaywallFeature(text: "A cleaner food memory without search friction")
            }
            .padding(18)
            .premiumCard()

            VStack(spacing: 12) {
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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.mrHeadline)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(MRColor.secondaryText)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.mrHeadline)
                        }
                        .foregroundStyle(MRColor.text)
                        .padding(18)
                        .background(product.id.contains("yearly") ? MRColor.accentSoft : MRColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Restore purchases") {
                Task { await app.purchases.restore() }
            }
            .font(.mrSmall)
            .foregroundStyle(MRColor.secondaryText)
            .frame(maxWidth: .infinity)

            Button("Not now") { dismiss() }
                .font(.mrSmall)
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(MRColor.background)
        .task { await app.purchases.loadProducts() }
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
        }
    }
}
