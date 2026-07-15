import Foundation

enum GeminiConfiguration {
    static let selectedModelKey = "GeminiSelectedModel"

    static var apiKey: String {
        UserDefaults.standard.string(forKey: "GeminiApiKey") ?? ""
    }

    static var selectedModel: GeminiModelOption {
        let rawValue = UserDefaults.standard.string(forKey: selectedModelKey)
        return GeminiModelOption.option(for: rawValue)
    }

    static var imageModel: String {
        selectedModel.rawValue
    }

    static var textModel: String {
        selectedModel.rawValue
    }

    static var imageFallbackModels: [String] {
        []
    }

    static var textFallbackModels: [String] {
        []
    }

    static func generateContentURL(model: String, apiKey: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "generativelanguage.googleapis.com"
        components.path = "/v1beta/models/\(model):generateContent"
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url!
    }

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate total calories, total food weight in grams, protein grams, carbohydrate grams, fat grams, and a health score from 1 to 10. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123, "estimated_grams": 250, "estimated_protein_grams": 30, "estimated_carb_grams": 40, "estimated_fat_grams": 12, "health_score": 7}."#

    static let nutritionTextGuessSystemPrompt = #"You are a nutritionist. Estimate total calories, protein grams, carbohydrate grams, fat grams, and a health score from 1 to 10 for the provided food and exact total weight. Use the provided weight as the exact total food weight. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123, "estimated_grams": 250, "estimated_protein_grams": 30, "estimated_carb_grams": 40, "estimated_fat_grams": 12, "health_score": 7}."#

    static func nutritionTextGuessUserPrompt(foodName: String, grams: Int) -> String {
        let cleanedFoodName = foodName
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "Food name: \(cleanedFoodName)\nTotal weight: \(grams) grams"
    }
}

enum GeminiModelOption: String, CaseIterable, Identifiable {
    case gemini31FlashLite = "gemini-3.1-flash-lite"
    case gemini35Flash = "gemini-3.5-flash"
    case gemini25Flash = "gemini-2.5-flash"
    case gemini25FlashLite = "gemini-2.5-flash-lite"
    case gemini31ProPreview = "gemini-3.1-pro-preview"

    var id: String { rawValue }

    static let defaultOption: GeminiModelOption = .gemini31FlashLite

    static func option(for rawValue: String?) -> GeminiModelOption {
        guard let rawValue,
              let option = GeminiModelOption(rawValue: rawValue) else {
            return defaultOption
        }

        return option
    }

    var title: String {
        switch self {
        case .gemini31FlashLite:
            return "3.1 Flash-Lite"
        case .gemini35Flash:
            return "3.5 Flash"
        case .gemini25Flash:
            return "2.5 Flash"
        case .gemini25FlashLite:
            return "2.5 Flash-Lite"
        case .gemini31ProPreview:
            return "3.1 Pro Preview"
        }
    }

    var detail: String {
        switch self {
        case .gemini31FlashLite:
            return "Default for this demo. Fast multimodal model."
        case .gemini35Flash:
            return "Newer Flash model. Can be busy depending on your quota."
        case .gemini25Flash:
            return "Stable 2.5 model. Use if your key has access."
        case .gemini25FlashLite:
            return "Cheaper/faster 2.5 option. Good fallback to try."
        case .gemini31ProPreview:
            return "Preview Pro model. Slower and access may be limited."
        }
    }
}
