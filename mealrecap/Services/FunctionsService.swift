import Foundation

final class FunctionsService: @unchecked Sendable {
    private let region = "us-central1"
    private let projectID = "food-sbj"

    func analyzeMealText(text: String, date: Date) async throws -> MealAnalysisResult {
        let payload: [String: Any] = [
            "text": text,
            "date": FirestoreService.dayID(date)
        ]
        let raw = try await call("analyzeMealText", payload: payload)
        return try Self.decodeMealResult(raw)
    }

    func analyzeDayRecap(text: String, date: Date) async throws -> DayRecapResult {
        let payload: [String: Any] = [
            "text": text,
            "date": FirestoreService.dayID(date)
        ]
        let raw = try await call("analyzeDayRecap", payload: payload)
        guard let dict = raw as? [String: Any], let mealsRaw = dict["meals"] as? [[String: Any]] else {
            throw FunctionDecodeError.invalidResponse
        }
        let meals = try mealsRaw.map { try Self.decodeMealResult($0) }
        return DayRecapResult(meals: meals, assistantSummary: dict["assistantSummary"] as? String ?? "I organized your day.")
    }

    func analyzeMealPhoto(storagePath: String, date: Date) async throws -> MealAnalysisResult {
        let payload: [String: Any] = [
            "storagePath": storagePath,
            "date": FirestoreService.dayID(date)
        ]
        let raw = try await call("analyzeMealPhoto", payload: payload)
        return try Self.decodeMealResult(raw)
    }

    func ping() async throws -> [String: Any] {
        let raw = try await call("ping", payload: [:])
        return raw as? [String: Any] ?? [:]
    }

    @discardableResult
    func generateMealImage(uid: String, date: Date, meal: MealEntry) async throws -> [String: Any] {
        let itemMaps: [[String: Any]] = meal.items.map { item in
            var map: [String: Any] = [
                "id": item.id,
                "name": item.name,
                "calories": item.calories,
                "confidence": item.confidence
            ]
            if let estimatedGrams = item.estimatedGrams { map["estimatedGrams"] = estimatedGrams }
            if let servingDescription = item.servingDescription { map["servingDescription"] = servingDescription }
            if let protein = item.protein { map["protein"] = protein }
            if let carbs = item.carbs { map["carbs"] = carbs }
            if let fat = item.fat { map["fat"] = fat }
            return map
        }

        var payload: [String: Any] = [
            "uid": uid,
            "date": FirestoreService.dayID(date),
            "mealId": meal.id,
            "title": meal.title,
            "mealType": meal.mealType.rawValue,
            "items": itemMaps,
            "totalCalories": meal.calories,
            "calories": meal.calories,
            "macros": ["protein": meal.macros.protein, "carbs": meal.macros.carbs, "fat": meal.macros.fat]
        ]
        if let photoPath = meal.photoPath { payload["photoPath"] = photoPath }
        if let foodCategory = meal.foodCategory { payload["foodCategory"] = foodCategory }

        let raw = try await call("generateMealImage", payload: payload)
        return raw as? [String: Any] ?? [:]
    }

    @discardableResult
    func backfillMealImages(uid: String, date: Date) async throws -> [String: Any] {
        let payload: [String: Any] = [
            "uid": uid,
            "date": FirestoreService.dayID(date)
        ]
        let raw = try await call("backfillMealImages", payload: payload)
        return raw as? [String: Any] ?? [:]
    }


    private static func endpointName(for logicalName: String) -> String {
        switch logicalName {
        case "ping": return "mrv24Ping"
        case "analyzeMealText": return "mrv24AnalyzeMealText"
        case "analyzeDayRecap": return "mrv24AnalyzeDayRecap"
        case "analyzeMealPhoto": return "mrv24AnalyzeMealPhoto"
        case "generateMealImage": return "mrv24GenerateMealImage"
        case "backfillMealImages": return "mrv24BackfillMealImages"
        default: return logicalName
        }
    }

    private func call(_ name: String, payload: [String: Any]) async throws -> Any {
        var enrichedPayload = payload
        if let uid = LocalAuthStore.currentSession()?.uid {
            enrichedPayload["_localUserID"] = uid
            enrichedPayload["_clientAuthUID"] = uid
        }
        enrichedPayload["_clientSDK"] = "ios-urlsession"
        enrichedPayload["_authMode"] = "local-only"
        enrichedPayload["_clientSentAt"] = ISO8601DateFormatter().string(from: Date())

        let endpoint = Self.endpointName(for: name)
        let url = URL(string: "https://\(region)-\(projectID).cloudfunctions.net/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = name == "backfillMealImages" ? 600 : 240
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": enrichedPayload], options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BackendFunctionError(functionName: name, statusCode: statusCode, message: body.isEmpty ? "Backend returned non-JSON response from \(endpoint)." : body)
        }

        if let dict = object as? [String: Any], let error = dict["error"] as? [String: Any] {
            let message = error["message"] as? String ?? error["status"] as? String ?? "Backend function error."
            throw BackendFunctionError(functionName: name, statusCode: statusCode, message: message)
        }

        guard (200..<300).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BackendFunctionError(functionName: name, statusCode: statusCode, message: body.isEmpty ? "HTTP \(statusCode)" : body)
        }

        if let dict = object as? [String: Any] {
            if let result = dict["result"] { return result }
            if let data = dict["data"] { return data }
            return dict
        }

        throw FunctionDecodeError.invalidResponse
    }

    private static func decodeMealResult(_ raw: Any) throws -> MealAnalysisResult {
        guard let dict = raw as? [String: Any] else { throw FunctionDecodeError.invalidResponse }
        let itemsRaw = dict["items"] as? [[String: Any]] ?? []
        let items = itemsRaw.map { item -> FoodItem in
            FoodItem(
                id: item["id"] as? String ?? UUID().uuidString,
                name: item["name"] as? String ?? "Food",
                estimatedGrams: item["estimatedGrams"] as? Double,
                servingDescription: item["servingDescription"] as? String,
                calories: item["calories"] as? Int ?? 0,
                protein: item["protein"] as? Double,
                carbs: item["carbs"] as? Double,
                fat: item["fat"] as? Double,
                confidence: item["confidence"] as? Double ?? 0.7
            )
        }
        let macros = dict["macros"] as? [String: Any]
        return MealAnalysisResult(
            title: dict["title"] as? String ?? "Meal",
            mealType: MealType(rawValue: dict["mealType"] as? String ?? "unknown") ?? .unknown,
            items: items,
            totalCalories: dict["totalCalories"] as? Int ?? items.reduce(0) { $0 + $1.calories },
            macros: MacroSummary(protein: macros?["protein"] as? Double ?? 0, carbs: macros?["carbs"] as? Double ?? 0, fat: macros?["fat"] as? Double ?? 0),
            confidence: dict["confidence"] as? Double ?? 0.7,
            assistantSummary: dict["assistantSummary"] as? String ?? "Logged.",
            needsClarification: dict["needsClarification"] as? Bool ?? false,
            photoPath: dict["photoPath"] as? String,
            imageURL: dict["imageURL"] as? String,
            foodCategory: dict["foodCategory"] as? String,
            imageStatus: dict["imageStatus"] as? String
        )
    }

    enum FunctionDecodeError: LocalizedError {
        case invalidResponse
        var errorDescription: String? { "MealRecap received an invalid backend response." }
    }
}

struct BackendFunctionError: LocalizedError {
    let functionName: String
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        let lower = message.lowercased()

        if lower.contains("not found") || statusCode == 404 {
            return "MealRecap could not reach its meal analysis service. Please try again in a moment."
        }

        if lower.contains("openai") || lower.contains("api key") || lower.contains("invalid_api_key") {
            return "MealRecap could not complete the AI analysis right now. Please try again later."
        }

        if lower.contains("unauthenticated") || statusCode == 401 || statusCode == 403 {
            return "MealRecap could not connect securely right now. Please try again later."
        }

        return "MealRecap ran into a service issue. Please try again."
    }
}
