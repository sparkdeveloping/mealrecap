import SwiftUI

struct DayView: View {
    @EnvironmentObject private var app: AppModel
    let date: Date

    private let pageHorizontalPadding: CGFloat = 22

    @Namespace private var mealZoomNamespace
    @State private var message = ""
    @State private var showCalendar = false
    @State private var showVoice = false
    @State private var showPhoto = false
    @State private var showRecap = false
    @State private var showProfile = false
    @State private var showFocusedComposer = false
    @State private var isComposerMenuOpen = false
    @State private var scrollChromeProgress = 0.0
    @State private var selectedMeal: MealEntry?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let viewportWidth = proxy.size.width
                let viewportHeight = proxy.size.height
                let contentWidth = max(0, viewportWidth - pageHorizontalPadding * 2)

                ZStack(alignment: .bottom) {
                    AmbientBackground()
                        .frame(width: viewportWidth, height: viewportHeight)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            CleanDayHero(
                                date: date,
                                day: app.activeDay,
                                meals: app.meals,
                                messages: app.messages,
                                usage: app.usage,
                                entitlement: app.entitlement,
                                proteinTarget: app.proteinTarget,
                                onUpgrade: { app.markPaywallMilestoneIfNeeded(.general) },
                                onConnectHealth: { Task { await app.requestHealthAccess() } }
                            )
                            .padding(.top, proxy.safeAreaInsets.top + 92)

                            if app.meals.isEmpty {
                                CleanEmptyPrompt { prompt in
                                    message = prompt
                                    showFocusedComposer = true
                                }
                                    .padding(.top, 2)
                            } else {
                                CleanMealFeed(
                                    meals: app.meals,
                                    messages: app.messages,
                                    day: app.activeDay,
                                    namespace: mealZoomNamespace,
                                    onSelectMeal: { meal in
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { selectedMeal = meal }
                                    },
                                    onGenerateMissingImages: nil
                                )
                            }

                            Color.clear.frame(height: 118 + proxy.safeAreaInsets.bottom)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.horizontal, pageHorizontalPadding)
                        .frame(width: viewportWidth, alignment: .center)
                        .padding(.bottom, 24)
                    }
                    .frame(width: viewportWidth)
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                    .contentMargins(.top, 0, for: .scrollContent)
                    .contentMargins(.bottom, 0, for: .scrollContent)
                    .onScrollGeometryChange(for: Double.self) { geometry in
                        let rawOffset = geometry.contentOffset.y + geometry.contentInsets.top
                        return min(max(rawOffset / 96, 0), 1)
                    } action: { _, newValue in
                        scrollChromeProgress = newValue
                    }

                    FloatingTopChrome(
                        progress: scrollChromeProgress,
                        safeTop: proxy.safeAreaInsets.top,
                        viewportWidth: viewportWidth,
                        entitlement: app.entitlement,
                        onUpgrade: { app.markPaywallMilestoneIfNeeded(.general) },
                        onCalendar: { showCalendar = true },
                        onProfile: { showProfile = true }
                    )
                    .zIndex(4)

                    if isComposerMenuOpen {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    isComposerMenuOpen = false
                                }
                            }
                            .zIndex(2)
                    }

                    ChatComposer(
                        text: $message,
                        isActionMenuOpen: $isComposerMenuOpen,
                        send: submitMessage,
                        onPhoto: { showPhoto = true },
                        onVoice: { showVoice = true },
                        onRecap: { showRecap = true },
                        onUpgrade: { app.markPaywallMilestoneIfNeeded(.general) },
                        onFocus: { showFocusedComposer = true }
                    )
                    .frame(width: contentWidth)
                    .padding(.horizontal, pageHorizontalPadding)
                    .frame(width: viewportWidth)
                    .padding(.bottom, max(8, proxy.safeAreaInsets.bottom))
                    .zIndex(3)
                }
                .frame(width: viewportWidth, height: viewportHeight)
                .overlay {
                    if app.isProcessingEntry {
                        ProcessingOverlay(title: app.processingTitle, subtitle: app.processingSubtitle)
                            .zIndex(20)
                    }
                }
                .overlay(alignment: .top) {
                    if let message = app.goalMilestoneMessage {
                        GoalMilestoneToast(message: message)
                            .padding(.top, proxy.safeAreaInsets.top + 74)
                            .padding(.horizontal, pageHorizontalPadding)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(12)
                    }
                }
            }
            .navigationDestination(item: $selectedMeal) { meal in
                MealDetailFullScreen(meal: meal, day: app.activeDay, namespace: mealZoomNamespace)
                    .environmentObject(app)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .sheet(isPresented: $showCalendar) {
            CalendarSheet(selectedDate: $app.selectedDate) { date in
                showCalendar = false
                Task { await app.loadDate(date) }
            }
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showVoice) {
            VoiceLogSheet()
                .presentationDetents([.medium])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showPhoto) {
            PhotoLogSheet()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRecap) {
            DayRecapSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(
                meals: app.meals,
                day: app.activeDay,
                usage: app.usage,
                entitlement: app.entitlement,
                onUpgrade: { app.markPaywallMilestoneIfNeeded(.general) },
                onGenerateImages: { Task { await app.generateMissingImagesForSelectedDay() } }
            )
            .environmentObject(app)
            .presentationDetents([.large])
            .presentationCornerRadius(34)
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showFocusedComposer) {
            FocusedComposerView(
                text: $message,
                suggestions: suggestions,
                submit: { text in await app.logText(text) },
                onPhoto: { showFocusedComposer = false; showPhoto = true },
                onVoice: { showFocusedComposer = false; showVoice = true },
                onRecap: { showFocusedComposer = false; showRecap = true },
                onUpgrade: { showFocusedComposer = false; app.markPaywallMilestoneIfNeeded(.general) }
            )
        }
        .sensoryFeedback(.selection, trigger: isComposerMenuOpen)
        .sensoryFeedback(.selection, trigger: showCalendar)
        .sensoryFeedback(.selection, trigger: selectedMeal?.id)
    }

    private var suggestions: [String] {
        var seen = Set<String>()
        let prompts = app.meals.compactMap { meal -> String? in
            if let origin = meal.originPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !origin.isEmpty { return origin }
            return meal.title
        }
        return prompts.reversed().filter { prompt in
            let key = prompt.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }.prefix(3).map { $0 }
    }

    private func submitMessage() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        message = ""
        Task { await app.logText(trimmed) }
    }
}

private struct GoalMilestoneToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MRColor.accentDeep)
                .frame(width: 30, height: 30)
                .glassCircle(tint: MRColor.accentSoft.opacity(0.30), strokeOpacity: 0.34, shadowOpacity: 0.02)
            Text(message)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 330, minHeight: 50)
        .glassRounded(cornerRadius: 25, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.50, shadowOpacity: 0.08)
        .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .accessibilityLabel(message)
    }
}

private struct FloatingTopChrome: View {
    let progress: Double
    let safeTop: CGFloat
    let viewportWidth: CGFloat
    let entitlement: ProEntitlement
    let onUpgrade: () -> Void
    let onCalendar: () -> Void
    let onProfile: () -> Void

    var body: some View {
        let chromeHorizontalPadding: CGFloat = 16

        VStack(spacing: 0) {
            MinimalTopBar(
                entitlement: entitlement,
                onUpgrade: onUpgrade,
                onCalendar: onCalendar,
                onProfile: onProfile
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: max(0, viewportWidth - chromeHorizontalPadding * 2))
            .glassRounded(
                cornerRadius: 28,
                tint: MRColor.backgroundTop.opacity(0.05 + progress * 0.08),
                strokeOpacity: 0.22 + progress * 0.34,
                shadowOpacity: progress * 0.12 + 0.04
            )
            .padding(.horizontal, chromeHorizontalPadding)
            .padding(.top, safeTop + 6)
            .animation(.snappy(duration: 0.22), value: progress)

            Spacer()
        }
        .frame(width: viewportWidth)
        .background(alignment: .top) {
            Rectangle()
                .fill(.regularMaterial)
                .frame(width: viewportWidth, height: safeTop + 92)
                .opacity(progress * 0.52)
                .mask(
                    LinearGradient(
                        colors: [.black, .black.opacity(0.86), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(true)
    }
}
