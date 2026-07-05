import Foundation

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func estimateCalories(fromBase64Image base64Image: String) async throws -> NutritionEstimate {
        try await requestNutritionEstimate(
            parts: [
                GeminiPart(text: GeminiConfiguration.nutritionistSystemPrompt),
                GeminiPart(text: "Analyze this food image."),
                GeminiPart(inlineData: GeminiInlineData(mimeType: "image/jpeg", data: base64Image))
            ]
        )
    }

    func estimateNutrition(foodName: String, grams: Int) async throws -> NutritionEstimate {
        let cleanedFoodName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedFoodName.isEmpty, grams > 0 else {
            throw NetworkManagerError.invalidEstimate
        }

        return try await requestNutritionEstimate(
            parts: [
                GeminiPart(text: GeminiConfiguration.nutritionTextGuessSystemPrompt),
                GeminiPart(text: GeminiConfiguration.nutritionTextGuessUserPrompt(foodName: cleanedFoodName, grams: grams))
            ]
        )
    }

    private func requestNutritionEstimate(parts: [GeminiPart]) async throws -> NutritionEstimate {
        let apiKey = GeminiConfiguration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NetworkManagerError.missingAPIKey
        }

        var request = URLRequest(url: GeminiConfiguration.generateContentURL(apiKey: apiKey))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    role: "user",
                    parts: parts
                )
            ],
            generationConfig: GeminiGenerationConfig(responseMimeType: "application/json")
        )
        request.httpBody = try encoder.encode(requestBody)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw NetworkManagerError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkManagerError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(GeminiErrorResponse.self, from: data) {
                throw NetworkManagerError.apiError(apiError.error.message)
            }

            throw NetworkManagerError.apiError("Gemini request failed with status code \(httpResponse.statusCode).")
        }

        let completion = try decoder.decode(GeminiResponse.self, from: data)
        guard let candidate = completion.candidates.first,
              let contentPart = candidate.content.parts.first?.text,
              !contentPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NetworkManagerError.emptyResponse
        }

        let estimate = try decodeNutritionEstimate(from: contentPart)
        guard !estimate.foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              estimate.estimatedCalories > 0 else {
            throw NetworkManagerError.invalidEstimate
        }

        return estimate
    }

    private func decodeNutritionEstimate(from content: String) throws -> NutritionEstimate {
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleanedContent.data(using: .utf8),
           let estimate = try? decoder.decode(NutritionEstimate.self, from: data) {
            return estimate
        }

        guard let openingBrace = cleanedContent.firstIndex(of: "{"),
              let closingBrace = cleanedContent.lastIndex(of: "}") else {
            throw NetworkManagerError.decodingFailed
        }

        let jsonSlice = cleanedContent[openingBrace...closingBrace]
        guard let jsonData = String(jsonSlice).data(using: .utf8) else {
            throw NetworkManagerError.decodingFailed
        }

        do {
            return try decoder.decode(NutritionEstimate.self, from: jsonData)
        } catch {
            throw NetworkManagerError.decodingFailed
        }
    }
}

enum NetworkManagerError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case decodingFailed
    case invalidEstimate
    case transport(URLError)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please enter a valid Gemini API Key in the Settings."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .emptyResponse:
            return "The nutrition estimate was empty."
        case .decodingFailed:
            return "The nutrition estimate could not be parsed."
        case .invalidEstimate:
            return "The nutrition estimate did not include a valid food name and calories."
        case .transport(let error):
            return "Network request failed. \(error.localizedDescription)"
        case .apiError(let message):
            return message
        }
    }
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    init(text: String? = nil, inlineData: GeminiInlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

private struct GeminiResponsePart: Decodable {
    let text: String
}

private struct GeminiErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
