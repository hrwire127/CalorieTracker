import Foundation

enum OpenAIConfiguration {
    static let apiKey = "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"
    static let visionModel = "gpt-5.5"
    static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    static let nutritionistSystemPrompt = #"You are a nutritionist. Analyze this food image and estimate the calories. Return ONLY valid JSON: {"food_name": "name", "estimated_calories": 123}."#
}
