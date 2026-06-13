import Foundation
import FirebaseFirestore

final class SmartActionService: @unchecked Sendable {
    private let db = Firestore.firestore()

    func fetchUsage(uid: String) async throws -> SmartActionUsage {
        let onboardingRef = db.collection("users").document(uid).collection("usage").document("onboarding")
        let weekRef = db.collection("users").document(uid).collection("usage").document(Self.weekID())
        let onboarding = try await onboardingRef.getDocument().data() ?? [:]
        let week = try await weekRef.getDocument().data() ?? [:]
        let startedAt = (onboarding["startedAt"] as? Timestamp)?.dateValue()
        let onboardingUsed = onboarding["used"] as? Int ?? 0
        let weeklyUsed = week["used"] as? Int ?? 0
        let isInWindow: Bool
        if let startedAt {
            let expires = Calendar.current.date(byAdding: .day, value: 7, to: startedAt) ?? Date()
            isInWindow = Date() < expires
        } else {
            isInWindow = true
        }
        return SmartActionUsage(weeklyUsed: weeklyUsed, onboardingUsed: onboardingUsed, onboardingStartedAt: startedAt, isInOnboardingWindow: isInWindow)
    }

    func canUse(uid: String, kind: SmartActionKind, remote: SmartActionLimits) async throws -> Bool {
        let cost = remote.cost(for: kind)
        let usage = try await fetchUsage(uid: uid)
        if usage.isInOnboardingWindow, usage.onboardingUsed + cost <= remote.onboardingLimit {
            return true
        }
        return usage.weeklyUsed + cost <= remote.weeklyLimit
    }

    /// Consumes a Smart Action after the paid backend action succeeds.
    ///
    /// Previous builds used Firestore.runTransaction here. On recent simulator / Firebase SDK
    /// combinations, that transaction could trip an internal Firestore queue assertion during
    /// the loading screen. This direct read/write path is intentionally simpler and avoids
    /// the crash while keeping the same product behavior for the current open/local-auth build.
    func consume(uid: String, kind: SmartActionKind, remote: SmartActionLimits) async throws {
        let cost = remote.cost(for: kind)
        let userRef = db.collection("users").document(uid)
        let onboardingRef = userRef.collection("usage").document("onboarding")
        let weekRef = userRef.collection("usage").document(Self.weekID())

        let onboardingSnap = try await onboardingRef.getDocument()
        let weekSnap = try await weekRef.getDocument()
        let onboardingData = onboardingSnap.data() ?? [:]
        let weekData = weekSnap.data() ?? [:]

        let startedAt = (onboardingData["startedAt"] as? Timestamp)?.dateValue() ?? Date()
        let onboardingUsed = onboardingData["used"] as? Int ?? 0
        let weeklyUsed = weekData["used"] as? Int ?? 0
        let onboardingExpires = Calendar.current.date(byAdding: .day, value: remote.onboardingDays, to: startedAt) ?? Date()
        let inOnboarding = Date() < onboardingExpires

        if !onboardingSnap.exists {
            try await onboardingRef.setData([
                "startedAt": FieldValue.serverTimestamp(),
                "used": 0,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }

        if inOnboarding, onboardingUsed + cost <= remote.onboardingLimit {
            try await onboardingRef.setData([
                "used": onboardingUsed + cost,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            try await weekRef.setData([
                "used": weeklyUsed + cost,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    func consumeIfAllowed(uid: String, kind: SmartActionKind, remote: SmartActionLimits) async throws -> Bool {
        guard try await canUse(uid: uid, kind: kind, remote: remote) else { return false }
        try await consume(uid: uid, kind: kind, remote: remote)
        return true
    }

    static func weekID(date: Date = Date()) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "week-\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
    }
}
