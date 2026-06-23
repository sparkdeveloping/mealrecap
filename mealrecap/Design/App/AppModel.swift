import Foundation
import SwiftUI
@preconcurrency import UserNotifications

struct MealProcessingStage: Equatable {
    let title: String
    let subtitle: String

    static let readingMeal = MealProcessingStage(title: "Reading your meal", subtitle: "Pulling out foods, portions, and context…")
    static let estimatingPortions = MealProcessingStage(title: "Estimating portions", subtitle: "Translating your meal into realistic serving sizes…")
    static let calculatingCalories = MealProcessingStage(title: "Calculating calories", subtitle: "Checking the day’s energy estimate…")
    static let balancingMacros = MealProcessingStage(title: "Balancing macros", subtitle: "Protein, carbs, and fat are being organized…")
    static let updatingDay = MealProcessingStage(title: "Updating your day", subtitle: "Saving the meal and refreshing your totals…")

    static func creatingMealPhoto(_ subtitle: String = "Creating a clean food image for your recap…") -> MealProcessingStage {
        MealProcessingStage(title: "Creating meal photo", subtitle: subtitle)
    }
}

enum MealProcessingStages {
    static let text: [MealProcessingStage] = [
        .readingMeal,
        .estimatingPortions,
        .calculatingCalories,
        .balancingMacros,
        .creatingMealPhoto(),
        .updatingDay
    ]

    static let photo: [MealProcessingStage] = [
        MealProcessingStage(title: "Reading your photo", subtitle: "Looking for foods, portions, and visible context…"),
        .estimatingPortions,
        .calculatingCalories,
        .balancingMacros,
        .updatingDay
    ]

    static let dayRecap: [MealProcessingStage] = [
        MealProcessingStage(title: "Reading your day", subtitle: "Separating meals, snacks, drinks, and timing…"),
        .estimatingPortions,
        .calculatingCalories,
        .balancingMacros,
        .creatingMealPhoto("Preparing photos for the meals in your recap…"),
        .updatingDay
    ]

    static func image(for title: String) -> [MealProcessingStage] {
        [
            .creatingMealPhoto("Making a clean, realistic image for \(title)…"),
            .updatingDay
        ]
    }
}

enum CalorieProgressMilestone: Int, CaseIterable, Identifiable {
    case quarter = 25
    case half = 50
    case threeQuarters = 75
    case almostThere = 90
    case goal = 100

    var id: Int { rawValue }

    var message: String {
        switch self {
        case .quarter: "25% of today logged"
        case .half: "Halfway to today’s goal"
        case .threeQuarters: "75% of today logged"
        case .almostThere: "You’re 90% there"
        case .goal: "Today’s goal complete"
        }
    }

    static func crossed(previous: Double, current: Double) -> [CalorieProgressMilestone] {
        let previousPercent = Int((previous * 100).rounded(.down))
        let currentPercent = Int((current * 100).rounded(.down))
        return allCases.filter { previousPercent < $0.rawValue && currentPercent >= $0.rawValue }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var session: UserSession?
    @Published var isBooting = true
    @Published var selectedDate = Date()
    @Published var activeDay: MealDay?
    @Published var meals: [MealEntry] = []
    @Published var messages: [DayMessage] = []
    @Published var usage: SmartActionUsage = .empty
    @Published var entitlement: ProEntitlement = .free
    @Published var healthSummary: HealthSummary = .empty
    @Published var appleHealthStatus: AppleHealthConnectionStatus = .notConnected
    @Published var proteinTarget: Int?
    @Published var errorMessage: String?
    @Published var shouldShowPaywall = false
    @Published var paywallReason: PaywallReason = .general
    @Published var isProcessingEntry = false
    @Published var processingTitle = ""
    @Published var processingSubtitle = ""
    @Published var hasCompletedOnboarding = false
    @Published var goalMilestoneMessage: String?
    @Published var mealHabitSummary: MealHabitSummary = .empty

    let auth = AuthService()
    let store = FirestoreService()
    let functions = FunctionsService()
    let storage = PhotoStorageService()
    let health = HealthKitService()
    let speech = SpeechService()
    let purchases = StoreKitService()
    let smartActions = SmartActionService()
    let remote = RemoteConfigService()
    let habitReminders = MealHabitReminderService()

    private var dayListener: Any?
    private var mealListener: Any?
    private var messageListener: Any?
    private var processingStageTask: Task<Void, Never>?

    func start() async {
        await remote.configureAndFetch()
        await purchases.configure()
        auth.listen { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.session = result
                if result != nil {
                    await self.bootstrapSignedInUser()
                    self.isBooting = false
                } else {
                    self.clearLoadedState()
                    self.isBooting = false
                }
            }
        }
    }

    func bootstrapSignedInUser() async {
        guard let uid = session?.uid else { return }
        do {
            try await store.ensureProfile(uid: uid)
            hasCompletedOnboarding = try await store.fetchHasCompletedOnboarding(uid: uid)
            proteinTarget = try await store.fetchProteinTarget(uid: uid)
            usage = try await smartActions.fetchUsage(uid: uid)
            entitlement = try await store.fetchEntitlement(uid: uid)
            if purchases.isPro {
                entitlement = ProEntitlement(isPro: true, expiresAt: nil)
                try? await store.updateEntitlement(uid: uid, isPro: true, expiresAt: nil)
            }
            mealHabitSummary = habitReminders.summary(uid: uid)
            await loadDate(selectedDate)
            await refreshHealth()
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func loadDate(_ date: Date) async {
        selectedDate = Calendar.current.startOfDay(for: date)
        guard let uid = session?.uid else { return }
        do {
            try await store.ensureDay(uid: uid, date: selectedDate)
            dayListener = store.observeDay(uid: uid, date: selectedDate) { [weak self] day in
                Task { @MainActor in
                    guard let self else { return }
                    let previous = self.activeDay
                    self.activeDay = day
                    if let previous, let day {
                        self.handleCalorieMilestones(previous: previous, current: day)
                    }
                }
            }
            mealListener = store.observeMeals(uid: uid, date: selectedDate) { [weak self] meals in
                Task { @MainActor in
                    guard let self else { return }
                    let sortedMeals = meals.sorted { $0.createdAt > $1.createdAt }
                    self.meals = sortedMeals
                    self.habitReminders.ingest(meals: sortedMeals, uid: uid)
                    self.mealHabitSummary = self.habitReminders.summary(uid: uid)
                    await self.habitReminders.scheduleReminders(uid: uid, selectedDate: self.selectedDate, todaysMeals: sortedMeals)
                }
            }
            messageListener = store.observeMessages(uid: uid, date: selectedDate) { [weak self] messages in
                Task { @MainActor in self?.messages = messages.sorted { $0.createdAt < $1.createdAt } }
            }
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func refreshHealth() async {
        do {
            appleHealthStatus = health.connectionStatus()
            guard appleHealthStatus == .connected else { return }
            healthSummary = try await health.readTodaySummary()
            if let uid = session?.uid {
                try await store.updateHealth(uid: uid, date: selectedDate, summary: healthSummary)
            }
        } catch {
            // Health permission may not be granted yet. Keep the app usable.
        }
    }

    func requestHealthAccess() async {
        do {
            try await health.requestAuthorization()
            appleHealthStatus = health.connectionStatus()
            await refreshHealth()
        } catch {
            appleHealthStatus = health.connectionStatus()
            errorMessage = friendlyHealthErrorMessage(error)
        }
    }

    func activateProEntitlement() async {
        entitlement = ProEntitlement(isPro: true, expiresAt: nil)
        guard let uid = session?.uid else { return }
        try? await store.updateEntitlement(uid: uid, isPro: true, expiresAt: nil)
        usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
    }

    func restorePurchases() async -> StoreKitService.RestoreState {
        let state = await purchases.restore()
        if state == .restored {
            await activateProEntitlement()
        }
        return state
    }

    func completeOnboarding(displayName: String?, goalCalories: Int, goalMode: String, proteinTarget: Int?, goalSetupMode: String? = nil, goalRecommendationSummary: String? = nil) async {
        guard let uid = session?.uid else { return }
        do {
            try await store.updateOnboardingPreferences(
                uid: uid,
                displayName: displayName,
                goalCalories: goalCalories,
                goalMode: goalMode,
                proteinTarget: proteinTarget,
                goalSetupMode: goalSetupMode,
                goalRecommendationSummary: goalRecommendationSummary
            )
            hasCompletedOnboarding = true
            self.proteinTarget = proteinTarget
            await loadDate(selectedDate)
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func signOut() {
        do {
            try auth.signOut()
            clearLoadedState()
            session = nil
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func backendPing() async {
        do {
            let result = try await functions.ping()
            errorMessage = "Backend ping: \(result)"
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func analyzeMealForReview(_ text: String, source: MealReviewSource) async -> PendingMealReview? {
        guard let uid = session?.uid else { return nil }
        beginProcessing(stages: MealProcessingStages.text)
        defer { endProcessing() }
        do {
            let action: SmartActionKind = source == .voice ? .voice : .text
            let reason: PaywallReason = source == .voice ? .textLimit : .textLimit
            guard try await ensureSmartActionAllowed(action, reason: reason) else { return nil }
            let result = try await functions.analyzeMealText(text: text, date: selectedDate)
            _ = uid
            return PendingMealReview(result: result, source: source, originPrompt: text)
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return nil
        }
    }

    func analyzeDayRecapForReview(_ text: String) async -> PendingDayReview? {
        guard let uid = session?.uid else { return nil }
        beginProcessing(stages: MealProcessingStages.dayRecap)
        defer { endProcessing() }
        do {
            guard try await ensureSmartActionAllowed(.dayRecap, reason: .dayRecapLimit) else { return nil }
            let result = try await functions.analyzeDayRecap(text: text, date: selectedDate)
            let meals = result.meals.map {
                PendingMealReview(result: $0, source: .dayRecap, originPrompt: text)
            }
            _ = uid
            return PendingDayReview(meals: meals, assistantSummary: result.assistantSummary, originPrompt: text)
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return nil
        }
    }

    func addReviewedMeal(_ pending: PendingMealReview, portionFactor: Double) async -> Bool {
        guard let uid = session?.uid else { return false }
        beginProcessing(stages: [.updatingDay])
        defer { endProcessing() }
        do {
            let scaledResult = pending.result.scaled(by: portionFactor)
            try await store.saveUserMessage(uid: uid, date: selectedDate, content: pending.originPrompt ?? scaledResult.title, source: pending.source.mealSource)
            try await store.saveMealAnalysis(uid: uid, date: selectedDate, result: scaledResult, source: pending.source.mealSource, presetMealId: pending.id, photoPath: pending.photoPath, originPrompt: pending.originPrompt)
            try await store.saveAssistantMessage(uid: uid, date: selectedDate, content: scaledResult.assistantSummary)
            try await consumeSmartActionIfNeeded(pending.source == .voice ? .voice : .text)
            showAddSuccess()
            return true
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return false
        }
    }

    func addReviewedDay(_ pending: PendingDayReview, selections: [String: Bool], portions: [String: Double]) async -> Bool {
        guard let uid = session?.uid else { return false }
        let selectedMeals = pending.meals.filter { selections[$0.id, default: true] }
        guard !selectedMeals.isEmpty else { return false }
        beginProcessing(stages: [.updatingDay])
        defer { endProcessing() }
        do {
            try await store.saveUserMessage(uid: uid, date: selectedDate, content: pending.originPrompt, source: .dayRecap)
            for meal in selectedMeals {
                let factor = portions[meal.id, default: 1]
                try await store.saveMealAnalysis(uid: uid, date: selectedDate, result: meal.result.scaled(by: factor), source: .dayRecap, presetMealId: meal.id, originPrompt: pending.originPrompt)
            }
            try await store.saveAssistantMessage(uid: uid, date: selectedDate, content: pending.assistantSummary)
            try await consumeSmartActionIfNeeded(.dayRecap)
            showAddSuccess()
            return true
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return false
        }
    }

    func analyzePhotoForReview(_ imageData: Data) async -> PendingPhotoMeal? {
        guard let uid = session?.uid else { return nil }
        beginProcessing(stages: MealProcessingStages.photo)
        defer { endProcessing() }
        do {
            guard try await ensureSmartActionAllowed(.photo, reason: .photoLimit) else { return nil }
            let mealId = UUID().uuidString
            setProcessingStage(.readingMeal)
            let path = try await storage.uploadMealPhoto(uid: uid, date: selectedDate, mealId: mealId, jpegData: imageData)
            setProcessingStage(.estimatingPortions)
            var result = try await functions.analyzeMealPhoto(storagePath: path, date: selectedDate)
            result.photoPath = result.photoPath ?? path
            return PendingPhotoMeal(mealId: mealId, photoPath: path, result: result)
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return nil
        }
    }

    func addReviewedPhotoMeal(_ pending: PendingPhotoMeal, portionFactor: Double) async -> Bool {
        guard let uid = session?.uid else { return false }
        beginProcessing(stages: [.updatingDay])
        defer { endProcessing() }
        do {
            let scaledResult = pending.result.scaled(by: portionFactor)
            try await store.saveMealAnalysis(uid: uid, date: selectedDate, result: scaledResult, source: .camera, presetMealId: pending.mealId, photoPath: pending.photoPath, originPrompt: nil)
            try await store.saveAssistantMessage(uid: uid, date: selectedDate, content: scaledResult.assistantSummary)
            try await consumeSmartActionIfNeeded(.photo)
            markPaywallMilestoneIfNeeded(.firstPhotoSuccess)
            showAddSuccess()
            return true
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
            return false
        }
    }

    func deleteMeal(_ meal: MealEntry) async {
        guard let uid = session?.uid else { return }
        do {
            try await store.deleteMeal(uid: uid, date: selectedDate, mealId: meal.id)
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func updateMeal(_ meal: MealEntry, title: String, mealType: MealType, foodCategory: String?, assistantNote: String?) async {
        guard let uid = session?.uid else { return }
        do {
            try await store.updateMeal(uid: uid, date: selectedDate, meal: meal, title: title, mealType: mealType, foodCategory: foodCategory, assistantNote: assistantNote)
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func generateImage(for meal: MealEntry) async {
        guard let uid = session?.uid else { return }
        beginProcessing(stages: MealProcessingStages.image(for: meal.title))
        defer { endProcessing() }
        do {
            try await store.updateMealImageState(uid: uid, date: selectedDate, mealId: meal.id, photoPath: meal.photoPath, imageURL: meal.imageURL, imageStatus: "pending")
            let result = try await functions.generateMealImage(uid: uid, date: selectedDate, meal: meal)
            let photoPath = result["photoPath"] as? String
            let imageURL = result["imageURL"] as? String
            let imageKind = result["imageKind"] as? String
            let imageAlpha = result["imageAlpha"] as? String
            let imageStyleVersion = result["imageStyleVersion"] as? String
            let imageStatus = result["imageStatus"] as? String ?? ((photoPath?.isEmpty == false || imageURL?.isEmpty == false) ? "ready" : "failed")
            try await store.updateMealImageState(uid: uid, date: selectedDate, mealId: meal.id, photoPath: photoPath, imageURL: imageURL, imageStatus: imageStatus, imageKind: imageKind, imageAlpha: imageAlpha, imageStyleVersion: imageStyleVersion)
        } catch {
            try? await store.updateMealImageState(uid: uid, date: selectedDate, mealId: meal.id, photoPath: nil, imageURL: nil, imageStatus: "failed")
            errorMessage = "MealRecap could not create a photo for this meal. You can retry from the meal card."
        }
    }

    func generateMissingImagesForSelectedDay() async {
        guard let uid = session?.uid else { return }
        beginProcessing(stages: [.creatingMealPhoto("Backfilling missing images for this day…"), .updatingDay])
        defer { endProcessing() }
        do {
            _ = try await functions.backfillMealImages(uid: uid, date: selectedDate)
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    private func runSmartAction(_ action: SmartActionKind, reason: PaywallReason, operation: @escaping () async throws -> Void) async {
        guard let uid = session?.uid else {
            errorMessage = "Sign in to use MealRecap."
            return
        }
        do {
            guard try await ensureSmartActionAllowed(action, reason: reason) else { return }

            try await operation()

            try await consumeSmartActionIfNeeded(action)
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
        }
    }

    private func ensureSmartActionAllowed(_ action: SmartActionKind, reason: PaywallReason) async throws -> Bool {
        guard let uid = session?.uid else {
            errorMessage = "Sign in to use MealRecap."
            return false
        }
        guard entitlement.isPro == false else { return true }
        let allowed = try await smartActions.canUse(uid: uid, kind: action, remote: remote.limits)
        guard allowed else {
            usage = try await smartActions.fetchUsage(uid: uid)
            paywallReason = reason
            shouldShowPaywall = true
            return false
        }
        return true
    }

    private func consumeSmartActionIfNeeded(_ action: SmartActionKind) async throws {
        guard let uid = session?.uid else { return }
        if entitlement.isPro == false {
            try await smartActions.consume(uid: uid, kind: action, remote: remote.limits)
        }
        usage = try await smartActions.fetchUsage(uid: uid)
    }

    private func showAddSuccess() {
        goalMilestoneMessage = "Added to today"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if self.goalMilestoneMessage == "Added to today" {
                withAnimation(.easeInOut(duration: 0.18)) { self.goalMilestoneMessage = nil }
            }
        }
    }

    private func beginProcessing(stages: [MealProcessingStage]) {
        processingStageTask?.cancel()
        let stages = stages.isEmpty ? [.readingMeal] : stages
        isProcessingEntry = true
        applyProcessingStage(stages[0])
        processingStageTask = Task { @MainActor in
            for stage in stages.dropFirst() {
                try? await Task.sleep(nanoseconds: 950_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.applyProcessingStage(stage)
                }
            }
        }
    }

    private func setProcessingStage(_ stage: MealProcessingStage) {
        processingStageTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            applyProcessingStage(stage)
        }
    }

    private func endProcessing() {
        processingStageTask?.cancel()
        processingStageTask = nil
        isProcessingEntry = false
    }

    private func applyProcessingStage(_ stage: MealProcessingStage) {
        processingTitle = stage.title
        processingSubtitle = stage.subtitle
    }

    private func handleCalorieMilestones(previous: MealDay, current: MealDay) {
        let goal = max(current.goalCalories, 1)
        let crossed = CalorieProgressMilestone.crossed(
            previous: Double(previous.caloriesIn) / Double(goal),
            current: Double(current.caloriesIn) / Double(goal)
        )
        for milestone in crossed {
            emitGoalMilestone(milestone, dayID: current.id)
        }
    }

    private func emitGoalMilestone(_ milestone: CalorieProgressMilestone, dayID: String) {
        let key = "goal-milestone-\(dayID)-\(milestone.rawValue)"
        guard UserDefaults.standard.bool(forKey: key) == false else { return }
        UserDefaults.standard.set(true, forKey: key)

        let message = milestone.message
        goalMilestoneMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if self.goalMilestoneMessage == message {
                withAnimation(.easeInOut(duration: 0.18)) { self.goalMilestoneMessage = nil }
            }
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                content.title = "MealRecap"
                content.body = message
                content.sound = .default
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
            default:
                return
            }
        }
    }

    func enableMealTimeReminders() async {
        guard let uid = session?.uid else { return }
        let granted = await habitReminders.requestReminderPermission(uid: uid)
        mealHabitSummary = habitReminders.summary(uid: uid)
        if granted {
            await habitReminders.scheduleReminders(uid: uid, selectedDate: selectedDate, todaysMeals: meals)
            goalMilestoneMessage = "Meal time reminders are on"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                if self.goalMilestoneMessage == "Meal time reminders are on" {
                    withAnimation(.easeInOut(duration: 0.18)) { self.goalMilestoneMessage = nil }
                }
            }
        } else {
            errorMessage = "Notifications are off. You can enable MealRecap reminders in iOS Settings."
        }
    }

    func requestSmartRemindersFromOnboarding() async {
        guard let uid = session?.uid else {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return
        }
        _ = await habitReminders.requestReminderPermission(uid: uid)
        mealHabitSummary = habitReminders.summary(uid: uid)
        await habitReminders.scheduleReminders(uid: uid, selectedDate: selectedDate, todaysMeals: meals)
    }

    func requestPostOnboardingNotificationsIfNeeded() async {
        guard hasCompletedOnboarding, let uid = session?.uid else { return }
        let key = "mealrecap.didAskPostOnboardingNotifications.\(uid).v1"
        guard UserDefaults.standard.bool(forKey: key) == false else { return }

        let settings = await notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        UserDefaults.standard.set(true, forKey: key)
        let granted = await habitReminders.requestReminderPermission(uid: uid)
        mealHabitSummary = habitReminders.summary(uid: uid)
        if granted {
            await habitReminders.scheduleReminders(uid: uid, selectedDate: selectedDate, todaysMeals: meals)
        }
    }

    func disableMealTimeReminders() async {
        guard let uid = session?.uid else { return }
        await habitReminders.setRemindersEnabled(false, uid: uid)
        mealHabitSummary = habitReminders.summary(uid: uid)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = localized.lowercased()

        if lower.contains("offline") ||
            lower.contains("network") ||
            lower.contains("unavailable") ||
            lower.contains("could not reach cloud firestore") ||
            lower.contains("client is offline") ||
            lower.contains("offline mode") {
            return "You’re offline. MealRecap will sync when your connection returns."
        }

        if lower.contains("unauthenticated") {
            return "MealRecap could not connect securely right now. Please try again later."
        }

        if lower.contains("firebase") ||
            lower.contains("firestore") ||
            lower.contains("backend") ||
            lower.contains("function") ||
            lower.contains("document") {
            return "Couldn’t analyze this right now. Try again."
        }

        return localized.isEmpty ? "Couldn’t analyze this right now. Try again." : localized
    }

    private func friendlyHealthErrorMessage(_ error: Error) -> String {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = localized.lowercased()
        if lower.contains("entitlement") || lower.contains("com.apple.developer.healthkit") {
            return "Health data isn't available in this build yet. You can keep using MealRecap with a manual calorie goal."
        }
        if lower.contains("unavailable") || lower.contains("not authorized") || lower.contains("permission") {
            return "Health data is not available right now. You can keep using MealRecap without it."
        }
        return localized.isEmpty ? "Health data is not available right now. You can keep using MealRecap without it." : localized
    }

    func markPaywallMilestoneIfNeeded(_ trigger: PaywallReason) {
        guard entitlement.isPro == false else { return }
        paywallReason = trigger
        shouldShowPaywall = true
    }

    private func clearLoadedState() {
        activeDay = nil
        meals = []
        messages = []
        usage = .empty
        entitlement = .free
        healthSummary = .empty
        appleHealthStatus = .notConnected
        proteinTarget = nil
        hasCompletedOnboarding = false
        mealHabitSummary = .empty
    }
}
