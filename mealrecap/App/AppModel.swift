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
    @Published var proteinTarget: Int?
    @Published var errorMessage: String?
    @Published var shouldShowPaywall = false
    @Published var paywallReason: PaywallReason = .general
    @Published var isProcessingEntry = false
    @Published var processingTitle = ""
    @Published var processingSubtitle = ""
    @Published var hasCompletedOnboarding = false
    @Published var goalMilestoneMessage: String?

    let auth = AuthService()
    let store = FirestoreService()
    let functions = FunctionsService()
    let storage = PhotoStorageService()
    let health = HealthKitService()
    let speech = SpeechService()
    let purchases = StoreKitService()
    let smartActions = SmartActionService()
    let remote = RemoteConfigService()

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
                Task { @MainActor in self?.meals = meals.sorted { $0.createdAt < $1.createdAt } }
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
            await refreshHealth()
        } catch {
            errorMessage = friendlyHealthErrorMessage(error)
        }
    }

    func completeOnboarding(displayName: String?, goalCalories: Int, goalMode: String, proteinTarget: Int?) async {
        guard let uid = session?.uid else { return }
        do {
            try await store.updateOnboardingPreferences(
                uid: uid,
                displayName: displayName,
                goalCalories: goalCalories,
                goalMode: goalMode,
                proteinTarget: proteinTarget
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

    func logText(_ text: String, source: MealSource = .text) async {
        guard let uid = session?.uid else { return }
        beginProcessing(stages: MealProcessingStages.text)
        defer { endProcessing() }
        await runSmartAction(.text, reason: .textLimit) {
            let result = try await self.functions.analyzeMealText(text: text, date: self.selectedDate)
            self.setProcessingStage(.updatingDay)
            try await self.store.saveUserMessage(uid: uid, date: self.selectedDate, content: text, source: source)
            try await self.store.saveMealAnalysis(uid: uid, date: self.selectedDate, result: result, source: source, originPrompt: text)
            try await self.store.saveAssistantMessage(uid: uid, date: self.selectedDate, content: result.assistantSummary)
        }
    }

    func logDayRecap(_ text: String) async {
        guard let uid = session?.uid else { return }
        beginProcessing(stages: MealProcessingStages.dayRecap)
        defer { endProcessing() }
        await runSmartAction(.dayRecap, reason: .dayRecapLimit) {
            let result = try await self.functions.analyzeDayRecap(text: text, date: self.selectedDate)
            self.setProcessingStage(.updatingDay)
            try await self.store.saveUserMessage(uid: uid, date: self.selectedDate, content: text, source: .dayRecap)
            for meal in result.meals {
                try await self.store.saveMealAnalysis(uid: uid, date: self.selectedDate, result: meal, source: .dayRecap, originPrompt: text)
            }
            try await self.store.saveAssistantMessage(uid: uid, date: self.selectedDate, content: result.assistantSummary)
        }
    }

    func analyzePhoto(_ imageData: Data) async {
        guard let uid = session?.uid else { return }
        beginProcessing(stages: MealProcessingStages.photo)
        defer { endProcessing() }
        await runSmartAction(.photo, reason: .photoLimit) {
            let mealId = UUID().uuidString
            self.setProcessingStage(.readingMeal)
            let path = try await self.storage.uploadMealPhoto(uid: uid, date: self.selectedDate, mealId: mealId, jpegData: imageData)
            self.setProcessingStage(.estimatingPortions)
            let result = try await self.functions.analyzeMealPhoto(storagePath: path, date: self.selectedDate)
            self.setProcessingStage(.updatingDay)
            try await self.store.saveMealAnalysis(uid: uid, date: self.selectedDate, result: result, source: .camera, presetMealId: mealId, photoPath: path, originPrompt: "Photo analysis")
            try await self.store.saveAssistantMessage(uid: uid, date: self.selectedDate, content: result.assistantSummary)
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
            let imageStatus = result["imageStatus"] as? String ?? ((photoPath?.isEmpty == false || imageURL?.isEmpty == false) ? "ready" : "failed")
            try await store.updateMealImageState(uid: uid, date: selectedDate, mealId: meal.id, photoPath: photoPath, imageURL: imageURL, imageStatus: imageStatus)
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
            if entitlement.isPro == false {
                let allowed = try await smartActions.canUse(uid: uid, kind: action, remote: remote.limits)
                guard allowed else {
                    usage = try await smartActions.fetchUsage(uid: uid)
                    paywallReason = reason
                    shouldShowPaywall = true
                    return
                }
            }

            try await operation()

            if entitlement.isPro == false {
                try await smartActions.consume(uid: uid, kind: action, remote: remote.limits)
            }
            usage = try await smartActions.fetchUsage(uid: uid)
        } catch {
            usage = (try? await smartActions.fetchUsage(uid: uid)) ?? usage
            errorMessage = friendlyErrorMessage(error)
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
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    let content = UNMutableNotificationContent()
                    content.title = "MealRecap"
                    content.body = message
                    content.sound = .default
                    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
                }
            default:
                return
            }
        }
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = localized.lowercased()

        if lower.contains("unauthenticated") {
            return "MealRecap could not connect securely right now. Please try again later."
        }

        return localized
    }

    private func friendlyHealthErrorMessage(_ error: Error) -> String {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = localized.lowercased()
        if lower.contains("entitlement") || lower.contains("com.apple.developer.healthkit") {
            return "Health data isn't available in this build yet. You can keep using MealRecap with a manual calorie goal."
        }
        return localized
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
        proteinTarget = nil
        hasCompletedOnboarding = false
    }
}
