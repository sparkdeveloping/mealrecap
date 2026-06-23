import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    func connectionStatus() -> AppleHealthConnectionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        guard let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return .unavailable
        }
        switch store.authorizationStatus(for: activeEnergy) {
        case .sharingAuthorized:
            return .connected
        case .sharingDenied:
            return .permissionDenied
        case .notDetermined:
            return .notConnected
        @unknown default:
            return .notConnected
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitAccessError.unavailable }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .height)!,
            HKObjectType.workoutType()
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func readTodaySummary() async throws -> HealthSummary {
        guard HKHealthStore.isHealthDataAvailable() else { return .empty }
        let active = try await cumulative(.activeEnergyBurned, unit: .kilocalorie())
        let resting = try await cumulative(.basalEnergyBurned, unit: .kilocalorie())
        let steps = try await cumulative(.stepCount, unit: .count())
        let activeValue = Int(active.rounded())
        let restingValue = Int(resting.rounded())
        let stepsValue = Int(steps.rounded())
        return HealthSummary(activeCalories: activeValue, restingCalories: restingValue, totalCalories: activeValue + restingValue, steps: stepsValue)
    }

    private func cumulative(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: value)
                }
            }
            store.execute(query)
        }
    }
}

enum HealthKitAccessError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data isn't available yet. You can continue with a manual calorie goal."
        }
    }
}
