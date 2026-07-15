import Foundation

typealias AIRequestProgressHandler = @Sendable (AIRequestProgressEvent) async -> Void

struct AIRequestProgressEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case active
        case success
        case warning
        case failure
    }

    let kind: Kind
    let title: String
    let detail: String?

    init(kind: Kind, title: String, detail: String? = nil) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

struct AIRequestProgressEntry: Identifiable, Equatable {
    let id: UUID
    let event: AIRequestProgressEvent

    init(event: AIRequestProgressEvent, id: UUID = UUID()) {
        self.id = id
        self.event = event
    }
}

extension NutritionEstimate {
    var aiProgressSummary: String {
        var parts = [
            foodName,
            "\(estimatedCalories) kcal"
        ]

        if let estimatedGrams {
            parts.append("\(estimatedGrams) g")
        }

        if let estimatedProteinGrams {
            parts.append("P \(estimatedProteinGrams)g")
        }

        if let estimatedCarbGrams {
            parts.append("C \(estimatedCarbGrams)g")
        }

        if let estimatedFatGrams {
            parts.append("F \(estimatedFatGrams)g")
        }

        if let healthScore {
            parts.append("Health \(healthScore)/10")
        }

        return parts.joined(separator: " | ")
    }
}
