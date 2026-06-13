import SwiftUI

struct ChatComposer: View {
    @Binding var text: String
    @Binding var isActionMenuOpen: Bool
    let send: () -> Void
    let onPhoto: () -> Void
    let onVoice: () -> Void
    let onRecap: () -> Void
    let onUpgrade: () -> Void
    var onFocus: (() -> Void)? = nil

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            Button { onFocus?() } label: {
                HStack(spacing: 10) {
                    Text(text.isEmpty ? "What did you eat?" : text)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(text.isEmpty ? MRColor.tertiaryText.opacity(0.62) : MRColor.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 58)
                .glassCapsule(strokeOpacity: 0.84, shadowOpacity: 0.07)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .accessibilityLabel("Open meal composer")

            ZStack {
                Button {
                    if canSend {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) { isActionMenuOpen = false }
                        send()
                    } else {
                        withAnimation(.interpolatingSpring(stiffness: 390, damping: 23)) { isActionMenuOpen.toggle() }
                    }
                } label: {
                    Image(systemName: canSend ? "arrow.up" : "plus")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isActionMenuOpen && !canSend ? 45 : 0))
                        .frame(width: 58, height: 58)
                        .glassCircle(tint: MRColor.accentDeep.opacity(0.55), strokeOpacity: 0.50, shadowOpacity: 0.12)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(canSend ? "Send meal" : "Open logging actions")
            }
            .frame(width: 58, height: 58)
            .zIndex(3)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .overlay(alignment: .bottomTrailing) {
            if isActionMenuOpen && !canSend {
                ComposerActionMenu(
                    onPhoto: { collapseThen(onPhoto) },
                    onVoice: { collapseThen(onVoice) },
                    onRecap: { collapseThen(onRecap) }
                )
                .padding(.bottom, 78)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity)
                ))
                .zIndex(12)
            }
        }
    }

    private func collapseThen(_ action: @escaping () -> Void) {
        withAnimation(.interpolatingSpring(stiffness: 330, damping: 26)) { isActionMenuOpen = false }
        action()
    }
}

private struct ComposerActionMenu: View {
    let onPhoto: () -> Void
    let onVoice: () -> Void
    let onRecap: () -> Void

    private var actions: [(String, String, String, () -> Void)] {
        [
            ("camera.fill", "Snap", "Photo", onPhoto),
            ("mic.fill", "Say", "Voice", onVoice),
            ("text.badge.plus", "Recap", "Whole day", onRecap)
        ]
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, item in
                ComposerBubble(icon: item.0, title: item.1, subtitle: item.2, action: item.3)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.88, anchor: .bottomTrailing)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing))
                    ))
                    .animation(.spring(response: 0.32, dampingFraction: 0.76).delay(Double(index) * 0.035), value: true)
            }
        }
        .padding(8)
        .frame(width: 168)
        .glassRounded(cornerRadius: 28, strokeOpacity: 0.72, shadowOpacity: 0.16)
    }
}

private struct ComposerBubble: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var tint: Color = MRColor.text

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.mrSmall.weight(.bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 52)
            .glassRounded(cornerRadius: 20, tint: tint.opacity(0.08), strokeOpacity: 0.28, shadowOpacity: 0.02)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

struct FocusedComposerView: View {
    @Binding var text: String
    let suggestions: [String]
    let submit: (String) async -> Void
    let onPhoto: () -> Void
    let onVoice: () -> Void
    let onRecap: () -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var isSubmitting = false

    private var cleanText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = proxy.size.width
            let viewportHeight = proxy.size.height
            let horizontalPadding: CGFloat = 20
            let contentWidth = max(0, viewportWidth - horizontalPadding * 2)

            ZStack(alignment: .bottom) {
                AmbientBackground()
                    .frame(width: viewportWidth, height: viewportHeight)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        focusedHeader

                        if !suggestions.isEmpty && cleanText.isEmpty {
                            suggestionList
                        }

                        editorCard

                        if !cleanText.isEmpty {
                            creationPreview
                        }

                        if isSubmitting {
                            ProcessingRibbon()
                                .transition(.opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 24)
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .frame(width: viewportWidth, alignment: .center)
                    .padding(.top, proxy.safeAreaInsets.top + 44)
                    .padding(.bottom, 128 + proxy.safeAreaInsets.bottom)
                }
                .frame(width: viewportWidth)
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollContent)

                bottomDock
                    .frame(maxWidth: contentWidth)
                    .padding(.horizontal, 18)
                    .frame(width: viewportWidth)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 8))
            }
            .frame(width: viewportWidth, height: viewportHeight)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .onAppear { focused = true }
        .interactiveDismissDisabled(isSubmitting)
    }

    private var focusedHeader: some View {
        HStack {
            MealRecapWordmark()
            .layoutPriority(1)

            Spacer(minLength: 12)
            Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MRColor.text)
                        .frame(width: 42, height: 42)
                        .glassCircle(strokeOpacity: 0.70, shadowOpacity: 0.06)
                        .contentShape(Circle())
                }
                .buttonStyle(PressablePolish())
                .accessibilityLabel("Close composer")
            }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Usual picks")
                .font(.mrMicro)
                .tracking(2.6)
                .foregroundStyle(MRColor.tertiaryText)
            ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { text = suggestion }
                } label: {
                    Text(suggestion)
                        .font(.mrBody)
                        .lineLimit(2)
                        .foregroundStyle(MRColor.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use usual pick \(suggestion)")
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(cleanText.isEmpty ? "Type naturally" : "Ready to recap")
                .font(.mrMicro)
                .tracking(2.6)
                .foregroundStyle(MRColor.tertiaryText)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.clear)
                    .glassRounded(cornerRadius: 30, tint: MRColor.backgroundTop.opacity(0.12), strokeOpacity: 0.45, shadowOpacity: 0.04)

                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(MRColor.text)
                    .padding(18)
                    .frame(minHeight: 180, maxHeight: 260)

                if text.isEmpty {
                    Text("2 eggs, toast with butter, and coffee...")
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundStyle(MRColor.tertiaryText.opacity(0.45))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 26)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var creationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MealRecap will create")
                .font(.mrMicro)
                .tracking(2.6)
                .foregroundStyle(MRColor.tertiaryText)
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(MRColor.accentDeep)
                Text("A polished meal card with calories, macros, category, and a generated food photo.")
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(3)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var bottomDock: some View {
        ViewThatFits(in: .horizontal) {
            bottomDockContent(compact: false)
            bottomDockContent(compact: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassRounded(cornerRadius: 32, strokeOpacity: 0.9, shadowOpacity: 0.10)
    }

    private func bottomDockContent(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            QuickAction(icon: "camera.fill", action: onPhoto, label: "Snap", size: compact ? 43 : 45)
            QuickAction(icon: "mic.fill", action: onVoice, label: "Say", size: compact ? 43 : 45)
            QuickAction(icon: "text.badge.plus", action: onRecap, label: "Day", size: compact ? 43 : 45)
            Button {
                guard !cleanText.isEmpty, !isSubmitting else { return }
                let prompt = cleanText
                Task { @MainActor in
                    guard !isSubmitting else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { isSubmitting = true }
                    await submit(prompt)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { isSubmitting = false }
                    text = ""
                    dismiss()
                }
            } label: {
                if compact {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 43, height: 43)
                } else {
                    Text("Create")
                        .font(.mrBody.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 23)
                        .frame(height: 48)
                }
            }
            .glassCapsule(tint: MRColor.accentDeep.opacity(cleanText.isEmpty ? 0.26 : 0.55), strokeOpacity: 0.36, shadowOpacity: 0.06)
            .contentShape(Capsule())
            .buttonStyle(.plain)
            .disabled(cleanText.isEmpty || isSubmitting)
            .accessibilityLabel("Create meal")
        }
    }
}

private struct ProcessingRibbon: View {
    @State private var pulse = false
    @State private var stageIndex = 0

    private let stages = [
        "Reading your meal",
        "Estimating portions",
        "Calculating calories",
        "Balancing macros",
        "Creating meal photo",
        "Updating your day"
    ]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(MRColor.accentSoft.opacity(0.7), lineWidth: 4).frame(width: 30, height: 30)
                Circle().trim(from: 0, to: 0.68).stroke(MRColor.accentDeep, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 30, height: 30).rotationEffect(.degrees(pulse ? 360 : 0))
            }
            Text(stages[stageIndex])
                .font(.mrBody.weight(.semibold))
                .foregroundStyle(MRColor.text)
                .lineLimit(2)
                .contentTransition(.opacity)
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 950_000_000)
                withAnimation(.easeInOut(duration: 0.18)) {
                    stageIndex = min(stageIndex + 1, stages.count - 1)
                }
            }
        }
    }
}

private struct QuickAction: View {
    let icon: String
    let action: () -> Void
    let label: String
    var size: CGFloat = 45
    var tint: Color = MRColor.text

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MRColor.secondaryText)
            }
            .frame(width: size, height: size)
            .background(.white.opacity(0.72))
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
