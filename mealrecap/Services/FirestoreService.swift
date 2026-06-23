import Foundation
import FirebaseFirestore

final class FirestoreService: @unchecked Sendable {
    private let db: Firestore

    init() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        self.db = firestore
    }

    func ensureProfile(uid: String) async throws {
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        if !snap.exists {
            try await ref.setData([
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "goalCalories": 2200,
                "displayName": "",
                "entitlements": ["isPro": false]
            ], merge: true)
        }
    }

    func updateOnboardingPreferences(uid: String, displayName: String?, goalCalories: Int, goalMode: String, proteinTarget: Int?, goalSetupMode: String? = nil, goalRecommendationSummary: String? = nil) async throws {
        var data: [String: Any] = [
            "goalCalories": goalCalories,
            "goalMode": goalMode,
            "updatedAt": FieldValue.serverTimestamp(),
            "onboardingCompletedAt": FieldValue.serverTimestamp()
        ]
        if let displayName, displayName.isEmpty == false {
            data["displayName"] = displayName
        }
        if let proteinTarget, proteinTarget > 0 {
            data["proteinTarget"] = proteinTarget
        }
        if let goalSetupMode, !goalSetupMode.isEmpty {
            data["goalSetupMode"] = goalSetupMode
        }
        if let goalRecommendationSummary, !goalRecommendationSummary.isEmpty {
            data["goalRecommendationSummary"] = goalRecommendationSummary
        }
        try await db.collection("users").document(uid).setData(data, merge: true)
        try await dayRef(uid: uid, date: Date()).setData([
            "goalCalories": goalCalories,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func fetchHasCompletedOnboarding(uid: String) async throws -> Bool {
        let snap = try await db.collection("users").document(uid).getDocument()
        let data = snap.data() ?? [:]
        if data["onboardingCompletedAt"] != nil { return true }
        return data["didCompleteOnboarding"] as? Bool ?? false
    }

    func fetchProteinTarget(uid: String) async throws -> Int? {
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let value = snap.data()?["proteinTarget"] as? Int, value > 0 else { return nil }
        return value
    }

    func fetchEntitlement(uid: String) async throws -> ProEntitlement {
        let snap = try await db.collection("users").document(uid).getDocument()
        let data = snap.data() ?? [:]
        guard let ent = data["entitlements"] as? [String: Any] else { return .free }
        return ProEntitlement(isPro: ent["isPro"] as? Bool ?? false,
                              expiresAt: (ent["expiresAt"] as? Timestamp)?.dateValue())
    }

    func updateEntitlement(uid: String, isPro: Bool, expiresAt: Date?) async throws {
        var entitlements: [String: Any] = ["isPro": isPro]
        if let expiresAt { entitlements["expiresAt"] = Timestamp(date: expiresAt) }
        try await db.collection("users").document(uid).setData([
            "entitlements": entitlements,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func ensureDay(uid: String, date: Date) async throws {
        let dayID = Self.dayID(date)
        let ref = dayRef(uid: uid, date: date)
        let snap = try await ref.getDocument()
        if !snap.exists {
            let profile = try await db.collection("users").document(uid).getDocument()
            let goal = profile.data()?["goalCalories"] as? Int ?? 2200
            try await ref.setData([
                "id": dayID,
                "date": Timestamp(date: Calendar.current.startOfDay(for: date)),
                "caloriesIn": 0,
                "activeCaloriesOut": 0,
                "restingCaloriesOut": 0,
                "totalCaloriesOut": 0,
                "netCalories": 0,
                "goalCalories": goal,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    func observeDay(uid: String, date: Date, onChange: @escaping (MealDay?) -> Void) -> ListenerRegistration {
        dayRef(uid: uid, date: date).addSnapshotListener { snap, _ in
            guard let snap, let data = snap.data() else { onChange(nil); return }
            onChange(MealDay.from(id: snap.documentID, data: data))
        }
    }

    func observeMeals(uid: String, date: Date, onChange: @escaping ([MealEntry]) -> Void) -> ListenerRegistration {
        dayRef(uid: uid, date: date)
            .collection("meals")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, _ in
                let meals = snap?.documents.compactMap { MealEntry.from(id: $0.documentID, data: $0.data()) } ?? []
                onChange(meals)
            }
    }

    func observeMessages(uid: String, date: Date, onChange: @escaping ([DayMessage]) -> Void) -> ListenerRegistration {
        dayRef(uid: uid, date: date)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snap, _ in
                let messages = snap?.documents.map { DayMessage.from(id: $0.documentID, data: $0.data()) } ?? []
                onChange(messages)
            }
    }

    func saveUserMessage(uid: String, date: Date, content: String, source: MealSource) async throws {
        try await dayRef(uid: uid, date: date).collection("messages").addDocument(data: [
            "role": "user",
            "content": content,
            "source": source.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func saveAssistantMessage(uid: String, date: Date, content: String) async throws {
        try await dayRef(uid: uid, date: date).collection("messages").addDocument(data: [
            "role": "assistant",
            "content": content,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func saveMealAnalysis(uid: String, date: Date, result: MealAnalysisResult, source: MealSource, presetMealId: String? = nil, photoPath: String? = nil, originPrompt: String? = nil) async throws {
        let ref = dayRef(uid: uid, date: date).collection("meals").document(presetMealId ?? UUID().uuidString)
        let itemMaps = result.items.map { item -> [String: Any] in
            var data: [String: Any] = [
                "id": item.id,
                "name": item.name,
                "calories": item.calories,
                "confidence": item.confidence
            ]
            if let estimatedGrams = item.estimatedGrams { data["estimatedGrams"] = estimatedGrams }
            if let servingDescription = item.servingDescription { data["servingDescription"] = servingDescription }
            if let protein = item.protein { data["protein"] = protein }
            if let carbs = item.carbs { data["carbs"] = carbs }
            if let fat = item.fat { data["fat"] = fat }
            if let nutritionDetails = item.nutritionDetails?.firestoreData, !nutritionDetails.isEmpty {
                data["nutritionDetails"] = nutritionDetails
            }
            return data
        }
        let resolvedPhotoPath = source == .camera ? (photoPath ?? result.photoPath) : (result.photoPath ?? photoPath)
        let resolvedImageStatus = result.imageStatus ?? ((resolvedPhotoPath?.isEmpty == false || result.imageURL?.isEmpty == false) ? "ready" : "none")
        var data: [String: Any] = [
            "title": result.title,
            "mealType": result.mealType.rawValue,
            "source": source.rawValue,
            "items": itemMaps,
            "calories": result.totalCalories,
            "macros": ["protein": result.macros.protein, "carbs": result.macros.carbs, "fat": result.macros.fat],
            "confidence": result.confidence,
            "assistantNote": result.assistantSummary,
            "imageStatus": resolvedImageStatus,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let originPrompt, originPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            data["originPrompt"] = originPrompt
        }
        if let foodCategory = result.foodCategory, foodCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            data["foodCategory"] = foodCategory
        }
        if let resolvedPhotoPath, resolvedPhotoPath.isEmpty == false { data["photoPath"] = resolvedPhotoPath }
        if let imageURL = result.imageURL, imageURL.isEmpty == false { data["imageURL"] = imageURL }
        if let imageKind = result.imageKind, imageKind.isEmpty == false { data["imageKind"] = imageKind }
        if let imageAlpha = result.imageAlpha, imageAlpha.isEmpty == false { data["imageAlpha"] = imageAlpha }
        if let imageStyleVersion = result.imageStyleVersion, imageStyleVersion.isEmpty == false { data["imageStyleVersion"] = imageStyleVersion }
        if let nutritionDetails = result.nutritionDetails?.firestoreData, !nutritionDetails.isEmpty {
            data["nutritionDetails"] = nutritionDetails
        }
        try await ref.setData(data, merge: true)
        try await recalculateDayTotals(uid: uid, date: date)
    }

    func deleteMeal(uid: String, date: Date, mealId: String) async throws {
        try await dayRef(uid: uid, date: date).collection("meals").document(mealId).delete()
        try await recalculateDayTotals(uid: uid, date: date)
    }

    func updateHealth(uid: String, date: Date, summary: HealthSummary) async throws {
        let snap = try await dayRef(uid: uid, date: date).getDocument()
        let caloriesIn = snap.data()?["caloriesIn"] as? Int ?? 0
        try await dayRef(uid: uid, date: date).setData([
            "activeCaloriesOut": summary.activeCalories,
            "restingCaloriesOut": summary.restingCalories,
            "totalCaloriesOut": summary.totalCalories,
            "steps": summary.steps,
            "netCalories": caloriesIn - summary.totalCalories,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }


    func updateMealImageState(uid: String, date: Date, mealId: String, photoPath: String?, imageURL: String?, imageStatus: String, imageKind: String? = nil, imageAlpha: String? = nil, imageStyleVersion: String? = nil) async throws {
        var data: [String: Any] = [
            "imageStatus": imageStatus,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let photoPath, photoPath.isEmpty == false { data["photoPath"] = photoPath }
        if let imageURL, imageURL.isEmpty == false { data["imageURL"] = imageURL }
        if let imageKind, imageKind.isEmpty == false { data["imageKind"] = imageKind }
        if let imageAlpha, imageAlpha.isEmpty == false { data["imageAlpha"] = imageAlpha }
        if let imageStyleVersion, imageStyleVersion.isEmpty == false { data["imageStyleVersion"] = imageStyleVersion }
        try await dayRef(uid: uid, date: date).collection("meals").document(mealId).setData(data, merge: true)
    }

    func updateMeal(uid: String, date: Date, meal: MealEntry, title: String, mealType: MealType, foodCategory: String?, assistantNote: String?) async throws {
        var data: [String: Any] = [
            "title": title,
            "mealType": mealType.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let foodCategory, !foodCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { data["foodCategory"] = foodCategory }
        if let assistantNote, !assistantNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { data["assistantNote"] = assistantNote }
        try await dayRef(uid: uid, date: date).collection("meals").document(meal.id).setData(data, merge: true)
    }

    func fetchCumulativeStats(uid: String) async throws -> CumulativeStats {
        let days = try await db.collection("users").document(uid).collection("days").getDocuments()
        var loggedDays = 0
        var totalMeals = 0
        var totalCalories = 0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var generatedPhotos = 0
        var categoryCounts: [String: Int] = [:]

        for day in days.documents {
            let meals = try await day.reference.collection("meals").getDocuments()
            if !meals.documents.isEmpty { loggedDays += 1 }
            for doc in meals.documents {
                let data = doc.data()
                totalMeals += 1
                totalCalories += data["calories"] as? Int ?? 0
                let macros = data["macros"] as? [String: Any]
                protein += macros?["protein"] as? Double ?? 0
                carbs += macros?["carbs"] as? Double ?? 0
                fat += macros?["fat"] as? Double ?? 0
                if let photoPath = data["photoPath"] as? String, !photoPath.isEmpty { generatedPhotos += 1 }
                if let category = data["foodCategory"] as? String, !category.isEmpty {
                    categoryCounts[category, default: 0] += 1
                } else if let mealType = data["mealType"] as? String, !mealType.isEmpty {
                    categoryCounts[mealType, default: 0] += 1
                }
            }
        }

        let divisor = max(totalMeals, 1)
        return CumulativeStats(
            loggedDays: loggedDays,
            totalMeals: totalMeals,
            totalCalories: totalCalories,
            averageCalories: loggedDays > 0 ? totalCalories / loggedDays : 0,
            averageProtein: Int((protein / Double(divisor)).rounded()),
            averageCarbs: Int((carbs / Double(divisor)).rounded()),
            averageFat: Int((fat / Double(divisor)).rounded()),
            generatedPhotos: generatedPhotos,
            topCategories: categoryCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key.capitalized }
        )
    }

    func deleteUser(uid: String) async throws {
        let userRef = db.collection("users").document(uid)
        let dayDocs = try await userRef.collection("days").getDocuments()
        for day in dayDocs.documents {
            try await deleteCollection(day.reference.collection("meals"))
            try await deleteCollection(day.reference.collection("messages"))
            try await day.reference.delete()
        }
        try await deleteCollection(userRef.collection("memory"))
        try await userRef.delete()
    }

    private func deleteCollection(_ collection: CollectionReference, batchSize: Int = 100) async throws {
        while true {
            let snapshot = try await collection.limit(to: batchSize).getDocuments()
            if snapshot.documents.isEmpty { return }
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            if snapshot.documents.count < batchSize { return }
        }
    }

    private func recalculateDayTotals(uid: String, date: Date) async throws {
        let mealDocs = try await dayRef(uid: uid, date: date).collection("meals").getDocuments()
        let caloriesIn = mealDocs.documents.reduce(0) { $0 + ($1.data()["calories"] as? Int ?? 0) }
        let daySnap = try await dayRef(uid: uid, date: date).getDocument()
        let totalOut = daySnap.data()?["totalCaloriesOut"] as? Int ?? 0
        try await dayRef(uid: uid, date: date).setData([
            "caloriesIn": caloriesIn,
            "netCalories": caloriesIn - totalOut,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func dayRef(uid: String, date: Date) -> DocumentReference {
        db.collection("users").document(uid).collection("days").document(Self.dayID(date))
    }

    static func dayID(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
