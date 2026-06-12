import Foundation

enum GeminiConfiguration {
    static var apiKey: String {
        UserDefaults.standard.string(forKey: "GeminiApiKey") ?? ""
    }
    // Folosim varianta "latest" care este mereu activă în v1beta
    static let model = "gemini-1.5-flash-latest"
    static func generateContentURL(apiKey: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
    }

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate the calories. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123}."#
}
