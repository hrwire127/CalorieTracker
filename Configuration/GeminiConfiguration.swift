import Foundation

enum GeminiConfiguration {
    static var apiKey: String {
        UserDefaults.standard.string(forKey: "GeminiApiKey") ?? ""
    }
    // Folosim un model din versiunile noi Gemini (ex: 3.5) care este disponibil
    static let model = "gemini-3.5-flash"
    static func generateContentURL(apiKey: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
    }

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate the calories. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123}."#
}
