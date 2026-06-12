import Foundation

enum OpenAIConfiguration {
    static var apiKey: String {
        UserDefaults.standard.string(forKey: "OpenAIApiKey") ?? ""
    }
    static let visionModel = "gpt-5.5"
    static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate the calories. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123}."#
}
