import Foundation
import FirebaseFirestore

struct UserSession: Equatable, Codable {
    let uid: String
    let email: String?
}

enum MealSource: String, Codable, CaseIterable {
    case text
    case voice
    case camera
    case dayRecap
    case manual
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    case drink
    case unknown

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

struct MacroSummary: Codable, Equatable, Hashable {
    var protein: Double
    var carbs: Double
    var fat: Double

    static let empty = MacroSummary(protein: 0, carbs: 0, fat: 0)
}

struct FoodItem: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var estimatedGrams: Double?
    var servingDescription: String?
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var confidence: Double

    init(id: String = UUID().uuidString,
         name: String,
         estimatedGrams: Double? = nil,
         servingDescription: String? = nil,
         calories: Int,
         protein: Double? = nil,
         carbs: Double? = nil,
         fat: Double? = nil,
         confidence: Double = 0.7) {
        self.id = id
        self.name = name
        self.estimatedGrams = estimatedGrams
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
    }
}

struct MealEntry: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var mealType: MealType
    var source: MealSource
    var items: [FoodItem]
    var calories: Int
    var macros: MacroSummary
    var confidence: Double
    var photoPath: String?
    var imageURL: String?
    var assistantNote: String?
    var originPrompt: String?
    var foodCategory: String?
    var imageStatus: String?
    var createdAt: Date
    var updatedAt: Date

    static func from(id: String, data: [String: Any]) -> MealEntry? {
        let title = data["title"] as? String ?? "Meal"
        let mealType = MealType(rawValue: data["mealType"] as? String ?? "unknown") ?? .unknown
        let source = MealSource(rawValue: data["source"] as? String ?? "manual") ?? .manual
        let calories = data["calories"] as? Int ?? 0
        let confidence = data["confidence"] as? Double ?? 0.7
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let photoPath = data["photoPath"] as? String
        let imageURL = data["imageURL"] as? String
        let assistantNote = data["assistantNote"] as? String
        let originPrompt = data["originPrompt"] as? String
        let foodCategory = data["foodCategory"] as? String
        let imageStatus = data["imageStatus"] as? String
        let macroData = data["macros"] as? [String: Any]
        let macros = MacroSummary(
            protein: macroData?["protein"] as? Double ?? 0,
            carbs: macroData?["carbs"] as? Double ?? 0,
            fat: macroData?["fat"] as? Double ?? 0
        )
        let itemMaps = data["items"] as? [[String: Any]] ?? []
        let items = itemMaps.map { item in
            FoodItem(
                id: item["id"] as? String ?? UUID().uuidString,
                name: item["name"] as? String ?? "Food",
                estimatedGrams: item["estimatedGrams"] as? Double,
                servingDescription: item["servingDescription"] as? String,
                calories: item["calories"] as? Int ?? 0,
                protein: item["protein"] as? Double,
                carbs: item["carbs"] as? Double,
                fat: item["fat"] as? Double,
                confidence: item["confidence"] as? Double ?? confidence
            )
        }
        return MealEntry(id: id, title: title, mealType: mealType, source: source, items: items, calories: calories, macros: macros, confidence: confidence, photoPath: photoPath, imageURL: imageURL, assistantNote: assistantNote, originPrompt: originPrompt, foodCategory: foodCategory, imageStatus: imageStatus, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct MealDay: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var date: Date
    var caloriesIn: Int
    var activeCaloriesOut: Int
    var restingCaloriesOut: Int
    var totalCaloriesOut: Int
    var netCalories: Int
    var goalCalories: Int
    var summary: String?
    var loggedDayCount: Int?

    static func from(id: String, data: [String: Any]) -> MealDay {
        let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        return MealDay(
            id: id,
            date: date,
            caloriesIn: data["caloriesIn"] as? Int ?? 0,
            activeCaloriesOut: data["activeCaloriesOut"] as? Int ?? 0,
            restingCaloriesOut: data["restingCaloriesOut"] as? Int ?? 0,
            totalCaloriesOut: data["totalCaloriesOut"] as? Int ?? 0,
            netCalories: data["netCalories"] as? Int ?? 0,
            goalCalories: data["goalCalories"] as? Int ?? 2200,
            summary: data["summary"] as? String,
            loggedDayCount: data["loggedDayCount"] as? Int
        )
    }
}

struct DayMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var role: String
    var content: String
    var source: MealSource?
    var createdAt: Date

    static func from(id: String, data: [String: Any]) -> DayMessage {
        DayMessage(
            id: id,
            role: data["role"] as? String ?? "assistant",
            content: data["content"] as? String ?? "",
            source: (data["source"] as? String).flatMap { MealSource(rawValue: $0) },
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

struct MealAnalysisResult: Codable, Equatable, Hashable {
    var title: String
    var mealType: MealType
    var items: [FoodItem]
    var totalCalories: Int
    var macros: MacroSummary
    var confidence: Double
    var assistantSummary: String
    var needsClarification: Bool
    var photoPath: String?
    var imageURL: String?
    var foodCategory: String?
    var imageStatus: String?
}

struct DayRecapResult: Codable, Equatable, Hashable {
    var meals: [MealAnalysisResult]
    var assistantSummary: String
}

struct HealthSummary: Codable, Equatable, Hashable {
    var activeCalories: Int
    var restingCalories: Int
    var totalCalories: Int
    var steps: Int

    static let empty = HealthSummary(activeCalories: 0, restingCalories: 0, totalCalories: 0, steps: 0)
}

struct ProEntitlement: Codable, Equatable, Hashable {
    var isPro: Bool
    var expiresAt: Date?
    static let free = ProEntitlement(isPro: false, expiresAt: nil)
}

enum PaywallReason: String, Identifiable {
    case general
    case textLimit
    case photoLimit
    case dayRecapLimit
    case loggedThreeDays
    case advancedInsight
    case firstPhotoSuccess
    case firstRecapSuccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoLimit, .firstPhotoSuccess: "Unlimited photo analysis"
        case .dayRecapLimit, .firstRecapSuccess: "Unlimited full-day recaps"
        case .textLimit: "Unlimited smart logging"
        case .loggedThreeDays: "Keep your food memory going"
        case .advancedInsight: "Unlock advanced insights"
        case .general: "MealRecap Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .photoLimit, .firstPhotoSuccess: "Snap meals, estimate portions, and get calories in seconds."
        case .dayRecapLimit, .firstRecapSuccess: "Dump everything you ate in one message and let MealRecap organize it."
        case .textLimit: "Chat your meals naturally without searching through databases."
        case .loggedThreeDays: "You’ve started a real streak. Pro keeps the experience unlimited."
        case .advancedInsight: "See weekly patterns, calorie balance, and smarter goal guidance."
        case .general: "Unlimited smart meal logging, photo analysis, voice recaps, and insights."
        }
    }
}

enum SmartActionKind: String, Codable, CaseIterable {
    case text
    case voice
    case photo
    case dayRecap

    var defaultCost: Int {
        switch self {
        case .text, .voice: 1
        case .dayRecap: 2
        case .photo: 3
        }
    }
}

struct SmartActionUsage: Codable, Equatable {
    var weeklyUsed: Int
    var onboardingUsed: Int
    var onboardingStartedAt: Date?
    var isInOnboardingWindow: Bool

    static let empty = SmartActionUsage(weeklyUsed: 0, onboardingUsed: 0, onboardingStartedAt: nil, isInOnboardingWindow: true)
}

struct SmartActionLimits: Equatable {
    var onboardingLimit = 12
    var onboardingDays = 7
    var weeklyLimit = 6
    var textCost = 1
    var voiceCost = 1
    var photoCost = 3
    var dayRecapCost = 2

    func cost(for kind: SmartActionKind) -> Int {
        switch kind {
        case .text: textCost
        case .voice: voiceCost
        case .photo: photoCost
        case .dayRecap: dayRecapCost
        }
    }
}


struct CumulativeStats: Equatable {
    var loggedDays: Int = 0
    var totalMeals: Int = 0
    var totalCalories: Int = 0
    var averageCalories: Int = 0
    var averageProtein: Int = 0
    var averageCarbs: Int = 0
    var averageFat: Int = 0
    var generatedPhotos: Int = 0
    var topCategories: [String] = []

    static let empty = CumulativeStats()
}
