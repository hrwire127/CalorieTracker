import Foundation

enum OpenAIConfiguration {
    static let apiKey = "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"
    static let visionModel = "gpt-5.5"
    static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate the calories. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123}."#
}
