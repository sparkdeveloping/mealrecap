import SwiftUI
import FirebaseStorage
import FirebaseCore

/// Real-image-first visuals. It prefers a direct backend URL, then falls back to
/// resolving Firebase Storage paths for older records.
struct MealVisual: View {
    let meal: MealEntry
    var size: CGFloat = 84
    var cornerRadius: CGFloat = 26
    var onRetry: (() -> Void)? = nil

    @State private var resolvedURL: URL?
    @State private var isLoadingURL = false
    @State private var didFailToLoad = false

    private var sourceKey: String {
        [meal.imageURL ?? "", meal.photoPath ?? "", meal.imageStatus ?? "", meal.imageKind ?? "", meal.imageAlpha ?? "", meal.imageStyleVersion ?? "", "\(meal.updatedAt.timeIntervalSince1970)"].joined(separator: "|")
    }

    private var effectiveImageStatus: String {
        if didFailToLoad { return "failed" }
        if meal.imageStatus == "pending" && Date().timeIntervalSince(meal.updatedAt) > 10 * 60 {
            return "failed"
        }
        if let photoPath = meal.photoPath, photoPath.isEmpty == false { return meal.imageStatus ?? "ready" }
        if let imageURL = meal.imageURL, imageURL.isEmpty == false { return meal.imageStatus ?? "ready" }
        return meal.imageStatus ?? "none"
    }

    private var usesAppBackgroundImageMode: Bool {
        guard meal.source != .camera else { return false }
        let kind = meal.imageKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let alpha = meal.imageAlpha?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let style = meal.imageStyleVersion?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return kind == "appbackground" || alpha == "appbackground" || style == "app-background-v1"
    }

    var body: some View {
        ZStack {
            if let resolvedURL {
                AsyncImage(url: resolvedURL, transaction: Transaction(animation: .easeInOut(duration: 0.22))) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        readyImage(image)
                    case .failure(let error):
                        failedPlaceholder(error: error)
                    @unknown default:
                        quietPlaceholder
                    }
                }
            } else if isLoadingURL {
                loadingPlaceholder
            } else {
                quietPlaceholder
            }
        }
        .frame(width: size, height: size)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: sourceKey) { await loadImageURL() }
        .onTapGesture {
            if effectiveImageStatus == "failed" {
                onRetry?()
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func readyImage(_ image: Image) -> some View {
        if usesAppBackgroundImageMode {
            ZStack {
                Ellipse()
                    .fill(MRColor.gold.opacity(0.08))
                    .frame(width: size * 0.76, height: size * 0.28)
                    .blur(radius: size * 0.14)
                    .offset(y: size * 0.24)

                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.02)
                    .mask(appBackgroundFeatherMask)
                    .shadow(color: MRColor.text.opacity(0.10), radius: size * 0.08, x: 0, y: size * 0.06)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            image
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.82), lineWidth: 1)
                )
                .shadow(color: MRColor.text.opacity(0.08), radius: 14, x: 0, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var appBackgroundFeatherMask: some View {
        RadialGradient(
            colors: [
                .black,
                .black,
                .black.opacity(0.96),
                .black.opacity(0.42),
                .clear
            ],
            center: .center,
            startRadius: size * 0.28,
            endRadius: size * 0.72
        )
    }

    private var quietPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MRColor.card.opacity(0.96), MRColor.accentSoft.opacity(0.32), MRColor.cardWarm.opacity(0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.44))
                .frame(width: size * 0.50, height: size * 0.50)
                .blur(radius: 14)
                .offset(x: -size * 0.12, y: -size * 0.10)

            Image(systemName: placeholderIcon)
                .font(.system(size: max(14, size * 0.18), weight: .semibold))
                .foregroundStyle(MRColor.accentDeep.opacity(0.68))
                .frame(width: size * 0.44, height: size * 0.44)
                .background(.white.opacity(0.42))
                .clipShape(Circle())

            if let placeholderText {
                Text(placeholderText.uppercased())
                    .font(.system(size: max(7, size * 0.075), weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(MRColor.tertiaryText.opacity(0.82))
                    .offset(y: size * 0.34)
            }

            if effectiveImageStatus == "failed" && onRetry != nil {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: max(9, size * 0.11), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: max(22, size * 0.25), height: max(22, size * 0.25))
                    .background(MRColor.accentDeep.opacity(0.86))
                    .clipShape(Circle())
                    .offset(x: size * 0.34, y: -size * 0.34)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: MRColor.text.opacity(0.06), radius: 12, x: 0, y: 8)
    }

    private var placeholderText: String? {
        switch effectiveImageStatus {
        case "pending":
            return "Making"
        case "failed":
            return "Retry"
        default:
            return nil
        }
    }

    private var placeholderIcon: String {
        switch effectiveImageStatus {
        case "failed":
            return "arrow.clockwise"
        case "pending":
            return "sparkles"
        default:
            return "fork.knife"
        }
    }

    private var loadingPlaceholder: some View {
        quietPlaceholder
            .shimmer(effectiveImageStatus == "pending" || isLoadingURL)
            .overlay(
                Group {
                    if effectiveImageStatus == "pending" || isLoadingURL {
                        ProgressView()
                            .tint(MRColor.accent)
                            .scaleEffect(0.75)
                    }
                }
            )
    }

    private func failedPlaceholder(error: Error) -> some View {
        quietPlaceholder
            .task(id: resolvedURL?.absoluteString) {
                #if DEBUG
                print("[MealVisual] failed image request", [
                    "url": resolvedURL?.absoluteString ?? "",
                    "meal": meal.title,
                    "status": effectiveImageStatus,
                    "imageKind": meal.imageKind ?? "",
                    "imageAlpha": meal.imageAlpha ?? "",
                    "imageStyleVersion": meal.imageStyleVersion ?? "",
                    "photoPath": meal.photoPath ?? "",
                    "error": error.localizedDescription
                ])
                #endif
                await MainActor.run {
                    didFailToLoad = true
                    resolvedURL = nil
                }
            }
    }

    private var accessibilityText: String {
        if resolvedURL != nil { return "\(meal.title) image" }
        if effectiveImageStatus == "failed" { return "\(meal.title) image failed. Retry photo available." }
        if effectiveImageStatus == "pending" { return "\(meal.title) image is being generated." }
        return "\(meal.title) meal image placeholder"
    }

    private func loadImageURL() async {
        await MainActor.run {
            resolvedURL = nil
            isLoadingURL = false
            didFailToLoad = false
        }

        if let direct = meal.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: direct),
           url.scheme?.hasPrefix("http") == true {
            await MainActor.run { resolvedURL = url }
            return
        }

        let path = meal.photoPath?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let path, let directURL = URL(string: path), directURL.scheme?.hasPrefix("http") == true {
            await MainActor.run { resolvedURL = directURL }
            return
        }

        if let path, path.isEmpty == false {
            await MainActor.run { isLoadingURL = true }
            do {
                let url = try await Storage.storage().reference(withPath: path).downloadURL()
                await MainActor.run {
                    resolvedURL = url
                    isLoadingURL = false
                }
                return
            } catch {
                #if DEBUG
                print("[MealVisual] failed storage image", [
                    "path": path,
                    "meal": meal.title,
                    "status": effectiveImageStatus,
                    "imageKind": meal.imageKind ?? "",
                    "imageAlpha": meal.imageAlpha ?? "",
                    "imageStyleVersion": meal.imageStyleVersion ?? "",
                    "hasImageURL": meal.imageURL?.isEmpty == false,
                    "error": error.localizedDescription
                ])
                #endif
            }
        }

        await MainActor.run {
            isLoadingURL = false
            didFailToLoad = effectiveImageStatus == "ready"
        }
        if effectiveImageStatus == "ready" {
            #if DEBUG
            print("[MealVisual] ready image missing usable source", [
                "meal": meal.title,
                "photoPath": meal.photoPath ?? "",
                "imageURL": meal.imageURL ?? "",
                "status": meal.imageStatus ?? "",
                "imageKind": meal.imageKind ?? "",
                "imageAlpha": meal.imageAlpha ?? "",
                "imageStyleVersion": meal.imageStyleVersion ?? ""
            ])
            #endif
        }
    }
}

struct MealThumb: View {
    let meal: MealEntry
    var body: some View {
        MealVisual(meal: meal, size: 58, cornerRadius: 22)
    }
}
