import Foundation
@preconcurrency import UserNotifications

struct MealHabitWindow: Identifiable, Equatable {
    var id: String { mealType.rawValue }
    let mealType: MealType
    let usualMinuteOfDay: Int
    let sampleCount: Int

    var title: String { mealType.title }

    var displayTime: String {
        var components = DateComponents()
        components.hour = usualMinuteOfDay / 60
        components.minute = usualMinuteOfDay % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct MealHabitSummary: Equatable {
    var learnedMealCount: Int
    var windows: [MealHabitWindow]
    var remindersEnabled: Bool

    static let empty = MealHabitSummary(learnedMealCount: 0, windows: [], remindersEnabled: false)

    var headline: String {
        guard !windows.isEmpty else { return "Learning your meal rhythm" }
        return windows.map { "\($0.title) \($0.displayTime)" }.joined(separator: " · ")
    }

    var detail: String {
        if windows.isEmpty {
            return learnedMealCount < 3
                ? "Log a few meals and MealRecap will learn your usual eating times."
                : "MealRecap is still looking for a consistent pattern."
        }
        return remindersEnabled
            ? "MealRecap will remind you around your usual meal times."
            : "Turn on reminders to get gentle nudges around your usual meal times."
    }
}

private struct MealHabitSample: Codable, Equatable {
    let id: String
    let mealTypeRawValue: String
    let timestamp: Date
    let minuteOfDay: Int
}

@MainActor
final class MealHabitReminderService {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func remindersEnabled(uid: String) -> Bool {
        defaults.bool(forKey: remindersEnabledKey(uid: uid))
    }

    func setRemindersEnabled(_ enabled: Bool, uid: String) async {
        defaults.set(enabled, forKey: remindersEnabledKey(uid: uid))
        if enabled {
            await scheduleReminders(uid: uid, selectedDate: Date(), todaysMeals: [])
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers(uid: uid))
        }
    }

    func ingest(meals: [MealEntry], uid: String) {
        guard !meals.isEmpty else { return }
        var samples = loadSamples(uid: uid)
        var knownIDs = Set(samples.map(\.id))

        for meal in meals where meal.mealType != .unknown {
            guard knownIDs.insert(meal.id).inserted else { continue }
            samples.append(
                MealHabitSample(
                    id: meal.id,
                    mealTypeRawValue: meal.mealType.rawValue,
                    timestamp: meal.createdAt,
                    minuteOfDay: minuteOfDay(for: meal.createdAt)
                )
            )
        }

        let cutoff = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date.distantPast
        samples = samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(160)
            .map { $0 }
        saveSamples(samples, uid: uid)
    }

    func summary(uid: String) -> MealHabitSummary {
        let samples = loadSamples(uid: uid)
        return MealHabitSummary(
            learnedMealCount: samples.count,
            windows: habitWindows(from: samples),
            remindersEnabled: remindersEnabled(uid: uid)
        )
    }

    func scheduleReminders(uid: String, selectedDate: Date, todaysMeals: [MealEntry]) async {
        guard remindersEnabled(uid: uid) else { return }
        let settings = await notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let windows = summary(uid: uid).windows
        guard !windows.isEmpty else { return }

        let loggedTypesToday = Set(todaysMeals.map(\.mealType))
        let identifiers = reminderIdentifiers(uid: uid)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        for window in windows where !loggedTypesToday.contains(window.mealType) {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            dateComponents.hour = window.usualMinuteOfDay / 60
            dateComponents.minute = window.usualMinuteOfDay % 60

            guard let fireDate = calendar.date(from: dateComponents), fireDate > Date().addingTimeInterval(10 * 60) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "MealRecap"
            content.body = "Want to log \(window.title.lowercased())? This is around your usual time."
            content.sound = .default

            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(identifier: reminderIdentifier(uid: uid, mealType: window.mealType), content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func requestReminderPermission(uid: String) async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await setRemindersEnabled(granted, uid: uid)
            return granted
        } catch {
            return false
        }
    }

    private func habitWindows(from samples: [MealHabitSample]) -> [MealHabitWindow] {
        let grouped = Dictionary(grouping: samples) { $0.mealTypeRawValue }
        return grouped.compactMap { rawValue, samples in
            guard samples.count >= 2, let mealType = MealType(rawValue: rawValue), mealType != .unknown else { return nil }
            let sortedMinutes = samples.map(\.minuteOfDay).sorted()
            let median = sortedMinutes[sortedMinutes.count / 2]
            return MealHabitWindow(mealType: mealType, usualMinuteOfDay: median, sampleCount: samples.count)
        }
        .sorted { lhs, rhs in
            if lhs.usualMinuteOfDay == rhs.usualMinuteOfDay { return lhs.mealType.rawValue < rhs.mealType.rawValue }
            return lhs.usualMinuteOfDay < rhs.usualMinuteOfDay
        }
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func loadSamples(uid: String) -> [MealHabitSample] {
        guard let data = defaults.data(forKey: samplesKey(uid: uid)) else { return [] }
        return (try? JSONDecoder().decode([MealHabitSample].self, from: data)) ?? []
    }

    private func saveSamples(_ samples: [MealHabitSample], uid: String) {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        defaults.set(data, forKey: samplesKey(uid: uid))
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func samplesKey(uid: String) -> String { "mealrecap.mealHabitSamples.\(uid).v1" }
    private func remindersEnabledKey(uid: String) -> String { "mealrecap.mealHabitRemindersEnabled.\(uid).v1" }

    private func reminderIdentifier(uid: String, mealType: MealType) -> String {
        "mealrecap.habitReminder.\(uid).\(mealType.rawValue)"
    }

    private func reminderIdentifiers(uid: String) -> [String] {
        MealType.allCases.map { reminderIdentifier(uid: uid, mealType: $0) }
    }
}
