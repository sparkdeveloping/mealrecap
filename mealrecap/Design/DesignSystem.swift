import SwiftUI

enum MRColor {
    static let background = Color(red: 0.965, green: 0.944, blue: 0.904)
    static let backgroundTop = Color(red: 0.992, green: 0.980, blue: 0.950)
    static let card = Color(red: 0.998, green: 0.990, blue: 0.968)
    static let cardWarm = Color(red: 0.948, green: 0.918, blue: 0.858)
    static let cardDeep = Color(red: 0.912, green: 0.874, blue: 0.792)
    static let text = Color(red: 0.135, green: 0.115, blue: 0.095)
    static let secondaryText = Color(red: 0.435, green: 0.392, blue: 0.335)
    static let tertiaryText = Color(red: 0.620, green: 0.575, blue: 0.500)
    static let accent = Color(red: 0.205, green: 0.365, blue: 0.285)
    static let accentDeep = Color(red: 0.070, green: 0.260, blue: 0.180)
    static let accentSoft = Color(red: 0.820, green: 0.878, blue: 0.814)
    static let gold = Color(red: 0.725, green: 0.555, blue: 0.285)
    static let blush = Color(red: 0.925, green: 0.800, blue: 0.720)
    static let blueMist = Color(red: 0.760, green: 0.845, blue: 0.865)
    static let line = Color(red: 0.840, green: 0.800, blue: 0.720)
    static let danger = Color(red: 0.650, green: 0.185, blue: 0.135)
}

enum MRRadius {
    static let card: CGFloat = 34
    static let large: CGFloat = 44
    static let pill: CGFloat = 999
    static let sheet: CGFloat = 36
}

enum MRSpace {
    static let page: CGFloat = 20
    static let card: CGFloat = 18
    static let stack: CGFloat = 14
}

struct MealRecapWordmark: View {
    var compact = false

    private var width: CGFloat { compact ? 55 : 64 }
    private var mealSize: CGFloat { compact ? 14.5 : 17 }
    private var recapSize: CGFloat { compact ? 11.8 : 13.8 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? -1 : -2) {
            Text("MEAL")
                .font(.system(size: mealSize, weight: .semibold, design: .rounded))
                .tracking(compact ? 3.6 : 4.5)
                .frame(width: width, alignment: .leading)
            Text("RECAP")
                .font(.system(size: recapSize, weight: .semibold, design: .rounded))
                .tracking(compact ? 2.15 : 2.72)
                .frame(width: width, alignment: .leading)
        }
        .foregroundStyle(MRColor.text)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .accessibilityLabel("MealRecap")
    }
}

struct PremiumCard: ViewModifier {
    var cornerRadius: CGFloat = MRRadius.card
    var shadowOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MRColor.card.opacity(0.78))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.56), .white.opacity(0.10), MRColor.cardWarm.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 26, x: 0, y: 16)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            )
    }
}

struct FrostedPanel: ViewModifier {
    var cornerRadius: CGFloat = MRRadius.large

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.64), lineWidth: 1)
            )
            .shadow(color: MRColor.text.opacity(0.10), radius: 28, x: 0, y: 18)
    }
}

struct PremiumGlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeOpacity: Double = 0.64
    var shadowOpacity: Double = 0.08

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 24, x: 0, y: 14)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.white.opacity(0.24))
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 24, x: 0, y: 14)
        }
    }
}

struct GlassRoundedBackground: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var strokeOpacity: Double
    var shadowOpacity: Double
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = tint.map { Glass.regular.tint($0).interactive(interactive) } ?? Glass.regular.interactive(interactive)
            content
                .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 20, x: 0, y: 12)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill((tint ?? .white).opacity(tint == nil ? 0.18 : 0.12))
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 20, x: 0, y: 12)
        }
    }
}

struct GlassCapsuleBackground: ViewModifier {
    var tint: Color?
    var strokeOpacity: Double
    var shadowOpacity: Double
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = tint.map { Glass.regular.tint($0).interactive(interactive) } ?? Glass.regular.interactive(interactive)
            content
                .glassEffect(glass, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
        } else {
            content
                .background {
                    Capsule()
                        .fill(.regularMaterial)
                        .overlay(Capsule().fill((tint ?? .white).opacity(tint == nil ? 0.18 : 0.12)))
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
        }
    }
}

struct GlassCircleBackground: ViewModifier {
    var tint: Color?
    var strokeOpacity: Double
    var shadowOpacity: Double
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = tint.map { Glass.regular.tint($0).interactive(interactive) } ?? Glass.regular.interactive(interactive)
            content
                .glassEffect(glass, in: Circle())
                .overlay(Circle().stroke(.white.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 16, x: 0, y: 10)
        } else {
            content
                .background {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(Circle().fill((tint ?? .white).opacity(tint == nil ? 0.18 : 0.12)))
                }
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: MRColor.text.opacity(shadowOpacity), radius: 16, x: 0, y: 10)
        }
    }
}

struct PressablePolish: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .shadow(color: MRColor.text.opacity(configuration.isPressed ? 0.03 : 0.07), radius: configuration.isPressed ? 8 : 16, x: 0, y: configuration.isPressed ? 4 : 10)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.9

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.38), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: max(proxy.size.width * 0.45, 24))
                        .rotationEffect(.degrees(18))
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.plusLighter)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.55).repeatForever(autoreverses: false)) {
                    phase = 1.8
                }
            }
    }
}

extension View {
    func premiumCard(cornerRadius: CGFloat = MRRadius.card, shadowOpacity: Double = 0.08) -> some View {
        modifier(PremiumCard(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }

    func frostedPanel(cornerRadius: CGFloat = MRRadius.large) -> some View {
        modifier(FrostedPanel(cornerRadius: cornerRadius))
    }

    func premiumGlass(cornerRadius: CGFloat = 24, strokeOpacity: Double = 0.64, shadowOpacity: Double = 0.08) -> some View {
        modifier(PremiumGlassPanel(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, shadowOpacity: shadowOpacity))
    }

    func glassRounded(cornerRadius: CGFloat = 24, tint: Color? = nil, strokeOpacity: Double = 0.58, shadowOpacity: Double = 0.08, interactive: Bool = true) -> some View {
        modifier(GlassRoundedBackground(cornerRadius: cornerRadius, tint: tint, strokeOpacity: strokeOpacity, shadowOpacity: shadowOpacity, interactive: interactive))
    }

    func glassCapsule(tint: Color? = nil, strokeOpacity: Double = 0.58, shadowOpacity: Double = 0.08, interactive: Bool = true) -> some View {
        modifier(GlassCapsuleBackground(tint: tint, strokeOpacity: strokeOpacity, shadowOpacity: shadowOpacity, interactive: interactive))
    }

    func glassCircle(tint: Color? = nil, strokeOpacity: Double = 0.58, shadowOpacity: Double = 0.08, interactive: Bool = true) -> some View {
        modifier(GlassCircleBackground(tint: tint, strokeOpacity: strokeOpacity, shadowOpacity: shadowOpacity, interactive: interactive))
    }

    func pressableScale() -> some View {
        buttonStyle(PressablePolish())
    }

    @ViewBuilder
    func shimmer(_ isActive: Bool = true) -> some View {
        if isActive {
            modifier(ShimmerModifier())
        } else {
            self
        }
    }
}

struct AnimatedNumberText: View {
    let value: Int
    var format: (Int) -> String = { $0.formatted() }
    var font: Font
    var color: Color = MRColor.text

    var body: some View {
        Text(format(value))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: value)
    }
}

extension Font {
    static let mrHero = Font.system(size: 62, weight: .semibold, design: .rounded)
    static let mrDisplay = Font.system(size: 42, weight: .semibold, design: .rounded)
    static let mrTitle = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let mrHeadline = Font.system(size: 21, weight: .semibold, design: .rounded)
    static let mrBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let mrSmall = Font.system(size: 13, weight: .medium, design: .rounded)
    static let mrMicro = Font.system(size: 10, weight: .bold, design: .rounded)
}

enum MRMath {
    static func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
        min(max(value, lower), upper)
    }

    static func percent(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return clamp(Double(numerator) / Double(denominator))
    }
}

struct AmbientBackground: View {
    var includeBaseFill = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                if includeBaseFill {
                    LinearGradient(
                        colors: [
                            MRColor.backgroundTop,
                            MRColor.background.opacity(reduceTransparency ? 1.0 : 0.92),
                            MRColor.cardWarm.opacity(reduceTransparency ? 0.75 : 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if reduceTransparency {
                    MRColor.background.opacity(0.74)
                } else {
                    ambientBlob(
                        color: MRColor.gold,
                        opacity: 0.18,
                        width: size.width * 0.92,
                        height: size.width * 0.72,
                        x: size.width * (drift ? 0.88 : 0.82),
                        y: size.height * (drift ? 0.09 : 0.13),
                        blur: 88
                    )
                    ambientBlob(
                        color: MRColor.accentSoft,
                        opacity: 0.28,
                        width: size.width * 1.05,
                        height: size.width * 0.86,
                        x: size.width * (drift ? 0.18 : 0.12),
                        y: size.height * (drift ? 0.36 : 0.42),
                        blur: 104
                    )
                    ambientBlob(
                        color: MRColor.accent,
                        opacity: 0.13,
                        width: size.width * 0.82,
                        height: size.width * 0.68,
                        x: size.width * (drift ? 0.96 : 0.88),
                        y: size.height * (drift ? 0.72 : 0.78),
                        blur: 118
                    )
                    ambientBlob(
                        color: MRColor.blush,
                        opacity: 0.12,
                        width: size.width * 0.74,
                        height: size.width * 0.58,
                        x: size.width * (drift ? 0.08 : 0.15),
                        y: size.height * (drift ? 0.92 : 0.86),
                        blur: 92
                    )
                    ambientBlob(
                        color: MRColor.backgroundTop,
                        opacity: 0.42,
                        width: size.width * 0.70,
                        height: size.width * 0.52,
                        x: size.width * 0.52,
                        y: size.height * 0.04,
                        blur: 70
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func ambientBlob(color: Color, opacity: Double, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(opacity * 0.42), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * 0.50
                )
            )
            .frame(width: max(width, 160), height: max(height, 140))
            .position(x: x, y: y)
            .blur(radius: blur)
    }
}

struct AmbientBokehView: View {
    var includeBaseFill = false

    var body: some View {
        AmbientBackground(includeBaseFill: includeBaseFill)
    }
}

struct GlassCircleButton: View {
    let systemName: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MRColor.text)
                .frame(width: size, height: size)
                .glassCircle(strokeOpacity: 0.76, shadowOpacity: 0.06)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName.replacingOccurrences(of: ".", with: " ")))
    }
}
