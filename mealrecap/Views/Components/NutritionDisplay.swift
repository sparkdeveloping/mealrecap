import Foundation

enum NutritionDisplay {
    static func rows(for details: NutritionDetails) -> [(String, String)] {
        var rows: [(String, String)] = []
        appendMg(details.sodiumMg, label: "Sodium", rows: &rows)
        appendG(details.fiberG, label: "Fiber", rows: &rows)
        appendG(details.sugarG, label: "Sugar", rows: &rows)
        appendG(details.addedSugarG, label: "Added sugar", rows: &rows)
        appendG(details.saturatedFatG, label: "Saturated fat", rows: &rows)
        appendG(details.transFatG, label: "Trans fat", rows: &rows)
        appendMg(details.cholesterolMg, label: "Cholesterol", rows: &rows)
        appendMg(details.potassiumMg, label: "Potassium", rows: &rows)
        appendMg(details.calciumMg, label: "Calcium", rows: &rows)
        appendIron(details.ironMg, rows: &rows)
        return rows
    }

    static func summary(for details: NutritionDetails, limit: Int = 3) -> String? {
        let values = rows(for: details).prefix(limit).map { "\($0.0) \($0.1)" }
        return values.isEmpty ? nil : values.joined(separator: "  ")
    }

    private static func appendG(_ value: Double?, label: String, rows: inout [(String, String)]) {
        guard let value else { return }
        rows.append((label, "\(Int(value.rounded()))g"))
    }

    private static func appendMg(_ value: Double?, label: String, rows: inout [(String, String)]) {
        guard let value else { return }
        rows.append((label, "\(Int(value.rounded()))mg"))
    }

    private static func appendIron(_ value: Double?, rows: inout [(String, String)]) {
        guard let value else { return }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            rows.append(("Iron", "\(Int(rounded))mg"))
        } else {
            rows.append(("Iron", String(format: "%.1fmg", rounded)))
        }
    }
}
